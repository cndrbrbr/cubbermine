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

**Stand:** 18.11.2026. Phase A ist abgeschlossen: Kurzmessungen, iperf3-Tests und die 72-stündige Langzeitmessung (14.–17.11.2026) sind ausgewertet. Die Bewertung in 9.8 ist endgültig.

Rohdaten liegen in [messdaten/](messdaten/), die Mess- und Auswerteskripte in [perfscripts/](perfscripts/).

### 9.1 Vorbemerkungen zum Plan

Gegen den Plan gab es keine grundsätzlichen Einwände. Bei der Durchführung wurde Folgendes ergänzt bzw. angepasst:

- **Firewall:** Auf allen drei Hosts steht die INPUT-Policy auf `ACCEPT`, eine Host-Firewall gibt es nicht. Damit Port 5201 wie gefordert nur zwischen den Messhosts offen ist, setzt [`netmess-iperf.sh`](perfscripts/netmess-iperf.sh) für jeden Server-Host vorübergehend iptables-Regeln: ACCEPT von den beiden anderen Host-IPs, für alle anderen DROP (Kommentar `netmess`). Nach dem Lauf werden die Regeln wieder entfernt, auch bei einem Abbruch (`trap`). Die Regeln werden nicht persistent gespeichert.
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

### 9.5 TCP-Durchsatz (iperf3, 60 s)

Messzeit: 15.11.2026, 04:00–04:12 Uhr (Sonntagnacht), systemd-Timer `netmess-iperf` auf NC3. Jeder Host war nacheinander iperf3-Server. Jede gerichtete Verbindung wurde zweimal gemessen: einmal sendet der Client (normal), einmal der Server (`-R`). Alle zwölf Läufe sind vollständig und ohne Fehler durchgelaufen. Danach waren auf allen drei Hosts keine `netmess`-Regeln mehr vorhanden und kein iperf3 lief mehr. Rohdaten: [messdaten/iperf/](messdaten/iperf/).

Die 1-Sekunden-Werte wurden zusätzlich ausgewertet (je 60 Intervalle). Die Retransmit-Quote ist der Anteil der neu gesendeten an allen gesendeten TCP-Segmenten (1448 Byte).

| Quelle → Ziel | Lauf | Durchsatz (Empfänger) | 1-s-Werte min–max | Streuung (σ) | Retransmits | Quote |
|---|---|---|---|---|---|---|
| MeckMinecraft → NC3 | normal | 937 Mbit/s | 903–1000 Mbit/s | 16,8 | 1.258 | 0,03 % |
| MeckMinecraft → NC3 | -R | 937 Mbit/s | 933–938 Mbit/s | 1,3 | 1.182 | 0,02 % |
| NC3 → MeckMinecraft | normal | 935 Mbit/s | 895–959 Mbit/s | 8,8 | 1.666 | 0,03 % |
| NC3 → MeckMinecraft | -R | 937 Mbit/s | 926–938 Mbit/s | 2,1 | 1.041 | 0,02 % |
| MeckMinecraft → Codefield | normal | 934 Mbit/s | 877–950 Mbit/s | 11,2 | 1.157 | 0,02 % |
| MeckMinecraft → Codefield | -R | 937 Mbit/s | 930–940 Mbit/s | 2,0 | 1.342 | 0,03 % |
| Codefield → MeckMinecraft | normal | 937 Mbit/s | 922–965 Mbit/s | 6,0 | 839 | 0,02 % |
| Codefield → MeckMinecraft | -R | 937 Mbit/s | 927–939 Mbit/s | 2,3 | 678 | 0,01 % |
| NC3 → Codefield | normal | 947 Mbit/s | 915–1000 Mbit/s | 19,8 | 795 | 0,02 % |
| NC3 → Codefield | -R | 947 Mbit/s | 943–950 Mbit/s | 1,9 | 1.581 | 0,03 % |
| **Codefield → NC3** | normal | **1,01 Gbit/s** | 763 Mbit/s–2,20 Gbit/s | 136 | **423.634** | **8,0 %** |
| **Codefield → NC3** | -R | **1,01 Gbit/s** | 867 Mbit/s–2,02 Gbit/s | 132 | **438.632** | **8,3 %** |

(Bei `-R` steht die Senderichtung in der Spalte „Quelle → Ziel“, d. h. Quelle ist der iperf3-Server.)

**Ergebnis:**

