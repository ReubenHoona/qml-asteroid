# Host test of DateFormat (src/utils/src/dateformat.{h,cpp}): its ranges under named zones and hand-written POSIX
# TZ strings. Qt 6 Core and Test, ICU. Locally:
#   cmake -S tests/dateformat -B build/dateformat && cmake --build build/dateformat && build/dateformat/tst_dateformat
# tests/run-qemu.sh cross-builds the same (tests/qemu/xbuild-ctests.sh) and runs it under qemu-aarch64.
cmake_minimum_required(VERSION 3.19)
project(tst_dateformat LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Test)
find_package(PkgConfig REQUIRED)
pkg_check_modules(ICU REQUIRED IMPORTED_TARGET icu-i18n icu-uc)

set(UTILS ${CMAKE_CURRENT_SOURCE_DIR}/../../src/utils/src)
add_executable(tst_dateformat tst_dateformat.cpp ${UTILS}/dateformat.cpp ${UTILS}/dateformat.h)
target_include_directories(tst_dateformat PRIVATE ${UTILS})
target_link_libraries(tst_dateformat PRIVATE Qt::Core Qt::Test PkgConfig::ICU)

enable_testing()
add_test(NAME tst_dateformat COMMAND tst_dateformat)
