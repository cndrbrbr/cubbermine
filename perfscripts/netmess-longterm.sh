#!/bin/bash
# Langzeitmessung gemaess PreNetzwerkmessung.md 3.2: alle 60 s 10 Pings
TARGET="$1"; NAME="$2"
mkdir -p /root/netzwerkmessung/langzeit
LOGFILE="/root/netzwerkmessung/langzeit/latency_${NAME}_${TARGET}.log"
while true; do
    echo "===== $(date -Is) =====" >> "$LOGFILE"
    ping -n -c 10 -i 0.2 "$TARGET" >> "$LOGFILE" 2>&1
    sleep 60
done
