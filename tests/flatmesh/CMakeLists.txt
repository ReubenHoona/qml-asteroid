# Host test of FlatMesh (src/controls/src/flatmesh.cpp): when it moves and when it stays still.
# Builds the real flatmesh.cpp, flatmeshnode.cpp and spring.cpp (ReduceMotion) against Qt 6 with an in-memory
# MDConfItem (stubs/), runs on the offscreen platform with the software Qt Quick backend. Locally:
#   cmake -S tests/flatmesh -B build-tests && cmake --build build-tests && \
#   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software build-tests/tst_flatmesh
# tests/run-qemu.sh cross-builds the same (tests/qemu/xbuild-ctests.sh) and runs it under qemu-aarch64.
cmake_minimum_required(VERSION 3.19)
project(tst_flatmesh LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Test)

set(CONTROLS ${CMAKE_CURRENT_SOURCE_DIR}/../../src/controls/src)
option(FLATMESH_COVERAGE "build with gcc --coverage" OFF)

add_executable(tst_flatmesh
    tst_flatmesh.cpp
    ${CONTROLS}/flatmesh.cpp ${CONTROLS}/flatmesh.h
    ${CONTROLS}/flatmeshnode.cpp ${CONTROLS}/flatmeshnode.h
    ${CONTROLS}/spring.cpp ${CONTROLS}/spring.h
    stubs/mdconfitem.cpp stubs/mdconfitem.h)
target_include_directories(tst_flatmesh PRIVATE stubs ${CONTROLS})
# Q_STATIC_LOGGING_CATEGORY is Qt 6.9; Debian has 6.8
target_compile_options(tst_flatmesh PRIVATE -include ${CMAKE_CURRENT_SOURCE_DIR}/qtcompat.h)
target_link_libraries(tst_flatmesh PRIVATE Qt::Core Qt::Gui Qt::Quick Qt::Test)
if(FLATMESH_COVERAGE)
    target_compile_options(tst_flatmesh PRIVATE --coverage -O0 -g)
    target_link_options(tst_flatmesh PRIVATE --coverage)
endif()

enable_testing()
add_test(NAME tst_flatmesh COMMAND tst_flatmesh)
set_tests_properties(tst_flatmesh PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
