# Primate

Throughput-Oriented Accelerator Generator

## Prerequisites
- Linux OS (tested on Ubuntu 20.04/22.04)
- Chisel3
- cmake
- ninja

### Install Chisel3
[Chisel3 setup guide](https://github.com/chipsalliance/chisel3/blob/master/SETUP.md)

### Install Cmake
[Get Cmake](https://cmake.org/download/)

### Install Ninja
```bash
sudo apt-get update
sudo apt-get -y install ninja-build
```

## Update submodules
```bash
git submodule update --init --recuesive
```

## Compile Primate ArchGen
```bash
cd <primate home>/primate-arch-gen
mkdir build
cd build
cmake -G Ninja -DLLVM_TARGETS_TO_BUILD=host -DLLVM_ENABLE_PROJECTS=clang -DLLVM_PARALLEL_LINK_JOBS=1 -DLLVM_LINK_LLVM_DYLIB=true ../llvm/
ninja
```

## Primate Application
### Description
Primate application must be put in `<primate home>/primate-uarch/apps/<app name>`. 
Our example project, packet reassembler, is located at `<primate home>/primate-uarch/apps/pktReassembly`. It has 2 subdirectories, `sw` and `hw`, and a build script, `build.sh`. 
`sw` contains primate applications written in annotated C++, and a file containing input data, `input.txt`. The structure of input/output data, `input_t/output_t` must be defined in the source code. Each line in `input.txt` is one piece of input data packed.
`hw` contains the hardware implementations of blue function units written in Chisel or Verilog, and a file listing out the module names and port names of each blue function unit, `bfu_list.txt`. The format is shown below,
```
<module 0>
{
    <port 0>
    <port 1>
    ...
}
<module 1>
{
    <port 0>
    ...
}
...
```

### Build Primate Packet Reassembler
```bash
cd <primate home>/primate-uarch/apps/pktReassembly
./build.sh
```

### Simulate in Verilator
```bash
cd <primate home>/primate-uarch/chisel/Gorilla++/emulator
make verilator
```
A waveform file, `Top.vcd`, will be generated at `<project home>/primate-uarch/chisel/Gorilla++/test_run_dir/TopMainxxxx>/`.

### Generate Verilog files
```bash
cd <primate home>/primate-uarch/chisel/Gorilla++/emulator
make verilog
```
`Top.v` will be generated at `<project home>/primate-uarch/chisel/Gorilla++/Top.v`

