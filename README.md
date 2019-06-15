# cyvips

An experiment in making a full Python binding for [libvips](https://github.com/libvips/libvips) using [Cython](https://cython.org/).

## Instructions

```bash
python3 setup.py build_ext --inplace
python3 test.py
```

## Debugging

```bash
cython --gdb src/cyvips.pyx
python3 setup.py build_ext --inplace --debug
cygdb . -- -ex r --args python3 test.py
```

## Benchmarks

```bash
# tune your system to run stable benchmarks
python3 -m pyperf system tune

python3 perf/operation-call-pyvips.py -o operation-call-pyvips.json
python3 -m pyperf stats operation-call-pyvips.json

python3 perf/operation-call-cyvips.py -o operation-call-cyvips.json
python3 -m pyperf stats operation-call-cyvips.json

# command to test if the difference is significant
python3 -m pyperf compare_to operation-call-pyvips.json operation-call-cyvips.json --table
```

| Benchmark      | operation-call-pyvips | operation-call-cyvips         |
| -------------- | --------------------- | ------------------------------|
| Operation.call | 70.7 us               | 18.5 us: 3.83x faster (-74%)  |
