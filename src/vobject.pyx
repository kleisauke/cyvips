cdef class CVipsObject(CGObject):
    @staticmethod
    cdef print_all(msg):
        """Print all objects.

        Print a table of all active libvips objects. Handy for debugging.

        """
        vips_object_print_all()

    cdef GParamSpec *_get_pspec(self, name):
        cdef GParamSpec *pspec
        cdef VipsArgumentClass *argument_class
        cdef VipsArgumentInstance *argument_instance

        result = vips_object_get_argument(<VipsObject *> self.pointer,
                                          to_bytes(name),
                                          &pspec, &argument_class,
                                          &argument_instance)

        if result != 0:
            return NULL

        return pspec

    def get_typeof(self, name):
        """Get the GType of a GObject property.

        This function returns 0 if the property does not exist.

        """

        pspec = self._get_pspec(name)
        if pspec is NULL:
            # need to clear any error, this is horrible
            vips_error_clear()
            return 0

        return pspec.value_type

    cdef get_blurb(self, name):
        """Get the blurb for a GObject property."""
        c_str = g_param_spec_get_blurb(self._get_pspec(name))
        return to_unicode(c_str)

    def get(self, name):
        """Get a GObject property.

        The value of the property is converted to a Python value.

        """

        pspec = self._get_pspec(name)
        if pspec is NULL:
            raise VipsError('Property not found.')

        gtype = pspec.value_type

        gv = CGValue()
        gv.set_type(gtype)
        g_object_get_property(<GObject *> self.pointer, to_bytes(name),
                              gv.pointer)

        return gv.get()

    def set(self, name, value):
        """Set a GObject property.

        The value is converted to the property type, if possible.

        """

        gtype = self.get_typeof(name)

        gv = CGValue()
        gv.set_type(gtype)
        gv.set(value)
        g_object_set_property(<GObject *> self.pointer, to_bytes(name),
                              gv.pointer)

    cdef bint set_string(self, string_options):
        """Set a series of properties using a string.

        For example::

            'fred=12, tile'
            '[fred=12]'

        """

        result = vips_object_set_from_string(<VipsObject *> self.pointer,
                                             to_bytes(string_options))

        return result == 0

    cdef unicode get_description(self):
        """Get the description of a GObject."""

        return to_unicode(
            vips_object_get_description(<VipsObject *> self.pointer))
