#!/bin/sh
# Cross-builds the org.asteroid.controls plugin (aarch64) of a qml-asteroid tree without bitbake, as
# src/controls/CMakeLists.txt builds it: moc on every header with Q_OBJECT, Q_GADGET or Q_NAMESPACE,
# qmltyperegistrar for plugins.qmltypes and the type registrations, the asteroid-gestures Wayland
# protocol, then one shared library. Incremental: a source is compiled again when it or anything it
# included changed (FORCE=1 compiles everything).
# usage: B=<build dir> XSYSROOT=<sysroot> SYSROOTS=<sysroots-components> [SRCTREE=<tree>] sh tests/qemu/xbuild.sh
# Output: $B/libasteroidcontrolsplugin.so and $B/plugins.qmltypes. SRCTREE defaults to this checkout.
set -e
here=$(cd "$(dirname "$0")" && pwd)
C=${SRCTREE:-$(cd "$here/../.." && pwd)}
. "$here/toolchain.sh"
SRC=$C/src/controls/src
G=$B/gen
O=$B/obj
mkdir -p "$G/new" "$O"
INC="-I$SRC -I$G $QTINC -I$TC/qtsvg/usr/include -I$TC/qtsvg/usr/include/QtSvg -I$TC/mlite/usr/include/mlite6 -I$TC/wayland/usr/include -I$TC/mesa/usr/include"
DEF="-DQT_NO_DEBUG -DQT_PLUGIN -DQT_SHARED -DQT_DBUS_LIB -DQT_QML_LIB -DQT_QUICK_LIB -DQT_GUI_LIB -DQT_CORE_LIB -DQT_SVG_LIB -DQT_WAYLANDCLIENT_LIB"
FL="--sysroot=$X -std=gnu++17 -O2 -fPIC -fvisibility=default -Wall -Wno-unused-parameter $DEF $INC"
$CXX $FL -dM -E -x c++ /dev/null > "$G/new/moc_predefs.h"
putf "$G/new/moc_predefs.h" "$G/moc_predefs.h"
XML=$C/wayland-protocols/asteroid-gestures-unstable-v1.xml
P=asteroid-gestures-unstable-v1
$WS client-header "$XML" "$G/new/wayland-$P-client-protocol.h"
$WS private-code "$XML" "$G/new/wayland-$P-protocol.c"
(cd "$G/new" && $QWS client-header "$XML" > "qwayland-$P.h" && $QWS client-code "$XML" > "qwayland-$P.cpp")
for f in "wayland-$P-client-protocol.h" "wayland-$P-protocol.c" "qwayland-$P.h" "qwayland-$P.cpp"; do
	putf "$G/new/$f" "$G/$f"
done
# the mocs as AUTOMOC compiles them: one unit including all (some need a type another one's header defines)
JSONS=""
: > "$G/mocs_compilation.cpp.new"
for h in "$SRC"/*.h; do
	grep -q "Q_OBJECT\|Q_GADGET\|Q_NAMESPACE" "$h" || continue
	n=$(basename "$h" .h)
	# beside its final place: moc includes the header by a path relative to the output
	$MOC --include "$G/moc_predefs.h" $DEF $INC --output-json -o "$G/moc_$n.cpp.new" "$h"
	putf "$G/moc_$n.cpp.new" "$G/moc_$n.cpp"
	JSONS="$JSONS $G/moc_$n.cpp.new.json"
	echo "#include \"moc_$n.cpp\"" >> "$G/mocs_compilation.cpp.new"
done
putf "$G/mocs_compilation.cpp.new" "$G/mocs_compilation.cpp"
$MOC --collect-json -o "$G/controls_metatypes.json" $JSONS
FOREIGN=$(ls "$X"/usr/lib/metatypes/qt6core_metatypes.json "$X"/usr/lib/metatypes/qt6gui_metatypes.json \
	"$X"/usr/lib/metatypes/qt6qml_metatypes.json "$X"/usr/lib/metatypes/qt6quick_metatypes.json \
	"$X"/usr/lib/metatypes/qt6dbus_metatypes.json "$X"/usr/lib/metatypes/qt6qmlmodels_metatypes.json \
	"$X"/usr/lib/metatypes/qt6qmlmeta_metatypes.json 2>/dev/null | tr "\n" ",")
$REG --generate-qmltypes="$G/new/plugins.qmltypes" --import-name=org.asteroid.controls --major-version=1 \
	--minor-version=0 --foreign-types="${FOREIGN%,}" -o "$G/new/controls_qmltyperegistrations.cpp" \
	"$G/controls_metatypes.json"
putf "$G/new/plugins.qmltypes" "$G/plugins.qmltypes"
putf "$G/new/controls_qmltyperegistrations.cpp" "$G/controls_qmltyperegistrations.cpp"
rm -f "$G"/*.new.json
ALL=""
for f in "$SRC"/*.cpp "$G/mocs_compilation.cpp" "$G/qwayland-$P.cpp" "$G/controls_qmltyperegistrations.cpp"; do
	o=$O/$(basename "$f").o
	cxx "$o" "$f" $FL
	ALL="$ALL $o"
done
if stale "$O/wlproto.o" "$G/wayland-$P-protocol.c"; then
	$CC --sysroot="$X" -O2 -fPIC -I"$TC/wayland/usr/include" -MMD -MF "$O/wlproto.o.d" \
		-c "$G/wayland-$P-protocol.c" -o "$O/wlproto.o"
fi
L=$X/usr/lib
$CXX --sysroot="$X" -shared -o "$B/libasteroidcontrolsplugin.so" $ALL "$O/wlproto.o" -L"$L" -lQt6Quick -lQt6Qml \
	-lQt6QmlModels -lQt6QmlMeta -lQt6Gui -lQt6Core -lQt6DBus -lQt6WaylandClient -lQt6OpenGL \
	"$TC/qtsvg/usr/lib/libQt6Svg.so" "$TC/mlite/usr/lib/libmlite6.so" "$TC/wayland/usr/lib/libwayland-client.so" \
	-Wl,--no-undefined -Wl,--allow-shlib-undefined
cp "$G/plugins.qmltypes" "$B/plugins.qmltypes"
echo "built $B/libasteroidcontrolsplugin.so"
