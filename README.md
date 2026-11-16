# Cubbermine

**Minecraft Hosting on Kubernetes (K3s)**

Cubbermine ist ein Projekt zur Weiterentwicklung einer bestehenden Minecraft-Hosting-Infrastruktur von **Docker Compose** zu einem **gemeinsamen Kubernetes-/K3s-Cluster**. Ziel ist eine zentral verwaltete Plattform, über die Minecraft-Server bereitgestellt und betrieben werden können.

> **Projektstatus (16.11.2026):** Architektur- und Planungsphase, Meilenstein M0 (Bestandsaufnahme und Architekturentscheidungen) läuft: Inventar und Netzwerkmessung sind erledigt, die Entscheidungen zu Control-Plane-Server, Storage und Proxy stehen noch aus. Die Netzwerkmessung zwischen den drei Hosts ist ausgewertet (Empfehlung: **geeignet**), das Konzept für die Minecraft-Container steht. Es ist noch kein Cluster installiert; die bestehende Infrastruktur läuft unverändert mit Docker Compose.

## Bisherige Aktivitäten

- **Bestandsaufnahme:** Die Docker-Compose-Infrastruktur auf den drei Hosts **MeckMinecraft** (`185.170.113.136`), **NC3** (`2.56.99.112`) und **Codefield** (`89.58.11.96`) wurde inventarisiert.
- **Zielarchitektur:** Gewählt ist Variante B, ein gemeinsamer K3s-Cluster mit einem zusätzlichen dedizierten Control-Plane-Server und den drei bestehenden Hosts als Worker. Ein späterer Ausbau auf drei Control Planes ist als Option beschrieben ([architecture.md](architecture.md)).
- **Funktionsumfang und Planung:** Features mit Prioritäten, Meilensteine M0–M5 mit Gates, Backlog und Risiken sind dokumentiert ([features.md](features.md), [planning.md](planning.md)).
- **Netzwerkmessung Phase A** (14.–17.11.2026, [PreNetzwerkmessung.md](PreNetzwerkmessung.md), Abschnitt 9):
  - Latenz im Mittel rund **0,5 ms**, Jitter rund 0,1 ms, Pfad-MTU 1500, nur ein Router zwischen den Hosts (selber Provider, sehr wahrscheinlich dasselbe Rechenzentrum).
  - Durchsatz in allen sechs Richtungen rund **1 Gbit/s**; auf der Strecke Codefield → NC3 bei Volllast etwa 8 % Retransmits (vermutlich Policer beim Provider), kein Ausschlusskriterium.
  - Langzeitmessung (Zwischenauswertung nach 46,5 h): kein Tag-/Nachtunterschied, einziger Paketverlust durch eine kurze providerseitige Unterbrechung am 16.11.2026 um 05:17 Uhr.
  - **Ergebnis: A – Geeignet**, für eine einzelne Control Plane wie auch für einen späteren etcd-HA-Verbund. Abschlussprüfung nach Messende am 17.11.2026, 22:05 Uhr.
- **Container-Konzept:** Die bestehenden Minecraft-Images (minecraftHostingServer, theDocks/mcserverdockB) wurden analysiert. Daraus ist das Konzept für Image und Pod in Cubbermine entstanden: ein unveränderliches Image pro Minecraft-Version aus der CI, Java als Hauptprozess, Start/Stopp über `replicas 1/0`, SFTP-Sidecar für Schüler, Verwaltung über RCON, unverändertes Datenlayout für die Migration ([dockerminecraft.md](dockerminecraft.md)).
- **Archiv eingeplant:** In M2 sind ein Archiv für alle produktiv genutzten Minecraft-Images und ein Archiv für Welt-Backups außerhalb der Worker-Nodes vorgesehen, jeweils mit Restore-Test.
- **Adresskonzept und Dienste eingeplant:** **meckminecraft.de** wird die Hauptadresse für Minecraft (inkl. gemeinsamer Weboberfläche, Grafana und des JavaScript-Workshops, der von codefield.de umzieht), **cndrbrbr.de** bleibt für Omasys, NonameQuiz mit lokaler KI und Kookie, **codefield.de** geht an orbita2core. Die Übernahme aller dieser Dienste samt Monitoring in den Cluster ist geplant ([websites-monitoring.md](websites-monitoring.md)). Dabei fiel auf, dass Prometheus und Grafana (MeckMinecraft) sowie Omasys (NC3) direkt über HTTP-Ports öffentlich erreichbar sind und Prometheus kein Volume hat; das soll vorab behoben werden.

