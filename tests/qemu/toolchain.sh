# Sourced by xbuild.sh and xbuild-ctests.sh: the aarch64 cross toolchain of an OE build, used without
# bitbake (all of it read only).
#   XSYSROOT  an aarch64 sysroot with the Qt 6 headers and libraries (usr/include/QtCore/<version>,
#             usr/lib/libQt6*.so, usr/lib/metatypes)
#   SYSROOTS  the OE build's tmp/sysroots-components: x86_64/ gives the cross gcc and binutils, moc,
#             qtwaylandscanner (qtbase-native), qmltyperegistrar (qtdeclarative-native) and
#             wayland-scanner; cortexa53/ the qtsvg, mlite, wayland and mesa headers and libraries
#   B         the build dir; the assembler and linker links go to $B/xbin
# Defines X H TC MOC REG QWS WS CXX CC QI V QTINC and the helpers putf, stale and cxx.
: "${XSYSROOT:?XSYSROOT= an aarch64 sysroot with the Qt 6 headers and libraries}"
: "${SYSROOTS:?SYSROOTS= the OE build tmp/sysroots-components}"
: "${B:?B= the build dir}"
X=$XSYSROOT
H=$SYSROOTS/x86_64
TC=$SYSROOTS/cortexa53
for d in "$X/usr/include/QtCore" "$X/usr/lib" "$H/gcc-cross-aarch64" "$H/binutils-cross-aarch64" \
	"$H/qtbase-native/usr/libexec/moc" "$H/qtdeclarative-native/usr/libexec/qmltyperegistrar"; do
	[ -e "$d" ] || { echo "toolchain: missing $d" >&2; exit 2; }
done
LD_LIBRARY_PATH=
for l in libpcre2-native qtbase-native qtdeclarative-native zlib-native zstd-native icu-native glib-2.0-native \
	libffi-native openssl-native; do
	LD_LIBRARY_PATH=$LD_LIBRARY_PATH${LD_LIBRARY_PATH:+:}$H/$l/usr/lib
done
export LD_LIBRARY_PATH
export LC_ALL=C.UTF-8
MOC=$H/qtbase-native/usr/libexec/moc
REG=$H/qtdeclarative-native/usr/libexec/qmltyperegistrar
QWS=$H/qtbase-native/usr/libexec/qtwaylandscanner
WS=$H/wayland-native/usr/bin/wayland-scanner
mkdir -p "$B/xbin"
ln -sfn "$H/binutils-cross-aarch64/usr/bin/aarch64-oe-linux/aarch64-oe-linux-as" "$B/xbin/as"
ln -sfn "$H/binutils-cross-aarch64/usr/bin/aarch64-oe-linux/aarch64-oe-linux-ld" "$B/xbin/ld"
CXX="$H/gcc-cross-aarch64/usr/bin/aarch64-oe-linux/aarch64-oe-linux-g++ -B$B/xbin/"
CC="$H/gcc-cross-aarch64/usr/bin/aarch64-oe-linux/aarch64-oe-linux-gcc -B$B/xbin/"
QI=$X/usr/include
V=$(ls "$QI/QtCore" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
[ -n "$V" ] || { echo "toolchain: no Qt version directory in $QI/QtCore" >&2; exit 2; }
QTINC="-I$QI -I$QI/QtQmlIntegration"
for m in QtCore QtGui QtQml QtQuick QtDBus QtQmlModels QtQmlMeta QtWaylandClient QtWaylandGlobal QtTest; do
	QTINC="$QTINC -I$QI/$m -I$QI/$m/$V -I$QI/$m/$V/$m"
done

# putf NEW DST: move NEW over DST only when they differ (generated files keep their time otherwise)
putf() { if cmp -s "$1" "$2"; then rm -f "$1"; else mv -f "$1" "$2"; fi; }
# stale OBJ SRC: OBJ is missing, or older than SRC or than anything SRC included when it was built
stale() {
	[ -n "${FORCE:-}" ] && return 0
	[ -f "$1" ] && [ -f "$1.d" ] || return 0
	[ "$2" -nt "$1" ] && return 0
	for d in $(sed -e 's/^[^:]*://' -e 's/\\$//' "$1.d"); do
		[ "$d" -nt "$1" ] && return 0
	done
	return 1
}
# cxx OBJ SRC FLAGS...: compile SRC when OBJ is stale, noting its includes in OBJ.d
cxx() {
	o=$1; f=$2; shift 2
	stale "$o" "$f" || return 0
	echo "CXX ${f##*/}"
	$CXX "$@" -MMD -MF "$o.d" -c "$f" -o "$o"
}
