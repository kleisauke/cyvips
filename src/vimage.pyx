# https://stackoverflow.com/a/22409540
def _with_metaclass(mcls):
    def decorator(cls):
        body = vars(cls).copy()
        # clean out class body
        body.pop('__dict__', None)
        body.pop('__weakref__', None)

        return mcls(cls.__name__, cls.__bases__, body)

    return decorator

# metaclass for Image ... getattr on this implements the class methods
class ImageType(type):
    def __getattr__(cls, name):
        # logger.debug('ImageType.__getattr__ %s', name)

        def call_function(*args, **kwargs):
            return COperation.call(name, None, args, kwargs)

        return call_function

@_with_metaclass(ImageType)
class Image():
    @staticmethod
    def _imageize(self, value):
        # careful! self can be None if value is a 2D array
        if isinstance(value, CImage):
            return value
        elif _is_2D(value):
            return Image.new_from_array(value)
        else:
            return self.new_from_image(value)

    @staticmethod
    def new_from_array(array, scale=1.0, offset=0.0):
        """Create an image from a 1D or 2D array.

        A new one-band image with :class:`BandFormat` ``'double'`` pixels is
        created from the array. These image are useful with the libvips
        convolution operator :meth:`Image.conv`.

        Args:
            array (list[list[float]]): Create the image from these values.
                1D arrays become a single row of pixels.
            scale (float): Default to 1.0. What to divide each pixel by after
                convolution.  Useful for integer convolution masks.
            offset (float): Default to 0.0. What to subtract from each pixel
                after convolution.  Useful for integer convolution masks.

        Returns:
            A new :class:`Image`.

        Raises:
            :class:`.Error`

        """
        if not _is_2D(array):
            array = [array]

        height = len(array)
        width = len(array[0])

        n = width * height

        cdef double *a = <double *> g_malloc(n * sizeof(double))

        for y in range(0, height):
            for x in range(0, width):
                a[x + y * width] = array[y][x]

        vi = vips_image_new_matrix_from_array(width, height, a, n)
        if vi is NULL:
            raise VipsError('unable to make image from matrix')

        image = CImage.new(vi)
        image.set_type(CGValue.gdouble_type, 'scale', scale)
        image.set_type(CGValue.gdouble_type, 'offset', offset)

        return image

    @staticmethod
    def new_from_file(vips_filename, **kwargs):
        """Load an image from a file.

        This method can load images in any format supported by vips. The
        filename can include load options, for example::

            image = cyvips.Image.new_from_file('fred.jpg[shrink=2]')

        You can also supply options as keyword arguments, for example::

            image = cyvips.Image.new_from_file('fred.jpg', shrink=2)

        The full set of options available depend upon the load operation that
        will be executed. Try something like::

            $ vips jpegload

        at the command-line to see a summary of the available options for the
        JPEG loader.

        Loading is fast: only enough of the image is loaded to be able to fill
        out the header. Pixels will only be decompressed when they are needed.

        Args:
            vips_filename (str): The disc file to load the image from, with
                optional appended arguments.

        All loaders support at least the following options:

        Keyword args:
            memory (bool): If set True, load the image via memory rather than
                via a temporary disc file. See :meth:`.new_temp_file` for
                notes on where temporary files are created. Small images are
                loaded via memory by default, use ``VIPS_DISC_THRESHOLD`` to
                set the definition of small.
            access (Access): Hint the expected access pattern for the image.
            fail (bool): If set True, the loader will fail with an error on
                the first serious error in the file. By default, libvips
                will attempt to read everything it can from a damaged image.

        Returns:
            A new :class:`.Image`.

        Raises:
            :class:`.Error`

        """
        vips_filename = to_bytes(vips_filename)
        pointer = vips_filename_get_filename(vips_filename)
        filename = to_unicode_free(pointer)

        pointer = vips_filename_get_options(vips_filename)
        options = to_unicode_free(pointer)

        cdef const char *loader = vips_foreign_find_load(vips_filename)
        if loader is NULL:
            raise VipsError('unable to load from file {0}'.format(vips_filename))
        name = to_unicode(loader)

        kwargs['string_options'] = options

        return COperation.call(name, None, (filename,), kwargs)

