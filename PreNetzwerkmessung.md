# Messauftrag: Netzwerk-Latenz und Verbindungsqualität

**Projekt:** Cubbermine – Minecraft Hosting on Kubernetes  
**Dokument:** PreNetzwerkmessung / Netzwerk-Messauftrag  
**Stand:** 14.11.2026  
**Status:** Zur Durchführung vorgesehen

## 1. Zielsetzung

Ziel der Messung ist die Bewertung der Netzwerkverbindungen zwischen den bestehenden Minecraft-Servern und dem geplanten Kubernetes-Control-Plane-Server.

Es soll festgestellt werden, ob die Netzwerkqualität für den stabilen Betrieb eines gemeinsamen K3s-Clusters ausreicht.

Insbesondere sind folgende Eigenschaften zu untersuchen:

- Round-Trip-Time (RTT) zwischen den Hosts
- Durchschnittliche Latenz sowie Minimum und Maximum
- Jitter beziehungsweise Latenzschwankungen
- Paketverlust
- TCP-Verbindungsqualität und Durchsatz
- Stabilität über längere Zeiträume
- Unterschiede zwischen direkter Verbindung und WireGuard-VPN
- Hinweise auf Routing-Probleme und Netzwerkengpässe

Die Ergebnisse bilden eine Entscheidungsgrundlage für die Kubernetes-Architektur und die spätere Erweiterung auf drei Control-Plane-Nodes.

## 2. Messobjekte

### Bestehende Server

| Bezeichnung | Öffentliche IPv4-Adresse | Geplante Kubernetes-Rolle |
|---|---|---|
| MeckMinecraft | 185.170.113.136 | Worker |
| NC3 | 2.56.99.112 | Worker |
| Codefield | 89.58.11.96 | Worker |
| Control Plane | Noch nicht vergeben | Control Plane |

Die Control Plane wird nach Bereitstellung des zusätzlichen Servers in die Messungen aufgenommen.

### Messmatrix

Die Messungen sind in beide Richtungen durchzuführen.

| Quelle | Ziel |
|---|---|
| MeckMinecraft | NC3 |
| NC3 | MeckMinecraft |
| MeckMinecraft | Codefield |
| Codefield | MeckMinecraft |
| NC3 | Codefield |
| Codefield | NC3 |

Nach Bereitstellung der Control Plane werden zusätzlich alle sechs gerichteten Verbindungen zwischen ihr und den drei Workern gemessen.

## 3. Messverfahren

### 3.1 ICMP-Latenzmessung

Auf jedem Quellserver wird folgender Befehl ausgeführt:

```bash
ping -n -c 1000 -i 0.2 ZIEL_IP
```

Die Messung umfasst 1.000 ICMP-Pakete mit einem Abstand von 200 Millisekunden.

Zu erfassen sind:

- Übertragene und empfangene Pakete
- Paketverlust in Prozent
- Minimale RTT
- Mittlere RTT
- Maximale RTT
- Standardabweichung der RTT (mdev)

Die Ausgabe ist vollständig in einer Protokolldatei zu speichern.

Beispiel:

```bash
ping -n -c 1000 -i 0.2 2.56.99.112 \
  | tee ping_nc3.txt
```

### 3.2 Langzeitmessung

Zur Erkennung zeitabhängiger Störungen ist eine Langzeitmessung durchzuführen.

**Messdauer: mindestens 24 Stunden, bevorzugt 72 Stunden.**

Alle 60 Sekunden werden zehn ICMP-Pakete versendet.

Beispiel:

```bash
#!/bin/bash

TARGET="$1"
LOGFILE="latency_${TARGET}.log"

while true; do
    echo "===== $(date -Is) =====" >> "$LOGFILE"

    ping -n -c 10 -i 0.2 "$TARGET" >> "$LOGFILE" 2>&1

    sleep 60
done
```

Die Messung soll sowohl tagsüber als auch nachts stattfinden.

### 3.3 Untersuchung des Netzwerkpfads

Zur Identifikation möglicher Engpässe wird `mtr` verwendet.

Installation unter Debian:

```bash
apt update
apt install -y mtr-tiny
```

Messung:

```bash
mtr -n -r -w -c 200 2.56.99.112
```

Zu dokumentieren sind:

- Anzahl der Netzwerk-Hops
- RTT zu den Zwischenstationen
- Paketverluste
- Auffällige Änderungen der Latenz

**Hinweis:** Paketverlust bei einzelnen Zwischenroutern ist nicht zwingend ein Verbindungsproblem. Entscheidend ist insbesondere, ob der Verlust auch am Ziel auftritt. Router können ICMP-Antworten begrenzen oder unterdrücken.

