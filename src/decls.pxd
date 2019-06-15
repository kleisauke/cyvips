from libc.stdint cimport int64_t, uint64_t, uint32_t, uintptr_t

cdef extern from "<glib.h>" nogil:
    ctypedef int gint
    ctypedef bint gboolean
    ctypedef void *gpointer
    ctypedef char gchar
    ctypedef unsigned long gulong
    ctypedef uint32_t guint
    ctypedef int64_t gint64
    ctypedef uint64_t guint64
    ctypedef double gdouble
    ctypedef size_t gsize

    cdef gpointer g_malloc(gsize n_bytes)
    cdef gpointer g_malloc0(gsize n_bytes)
    cdef void g_free(gpointer data)

# These callbacks may raise exceptions or manipulate Python objects
cdef extern from "<glib-object.h>":
    ctypedef void (*GLogFunc)(const gchar *log_domain,
                              GLogLevelFlags log_level,
                              const gchar *message,
                              user_data)

    ctypedef void (*GCallback)()
    ctypedef void (*GClosureNotify)(gpointer data, GClosure *closure)

cdef extern from "<glib-object.h>" nogil:
    ctypedef uintptr_t GType

    ctypedef struct GValue:
        GType g_type
        guint64 data[2]

    cdef GValue *g_value_init(GValue *value, GType g_type)
    cdef void g_value_unset(GValue *value)

    cdef gpointer g_object_ref(gpointer object)
    cdef void g_object_unref(gpointer object)

    cdef const gchar *g_type_name(GType type)
    cdef GType g_type_from_name(const gchar *name)
    cdef GType g_type_fundamental(GType type_id)

    cdef void g_value_set_boolean(GValue *value, gboolean v_boolean)
    cdef void g_value_set_int(GValue *value, gint v_int)
    cdef void g_value_set_double(GValue *value, gdouble v_double)
    cdef void g_value_set_enum(GValue *value, gint v_enum)
    cdef void g_value_set_flags(GValue *value, guint v_flags)
    cdef void g_value_set_string(GValue *value, const gchar *v_string)
    cdef void g_value_set_object(GValue *value, gpointer v_object)

    cdef gboolean g_value_get_boolean(const GValue *value)
    cdef gint g_value_get_int(const GValue *value)
    cdef guint64 g_value_get_uint64(const GValue *value)
    cdef gdouble g_value_get_double(const GValue *value)
    cdef gint g_value_get_enum(const GValue *value)
    cdef guint g_value_get_flags(const GValue *value)
    cdef const gchar *g_value_get_string(const GValue *value)
    cdef gpointer g_value_get_object(const GValue *value)

    ctypedef struct GData:
        # opaque
        pass

    ctypedef struct GTypeClass:
        # opaque
        pass

    ctypedef struct GTypeInstance:
        GTypeClass *g_class

    ctypedef struct GObject:
        GTypeInstance g_type_instance
        guint ref_count
        gpointer qdata

    ctypedef struct GParamSpec:
        GTypeInstance g_type_instance

        const gchar *name
        guint flags
        GType value_type
        GType owner_type

        # rest opaque

    ctypedef struct GEnumValue:
        gint value

        const gchar *value_name
        const gchar *value_nick

    ctypedef struct GEnumClass:
        GTypeClass *g_type_class

        gint minimum
        gint maximum
        guint n_values
        GEnumValue *values

    cdef gpointer g_type_class_ref(GType type)

    cdef void g_object_set_property(GObject *object,
                                    const gchar *property_name,
                                    const GValue *value)

    cdef void g_object_get_property(GObject *object,
                                    const gchar *property_name,
                                    GValue *value)
    ctypedef struct GClosure:
        # opaque
        pass

    cdef gulong g_signal_connect_data(GObject *object,
                                      const gchar *detailed_signal,
                                      GCallback c_handler,
                                      gpointer data,
                                      GClosureNotify destroy_data,
                                      gint connect_flags)

    cdef enum GLogLevelFlags:
        # log flags
        G_LOG_FLAG_RECURSION
        G_LOG_FLAG_FATAL

        # GLib log levels
        G_LOG_LEVEL_ERROR  # always fatal
        G_LOG_LEVEL_CRITICAL
        G_LOG_LEVEL_WARNING
        G_LOG_LEVEL_MESSAGE
        G_LOG_LEVEL_INFO
        G_LOG_LEVEL_DEBUG

        G_LOG_LEVEL_MASK

    cdef guint g_log_set_handler(const gchar *log_domain,
                                 gint log_levels,
                                 GLogFunc log_func,
                                 gpointer user_data)
    cdef void g_log_remove_handler(const gchar *log_domain,
                                   guint handler_id)