- Alle sechs Richtungen erreichen etwa **1 Gbit/s**. Die Werte um 935–947 Mbit/s entsprechen dem, was bei einer 1-Gbit/s-Anbindung nach Abzug des TCP/IP-Overheads als Nutzdatenrate übrig bleibt. Die Anbindung ist also auf 1 Gbit/s pro Host begrenzt, und diese Grenze wird voll erreicht.
- Die Werte sind sehr gleichmäßig. Bei `-R` schwanken die 1-Sekunden-Werte nur um ±1–2 Mbit/s, beim normalen Lauf um 6–20 Mbit/s (Hochlaufen der TCP-Überlastkontrolle beim Sender).
- Hin- und Rückrichtung sind gleich schnell. Eine Asymmetrie gibt es nicht.

**Auffälligkeit Codefield → NC3:** In dieser Richtung kommen zwar ebenfalls rund 1 Gbit/s an, aber mit etwa **8 % Retransmits** (rund 7.000 pro Sekunde statt sonst 10–30). Das Staufenster (Cwnd) bleibt dabei fast durchgehend bei 15–50 KByte, in den anderen Richtungen liegt es bei 400–650 KByte. In der ersten Sekunde kommen kurz 2,0–2,2 Gbit/s durch. Das passt zu einem **Policer**, der auf diesem Pfad hart bei etwa 1 Gbit/s abschneidet und überzählige Pakete verwirft, statt sie zu puffern. Auf den anderen Pfaden wird offenbar sanft geformt (Shaping). Das deckt sich mit dem Funktionstest vom Vortag, bei dem auf derselben Strecke 1,51 Gbit/s gemessen wurden (2 Sekunden, also überwiegend Anfangsspitze). Die Gegenrichtung NC3 → Codefield ist unauffällig.

Bewertung: Für K3s ist das **kein Ausschlusskriterium**. Der Effekt tritt nur auf, wenn die Strecke voll ausgelastet ist. Die ICMP-Messung (9.2) zeigt auf NC3 ↔ Codefield sogar die geringste Streuung aller Pfade. Bei großen Übertragungen von Codefield zu NC3 (Image-Pulls, Volume-Replikation, Backups) können aber Paketverluste auftreten. Diese können gleichzeitig laufenden Verkehr (Kubernetes-API, Minecraft) kurz verzögern. Deshalb sollte man solche Übertragungen begrenzen (z. B. Bandbreitenlimit bei Backups). In Phase B ist zu prüfen, ob der Effekt über WireGuard (UDP) ebenso auftritt.

Der 2-Sekunden-Funktionstest vom 14.11.2026 ist nur noch der Vollständigkeit halber in [messdaten/iperf-funktionstest-2s/](messdaten/iperf-funktionstest-2s/) abgelegt.

### 9.6 Langzeitmessung (72 h, Abschlussauswertung)

Messzeit: 14.11.2026, 22:05 Uhr bis 17.11.2026, 22:05 Uhr (Samstagabend bis Dienstagabend, drei volle Tag-Nacht-Zyklen, davon zwei Werktage). Je Richtung 4.191–4.192 Messblöcke zu je 10 Pings, also rund 41.900 Pakete pro Richtung und gut 251.000 insgesamt. In keinem Log fehlt ein Messblock (kein Abstand über 75 s). Alle sechs Units liefen bis zum Ende durch und wurden nach Ablauf von `RuntimeMaxSec=72h` planmäßig beendet (systemd zeigt sie deshalb als „failed (timeout)“ an). Rohdaten (gzip): [messdaten/langzeit/](messdaten/langzeit/), Auswerteskript: [perfscripts/netmess-longterm-auswertung.py](perfscripts/netmess-longterm-auswertung.py).

