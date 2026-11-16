#!/bin/bash
# Phase A short measurement: ping 1000, MTU probe, mtr. Args: SELF_NAME then NAME=IP pairs
SELF=$1; shift
OUT=/root/netzwerkmessung/phaseA; mkdir -p $OUT; cd $OUT
for pair in "$@"; do
  N=${pair%%=*}; IP=${pair#*=}; P="${SELF}_to_${N}"
  (
    echo "start $(date -Is) src=$SELF dst=$N ip=$IP" > ${P}_meta.txt
    ping -n -c 1000 -i 0.2 $IP > ${P}_ping.txt 2>&1
    { for s in 1472 1473 1400; do echo "--- DF payload $s"; ping -n -c 3 -M do -s $s $IP 2>&1 | tail -3; done; echo "--- tracepath"; tracepath -n $IP 2>&1 | tail -3; } > ${P}_mtu.txt
    mtr -n -r -w -c 200 $IP > ${P}_mtr.txt 2>&1
    echo "end $(date -Is)" >> ${P}_meta.txt
  ) &
done
wait
