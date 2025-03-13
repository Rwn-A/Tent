# Tent
A minimal Risc-V implementation. This is my first time implementing any emulator, first introduction to Risc and my second time using Zig.

## Building
There are three build files, a zig build, a build shell script and a makefile. The shell script is a convience that calls `zig build` and `make` with the same config. the makefile is for building the boot code into a binary and the zig build is for building the emulator. The emulator always requires a boot binary to exist at compile time. A user of the emulator may not need to make their own binaries or will have a radically different toolchain hence the seperation. When running `zig build` confirm a binary file exists in the out directory. The name of the expected file as well as the RAM and ROM specifications are configurable with the zig-build and the makefile through command line arguments. 

**I am not completely happy with the state of the build system for this project, it is subject to change.**

**Project has just begun, no documentation yet.**
