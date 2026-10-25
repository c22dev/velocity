#!/bin/sh
# Velocity - prepare.sh
# Constantin Clerc (c22dev) - 0.1
set -e
NXHOST="${NXHOST:-../nxhost}"
W=work/v109
cargo build --release --manifest-path "$NXHOST/Cargo.toml" -p nxfs -p nxpatch
T="$NXHOST/target/release"
[ -f $W/exefs/main ] || "$T/nxfs" --keys prod.keys extract --base base.nsp --update upd.nsp --out $W
[ "$(cat $W/patched/nxpatch.stamp 2>/dev/null)" = "$("$T/nxpatch" stamp)" ] || "$T/nxpatch" rewrite --out $W/patched $W/exefs/main $W/exefs/subsdk2 $W/exefs/subsdk3
