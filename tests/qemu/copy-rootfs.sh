#!/bin/sh
# copy-rootfs.sh SRC DST: a private copy of an image rootfs for run-qemu.sh (R=DST). Waits while a
# bitbake runs (it may be rewriting SRC), copies with cp -a to DST.tmp, checks that the copy has the
# files the tests need and moves it to DST. SRC is only read; an existing DST is kept.
set -u
SRC=${1:?usage: copy-rootfs.sh SRC DST}
DST=${2:?usage: copy-rootfs.sh SRC DST}
need="etc/asteroid/machine.conf usr/lib/qml/org/asteroid/controls/qmldir usr/lib/qml/org/asteroid/utils/qmldir usr/lib/qml/QtTest/qmldir"
ok() { for f in $need; do [ -e "$1/$f" ] || return 1; done; }
if ok "$DST"; then
	echo "rootfs $DST already there"
	exit 0
fi
while pgrep -f "[b]itbake/bin/bitbake" > /dev/null; do sleep 30; done
rm -rf "$DST.tmp"
if cp -a "$SRC" "$DST.tmp" && ok "$DST.tmp"; then
	mv "$DST.tmp" "$DST"
	echo "rootfs $DST $(du -sh "$DST" | cut -f1)"
else
	rm -rf "$DST.tmp"
	echo "copy-rootfs.sh: the copy of $SRC failed or lacks one of: $need" >&2
	exit 1
fi
