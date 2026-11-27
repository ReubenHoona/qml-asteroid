#!/bin/sh
# Cross-builds the C++ tests (aarch64) for run-qemu.sh, with the toolchain of xbuild.sh:
#   tst_crownspeed  tests/crownspeed (plain C++) with src/controls/src/crownspeed.cpp
#   tst_flatmesh    tests/flatmesh (Qt Test) with the real flatmesh.cpp, flatmeshnode.cpp and spring.cpp
#                   and the in-memory MDConfItem of tests/flatmesh/stubs, as tests/flatmesh/CMakeLists.txt
#   tst_dateformat  tests/dateformat (Qt Test) with the real src/utils/src/dateformat.cpp and ICU, as
#                   tests/dateformat/CMakeLists.txt
#   tst_asteroidapp tests/asteroidapp (Qt Test) with the real src/app/localefollower.cpp (AsteroidApp's
#                   catalogues and the language follower) and the invented catalogues of
#                   tests/asteroidapp/i18n, made with the OE build's lrelease into $B/ctests/asteroidapp/i18n
# The CMakeLists.txt in those folders build the same for the host.
# usage: B=<build dir> XSYSROOT=<sysroot> SYSROOTS=<sysroots-components> [SRCTREE=<tree>] sh tests/qemu/xbuild-ctests.sh [crownspeed] [flatmesh] [dateformat] [asteroidapp]
# Output: $B/ctests/tst_crownspeed, $B/ctests/tst_flatmesh, $B/ctests/tst_dateformat, $B/ctests/tst_asteroidapp.
set -e
here=$(cd "$(dirname "$0")" && pwd)
C=${SRCTREE:-$(cd "$here/../.." && pwd)}
. "$here/toolchain.sh"
SRC=$C/src/controls/src
O=$B/ctests
want=${*:-crownspeed flatmesh dateformat asteroidapp}
for t in $want; do
	case $t in
	crownspeed)
		D=$O/crownspeed; mkdir -p "$D"
		FL="--sysroot=$X -std=gnu++17 -O2 -Wall -Wextra -I$SRC"
		cxx "$D/tst_crownspeed.o" "$C/tests/crownspeed/tst_crownspeed.cpp" $FL
		cxx "$D/crownspeed.o" "$SRC/crownspeed.cpp" $FL
		$CXX --sysroot="$X" -o "$O/tst_crownspeed" "$D/tst_crownspeed.o" "$D/crownspeed.o"
		echo "built $O/tst_crownspeed" ;;
	flatmesh)
		F=$C/tests/flatmesh; D=$O/flatmesh; mkdir -p "$D"
		# the stubs first: <MDConfItem> is the in-memory one
		INC="-I$F/stubs -I$SRC -I$D $QTINC"
		DEF="-DQT_NO_DEBUG -DQT_SHARED -DQT_TESTLIB_LIB -DQT_QML_LIB -DQT_QUICK_LIB -DQT_GUI_LIB -DQT_CORE_LIB"
		FL="--sysroot=$X -std=gnu++17 -O2 -fPIC -Wall -Wno-unused-parameter -include $F/qtcompat.h $DEF $INC"
		$CXX $FL -dM -E -x c++ /dev/null > "$D/moc_predefs.h.new"
		putf "$D/moc_predefs.h.new" "$D/moc_predefs.h"
		$MOC --include "$D/moc_predefs.h" $DEF $INC -o "$D/tst_flatmesh.moc.new" "$F/tst_flatmesh.cpp"
		putf "$D/tst_flatmesh.moc.new" "$D/tst_flatmesh.moc"
		MOCS=""
		for h in "$SRC/flatmesh.h" "$SRC/spring.h" "$F/stubs/mdconfitem.h"; do
			n=$(basename "$h" .h)
			$MOC --include "$D/moc_predefs.h" $DEF $INC -o "$D/moc_$n.cpp.new" "$h"
			putf "$D/moc_$n.cpp.new" "$D/moc_$n.cpp"
			MOCS="$MOCS $D/moc_$n.cpp"
		done
		ALL=""
		for f in "$F/tst_flatmesh.cpp" "$SRC/flatmesh.cpp" "$SRC/flatmeshnode.cpp" "$SRC/spring.cpp" \
			"$F/stubs/mdconfitem.cpp" $MOCS; do
			o=$D/$(basename "$f").o
			cxx "$o" "$f" $FL
			ALL="$ALL $o"
		done
		$CXX --sysroot="$X" -o "$O/tst_flatmesh" $ALL -L"$X/usr/lib" -lQt6Test -lQt6Quick -lQt6QmlModels \
			-lQt6Qml -lQt6QmlMeta -lQt6Gui -lQt6Core -Wl,--allow-shlib-undefined
		echo "built $O/tst_flatmesh" ;;
	dateformat)
		F=$C/tests/dateformat; U=$C/src/utils/src; D=$O/dateformat; mkdir -p "$D"
		INC="-I$U -I$D $QTINC"
		DEF="-DQT_NO_DEBUG -DQT_SHARED -DQT_TESTLIB_LIB -DQT_CORE_LIB"
		FL="--sysroot=$X -std=gnu++17 -O2 -fPIC -Wall -Wno-unused-parameter $DEF $INC"
		$CXX $FL -dM -E -x c++ /dev/null > "$D/moc_predefs.h.new"
		putf "$D/moc_predefs.h.new" "$D/moc_predefs.h"
		$MOC --include "$D/moc_predefs.h" $DEF $INC -o "$D/tst_dateformat.moc.new" "$F/tst_dateformat.cpp"
		putf "$D/tst_dateformat.moc.new" "$D/tst_dateformat.moc"
		$MOC --include "$D/moc_predefs.h" $DEF $INC -o "$D/moc_dateformat.cpp.new" "$U/dateformat.h"
		putf "$D/moc_dateformat.cpp.new" "$D/moc_dateformat.cpp"
		ALL=""
		for f in "$F/tst_dateformat.cpp" "$U/dateformat.cpp" "$D/moc_dateformat.cpp"; do
			o=$D/$(basename "$f").o
			cxx "$o" "$f" $FL
			ALL="$ALL $o"
		done
		$CXX --sysroot="$X" -o "$O/tst_dateformat" $ALL -L"$X/usr/lib" -lQt6Test -lQt6Core -licui18n -licuuc \
			-licudata -Wl,--allow-shlib-undefined
		echo "built $O/tst_dateformat" ;;
	asteroidapp)
		F=$C/tests/asteroidapp; A=$C/src/app; D=$O/asteroidapp; mkdir -p "$D/i18n"
		for ts in "$F"/i18n/*.ts; do
			"$H/qttools-native/usr/bin/lrelease" -silent "$ts" -qm "$D/i18n/$(basename "$ts" .ts).qm"
		done
		INC="-I$A -I$D $QTINC"
		DEF="-DQT_NO_DEBUG -DQT_SHARED -DQT_TESTLIB_LIB -DQT_QUICK_LIB -DQT_QML_LIB -DQT_GUI_LIB -DQT_DBUS_LIB -DQT_CORE_LIB"
		FL="--sysroot=$X -std=gnu++17 -O2 -fPIC -Wall -Wextra -Wno-unused-parameter $DEF $INC -DTST_I18N_DIR=\"$D/i18n\""
		$CXX $FL -dM -E -x c++ /dev/null > "$D/moc_predefs.h.new"
		putf "$D/moc_predefs.h.new" "$D/moc_predefs.h"
		$MOC --include "$D/moc_predefs.h" $DEF $INC -o "$D/tst_asteroidapp.moc.new" "$F/tst_asteroidapp.cpp"
		putf "$D/tst_asteroidapp.moc.new" "$D/tst_asteroidapp.moc"
		$MOC --include "$D/moc_predefs.h" $DEF $INC -o "$D/moc_localefollower.cpp.new" "$A/localefollower.h"
		putf "$D/moc_localefollower.cpp.new" "$D/moc_localefollower.cpp"
		ALL=""
		for f in "$F/tst_asteroidapp.cpp" "$A/localefollower.cpp" "$D/moc_localefollower.cpp"; do
			o=$D/$(basename "$f").o
			cxx "$o" "$f" $FL
			ALL="$ALL $o"
		done
		$CXX --sysroot="$X" -o "$O/tst_asteroidapp" $ALL -L"$X/usr/lib" -lQt6Test -lQt6Quick -lQt6QmlModels \
			-lQt6Qml -lQt6QmlMeta -lQt6Gui -lQt6DBus -lQt6Core -Wl,--allow-shlib-undefined
		echo "built $O/tst_asteroidapp" ;;
	*)
		echo "xbuild-ctests.sh: no C++ test $t" >&2; exit 2 ;;
	esac
done
