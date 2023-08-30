# Primate

Throughput-Oriented Accelerator Generator

## Prerequisites
- Linux OS (tested on Ubuntu 20.04/22.04)
- Chisel3
- cmake
- ninja

### Install Chisel3
[Chisel3 setup guide](https://github.com/chipsalliance/chisel/blob/3.4-release/SETUP.md)

### Install Cmake
[Get Cmake](https://cmake.org/download/)

### Install Ninja
```bash
sudo apt-get update
sudo apt-get -y install ninja-build
```
NOTE: For some Linux distros, including CentOS, openSUSE, RHEL, Arch, macOS X, and Fedora, the default package manager is **yum**, not **apt-get**. To view your distro, run **cat /etc/*-release**


## Update submodules
```bash
git submodule update --init --recursive
```

## Compile Primate ArchGen
```bash
cd <primate home>/primate-arch-gen
mkdir build
cd build
cmake -G Ninja -DLLVM_TARGETS_TO_BUILD=host -DLLVM_ENABLE_PROJECTS=clang -DLLVM_PARALLEL_LINK_JOBS=1 -DLLVM_LINK_LLVM_DYLIB=true ../llvm/
ninja
```
NOTE: If you run into an error that reads
```CMake Error at CMakeLists.txt:3 (cmake_minimum_required):
  CMake 3.13.4 or higher is required.  You are running version 2.8.12.2
```
run
```cmake -G Ninja -DLLVM_TARGETS_TO_BUILD=host -DLLVM_ENABLE_PROJECTS=clang -DLLVM_PARALLEL_LINK_JOBS=1 -DLLVM_LINK_LLVM_DYLIB=true ../llvm/```

NOTE:
If you are getting a GCC version error that reads
```Host GCC version must be at least 5.1, your version is 4.8.5.```

simply remove the CMakeCache.txt file in the build directory:
```rm CMakeCache.txt```

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

