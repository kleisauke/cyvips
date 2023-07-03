from libc.stdio cimport printf
from libc.stdlib cimport atexit as stdlib_atexit
import sys

cdef unsigned int _log_handler_id = 0

if vips_init(to_bytes(sys.argv[0])) != 0:
    raise VipsError('unable to init libvips')

cdef void log_handler_callback(const char *domain, int log_level, const char *message,
                               void *user_data) noexcept nogil:
    pass
    # printf("%s (%d): %s\n", domain, log_level, message)

_log_handler_id = g_log_set_handler('VIPS',
                                    GLogLevelFlags.G_LOG_LEVEL_DEBUG |
                                    GLogLevelFlags.G_LOG_LEVEL_INFO |
                                    GLogLevelFlags.G_LOG_LEVEL_MESSAGE |
                                    GLogLevelFlags.G_LOG_LEVEL_WARNING |
                                    GLogLevelFlags.G_LOG_LEVEL_CRITICAL |
                                    GLogLevelFlags.G_LOG_LEVEL_ERROR |
                                    GLogLevelFlags.G_LOG_FLAG_FATAL |
                                    GLogLevelFlags.G_LOG_FLAG_RECURSION,
                                    <GLogFunc> &log_handler_callback, NULL)

cdef void on_stdlib_atexit() noexcept nogil:
    global _log_handler_id
    if _log_handler_id > 0:
        g_log_remove_handler('VIPS', _log_handler_id)
        _log_handler_id = 0

stdlib_atexit(on_stdlib_atexit)