| Quelle → Ziel | Pakete gesendet / verloren | Verlust | RTT min | RTT avg | Median | p99 | p99,9 | max | Jitter (mdev je Block, Ø) | Pakete > 10 ms |
|---|---|---|---|---|---|---|---|---|---|---|
| MeckMinecraft → NC3 | 41.910 / 10 | 0,024 % | 0,219 ms | 0,489 ms | 0,457 ms | 0,90 ms | 7,6 ms | 10,8 ms | 0,08 ms | 6 |
| NC3 → MeckMinecraft | 41.920 / 9 | 0,021 % | 0,253 ms | 0,498 ms | 0,457 ms | 1,00 ms | 7,5 ms | 17,6 ms | 0,10 ms | 20 |
| MeckMinecraft → Codefield | 41.910 / 10 | 0,024 % | 0,215 ms | 0,491 ms | 0,469 ms | 0,82 ms | 5,0 ms | 12,1 ms | 0,07 ms | 1 |
| Codefield → MeckMinecraft | 41.920 / 0 | 0 % | 0,212 ms | 0,503 ms | 0,458 ms | 1,17 ms | 8,6 ms | 11,7 ms | 0,10 ms | 14 |
| NC3 → Codefield | 41.920 / 8 | 0,019 % | 0,251 ms | 0,491 ms | 0,470 ms | 0,99 ms | 2,0 ms | 8,9 ms | 0,08 ms | 0 |
| Codefield → NC3 | 41.920 / 0 | 0 % | 0,188 ms | 0,485 ms | 0,455 ms | 1,00 ms | 5,6 ms | 14,6 ms | 0,09 ms | 3 |

**Latenz und Jitter:** Über die ganze Messung liegt die mittlere RTT auf allen Pfaden bei 0,49–0,50 ms, praktisch identisch mit der Kurzmessung (9.2). 99 % aller Pakete sind schneller als 1,2 ms. Ausreißer über 10 ms sind selten (höchstens 20 von 41.920 Paketen pro Richtung, Maximum 17,6 ms) und treten einzeln auf, nicht als länger erhöhte Phase. Der Jitter innerhalb eines Messblocks liegt im Mittel bei 0,07–0,10 ms, die Gesamtstreuung (σ) bei 0,16–0,46 ms.

**Tag/Nacht und Werktag:** Es gibt keinen Tagesgang. Der schlechteste Stundenmittelwert liegt je nach Pfad bei 0,51–0,59 ms, der beste bei 0,45–0,47 ms. Tagsüber (07–23 Uhr) und nachts unterscheiden sich die Mittelwerte um höchstens 0,04 ms. Auch die Werktage (Montag/Dienstag) unterscheiden sich nicht vom Wochenende: Im letzten Messabschnitt (16.11.2026, 20:34 Uhr bis Messende, 25,5 h) liegt die mittlere RTT bei 0,48–0,50 ms, p99 bei 0,73–1,09 ms, und kein Stundenmittelwert übersteigt 0,66 ms. Die einzige messbare Erhöhung fällt in den iperf3-Lauf am 15.11.2026, 04:00–04:12 Uhr (Ø 1,25–1,36 ms auf den Pfaden mit MeckMinecraft, Spitzen bis 10,8 ms). Das ist die eigene Volllast und kein Netzproblem; es zeigt aber, dass ausgelastete Leitungen die Latenz anderer Verbindungen spürbar erhöhen (vgl. Hinweis zu großen Übertragungen in 9.5).

**Paketverlust – ein einzelnes Ereignis:** Alle Verluste stammen aus **einem Ereignis am 16.11.2026 um 05:17 Uhr** (Montagfrüh); außerhalb davon ging in 72 Stunden kein einziges Paket verloren. In den 41 Stunden nach dem Ereignis trat keine weitere Unterbrechung auf.

| Host | Messblock | Ergebnis |
|---|---|---|
| NC3 → Codefield / MeckMinecraft | 05:17:38 | nur die ersten 1–2 Pings beantwortet, danach 8 bzw. 9 von 10 verloren |
| MeckMinecraft → NC3 / Codefield | 05:17:43 | 10 von 10 verloren |
| Codefield → NC3 / MeckMinecraft | 05:17:32 und 05:18:33 | vollständig, beide Blöcke liegen außerhalb des Ausfallfensters |
| alle | ab 05:18:33 | wieder normal (Ø 0,4–0,5 ms) |

Die Unterbrechung begann also gegen 05:17:38 Uhr, dauerte mindestens 7 Sekunden und war spätestens um 05:18:33 Uhr vorbei. Passend dazu meldet Docker auf NC3 um 05:17:57 Uhr einen Timeout beim externen DNS-Server des Providers (46.38.225.230); auch Verkehr nach außen war also betroffen. In den Journals der drei Hosts gibt es zu dieser Zeit keine lokale Ursache (kein Neustart, keine Netzwerkänderung, nur der normale stündliche Cron-Lauf um 05:17:01 Uhr). Da NC3 und MeckMinecraft gleichzeitig betroffen waren, liegt die Ursache sehr wahrscheinlich beim Provider (Router/Switch oder Wartung). Ob Codefield ebenfalls betroffen war, lässt sich nicht sagen, weil dort zwischen 05:17:34 und 05:18:33 Uhr nicht gemessen wurde.

