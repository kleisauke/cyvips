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
# Disable the CPU frequency scaling while running the benchmark
sudo cpupower frequency-set --governor performance

# tune your system to run stable benchmarks
python3 -m pyperf system tune

python3 perf/operation-call-pyvips.py -o operation-call-pyvips.json
python3 -m pyperf stats operation-call-pyvips.json

python3 perf/operation-call-cyvips.py -o operation-call-cyvips.json
python3 -m pyperf stats operation-call-cyvips.json

# command to test if the difference is significant
python3 -m pyperf compare_to operation-call-pyvips.json operation-call-cyvips.json --table

# Prepare test-images
mkdir tmp/
vips colourspace perf/images/sample2.v tmp/t1.v srgb
vips replicate tmp/t1.v tmp/t2.v 20 15
vips extract_area tmp/t2.v tmp/x.tif[tile] 0 0 5000 5000
vips copy tmp/x.tif tmp/x.jpg
vipsheader tmp/x.jpg

python3 perf/pyvips-bench.py -o pyvips-bench.json
python3 -m pyperf stats pyvips-bench.json

python3 perf/cyvips-bench.py -o cyvips-bench.json
python3 -m pyperf stats cyvips-bench.json

python3 -m pyperf compare_to pyvips-bench.json cyvips-bench.json --table

# After benchmarking you can go back to the more conservative option
sudo cpupower frequency-set --governor powersave
```

| Benchmark      | operation-call-pyvips | operation-call-cyvips         |
| -------------- | --------------------- | ------------------------------|
| Operation.call | 70.7 us               | 18.5 us: 3.83x faster (-74%)  |

| Benchmark  | pyvips-bench | cyvips-bench               |
| ---------- | ------------ | ---------------------------|
| vips bench | 190 ms       | 189 ms: 1.01x faster (-1%) |

## Conclusion

In terms of performance, there's no significant difference between pyvips 
(using CFFI API mode) and cyvips (using Cython).
