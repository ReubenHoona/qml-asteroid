#!/bin/sh
# Runs the qml-asteroid tests under qemu-aarch64 against a copy of an AsteroidOS image rootfs, without
# a device: tests/qml/tst_*.qml with the sysroot's qmltestrunner (offscreen platform, 384 x 384, the
# software Qt Quick backend) and the C++ tests of tests/crownspeed, tests/flatmesh and tests/dateformat,
# cross-built.
# org.asteroid.controls is this checkout: the plugin cross-built from it (tests/qemu/xbuild.sh, unless
# XB= names a build dir that holds one) and the QML of src/controls/qml, in an overlay that comes before
# the rootfs's imports; everything else (Qt, org.asteroid.utils, Nemo.*, fonts, icons) is the rootfs's.
# The rootfs and the checkout are only read; the run's files live in a fresh /tmp/qXXXXX folder.
#
# usage: R=<rootfs copy> QEMU=<qemu-aarch64> XSYSROOT=<sysroot> SYSROOTS=<sysroots-components> \
#        tests/run-qemu.sh [test ...]
#   test: tst_x.qml or tst_x (tests/qml), a path to a .qml file, crownspeed, flatmesh or dateformat;
#         none = all
# Prints a line per file (its totals, the binding-loop warnings it logged, its failures) and a grand
# total; exits 1 when a test failed, a file gave no totals (crash, timeout) or logged a binding loop.
#
# Environment:
#   R              the rootfs copy (tests/qemu/copy-rootfs.sh makes one), qemu -L      required
#   QEMU           the qemu-aarch64 (user mode) binary                                    required
#   XSYSROOT       aarch64 sysroot with the Qt 6 headers and libraries; its usr/bin/qmltestrunner runs the
#                  QML tests                                       required to build, or for the QML tests
#   SYSROOTS       the OE build's tmp/sysroots-components (cross gcc, moc, qmltyperegistrar, wayland
#                  scanners; qtsvg, mlite, wayland, mesa)                                 required to build
#   XB             a build dir with libasteroidcontrolsplugin.so and plugins.qmltypes to use as they are
#   BUILD          where the plugin and the C++ tests are built and the logs kept (default build/qemu-tests
#                  in this checkout; git ignores build/)
#   QMLTESTRUNNER  default $XSYSROOT/usr/bin/qmltestrunner
#   CONTACTS       an org.asteroid.contacts tree for tst_q4contacts.qml (skipped without it)
#   ICONS=1        the rootfs icons for every test (a test asks for them with "// run-qemu: icons")
#   SHOTS          a folder for the pictures tests save (default: the run folder, removed at the end)
#   TMO            seconds per file (default 900)      KEEP=1  keep the run folder
#   FAILS          failure lines shown per file (default 12)
#
# A test file can ask for more with a line "// run-qemu: WORD ...":
#   mocks     tests/qml/mocks first in the import path (Nemo.DBus double, VoiceTest)
#   icons     the controls plugin draws the rootfs icons (it reads /usr/share/icons/asteroid/, which
#             qemu -L does not redirect for it)
#   contacts  the contacts tree beside the test as ../org.asteroid.contacts, its QML as the module
#             org.asteroid.contacts with its ContactStore double, and its test mocks
set -u
here=$(cd "$(dirname "$0")" && pwd)
C=$(cd "$here/.." && pwd)
die() { echo "run-qemu.sh: $*" >&2; exit 2; }
[ -n "${R:-}" ] || die "R= the rootfs copy"
[ -n "${QEMU:-}" ] || die "QEMU= the qemu-aarch64 binary"
[ -x "$QEMU" ] || die "QEMU=$QEMU is not executable"
for f in etc/asteroid/machine.conf usr/lib/qml/org/asteroid/controls/qmldir usr/lib/qml/org/asteroid/utils/qmldir \
	usr/lib/qml/QtTest/qmldir; do
	[ -e "$R/$f" ] || die "R=$R has no $f"
