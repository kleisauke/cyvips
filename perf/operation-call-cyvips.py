#!/usr/bin/env python3
import pyperf
import cyvips


def operation_call(loops):
    range_it = range(loops)

    t0 = pyperf.perf_counter()

    for loops in range_it:
        _ = cyvips.Image.black(10, 10)

    return pyperf.perf_counter() - t0


runner = pyperf.Runner()
runner.bench_time_func('Operation.call', operation_call)
