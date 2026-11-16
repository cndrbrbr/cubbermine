# Performance-Skripte (Netzwerkmessung)

Skripte zur Netzwerkmessung vor der K3s-Migration, siehe [PreNetzwerkmessung.md](../PreNetzwerkmessung.md). Die Ergebnisse stehen dort in Abschnitt 9, die Rohdaten in [messdaten/](../messdaten/).

Alle Mess-Skripte laufen als root und schreiben nach `/root/netzwerkmessung/`. Benötigt werden `ping`, `tracepath`, `mtr-tiny` und `iperf3`.

| Skript | Zweck | Aufruf |
|---|---|---|
| `netmess-a.sh` | Kurzmessung Phase A: 1000 Pings (Abstand 0,2 s), MTU-Test mit DF-Bit (1472/1473/1400 Byte), `tracepath`, `mtr` mit 200 Zyklen. Alle Ziele parallel. Ausgabe: `/root/netzwerkmessung/phaseA/<quelle>_to_<ziel>_{meta,ping,mtu,mtr}.txt` | auf jedem Host: `./netmess-a.sh nc3 meck=185.170.113.136 codefield=89.58.11.96` |
| `netmess-longterm.sh` | Langzeitmessung (Plan 3.2): alle 60 s 10 Pings, Endlosschleife. Ausgabe: `/root/netzwerkmessung/langzeit/latency_<name>_<ip>.log` | je Ziel als befristete Unit: `systemd-run --unit netmess-lz-meck -p RuntimeMaxSec=72h /root/netmess-longterm.sh 185.170.113.136 meck` |
| `netmess-iperf.sh` | TCP-Durchsatz (Plan 3.4): jeder Host nacheinander iperf3-Server, je gerichteter Verbindung 60 s normal und 60 s mit `-R`. Öffnet Port 5201 vorübergehend nur für die Messhosts (iptables, Kommentar `netmess`) und räumt per `trap` wieder auf. Ausgabe: `/root/netzwerkmessung/iperf/` | nur auf NC3 (orchestriert die anderen Hosts per SSH): `./netmess-iperf.sh`, z. B. nachts per Timer: `systemd-run --unit netmess-iperf --on-calendar '2026-11-15 04:00' /root/netmess-iperf.sh` |
| `netmess-longterm-auswertung.py` | Auswertung der Langzeit-Logs: Verlust, RTT min/avg/Median/p99/p99,9/max, Jitter je Block, Ausreißer, Tag/Nacht, Stundenprofil, Lücken, Top-Ausreißer | `python3 -I netmess-longterm-auswertung.py <verzeichnis>`; erwartet Dateien `<quelle>_to_<ziel>.log` (Logs vorher von allen Hosts einsammeln und umbenennen) |

Die Host-IPs (MeckMinecraft 185.170.113.136, NC3 2.56.99.112, Codefield 89.58.11.96) sind in `netmess-iperf.sh` fest eingetragen und müssen für Phase B um die neue Control Plane ergänzt werden.
