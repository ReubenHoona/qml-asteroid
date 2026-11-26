#!/usr/bin/env python3
"""patch-path.py FILE OLD NEW: replaces the path OLD by NEW in the binary FILE, in its Latin-1 and its
UTF-16-LE (QStringLiteral) spellings, and prints how many it replaced. NEW must be as long as OLD, so
string tables keep their layout. run-qemu.sh points the plugins' /etc/asteroid/machine.conf and the
controls' /usr/share/icons/asteroid/ at copies of the rootfs files this way."""
import sys

path, old, new = sys.argv[1:4]
if len(old) != len(new):
    sys.exit("patch-path.py: %r (%d) and %r (%d) differ in length" % (old, len(old), new, len(new)))
data = open(path, "rb").read()
count = 0
for enc in ("latin-1", "utf-16-le"):
    count += data.count(old.encode(enc))
    data = data.replace(old.encode(enc), new.encode(enc))
open(path, "wb").write(data)
print(count)