### 3.4 TCP-Durchsatzmessung

Zur Messung des tatsächlichen Datendurchsatzes wird `iperf3` verwendet.

Installation:

```bash
apt install -y iperf3
```

Auf dem Zielserver:

```bash
iperf3 -s -B ZIEL_IP
```

Auf dem Quellserver:

```bash
iperf3 -c ZIEL_IP -t 60
```

Gegenrichtung:

```bash
iperf3 -c ZIEL_IP -t 60 -R
```

Die Messung wird für jede Serverkombination durchgeführt.

**Sicherheit:** TCP-Port 5201 darf nur zwischen den beteiligten Messhosts freigegeben werden. Nach Abschluss der Messungen ist der Testdienst zu beenden.

Die Bandbreitentests sollten außerhalb stark belasteter Minecraft-Zeiten stattfinden, da sie produktive Netzwerkverbindungen beeinflussen können.

### 3.5 WireGuard-Vergleich

Nach Einrichtung des geplanten WireGuard-Netzwerks sind die Latenz- und Durchsatzmessungen über die privaten VPN-Adressen zu wiederholen.

Folgende Größen werden verglichen:

| Messgröße | Direkte Verbindung | WireGuard |
|---|---|---|
| Mittlere RTT | Messwert | Messwert |
| Maximale RTT | Messwert | Messwert |
| Jitter | Messwert | Messwert |
| Paketverlust | Messwert | Messwert |
| TCP-Durchsatz | Messwert | Messwert |

Ziel ist die Ermittlung des zusätzlichen Netzwerk-Overheads durch WireGuard.

Zusätzlich müssen MTU und mögliche Fragmentierungsprobleme untersucht werden.

## 4. Bewertungskriterien

Für Cubbermine gelten zunächst folgende **vorläufige technische Orientierungswerte**:

| Messgröße | Gut | Prüfbedarf | Kritisch |
|---|---|---|---|
| Mittlere RTT | < 10 ms | 10–30 ms | > 30 ms |
| Jitter | < 2 ms | 2–5 ms | > 5 ms |
| Paketverlust | 0 % | > 0–0,1 % | > 0,1 % |
| Stabilität | Keine Ausfälle | Einzelne Unterbrechungen | Wiederkehrende Ausfälle |

Diese Werte sind **projektinterne Richtwerte und keine offiziellen Kubernetes-Grenzwerte**.

Für einen einzelnen K3s-Control-Plane-Server mit drei Workern sind höhere Latenzen nicht automatisch ein Ausschlusskriterium. Die tatsächliche Eignung muss durch Cluster- und Anwendungstests nachgewiesen werden.

Für den später geplanten hochverfügbaren Control-Plane-Verbund mit Embedded etcd gelten strengere Anforderungen an Latenz, Stabilität und Datenträgerleistung.

## 5. Durchführung

Die Messungen werden in zwei Phasen unterteilt.

### Phase A – Bestehende Infrastruktur

Messung aller sechs gerichteten Verbindungen zwischen:

- MeckMinecraft
- NC3
- Codefield

Die Ergebnisse dienen der Bewertung des bestehenden Netzwerks und der Auswahl eines geeigneten Standorts für die neue Control Plane.

### Phase B – Erweiterte Infrastruktur

Nach Bereitstellung des zusätzlichen Servers:

1. Messung zwischen Control Plane und allen drei Workern.
2. Einrichtung des privaten WireGuard-Netzwerks.
3. Wiederholung der Messungen über WireGuard.
4. Aufbau eines nichtproduktiven K3s-Clusters.
5. Prüfung der Kubernetes-API-Erreichbarkeit und der Pod-Kommunikation.
6. Kontrollierte Tests beim Ausfall einzelner Netzwerkverbindungen.

## 6. Ergebnisdokumentation

Für jede gerichtete Verbindung ist ein Messprotokoll mit folgenden Informationen zu erstellen:

| Feld | Inhalt |
|---|---|
| Quellserver | Hostname |
| Zielserver | Hostname |
| Quell-IP | IPv4-Adresse |
| Ziel-IP | IPv4-Adresse |
| Messbeginn | Datum und Uhrzeit |
| Messende | Datum und Uhrzeit |
| Verbindung | Direkt / WireGuard |
| RTT min | Millisekunden |
| RTT avg | Millisekunden |
| RTT max | Millisekunden |
| RTT mdev | Millisekunden |
| Paketverlust | Prozent |
| TCP-Durchsatz | Mbit/s |
| Auffälligkeiten | Beschreibung |

Alle Rohdaten sind aufzubewahren, damit die Messungen später erneut ausgewertet werden können.