# These callbacks may raise exceptions or manipulate Python objects
cdef extern from "<vips/vips.h>":
    ctypedef void *(*VipsArgumentMapFn)(VipsObject *object, GParamSpec *pspec,
                                        VipsArgumentClass *argument_class,
                                        VipsArgumentInstance *argument_instance,
                                        void *a, void *b)

    ctypedef void *(*VipsTypeMap2Fn)(GType type, void *a, void *b)

cdef extern from "<vips/vips.h>" nogil:
    ctypedef unsigned char VipsPel
    ctypedef int (*VipsCallbackFn)(void *a, void *b)

    cdef GType vips_blend_mode_get_type()
    cdef GType vips_band_format_get_type()

    cdef int vips_enum_from_nick(const char *domain,
                                 GType type, const char *str)
    cdef const char *vips_enum_nick(GType gtype, int value)

    cdef void vips_value_set_ref_string(GValue *value, const char *str)
    cdef void vips_value_set_array_double(GValue *value, const double *array, int n)
    cdef void vips_value_set_array_int(GValue *value, const int *array, int n)
    cdef void vips_value_set_array_image(GValue *value, int n)
    cdef void vips_value_set_blob(GValue *value, VipsCallbackFn free_fn,
                                  const void *data, size_t length)
    cdef void vips_value_set_blob_free(GValue *value, void *data,
                                       size_t length)

    cdef const char *vips_value_get_ref_string(const GValue *value,
                                               size_t *length)
    cdef double *vips_value_get_array_double(const GValue *value, int *n)
    cdef int *vips_value_get_array_int(const GValue *value, int *n)
    cdef void *vips_value_get_blob(const GValue *value, size_t *length)

    cdef void vips_image_set_progress(VipsImage *image, gboolean progress)

    ctypedef struct VipsObject:
        GObject parent_instance
        gboolean constructed
        gboolean static_object
        void *argument_table
        char *nickname
        char *description
        gboolean preclose
        gboolean close
        gboolean postclose
        size_t local_memory

    ctypedef struct VipsObjectClass:
        # opaque
        pass

    ctypedef struct VipsArgument:
        GParamSpec *pspec

    ctypedef struct VipsArgumentInstance:
        VipsArgument parent

        # opaque

    ctypedef enum VipsArgumentFlags:
        VIPS_ARGUMENT_NONE
        VIPS_ARGUMENT_REQUIRED
        VIPS_ARGUMENT_CONSTRUCT
        VIPS_ARGUMENT_SET_ONCE
        VIPS_ARGUMENT_SET_ALWAYS
        VIPS_ARGUMENT_INPUT
        VIPS_ARGUMENT_OUTPUT
        VIPS_ARGUMENT_DEPRECATED
        VIPS_ARGUMENT_MODIFY

    ctypedef struct VipsArgumentClass:
        VipsArgument parent

        VipsObjectClass *object_class
        VipsArgumentFlags flags
        int priority
        uint64_t offset

    cdef int vips_object_get_argument(VipsObject *object, const char *name,
                                      GParamSpec **pspec,
                                      VipsArgumentClass **argument_class,
                                      VipsArgumentInstance **argument_instance)

    cdef void vips_object_print_all()

    cdef int vips_object_set_from_string(VipsObject *object,
                                         const char *options)

    cdef const char *vips_object_get_description(VipsObject *object)

    cdef const char *g_param_spec_get_blurb(GParamSpec *pspec)

    ctypedef struct VipsImage:
        VipsObject parent_instance

        # opaque

    ctypedef struct VipsProgress:
        VipsImage *im

        int run
        int eta
        gint64 tpels
        gint64 npels
        int percent
        gpointer start

    cdef const char *vips_foreign_find_load(const char *filename)
    cdef const char *vips_foreign_find_load_buffer(const void *data,
                                                   size_t size)

    cdef const char *vips_foreign_find_save(const char *filename)
    cdef gchar **vips_foreign_get_suffixes()
    cdef const char *vips_foreign_find_save_buffer(const char *suffix)

    cdef VipsImage *vips_image_new_matrix_from_array(int width, int height,
                                                     const double *array,
                                                     int size)

    cdef VipsImage *vips_image_new_from_memory(const void *data,
                                               size_t size,
                                               int width, int height,
                                               int bands, int format)

    cdef void *vips_image_write_to_memory(VipsImage *image, size_t *size_out)

    cdef VipsImage *vips_image_copy_memory(VipsImage *image)

    cdef VipsImage **vips_value_get_array_image(const GValue *value, int *n)

    cdef GType vips_image_get_typeof(const VipsImage *image, const char *name)
    cdef int vips_image_get(const VipsImage *image, const char *name,
                            GValue *value_copy)
    cdef void vips_image_set(VipsImage *image, const char *name, GValue *value)
    cdef gboolean vips_image_remove(VipsImage *image, const char *name)

    cdef char *vips_filename_get_filename(const char *vips_filename)
    cdef char *vips_filename_get_options(const char *vips_filename)

    ctypedef struct VipsOperation:
        VipsObject parent_instance

        # opaque

    cdef VipsOperation *vips_operation_new(const char *name)

    cdef void *vips_argument_map(VipsObject *object,
                                 VipsArgumentMapFn fn, void *a, void *b)

    ctypedef struct VipsRegion:
        GObject parent_object

        # more

    cdef VipsRegion *vips_region_new(VipsImage *image)
    cdef VipsPel *vips_region_fetch(VipsRegion *region,
                                    int left, int top,
                                    int width, int height, size_t *len)
    cdef int vips_region_width(VipsRegion *region)
    cdef int vips_region_height(VipsRegion *region)

    cdef int vips_object_get_args(VipsObject *object, const char ***names,
                                  int **flags, int *n_args)

    cdef VipsOperation *vips_cache_operation_build(VipsOperation *operation)

    cdef void vips_object_unref_outputs(VipsObject *object)

    cdef int vips_operation_get_flags(VipsOperation *operation)

    cdef void vips_leak_set(gboolean leak)

    cdef char *vips_path_filename7(const char *path)
    cdef char *vips_path_mode7(const char *path)

    cdef GType vips_type_find(const char *basename, const char *nickname)
    cdef const char *vips_nickname_find(GType type)

    cdef void *vips_type_map(GType base, VipsTypeMap2Fn fn, void *a, void *b)

    cdef void vips_cache_set_max(int max)
    cdef int vips_cache_get_max()

    cdef void vips_cache_set_max_mem(size_t max_mem)
    cdef size_t vips_cache_get_max_mem()

    cdef void vips_cache_set_max_files(int max_files)
    cdef int vips_cache_get_max_files()

    cdef void vips_cache_set_trace(gboolean trace)

    cdef int vips_init(const char *argv0)
    cdef int vips_version(int flag)

    cdef const char *vips_error_buffer()
    cdef void vips_error_clear()
