#!/usr/bin/env python3

import cyvips

# print(dir(cyvips))

print('libvips version {}.{}.{}'.format(cyvips.version(0), cyvips.version(1), cyvips.version(2)))

im = cyvips.Image.black(100, 100, bands=1)

print('width = {0}'.format(im.width))
print('height = {0}'.format(im.height))

print('max = {0}'.format(im.max()))

im = cyvips.Image.new_from_array([[1, 2, 3], [4, 5, 6], [7, 8, 9]], 8, 128)

print('scale = {0}'.format(im.get('scale')))
print('offset = {0}'.format(im.get('offset')))