**Bewertung nach Abschnitt 4:**

- Mittlere RTT: 0,49–0,50 ms → **Gut** (< 10 ms)
- Jitter: 0,07–0,10 ms im Mittel, Gesamtstreuung (σ) 0,16–0,46 ms → **Gut** (< 2 ms)
- Paketverlust: 0,02 % auf vier Pfaden, 0 % auf zwei → formal **Prüfbedarf** (> 0–0,1 %). Der Verlust geht aber vollständig auf die eine Unterbrechung zurück und ist nicht über die Zeit verteilt; ohne dieses Ereignis läge er auf allen Pfaden bei 0 %.
- Stabilität: eine einzelne kurze Unterbrechung (Sekunden bis höchstens 1 Minute) in 72 h, keine Wiederholung → **Prüfbedarf** („Einzelne Unterbrechungen“), keine wiederkehrenden Ausfälle.

Für K3s ist eine Unterbrechung dieser Länge unkritisch: Der Node-Status wechselt erst nach 40–50 s ohne Heartbeat auf `NotReady` (je nach Kubernetes-Version), Pods werden standardmäßig erst nach 5 Minuten verdrängt. Für embedded etcd (Phase 2) könnte eine solche Unterbrechung eine Leader-Neuwahl auslösen; das Cluster erholt sich davon selbst, sollte aber überwacht werden. Da sich das Ereignis bis Messende nicht wiederholt hat, wird es als Einzelfall gewertet.

### 9.7 Offene Punkte

| Punkt | Status |
|---|---|
| Langzeitmessung (alle 60 s 10 Pings, 6 Richtungen, 72 h) | erledigt am 17.11.2026, 22:05 Uhr, abschließend ausgewertet in 9.6 |
| iperf3, 60 s je Richtung, mit und ohne `-R` | erledigt am 15.11.2026, 04:00–04:12 Uhr, ausgewertet in 9.5 |
| Unterbrechungen im Betrieb erfassen | im Monitoring (M5) vorsehen: Ping-/Blackbox-Prüfung zwischen den Nodes mit Alarm bei Verlust, damit sich wiederholende Provider-Störungen auffallen |
| Phase B (Control Plane, WireGuard, K3s) | wartet auf den zusätzlichen Server |

### 9.8 Bewertung

Gemessen an den Orientierungswerten aus Abschnitt 4 sind Latenz und Jitter in allen Messungen **„Gut“**:

- Die mittlere RTT liegt bei etwa 0,45 ms (Kurzmessung) bzw. 0,49–0,50 ms (72 h), gefordert sind unter 10 ms.
- Der Jitter (mdev) liegt bei höchstens 0,73 ms (Kurzmessung) bzw. im Mittel 0,07–0,10 ms (72 h), gefordert sind unter 2 ms.
- Der Paketverlust beträgt in den Kurzmessungen 0 %, in der Langzeitmessung 0–0,024 %, verursacht durch eine einzige kurze Provider-Unterbrechung.

Einzelne Ausreißer bis 17,6 ms sind vereinzelte Spitzen und haben keinen Einfluss auf Mittelwert und Streuung.

Die Durchsatzmessung (9.5) zeigt in allen Richtungen die volle 1-Gbit/s-Anbindung. Einzige Einschränkung ist die hohe Retransmit-Quote von Codefield zu NC3 bei Volllast; große Übertragungen auf dieser Strecke sollten deshalb begrenzt werden. Die Langzeitmessung (9.6) zeigt über drei Tage und Nächte unverändert rund 0,5 ms Latenz und 0,1 ms Jitter ohne Tagesgang. Die einzige Auffälligkeit, eine kurze providerseitige Unterbrechung am 16.11.2026 um 05:17 Uhr, hat sich bis Messende nicht wiederholt.

**Empfehlung: A – Geeignet.** Das Netz zwischen den drei Hosts genügt sowohl einem Cluster mit einer einzelnen Control Plane als auch den strengeren Anforderungen von embedded etcd (Phase 2). Für die neue Control Plane bietet sich derselbe Provider und dasselbe Rechenzentrum an, damit sie ebenfalls nur einen Hop entfernt ist. Begleitend sollten große Übertragungen von Codefield zu NC3 in der Bandbreite begrenzt und Unterbrechungen zwischen den Nodes im Monitoring erfasst werden.
