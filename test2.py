#!/usr/bin/env python3

import sys
from cyvips import Image

last_percent = 0


def preeval_cb(image, progress):
    print('preeval')


def eval_cb(image, progress):
    global last_percent
    if progress.percent != last_percent:
        print('{}%, eta {}s'.format(progress.percent, progress.eta))
        last_percent = progress.percent


def posteval_cb(image, progress):
    print('posteval')


image = Image.new_from_file(sys.argv[1], access='sequential')
image.set_progress(True)
image.signal_connect('preeval', preeval_cb)
image.signal_connect('eval', eval_cb)
image.signal_connect('posteval', posteval_cb)
image.write_to_file(sys.argv[2])