done
B=${BUILD:-$C/build/qemu-tests}
TMO=${TMO:-900}
FAILS=${FAILS:-12}
mkdir -p "$B/logs" || die "cannot make $B"
# a build dir follows one checkout: the incremental build compares file times
if [ -f "$B/source" ] && [ "$(cat "$B/source")" != "$C" ]; then
	rm -rf "$B/controls" "$B/ctests"
fi
echo "$C" > "$B/source"

# ---- what to run ----
QMLS=""
CTESTS=""
if [ $# -eq 0 ]; then
	QMLS=$(cd "$C/tests/qml" && ls tst_*.qml | sed "s#^#$C/tests/qml/#")
	CTESTS="crownspeed flatmesh dateformat"
fi
for a in "$@"; do
	case $a in
	crownspeed|tst_crownspeed|flatmesh|tst_flatmesh|dateformat|tst_dateformat)
		CTESTS="$CTESTS ${a#tst_}" ;;
	*/*.qml)
		[ -f "$a" ] || die "no test $a"
		QMLS="$QMLS $(cd "$(dirname "$a")" && pwd)/$(basename "$a")" ;;
	*)
		a=${a%.qml}
		[ -f "$C/tests/qml/$a.qml" ] || die "no test tests/qml/$a.qml"
		QMLS="$QMLS $C/tests/qml/$a.qml" ;;
	esac
done

# ---- build ----
build() { # build LOG DIR CMD...: run CMD with B=DIR into LOG, say what it did, stop on a failure
	blog=$1; bdir=$2; shift 2
	t0=$(date +%s)
	if B=$bdir "$@" > "$blog" 2>&1; then :; else
		echo; tail -20 "$blog"; die "build failed: $blog"
	fi
	echo "$(grep -c "^CXX " "$blog") compiled in $(($(date +%s) - t0)) s"
}
if [ -n "$QMLS" ]; then
	if [ -n "${XB:-}" ]; then
		PB=$XB
		echo "plugin: $PB (XB, as it is)"
	else
		PB=$B/controls
		printf "plugin: cross-built from %s: " "$C"
		mkdir -p "$PB"
		build "$B/logs/xbuild.log" "$PB" env SRCTREE="$C" sh "$here/qemu/xbuild.sh"
	fi
	[ -f "$PB/libasteroidcontrolsplugin.so" ] && [ -f "$PB/plugins.qmltypes" ] \
		|| die "$PB has no libasteroidcontrolsplugin.so and plugins.qmltypes"
	QTR=${QMLTESTRUNNER:-${XSYSROOT:+$XSYSROOT/usr/bin/qmltestrunner}}
	[ -n "$QTR" ] && [ -f "$QTR" ] || die "QMLTESTRUNNER= or XSYSROOT= (for its usr/bin/qmltestrunner)"
fi
if [ -n "$CTESTS" ]; then
	printf "C++ tests %s: " "$(echo $CTESTS)"
	build "$B/logs/xbuild-ctests.log" "$B" env SRCTREE="$C" sh "$here/qemu/xbuild-ctests.sh" $CTESTS
fi

# ---- the run folder: its path is as long as /etc/asteroid, for the plugin patches ----
T=$(mktemp -d /tmp/qXXXXX) || die "mktemp"
[ ${#T} -eq 11 ] || die "run folder $T: not 11 characters"
[ -n "${KEEP:-}" ] || trap 'rm -rf "$T"' EXIT
trap 'exit 130' INT TERM
mkdir -p "$T/a" "$T/home" "$T/run" "$T/t" "$T/icons"
chmod 700 "$T/home"
cp "$R/etc/asteroid/machine.conf" "$T/a/machine.conf"
ln -s "$R/usr/share/icons/asteroid" "$T/icons/asteroi"
if [ -n "${SHOTS:-}" ]; then
	mkdir -p "$SHOTS" && ln -s "$(cd "$SHOTS" && pwd)" "$T/run/shots"
else
	mkdir "$T/run/shots"
fi
# plug SRC DST [icons]: a copy of a plugin that reads machine.conf (and the icons) from the run folder
plug() {
	cp "$1" "$2"
	python3 "$here/qemu/patch-path.py" "$2" /etc/asteroid/machine.conf "$T/a/machine.conf" > /dev/null || exit 2
	if [ "${3:-}" = icons ]; then
		python3 "$here/qemu/patch-path.py" "$2" /usr/share/icons/asteroid/ "$T/icons/asteroi/" > /dev/null || exit 2
	fi
}
# overlay DIR [icons]: org.asteroid.controls of this checkout and the rootfs org.asteroid.utils
overlay() {
	O=$1/org/asteroid/controls
	mkdir -p "$O" "$1/org/asteroid/utils"
	ln -s "$C/src/controls/qml" "$O/qml"
	plug "$PB/libasteroidcontrolsplugin.so" "$O/libasteroidcontrolsplugin.so" "${2:-}"
	cp "$PB/plugins.qmltypes" "$O/plugins.qmltypes"
	S=$(grep -o "qml/[A-Za-z]*\.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE" "$C/src/controls/CMakeLists.txt" \
		| sed "s#qml/##;s#\.qml.*##" | tr "\n" " ")
	{
		grep "^module \|^linktarget \|^optional plugin \|^classname " "$R/usr/lib/qml/org/asteroid/controls/qmldir"
		sed -n '/^set(controls$/,/^)/p' "$C/src/controls/CMakeLists.txt" | sed '1d;$d' | tr -d ' \t' \
			| while read -r cn; do
				[ -n "$cn" ] || continue
				case " $S " in *" $cn "*) echo "singleton $cn 1.0 qml/$cn.qml" ;; *) echo "$cn 1.0 qml/$cn.qml" ;; esac
			done
		echo "depends QtQuick"
	} > "$O/qmldir"
	for uf in "$R"/usr/lib/qml/org/asteroid/utils/*; do
		un=$(basename "$uf")
		case $un in
		*.so) plug "$uf" "$1/org/asteroid/utils/$un" ;;
		qmldir) grep -v "^prefer " "$uf" > "$1/org/asteroid/utils/qmldir" ;;
		*) cp -r "$uf" "$1/org/asteroid/utils/$un" ;;
		esac
	done
}
# the tests and what they use, staged as links (relative paths in them resolve here)
for tf in "$C"/tests/qml/*; do ln -s "$tf" "$T/t/$(basename "$tf")"; done
contacts_staged=""
stage_contacts() {
	[ -n "$contacts_staged" ] && return 0
	M=$T/qmlc/org/asteroid/contacts
	mkdir -p "$M"
	ln -s "$CONTACTS" "$T/org.asteroid.contacts"
	{
		echo "module org.asteroid.contacts"
		for cf in "$CONTACTS"/qml/*.qml "$CONTACTS"/qml/*.js; do
			[ -e "$cf" ] && ln -s "$cf" "$M/$(basename "$cf")"
		done
		rm -f "$M/ContactStore.qml"
		cp "$CONTACTS/tests/qml/mocks/ContactStore.qml" "$M/ContactStore.qml"
		for cf in "$CONTACTS"/qml/*.qml "$M/ContactStore.qml"; do
			cn=$(basename "$cf" .qml)
			if [ "$cn" = Strings ]; then echo "singleton Strings 1.0 Strings.qml"; else echo "$cn 1.0 $cn.qml"; fi
		done
		echo "depends QtQuick"
	} > "$M/qmldir"
	contacts_staged=1
}

# ---- run ----
NP=0; NF=0; NS=0; NL=0; NFILES=0; BAD=0; SKIPPED=""
report() { # report NAME LOG RC: the file's line and its failures; adds to the totals
	rname=$1; rlog=$2; rc=$3
	tot=$(grep "^Totals: " "$rlog" | tail -1)
	loops=$(grep -c "inding loop" "$rlog")
	# Qt Test: "Totals: P passed, F failed, S skipped, ..."; tst_crownspeed: "Totals: N checks, F failed"
	p=$(echo "$tot" | sed -n 's/^Totals: \([0-9]*\) passed, \([0-9]*\) failed, \([0-9]*\) skipped.*/\1 \2 \3/p')
	[ -n "$p" ] || p=$(echo "$tot" | sed -n 's/^Totals: \([0-9]*\) checks, \([0-9]*\) failed.*/\1 \2/p' \
		| awk '{ print $1 - $2, $2, 0 }')
	NFILES=$((NFILES + 1))
	NL=$((NL + loops))
	if [ -z "$p" ]; then
		echo "$rname: NO TOTALS (exit $rc$([ "$rc" = 124 ] && echo ", timed out after $TMO s")), loops $loops"
		tail -5 "$rlog" | sed 's/^/    /'
		BAD=1; NF=$((NF + 1))
		return
	fi
	set -- $p
	echo "$rname: $1 passed, $2 failed, $3 skipped, loops $loops"
	NP=$((NP + $1)); NF=$((NF + $2)); NS=$((NS + $3))
	if [ "$2" -gt 0 ] || [ "$loops" -gt 0 ]; then
		grep -E "^(FAIL|   Actual|   Expected|   Loc)|inding loop" "$rlog" | sed "s#$T/t/#tests/qml/#g" \
			| head -"$FAILS" | sed 's/^/    /'
	fi
}
qenv() { # qenv CMD...: CMD in the environment of every run under qemu
	env -i HOME="$T/home" XDG_RUNTIME_DIR="$T/home" PATH=/usr/bin:/bin LC_ALL=C.UTF-8 \
		QT_QPA_PLATFORM="offscreen:configfile=$here/qemu/offscreen.json" QT_QUICK_BACKEND=software \
		QT_PLUGIN_PATH="$R/usr/lib/plugins" QML_DISABLE_DISK_CACHE=1 "$@"
}
for c in $CTESTS; do
	log=$B/logs/tst_$c.txt
	(cd "$T/run" && qenv timeout "$TMO" "$QEMU" -L "$R" "$B/ctests/tst_$c") > "$log" 2>&1
	report "tst_$c" "$log" $?
