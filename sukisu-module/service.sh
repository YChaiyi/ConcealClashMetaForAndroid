#!/system/bin/sh

MODDIR=${0%/*}
export MODDIR

"$MODDIR/scripts/cmfa-root.sh" monitor &