## 7. Abnahmekriterien

Der Messauftrag gilt als abgeschlossen, wenn:

- Alle sechs gerichteten Verbindungen der bestehenden Hosts untersucht wurden.
- Mindestens eine 24-Stunden-Messung pro Verbindung vorliegt.
- Paketverlust, Latenz und Schwankungen dokumentiert sind.
- Die TCP-Durchsatzmessungen durchgeführt wurden.
- Auffällige Netzwerkpfade identifiziert wurden.
- Die Ergebnisse technisch bewertet wurden.
- Eine Empfehlung für den Betrieb des gemeinsamen K3s-Clusters vorliegt.

Nach Bereitstellung der neuen Control Plane wird der Messauftrag um deren Verbindungen erweitert.

## 8. Erwartetes Ergebnis

Am Ende der Messungen ist eine technische Bewertung mit einer der folgenden Empfehlungen abzugeben:

**A – Geeignet:** Die gemessene Netzwerkqualität lässt einen gemeinsamen K3s-Cluster erwarten. Ein Praxistest bestätigt die Eignung.

**B – Bedingt geeignet:** Der gemeinsame Cluster ist möglich, benötigt jedoch Optimierungen am Netzwerk oder an der Architektur.

**C – Nicht geeignet:** Die Netzwerkqualität ist für die geplante Cluster-Architektur unzureichend. Alternative Standorte oder eine getrennte Cluster-Struktur müssen geprüft werden.

Die abschließende Entscheidung erfolgt erst nach Auswertung der Messdaten und praktischen Kubernetes-Tests.

---

**Projekt:** Cubbermine  
**Verwendungszweck:** Architekturentscheidung und Vorbereitung der K3s-Migration  
**Zugehörige Dokumente:** [architecture.md](architecture.md), [features.md](features.md), [planning.md](planning.md)

---

## 9. Ergebnisse

**Stand:** 14.11.2026, 22:15 Uhr. Phase A läuft noch: Die Kurzmessungen sind fertig, die Langzeitmessung und die iperf3-Tests stehen aus (Zeitplan in 9.6).

Rohdaten und Skripte liegen in [messdaten/](messdaten/).

### 9.1 Vorbemerkungen zum Plan

Gegen den Plan gab es keine grundsätzlichen Einwände. Bei der Durchführung wurde Folgendes ergänzt bzw. angepasst:

- **Firewall:** Auf allen drei Hosts steht die INPUT-Policy auf `ACCEPT`, eine Host-Firewall gibt es nicht. Damit Port 5201 wie gefordert nur zwischen den Messhosts offen ist, setzt `netmess-iperf.sh` für jeden Server-Host vorübergehend iptables-Regeln: ACCEPT von den beiden anderen Host-IPs, für alle anderen DROP (Kommentar `netmess`). Nach dem Lauf werden die Regeln wieder entfernt, auch bei einem Abbruch (`trap`). Die Regeln werden nicht persistent gespeichert.
- **MTU:** Der Plan untersucht die MTU erst beim WireGuard-Vergleich, `planning.md` (M0) verlangt sie aber schon für Phase A. Deshalb wurde zusätzlich ein Ping mit gesetztem DF-Bit gemessen (1472/1473 Byte Nutzlast).
- **Langzeitmessung:** Sie läuft 72 Stunden lang (bevorzugte Dauer laut Plan) als systemd-Unit `netmess-lz-<ziel>` mit `RuntimeMaxSec=72h` und beendet sich danach selbst.
- **iperf3:** Gemessen wird nachts (Start 15.11.2026, 04:00 Uhr), damit die Minecraft-Server nicht beeinträchtigt werden. Für jede gerichtete Verbindung gibt es zwei 60-Sekunden-Läufe: normal und mit `-R`.
- `mtr-tiny` und `iperf3` wurden auf allen drei Hosts installiert. Der iperf3-Systemdienst ist deaktiviert und läuft nicht.

### 9.2 ICMP-Latenz (1000 Pakete, Abstand 0,2 s)

Messzeit: 14.11.2026, 22:04–22:08 Uhr (Samstagabend). Alle Verbindungen wurden gleichzeitig gemessen.