## Anstehende Arbeiten

1. **Netzwerkmessung abschließen:** Langzeitmessung nach Ende am 17.11.2026 abschließend prüfen (Wiederholung der Unterbrechung?) und die Bewertung in [PreNetzwerkmessung.md](PreNetzwerkmessung.md) festschreiben.
2. **Offene Entscheidungen treffen:** Control-Plane-Server (Empfehlung: selber Provider/Standort), Speicherstrategie, Container-Registry und Archivspeicher, Minecraft-Proxy (BungeeCord oder Velocity), siehe [dockerminecraft.md](dockerminecraft.md), Abschnitt 8.
3. **Control Plane bereitstellen und Cluster-Netz aufbauen (M1):** Server anmieten, WireGuard mit MTU 1420, K3s installieren, Datastore-Backup testen, die drei Worker aufnehmen.
4. **Minecraft-Prototyp (M2):** Spigot-Image per CI bauen und archivieren, Testserver als StatefulSet mit PVC, SFTP-Sidecar und Proxy betreiben, Welt-Backup ins Archiv und vollständigen Restore nachweisen.
5. **Cubbermine-Verwaltung (M3):** API/Adminpanel für Erstellen, Starten, Stoppen, Überwachen und Verwalten der Server; Befehle des bisherigen Dispatchers als API-Endpunkte.
6. **Schrittweise migrieren (M4):** Server einzeln mit Backup und Rückfallmöglichkeit umziehen, Proxy und Lobby zuletzt; danach Websites und Dienste nach dem neuen Adresskonzept umziehen (meckminecraft.de mit Workshop, cndrbrbr.de, zuletzt orbita2core auf codefield.de).
7. **Härtung und Betrieb (M5):** Monitoring, Alerts, regelmäßige Restore- und Ausfalltests.
8. **Optional HA ausbauen (M1b):** später zwei weitere Control-Plane-Server, sofern Bedarf besteht; die Netzwerkqualität lässt es zu.

## Dokumentation

| Dokument | Inhalt |
| --- | --- |
| [altsystem.md](altsystem.md) | Beschreibung des heute laufenden Altsystems (drei Docker-Compose-Hosts): Architektur, technischer Aufbau, Ports, Backups, Monitoring, Befunde |
| [architecture.md](architecture.md) | Aktuelle Infrastruktur und K3s-Zielarchitektur mit Mermaid-Diagrammen |
| [features.md](features.md) | Geplanter Funktionsumfang und Prioritäten |
| [planning.md](planning.md) | Meilensteine, Aufgaben und Migrationsplanung, inkl. Image- und Backup-Archiv (M2) |
| [dockerminecraft.md](dockerminecraft.md) | Analyse der bestehenden Minecraft-Docker-Images und Container-/Pod-Konzept für Cubbermine mit Architekturdiagramm |
| [websites-monitoring.md](websites-monitoring.md) | Adresskonzept (meckminecraft.de / cndrbrbr.de / codefield.de) und Übernahme aller Websites, Dienste und des Monitorings in den Cluster, Befunde im Bestand, Architekturdiagramm |
| [PreNetzwerkmessung.md](PreNetzwerkmessung.md) | Messauftrag und Ergebnisse der Netzwerkmessung zwischen den Hosts (Abschnitt 9) |
| [messdaten/](messdaten/) | Rohdaten der Netzwerkmessung |
| [perfscripts/](perfscripts/) | Mess- und Auswerteskripte der Netzwerkmessung |

Die Reihenfolge der Umsetzung und technische Entscheidungen werden anhand der Messungen und Pilotversuche überprüft.
