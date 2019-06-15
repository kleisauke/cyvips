from libc.string cimport memmove

cdef class CGValue:
    """Wrap GValue in a Cython class.

    This class wraps :class:`.GValue` in a convenient interface. You can use
    instances of this class to get and set :class:`.GObject` properties.

    On construction, :class:`.GValue` is all zero (empty). You can pass it to
    a get function to have it filled by :class:`.GObject`, or use init to
    set a type, set to set a value, then use it to set an object property.

    GValue lifetime is managed automatically.

    """

    cdef GValue *pointer

    # look up some common gtypes at init for speed
    gbool_type = type_from_name('gboolean')
    gint_type = type_from_name('gint')
    guint64_type = type_from_name('guint64')
    gdouble_type = type_from_name('gdouble')
    gstr_type = type_from_name('gchararray')
    genum_type = type_from_name('GEnum')
    gflags_type = type_from_name('GFlags')
    gobject_type = type_from_name('GObject')
    image_type = type_from_name('VipsImage')
    array_int_type = type_from_name('VipsArrayInt')
    array_double_type = type_from_name('VipsArrayDouble')
    array_image_type = type_from_name('VipsArrayImage')
    refstr_type = type_from_name('VipsRefString')
    blob_type = type_from_name('VipsBlob')

    vips_band_format_get_type()
    format_type = type_from_name('VipsBandFormat')
    blend_mode_type = type_from_name('VipsBlendMode')

    if at_least_libvips(8, 6):
        vips_blend_mode_get_type()

    # map a gtype to the name of the corresponding Python type
    _gtype_to_python = {
        gbool_type: u'bool',
        gint_type: u'int',
        guint64_type: u'long',  # Note: int and long are unified in Python 3
        gdouble_type: u'float',
        gstr_type: u'str',
        refstr_type: u'str',
        genum_type: u'str',
        gflags_type: u'int',
        gobject_type: u'GObject',
        image_type: u'Image',
        array_int_type: u'list[int]',
        array_double_type: u'list[float]',
        array_image_type: u'list[Image]',
        blob_type: u'str'
    }

    @staticmethod
    cdef unicode gtype_to_python(GType gtype):
        """Map a gtype to the name of the Python type we use to represent it.
        
        """

        fundamental = g_type_fundamental(gtype)

        if gtype in CGValue._gtype_to_python:
            return CGValue._gtype_to_python[gtype]
        if fundamental in CGValue._gtype_to_python:
            return CGValue._gtype_to_python[fundamental]
        return u'<unknown type>'

    @staticmethod
    cdef int to_enum(GType gtype, value):
        """Turn a string into an enum value ready to be passed into libvips.
        
        """
        if type(value) is unicode:
            enum_value = vips_enum_from_nick(b'cyvips', gtype, to_bytes(value))
            if enum_value < 0:
                raise VipsError('no value {0} in gtype {1} ({2})'.
                                format(value, type_name(gtype), gtype))
        else:
            enum_value = value

        return enum_value

    @staticmethod
    cdef from_enum(GType gtype, int enum_value):
        """Turn an int back into an enum string.
        
        """

        pointer = vips_enum_nick(gtype, enum_value)
        if pointer is NULL:
            raise VipsError('value not in enum')

        return to_unicode(pointer)

    def __cinit__(self):
        self.pointer = <GValue *> g_malloc0(sizeof(GValue))

    cdef set_type(self, GType gtype):
        """Set the type of a GValue.

        GValues have a set type, fixed at creation time. Use set_type to set
        the type of a GValue before assigning to it.

        GTypes are 3 or 64-bit integers (depending on the platform). See
        type_find.

        """

        g_value_init(self.pointer, gtype)

    @staticmethod
    cdef int _vips_blob_free(void *buf, void *area) nogil:
        g_free(buf)

        return 0

    cdef set(self, value):
        """Set a GValue.
        
        The value is converted to the type of the GValue, if possible, and
        assigned.
        
        """

        cdef double[:] doubles
        cdef int[:] ints

        # logger.debug('GValue.set: value = %s', value)

        gtype = self.pointer.g_type
        fundamental = g_type_fundamental(gtype)

        if gtype == CGValue.gbool_type:
            g_value_set_boolean(self.pointer, value)
        elif gtype == CGValue.gint_type:
            g_value_set_int(self.pointer, value)
        elif gtype == CGValue.gdouble_type:
            g_value_set_double(self.pointer, value)
        elif fundamental == CGValue.genum_type:
            g_value_set_enum(self.pointer,
                             CGValue.to_enum(gtype, value))
        elif fundamental == CGValue.gflags_type:
            g_value_set_flags(self.pointer, value)
        elif gtype == CGValue.gstr_type:
            g_value_set_string(self.pointer, to_bytes(value))
        elif gtype == CGValue.refstr_type:
            vips_value_set_ref_string(self.pointer, to_bytes(value))
        elif fundamental == CGValue.gobject_type:
            g_value_set_object(self.pointer, (<CGObject> value).pointer)
        elif gtype == CGValue.array_int_type:
            if isinstance(value, int):
                value = [value]

            ints = value
            vips_value_set_array_int(self.pointer, &ints[0], len(value))
        elif gtype == CGValue.array_double_type:
            if isinstance(value, float):
                value = [value]

            doubles = value
            vips_value_set_array_double(self.pointer, &doubles[0],
                                        len(value))
        elif gtype == CGValue.array_image_type:
            if isinstance(value, Image):
                value = [value]

            size = len(value)

            vips_value_set_array_image(self.pointer, size)
            array = vips_value_get_array_image(self.pointer, NULL)

            for i in range(size):
                vi = <VipsImage *> (<CImage> value[i]).pointer
                g_object_ref(vi)
                array[i] = vi
        elif gtype == CGValue.blob_type:
            # we need to set the blob to a copy of the string that vips
            # can own
            buf = to_bytes(value)

            memory = g_malloc(len(value))
            memmove(memory, <void *> buf, len(value))

            if at_least_libvips(8, 6):
                vips_value_set_blob_free(self.pointer, memory, len(value))
            else:
                vips_value_set_blob(self.pointer,
                                    <VipsCallbackFn> &CGValue._vips_blob_free,
                                    memory, len(value))
        else:
            raise VipsError('unsupported gtype for set {0}, fundamental {1}'.
                            format(type_name(gtype), type_name(fundamental)))

    cdef get(self):
        """Get the contents of a GValue.

        The contents of the GValue are read out as a Python type.
        """
        cdef int pint
        cdef size_t psize

        gtype = self.pointer.g_type
        fundamental = g_type_fundamental(gtype)

        result = None

        if gtype == CGValue.gbool_type:
            result = bool(g_value_get_boolean(self.pointer))
        elif gtype == CGValue.gint_type:
            result = g_value_get_int(self.pointer)
        elif gtype == CGValue.guint64_type:
            result = g_value_get_uint64(self.pointer)
        elif gtype == CGValue.gdouble_type:
            result = g_value_get_double(self.pointer)
        elif fundamental == CGValue.genum_type:
            return CGValue.from_enum(gtype, g_value_get_enum(self.pointer))
        elif fundamental == CGValue.gflags_type:
            result = g_value_get_flags(self.pointer)
        elif gtype == CGValue.gstr_type:
            pointer = g_value_get_string(self.pointer)

            if pointer != NULL:
                result = to_unicode(pointer)
        elif gtype == CGValue.refstr_type:
            pointer = vips_value_get_ref_string(self.pointer, &psize)

            # psize will be number of bytes in string, but just assume it's
            # NULL-terminated
            result = to_unicode(pointer)
        elif gtype == CGValue.image_type:
            # g_value_get_object() will not add a ref ... that is
            # held by the gvalue
            vi = <VipsImage *> g_value_get_object(self.pointer)

            # we want a ref that will last with the life of the vimage:
            # this ref is matched by the unref that's attached to finalize
            # by Image()
            g_object_ref(vi)

            result = CImage.new(vi)
        elif gtype == CGValue.array_int_type:
            array = <int[:pint]> vips_value_get_array_int(self.pointer, &pint)

            result = []
            for i in range(pint):
                result.append(array[i])
        elif gtype == CGValue.array_double_type:
            array = <double[:pint]> vips_value_get_array_double(self.pointer, &pint)

            result = []
            for i in range(pint):
                result.append(array[i])
        elif gtype == CGValue.array_image_type:
            images = vips_value_get_array_image(self.pointer, &pint)

            result = []
            for i in range(pint):
                vi = <VipsImage *> images[i]
                g_object_ref(vi)
                result.append(CImage.new(vi))
        elif gtype == CGValue.blob_type:
            buf = <char *> vips_value_get_blob(self.pointer, &psize)

            result = to_unicode_with_length(buf, psize)
        else:
            raise VipsError('unsupported gtype for get {0}'.
                            format(type_name(gtype)))

        return result

    def __dealloc__(self):
        """Clears the current value in self.pointer (if any) and "unsets" the type,
        this releases all resources associated with this GValue.
        """
        if self.pointer is not NULL:
            g_value_unset(self.pointer)
