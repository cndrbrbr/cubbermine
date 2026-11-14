#!/bin/bash
# iperf3-Durchsatz gemaess PreNetzwerkmessung.md 3.4, orchestriert von nc3.
# Port 5201 wird je Server-Host nur temporaer fuer die beiden anderen Hosts freigegeben.
declare -A IP=([meck]=185.170.113.136 [nc3]=2.56.99.112 [codefield]=89.58.11.96)
OUT=/root/netzwerkmessung/iperf; mkdir -p $OUT
run() { local h=$1; shift; if [ $h = nc3 ]; then bash -c "$*"; else ssh -o BatchMode=yes root@${IP[$h]} "$*"; fi; }
rules() { # $1=host $2=-I|-D
  local h=$1 op=$2 o
  run $h "iptables $op INPUT -p tcp --dport 5201 -m comment --comment netmess -j DROP"
  for o in "${!IP[@]}"; do [ $o = $h ] && continue
    run $h "iptables $op INPUT -p tcp --dport 5201 -s ${IP[$o]} -m comment --comment netmess -j ACCEPT"; done
}
cleanup() { for h in "${!IP[@]}"; do run $h "pkill -x iperf3; while iptables -D INPUT -p tcp --dport 5201 -m comment --comment netmess -j DROP 2>/dev/null; do :; done; for s in ${IP[*]}; do while iptables -D INPUT -p tcp --dport 5201 -s \$s -m comment --comment netmess -j ACCEPT 2>/dev/null; do :; done; done; iptables -S INPUT | grep -c netmess"; done; }
trap cleanup EXIT
echo "start $(date -Is)" >> $OUT/run.log
for srv in meck nc3 codefield; do
  rules $srv -I
  run $srv "iptables -S INPUT | grep netmess" >> $OUT/run.log
  run $srv "iperf3 -s -B ${IP[$srv]} -D --pidfile /run/netmess-iperf3.pid"; sleep 2
  for cli in "${!IP[@]}"; do [ $cli = $srv ] && continue
    echo "== $(date -Is) $cli -> $srv (client sendet)" > $OUT/${cli}_to_${srv}_iperf.txt
    run $cli "timeout 90 iperf3 -c ${IP[$srv]} -t 60" >> $OUT/${cli}_to_${srv}_iperf.txt 2>&1
    echo "== $(date -Is) $srv -> $cli (-R, server sendet)" > $OUT/${srv}_to_${cli}_iperfR.txt
    run $cli "timeout 90 iperf3 -c ${IP[$srv]} -t 60 -R" >> $OUT/${srv}_to_${cli}_iperfR.txt 2>&1
    sleep 5
  done
  run $srv "kill \$(cat /run/netmess-iperf3.pid)"
  rules $srv -D
done
echo "end $(date -Is)" >> $OUT/run.log