done
for f in $QMLS; do
	name=$(basename "$f")
	words=" $(sed -n 's#^// run-qemu: ##p' "$f" | tr '\n' ' ') "
	extra=""
	ov=$T/qml
	case $words in *" icons "*) ov=$T/qml-icons ;; esac
	[ -n "${ICONS:-}" ] && ov=$T/qml-icons
	case $words in *" mocks "*) extra="$extra -import $T/t/mocks" ;; esac
	case $words in *" contacts "*)
		if [ -z "${CONTACTS:-}" ] || [ ! -f "$CONTACTS/tests/qml/mocks/ContactStore.qml" ]; then
			echo "$name: skipped (needs CONTACTS= an org.asteroid.contacts tree)"
			SKIPPED="$SKIPPED $name"
			continue
		fi
		stage_contacts
		extra="$extra -import $CONTACTS/tests/qml/mocks -import $T/qmlc" ;;
	esac
	if [ ! -d "$ov" ]; then
		if [ "$ov" = "$T/qml-icons" ]; then overlay "$ov" icons; else overlay "$ov"; fi
	fi
	# a test from elsewhere is staged beside the others
	[ "$f" = "$C/tests/qml/$name" ] || ln -sfn "$f" "$T/t/$name"
	log=$B/logs/${name%.qml}.txt
	(cd "$T/run" && qenv QML_IMPORT_PATH="$ov:$R/usr/lib/qml" QML2_IMPORT_PATH="$ov:$R/usr/lib/qml" \
		QT_LOGGING_RULES="asteroid.rotary.debug=false" \
		timeout "$TMO" "$QEMU" -L "$R" "$QTR" $extra -input "$T/t/$name") > "$log" 2>&1
	report "$name" "$log" $?
done
[ -n "${KEEP:-}" ] && echo "run folder kept: $T"
echo "Total: $NP passed, $NF failed, $NS skipped, $NL binding-loop warnings in $NFILES files$([ -n "$SKIPPED" ] && echo "; not run:$SKIPPED") (logs: $B/logs)"
[ "$NF" -eq 0 ] && [ "$NL" -eq 0 ] && [ "$BAD" -eq 0 ]
