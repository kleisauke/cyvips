# values for VipsArgumentFlags
_REQUIRED = 1
_CONSTRUCT = 2
_SET_ONCE = 4
_SET_ALWAYS = 8
_INPUT = 16
_OUTPUT = 32
_DEPRECATED = 64
_MODIFY = 128

# for VipsOperationFlags
_OPERATION_DEPRECATED = 8

cdef class COperation(CVipsObject):
    """Call libvips operations.

    This class wraps the libvips VipsOperation class.

    """

    @staticmethod
    cdef COperation new(VipsOperation *ptr):
        cdef COperation op = COperation()
        op.pointer = <GObject *> ptr
        return op

    @staticmethod
    cdef COperation new_from_name(unicode operation_name):
        vop = vips_operation_new(to_bytes(operation_name))
        if vop is NULL:
            raise VipsError('no such operation {0}'.format(operation_name))
        return COperation.new(vop)

    cdef set_value(self, name, int flags, CImage match_image, value):
        # if the object wants an image and we have a constant, _imageize it
        #
        # if the object wants an image array, _imageize any constants in the
        # array
        if match_image is not None:
            gtype = self.get_typeof(name)

            if gtype == CGValue.image_type:
                value = Image._imageize(match_image, value)
            elif gtype == CGValue.array_image_type:
                value = [Image._imageize(match_image, x)
                         for x in value]

        # MODIFY args need to be copied before they are set
        if (flags & _MODIFY) != 0:
            # logger.debug('copying MODIFY arg %s', name)
            # make sure we have a unique copy
            value = value.copy().copy_memory()

        self.set(name, value)

    cdef get_flags(self):
        return vips_operation_get_flags(<VipsOperation *> self.pointer)

    @staticmethod
    cdef void add_construct(VipsObject *object, GParamSpec *pspec,
                            VipsArgumentClass *argument_class,
                            VipsArgumentInstance *argument_instance,
                            void *a, void *b):
        flags = argument_class.flags
        if (flags & _CONSTRUCT) != 0:
            name = to_unicode(pspec.name)

            # libvips uses '-' to separate parts of arg names, but we
            # need '_' for Python
            name = name.replace('-', '_')

            (<list> a).append([name, flags])

    # this is slow ... call as little as possible
    cpdef list get_args(self):
        cdef const char ** p_names
        cdef int *p_flags
        cdef int n_args

        args = []

        if at_least_libvips(8, 7):
            result = vips_object_get_args(<VipsObject *> self.pointer,
                                          &p_names, &p_flags, &n_args)

            if result != 0:
                raise VipsError('unable to get arguments from operation')

            for i in range(n_args):
                flags = p_flags[i]
                if (flags & _CONSTRUCT) != 0:
                    name = to_unicode(p_names[i])

                    # libvips uses '-' to separate parts of arg names, but we
                    # need '_' for Python
                    name = name.replace('-', '_')

                    args.append([name, flags])
        else:
            vips_argument_map(<VipsObject *> self.pointer,
                              <VipsArgumentMapFn> &COperation.add_construct,
                              <void *> args,
                              NULL)
        return args

    # TODO static cpdef methods are not yet supported,
    # so this isn't visible in Python
    @staticmethod
    cdef call(unicode operation_name, CImage match_image, tuple args,
              dict kwargs):
        """Call a libvips operation.

        Use this method to call any libvips operation. For example::

            black_image = COperation.call(u'black', 10, 10)

        See the Introduction for notes on how this works.

        """

        args_len = len(args)

        # pull out the special string_options kwarg
        string_options = kwargs.pop('string_options', '')

        op = COperation.new_from_name(operation_name)

        arguments = op.get_args()

        required_output = []
        optional_output = []

        # set any string options before any args so they can't be
        # overridden
        if not op.set_string(string_options):
            raise VipsError('unable to call {0}'.format(operation_name))

        n = 0
        member_x = match_image is None
        for name, flags in arguments:
            # fetch required output args, plus modified input images
            if ((flags & _OUTPUT) != 0 and
                    (flags & _REQUIRED) != 0 and
                    (flags & _DEPRECATED) == 0 or
                    (flags & _INPUT) != 0 and
                    (flags & _MODIFY) != 0):
                required_output.append(name)

            # fetch and set optional args
            if (flags & _REQUIRED) == 0 and name in kwargs:
                # log when an deprecated argument is used
                if (flags & _DEPRECATED) != 0:
                    pass
                    # TODO: Arghh, we don't have a logger here.
                    # logger.info('argument {0} for operation {1} '
                    #             'is deprecated', name, operation_name)

                value = kwargs.pop(name)
                op.set_value(name, flags, match_image, value)

                if (flags & _OUTPUT) != 0:
                    optional_output.append(name)

                continue

            # set required input args
            if ((flags & _INPUT) != 0 and
                (flags & _REQUIRED) != 0 and
                (flags & _DEPRECATED) == 0):
                # the first required input image arg will be self
                if not member_x and op.get_typeof(name) == CGValue.image_type:
                    op.set_value(name, flags, None, match_image)
                    member_x = True
                else:
                    if n > args_len:
                        break

                    value = args[n]
                    op.set_value(name, flags, match_image, value)
                    n += 1

        if n != args_len:
            raise VipsError('unable to call {0}: {1} arguments given, '
                            'but {2} required'.format(operation_name, len(args), n))

        if len(kwargs) > 0:
            raise VipsError('{0} does not support argument(s): '
                            '{1}'.format(operation_name, ', '.join(kwargs.keys())))

        # build operation
        vop = vips_cache_operation_build(<VipsOperation *> op.pointer)
        if vop is NULL:
            raise VipsError('unable to call {0}'.format(operation_name))

        op = COperation.new(vop)

        # fetch required output args, plus modified input images
        result = []
        for name in required_output:
            value = op.get(name)
            result.append(value)

        # fetch optional output args
        if len(optional_output) > 0:
            opts = {}
            for name in optional_output:
                value = op.get(name)
                opts[name] = value

            result.append(opts)

        vips_object_unref_outputs(<VipsObject *> op.pointer)

        if len(result) == 0:
            result = None
        elif len(result) == 1:
            result = result[0]

        return result
