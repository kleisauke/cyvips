#!/usr/bin/env python

import sys
import pkgconfig
from Cython.Build import cythonize

from setuptools import setup, find_packages, Extension

# See https://pypi.python.org/pypi?%3Aaction=list_classifiers
cyvips_classifiers = [
    'Development Status :: 5 - Production/Stable',
    'Environment :: Console',
    'Intended Audience :: Developers',
    'Intended Audience :: Science/Research',
    'Topic :: Multimedia :: Graphics',
    'Topic :: Multimedia :: Graphics :: Graphics Conversion',
    'License :: OSI Approved :: MIT License',
    'Programming Language :: Python :: 2.7',
    'Programming Language :: Python :: 3',
    'Programming Language :: Python :: 3.3',
    'Programming Language :: Python :: 3.4',
    'Programming Language :: Python :: 3.5',
    'Programming Language :: Python :: 3.6',
    'Programming Language :: Cython',
    'Programming Language :: Python :: Implementation :: PyPy',
    'Programming Language :: Python :: Implementation :: CPython',
]

setup_deps = [
    'cython>=0.x',
    'pkgconfig',
]

install_deps = setup_deps

test_deps = [
    'cython>=0.x',
    'pytest',
    'pytest-flake8',
    'pyperf',
]

extras = {
    'test': test_deps,
    'doc': ['sphinx', 'sphinx_rtd_theme'],
}

vips_pc = pkgconfig.parse('vips')
vips_libs = vips_pc['libraries']
vips_library_dirs = vips_pc['library_dirs']
vips_include_dirs = vips_pc['include_dirs']

ext_modules = [
    Extension("cyvips",
              sources=["src/cyvips.pyx"],
              libraries=vips_libs,
              extra_compile_args=["-O3", "-ffast-math"],
              # extra_compile_args=["-g"],
              # extra_link_args=["-g"],
              library_dirs=vips_library_dirs,
              include_dirs=['src/'] + vips_include_dirs, )
]

pyvips_packages = find_packages(exclude=['docs', 'tests', 'examples'])

setup(name="cyvips",
      version='0.0.1',
      description='binding for the libvips image processing library using Cython',
      url='https://github.com/kleisauke/cyvips',
      author='Kleis Auke Wolthuizen',
      author_email='github@kleisauke.nl',
      license='MIT',
      classifiers=cyvips_classifiers,
      keywords='image processing',

      packages=pyvips_packages,
      setup_requires=setup_deps,
      install_requires=install_deps,
      ext_modules=cythonize(ext_modules,
                            language_level=sys.version_info[0],
                            compiler_directives={
                                'boundscheck': False,
                                'wraparound': False
                            }),
                            # gdb_debug=True),
      tests_require=test_deps,
      extras_require=extras,

      # we will try to compile as part of install, so we can't run in a zip
      zip_safe=False)
