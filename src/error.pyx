class VipsError(Exception):
    """An error from vips.

    Attributes:
        message (str): a high-level description of the error
        detail (str): a string with some detailed diagnostics

    """

    def __init__(self, message, detail=None):
        self.message = message
        if detail is None:
            detail = to_unicode(vips_error_buffer())
            vips_error_clear()
        self.detail = detail

    def __str__(self):
        return '{0}\n  {1}'.format(self.message, self.detail)
