# Host test of CrownSpeed (src/controls/src/crownspeed.{h,cpp}), the state machine of RotaryInput's
# crown-speed mode; plain C++, no Qt. Locally:
#   cmake -S tests/crownspeed -B build-crownspeed && cmake --build build-crownspeed && build-crownspeed/tst_crownspeed
# tests/run-qemu.sh cross-builds the same (tests/qemu/xbuild-ctests.sh) and runs it under qemu-aarch64.
cmake_minimum_required(VERSION 3.19)
project(tst_crownspeed LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CONTROLS ${CMAKE_CURRENT_SOURCE_DIR}/../../src/controls/src)
add_executable(tst_crownspeed tst_crownspeed.cpp ${CONTROLS}/crownspeed.cpp ${CONTROLS}/crownspeed.h)
target_include_directories(tst_crownspeed PRIVATE ${CONTROLS})
target_compile_options(tst_crownspeed PRIVATE -Wall -Wextra)

enable_testing()
add_test(NAME tst_crownspeed COMMAND tst_crownspeed)
