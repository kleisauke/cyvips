# https://stackoverflow.com/a/32067984/10952119
# an exception just to confirm that the .so file is loaded instead of the .py file
raise ImportError("__init__.py loaded when cyvips.so should have been loaded")
