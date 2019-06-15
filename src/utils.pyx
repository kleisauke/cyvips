from cpython.version cimport PY_MAJOR_VERSION

cdef char *to_bytes(s):
    """Convert to a byte string.
    
    Convert a Python unicode string to a utf-8-encoded byte string. You must
    call this on strings you pass to libvips.
    
    """

    if PY_MAJOR_VERSION == 3 and isinstance(s, str):
        s = (<str> s).encode('utf8')
    elif PY_MAJOR_VERSION < 3 and isinstance(s, unicode):
        s = (<unicode> s).encode('utf8')

    return s

cdef unicode to_unicode(const char*s):
    """Convert to a unicode string.
    
    If x is a byte string, assume it is utf-8 and decode to a Python unicode
    string. You must call this on text strings you get back from libvips.
    
    """

    if s is NULL:
        return u'NULL'
    else:
        return s.decode('UTF-8', 'strict')

cdef unicode to_unicode_with_length(const char *s, size_t length):
    if s is NULL:
        return u'NULL'
    else:
        return s[:length].decode('UTF-8', 'strict')

cdef unicode to_unicode_free(char *s):
    """Convert to a unicode string, and auto-free.
    
    As to_unicode(), but also free the GLib string.
    """

    try:
        return to_unicode(s)
    finally:
        g_free(s)

def leak_set(int leak):
    """Enable or disable libvips leak checking.

    With this enabled, libvips will check for object and area leaks on exit.
    Enabling this option will make libvips run slightly more slowly.
    
    """

    return vips_leak_set(leak)

def get_suffixes():
    """Get a list of all the filename suffixes supported by libvips.

    Returns:
        [string]

    """

    names = []

    if at_least_libvips(8, 8):
        array = vips_foreign_get_suffixes()
        i = 0
        while array[i] != NULL:
            name = to_unicode_free(array[i])
            if name not in names:
                names.append(name)
            i += 1
        g_free(array)

    return names

def version(int flag):
    """Get the major, minor or micro version number of the libvips library.
    Args:
        flag (int): Pass flag 0 to get the major version number, flag 1 to
            get minor, flag 2 to get micro.
    Returns:
        The version number,
    Raises:
        :class:`.Error`

    """

    value = vips_version(flag)
    if value < 0:
        raise VipsError('unable to get library version')

    return value

cdef bint at_least_libvips(int x, int y):
    """Is this at least libvips x.y?"""

    major = version(0)
    minor = version(1)

    return major > x or (major == x and minor >= y)

def path_filename7(filename):
    return to_unicode(vips_path_filename7(to_bytes(filename)))

def path_mode7(filename):
    return to_unicode(vips_path_mode7(to_bytes(filename)))

def type_find(basename, nickname):
    """Get the GType for a name.

    Looks up the GType for a nickname. Types below basename in the type
    hierarchy are searched.
    
    """

    return vips_type_find(to_bytes(basename), to_bytes(nickname))

def type_name(GType gtype):
    """Return the name for a GType."""

    return to_unicode(g_type_name(gtype))

def nickname_find(GType gtype):
    """Return the nickname for a GType."""

    return to_unicode(vips_nickname_find(gtype))

def type_from_name(name):
    """Return the GType for a name."""

    return g_type_from_name(to_bytes(name))

cdef void *type_map(GType gtype, VipsTypeMap2Fn cb):
    """Map fn over all child types of gtype."""

    return vips_type_map(gtype, cb, NULL, NULL)

def values_for_enum(GType gtype):
    """Get all values for a enum (gtype)."""

    g_type_class = g_type_class_ref(gtype)
    g_enum_class = <GEnumClass *> g_type_class

    values = []

    # -1 since we always have a "last" member.
    for i in range(g_enum_class.n_values - 1):
        value = to_unicode(g_enum_class.values[i].value_nick)
        values.append(value)

    return values

def cache_set_max(int mx):
    """Set the maximum number of operations libvips will cache."""
    vips_cache_set_max(mx)

def cache_set_max_mem(size_t mx):
    """Limit the operation cache by memory use."""
    vips_cache_set_max_mem(mx)

def cache_set_max_files(int mx):
    """Limit the operation cache by number of open files."""
    vips_cache_set_max_files(mx)

def cache_set_trace(int trace):
    """Turn on libvips cache tracing."""
    vips_cache_set_trace(trace)

# test for rectangular array of something
def _is_2D(array):
    if not isinstance(array, list):
        return False

    for x in array:
        if not isinstance(x, list):
            return False
        if len(x) != len(array[0]):
            return False

    return True