cdef class CImage(CVipsObject):
    """Wrap a VipsImage object.

    """

    @staticmethod
    cdef CImage new(VipsImage *ptr):
        cdef CImage im = CImage()
        im.pointer = <GObject *> ptr
        return im

    @staticmethod
    def call_static(unicode name, *args, **kwargs):
        return COperation.call(name, None, args, kwargs)

    def call(self, unicode name, *args, **kwargs):
        return COperation.call(name, self, args, kwargs)

    def new_from_image(self, value):
        """Make a new image from an existing one.

        A new image is created which has the same size, format, interpretation
        and resolution as ``self``, but with every pixel set to ``value``.

        Args:
            value (float, list[float]): The value for the pixels. Use a
                single number to make a one-band image; use an array constant
                to make a many-band image.

        Returns:
            A new :class:`Image`.

        Raises:
            :class:`.Error`

        """

        pixel = (Image.black(1, 1) + value).cast(self.format)
        image = pixel.embed(0, 0, self.width, self.height,
                            extend='copy')
        image = image.copy(interpretation=self.interpretation,
                           xres=self.xres,
                           yres=self.yres,
                           xoffset=self.xoffset,
                           yoffset=self.yoffset)

        return image

    def copy_memory(self):
        """Copy an image to memory.

        A large area of memory is allocated, the image is rendered to that
        memory area, and a new image is returned which wraps that large memory
        area.

        Returns:
            A new :class:`Image`.

        Raises:
            :class:`.Error`

        """
        vi = vips_image_copy_memory(<VipsImage *> self.pointer)
        if vi is NULL:
            raise VipsError('unable to copy to memory')

        return CImage.new(vi)

    # writers

    def write_to_file(self, vips_filename, **kwargs):
        """Write an image to a file on disc.

        This method can save images in any format supported by vips. The format
        is selected from the filename suffix. The filename can include embedded
        save options, see :func:`Image.new_from_file`.

        For example::

            image.write_to_file('fred.jpg[Q=95]')

        You can also supply options as keyword arguments, for example::

            image.write_to_file('fred.jpg', Q=95)

        The full set of options available depend upon the load operation that
        will be executed. Try something like::

            $ vips jpegsave

        at the command-line to see a summary of the available options for the
        JPEG saver.

        Args:
            vips_filename (str): The disc file to save the image to, with
                optional appended arguments.

        Other arguments depend upon the save operation.

        Returns:
            None

        Raises:
            :class:`.Error`

        """
        vips_filename = to_bytes(vips_filename)
        pointer = vips_filename_get_filename(vips_filename)
        filename = to_unicode_free(pointer)

        pointer = vips_filename_get_options(vips_filename)
        options = to_unicode_free(pointer)

        cdef const char *saver = vips_foreign_find_save(vips_filename)
        if saver is NULL:
            raise VipsError('unable to write to file {0}'.format(vips_filename))
        name = to_unicode(saver)

        kwargs['string_options'] = options

        return COperation.call(name, self, (filename,), kwargs)

    def set_progress(self, progress):
        """Enable progress reporting on an image.

        When progress reporting is enabled, evaluation of the most downstream
        image from this image will report progress using the ::preeval, ::eval,
        and ::posteval signals.

        """

        vips_image_set_progress(<VipsImage *> self.pointer, progress)

    def get_typeof(self, name):
        """Get the GType of an item of metadata.

        Fetch the GType of a piece of metadata, or 0 if the named item does not
        exist. See :class:`GValue`.

        Args:
            name (str): The name of the piece of metadata to get the type of.

        Returns:
            The ``GType``, or 0.

        Raises:
            None

        """

        # on libvips before 8.5, property types must be fetched separately,
        # since built-in enums were reported as ints
        if not at_least_libvips(8, 5):
            gtype = super(CImage, self).get_typeof(name)
            if gtype != 0:
                return gtype

        return vips_image_get_typeof(<VipsImage *> self.pointer,
                                     to_bytes(name))

    def get(self, name):
        """Get an item of metadata.

        Fetches an item of metadata as a Python value. For example::

            orientation = image.get('orientation')

        would fetch the image orientation.

        Args:
            name (str): The name of the piece of metadata to get.

        Returns:
            The metadata item as a Python value.

        Raises:
            :class:`.Error`

        """

        # with old libvips, we must fetch properties (as opposed to
        # metadata) via VipsObject
        if not at_least_libvips(8, 5):
            gtype = super(CImage, self).get_typeof(name)
            if gtype != 0:
                return super(CImage, self).get(name)

        gv = CGValue()
        result = vips_image_get(<VipsImage *> self.pointer, to_bytes(name),
                                gv.pointer)
        if result != 0:
            raise VipsError('unable to get {0}'.format(name))

        return gv.get()

    def set_type(self, gtype, name, value):
        """Set the type and value of an item of metadata.

        Sets the type and value of an item of metadata. Any old item of the
        same name is removed. See :class:`GValue` for types.

        Args:
            gtype (int): The GType of the metadata item to create.
            name (str): The name of the piece of metadata to create.
            value (mixed): The value to set as a Python value. It is
                converted to the ``gtype``, if possible.

        Returns:
            None

        Raises:
            None

        """

        gv = CGValue()
        gv.set_type(gtype)
        gv.set(value)
        vips_image_set(<VipsImage *> self.pointer, to_bytes(name), gv.pointer)

    def __getattr__(self, name):
        """Divert unknown names to libvips.

        Unknown attributes are first looked up in the image properties as
        accessors, for example::

            width = image.width

        and then in the libvips operation table, where they become method
        calls, for example::

            new_image = image.invert()

        Use :func:`get` to fetch image metadata.

        A ``__getattr__`` on the metatype lets you call static members in the
        same way.

        Args:
            name (str): The name of the piece of metadata to get.

        Returns:
            Mixed.

        Raises:
            :class:`.Error`

        """

        # logger.debug('Image.__getattr__ %s', name)

        # scale and offset have default values
        if name == 'scale':
            if self.get_typeof('scale') != 0:
                return self.get('scale')
            else:
                return 1.0

        if name == 'offset':
            if self.get_typeof('offset') != 0:
                return self.get('offset')
            else:
                return 0.0

        # look up in props first (but not metadata)
        if super(CImage, self).get_typeof(name) != 0:
            return super(CImage, self).get(name)

        def call_function(*args, **kwargs):
            return COperation.call(name, self, args, kwargs)

        return call_function

    # operator overloads

    def __add__(self, other):
        if isinstance(other, Image):
            return self.add(other)
        else:
            return self.linear(1, other)
