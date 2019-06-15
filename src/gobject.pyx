cdef class CGObject:
    """Manage GObject lifetime.

    """

    cdef GObject *pointer

    def __cinit__(self):
        self.pointer = NULL

    def __dealloc__(self):
        """Decreases the reference count of object.
         When its reference count drops to 0, the object is finalized
        (i.e. its memory is freed).
        """
        if self.pointer is not NULL:
            g_object_unref(self.pointer)

    @staticmethod
    cdef void marshall_image_progress(void *im, void *pointer, void *handle):
        cdef VipsImage *vi = <VipsImage *> im
        cdef VipsProgress *p = <VipsProgress *> pointer

        # the image we're passed is not reffed for us, so make a ref for us
        g_object_ref(vi)
        image = CImage.new(vi)
        progress = Progress.new(p)
        (<object> handle)(image, progress)

    def signal_connect(self, name, callback):
        """Connect to a signal on this object.

        The callback will be triggered every time this signal is issued on this
        instance. It will be passed the image ('self' here), and a single
        `void *` pointer from libvips. 
        
        The value of the pointer, if any, depends on the signal -- for
        example, ::eval passes a pointer to a `VipsProgress` struct.

        """

        g_signal_connect_data(<GObject *> self.pointer, to_bytes(name),
                              <GCallback> &CGObject.marshall_image_progress,
                              <void *> callback, NULL, 0)

cdef class Progress:
    cdef VipsProgress *pointer

    @staticmethod
    cdef Progress new(VipsProgress *ptr):
        cdef Progress py_obj = Progress()
        py_obj.pointer = <VipsProgress *> ptr
        return py_obj

    @property
    def run(self):
        return self.pointer.run

    @property
    def eta(self):
        return self.pointer.eta

    @property
    def percent(self):
        return self.pointer.percent
