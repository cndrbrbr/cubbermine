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