| Quelle → Ziel | Gesendet / empfangen | Verlust | RTT min | RTT avg | RTT max | mdev |
|---|---|---|---|---|---|---|
| MeckMinecraft → NC3 | 1000 / 1000 | 0 % | 0,212 ms | 0,462 ms | 5,075 ms | 0,404 ms |
| NC3 → MeckMinecraft | 1000 / 1000 | 0 % | 0,255 ms | 0,470 ms | 5,609 ms | 0,439 ms |
| MeckMinecraft → Codefield | 1000 / 1000 | 0 % | 0,325 ms | 0,497 ms | 5,482 ms | 0,402 ms |
| Codefield → MeckMinecraft | 1000 / 1000 | 0 % | 0,281 ms | 0,499 ms | 15,694 ms | 0,730 ms |
| NC3 → Codefield | 1000 / 1000 | 0 % | 0,273 ms | 0,439 ms | 1,581 ms | 0,096 ms |
| Codefield → NC3 | 1000 / 1000 | 0 % | 0,256 ms | 0,446 ms | 2,327 ms | 0,119 ms |

### 9.3 MTU (Ping mit DF-Bit)

Auf allen sechs Verbindungen gilt:

- 1472 Byte Nutzlast kommen an (das entspricht 1500 Byte IP-Paket).
- 1473 Byte werden mit „message too long“ abgewiesen.

Die Pfad-MTU ist damit durchgehend **1500**. Unterwegs wird nicht fragmentiert und es gibt keinen Tunnel-Overhead. Für WireGuard heißt das: Die Standard-MTU von 1420 passt (1500 − 80 Byte für IPv6-Outer-Header, bei IPv4 sind es 60).

### 9.4 Netzwerkpfad (mtr, 200 Zyklen)

Alle sechs Pfade haben **zwei Hops**: das Gateway im eigenen Subnetz des Quellhosts (89.58.8.2, 185.170.112.2 bzw. 2.56.96.2) und dann direkt das Ziel. Weder an den Gateways noch an den Zielen gab es Verlust. Die Hosts sind also nur über einen Router verbunden; sie liegen sehr wahrscheinlich beim selben Provider im selben Rechenzentrum.

Die Gateways antworten mit schwankenden Zeiten (Durchschnitt 3–4,6 ms, Maximum 23–44 ms). Das liegt an der ICMP-Behandlung im Router selbst und betrifft den durchgeleiteten Verkehr nicht: Am Ziel liegt der Durchschnitt bei 0,4–0,5 ms und die Standardabweichung bei 0,1–0,5 ms.

### 9.5 TCP-Durchsatz (vorläufig)

Bisher gab es nur einen **2-Sekunden-Funktionstest** (14.11.2026, 22:05 Uhr) mit Codefield als iperf3-Server. Er sollte prüfen, ob das Skript und die Firewall-Regeln funktionieren; als Messung zählt er nicht.

| Quelle → Ziel | Durchsatz (Empfänger) |
|---|---|
| MeckMinecraft → Codefield | 937 Mbit/s |
| NC3 → Codefield | 938 Mbit/s |
| Codefield → MeckMinecraft (-R) | 935 Mbit/s |
| Codefield → NC3 (-R) | 1,51 Gbit/s |

Die maßgeblichen 60-Sekunden-Messungen für alle sechs Richtungen werden nachgetragen.

### 9.6 Offene Punkte

| Punkt | Status |
|---|---|
| Langzeitmessung (alle 60 s 10 Pings, 6 Richtungen) | läuft seit 14.11.2026, 22:05 Uhr, endet automatisch am 17.11.2026, 22:05 Uhr; Auswertung nach ≥ 24 h |
| iperf3, 60 s je Richtung, mit und ohne `-R` | geplant für 15.11.2026, 04:00 Uhr (systemd-Timer `netmess-iperf` auf NC3) |
| Phase B (Control Plane, WireGuard, K3s) | wartet auf den zusätzlichen Server |

### 9.7 Vorläufige Bewertung

Gemessen an den Orientierungswerten aus Abschnitt 4 sind alle Kurzzeitwerte **„Gut“**:

- Die mittlere RTT liegt bei etwa 0,45 ms, gefordert sind unter 10 ms.
- Der Jitter (mdev) liegt bei höchstens 0,73 ms, gefordert sind unter 2 ms.
- Der Paketverlust beträgt 0 %.

Einzelne Ausreißer bis 15,7 ms (Codefield → MeckMinecraft) sind vereinzelte Spitzen und haben keinen Einfluss auf Mittelwert und Streuung.

**Vorläufige Empfehlung: A – Geeignet.** Das Netz zwischen den drei Hosts genügt sowohl einem Cluster mit einer einzelnen Control Plane als auch den strengeren Anforderungen von embedded etcd (Phase 2). Für die neue Control Plane bietet sich derselbe Provider und dasselbe Rechenzentrum an, damit sie ebenfalls nur einen Hop entfernt ist. Diese Empfehlung ist erst endgültig, wenn die Langzeit- und Durchsatzmessung ausgewertet ist.
