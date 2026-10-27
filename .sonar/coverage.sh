#!/bin/sh
# Coverage of src/controls/src/flatmesh.{cpp,h} (the eos FlatMesh idle/unexposed hold) from tests/flatmesh, which
# builds the real flatmesh.cpp and flatmeshnode.cpp with an in-memory MDConfItem and drives a FlatMesh in offscreen
# windows. The QML (HandWritingKeyboard.qml) is not analysed by SonarQube.
# Run by ~/stacks/sonarqube/scan.sh in the image from .sonar/Dockerfile, cwd = the repository root.
# Local run: sh .sonar/coverage.sh (needs Qt 6 Quick/Test, cmake, gcc, gcovr); report .sonar-reports/cobertura.xml.
set -eu
out=.sonar-reports
build=$out/build
rm -rf "$build"
mkdir -p "$build"
cmake -S tests/flatmesh -B "$build" -DFLATMESH_COVERAGE=ON -DCMAKE_BUILD_TYPE=Debug > "$build/cmake.log"
cmake --build "$build" -j "${JOBS:-1}"
(cd "$build" && QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software ./tst_flatmesh)
gcovr --root . --filter 'src/controls/src/flatmesh\.(cpp|h)$' --object-directory "$build" \
  --exclude-unreachable-branches --cobertura "$out/cobertura.xml" --txt "$out/coverage.txt" "$build"
cat "$out/coverage.txt"
