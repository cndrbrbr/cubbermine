# Cubbermine

**Minecraft Hosting on Kubernetes (K3s)**

Cubbermine ist ein Projekt zur Weiterentwicklung einer bestehenden Minecraft-Hosting-Infrastruktur von **Docker Compose** zu einem **gemeinsamen Kubernetes-/K3s-Cluster**. Ziel ist eine zentral verwaltete Plattform, über die Minecraft-Server bereitgestellt und betrieben werden können.

> **Projektstatus (18.11.2026):** Architektur- und Planungsphase. Meilenstein M0 läuft: Bestandsaufnahme und Netzwerkmessung sind erledigt (Empfehlung: **geeignet**), die Konzepte für Minecraft-Container, Registry, Websites/Dienste, Adressen und Backups stehen. Offen sind vor allem der Control-Plane-Server und die Speicherstrategie im Cluster. Parallel laufen **Sofortmaßnahmen im Bestand**: Sicherheitslücken wurden geschlossen, und seit dem 17.11.2026 liegt eine verschlüsselte Offsite-Kopie aller Backups auf einer Hetzner Storage Box, die täglich aktualisiert wird. Ein Cluster ist noch nicht installiert; die Infrastruktur läuft weiter mit Docker Compose.

## Bisherige Aktivitäten

### Analyse und Planung

- **Bestandsaufnahme:** Die Docker-Compose-Infrastruktur auf **MeckMinecraft** (`185.170.113.136`), **NC3** (`2.56.99.112`) und **Codefield** (`89.58.11.96`) ist mit Architekturdiagramm, Ports, Volumes, Backups und Befunden beschrieben ([altsystem.md](altsystem.md)).
- **Zielarchitektur:** Variante B, ein gemeinsamer K3s-Cluster mit einem zusätzlichen dedizierten Control-Plane-Server und den drei bestehenden Hosts als Worker; ein späterer Ausbau auf drei Control Planes ist als Option beschrieben ([architecture.md](architecture.md)).
- **Netzwerkmessung Phase A** (14.–17.11.2026, [PreNetzwerkmessung.md](PreNetzwerkmessung.md)): Latenz rund **0,5 ms**, Jitter rund 0,1 ms, Durchsatz rund **1 Gbit/s** in allen Richtungen, eine kurze providerseitige Unterbrechung am 16.11.2026, die sich bis Messende nicht wiederholt hat. **Ergebnis: A – Geeignet** (abschließend ausgewertet).
- **Container-Konzept:** unveränderliches Image pro Minecraft-Version aus der CI, Java als Hauptprozess, Start/Stopp über `replicas 1/0`, SFTP-Sidecar für FileZilla, Verwaltung über RCON, unverändertes Datenlayout ([dockerminecraft.md](dockerminecraft.md)); Registry GHCR mit GitHub Actions ([registries.md](registries.md)).
- **Weboberfläche:** Das bestehende Adminpanel wird zur **gemeinsamen Weboberfläche** für alle Server (`admin.meckminecraft.de`); alle heutigen Funktionen bleiben erhalten, neu kommt der **Restore in der Weboberfläche** (Schüler für den eigenen Server, Lehrkräfte für alle) ([features.md](features.md)).
- **Adresskonzept:** **meckminecraft.de** für alles rund um Minecraft (inkl. des JavaScript-Workshops, der von codefield.de umzieht; NC3-Server als `nc3-mc1` … `nc3-mc5`), **cndrbrbr.de** für Omasys, NonameQuiz und Kookie, **codefield.de** für orbita2core mit eigener Einstiegsseite. Minecraft-Server werden über **mc-router** nach Namen auf Port 25565 erreicht; Ollama bekommt eine niedrigere Priorität als Minecraft ([websites-monitoring.md](websites-monitoring.md)).
- **Backupkonzept:** 3-2-1 mit mineback-Tresor, verschlüsselter Offsite-Kopie (restic, Zugang nur anhängen) und Box-Snapshots; dieselbe Storage Box dient später als Backup- und Image-Archiv des Clusters. Anleitungen für restic unter Debian und Kopia unter Windows ([backups.md](backups.md)).

### Umgesetzt im Bestand (Sofortmaßnahmen, [planning.md](planning.md), Abschnitt S)

- Prometheus und Grafana (MeckMinecraft) sowie Omasys (NC3) sind nicht mehr direkt öffentlich; Grafana läuft unter `https://grafana.meckminecraft.de`.
- Prometheus-Daten liegen in einem benannten Volume; Prometheus, Grafana und Ollama laufen mit festen Versionen.
- Die lokalen Änderungen von minecraftDash sind eingecheckt, das node_exporter-Passwort liegt außerhalb von Git.
- **Offsite-Kopie:** Hetzner Storage Box BX21 (5 TB) in Helsinki bestellt; restic sichert den mineback-Tresor und weitere Zugangsdateien täglich um 03:30 verschlüsselt dorthin, der Zugang von NC3 kann nur anhängen (Löschen getestet: abgewiesen). Der Erstlauf (rund 834 GiB, davon 376 GiB nach Deduplizierung) ist am 17.11.2026 um 04:07 abgeschlossen; der erste tägliche Lauf am 18.11.2026 war ebenfalls erfolgreich (+14 GiB, 40 Minuten). Das Repository umfasst derzeit rund 390 GiB.

## Anstehende Arbeiten

1. **Sofortmaßnahmen abschließen** ([planning.md](planning.md), Abschnitt S):
   - Offsite-Kopie vervollständigen (Grafana-Alarm seit 18.11.2026 eingerichtet): Admin-Zugang zum Aufräumen, Box-Snapshots und Restore-Test von außerhalb NC3.
   - Passwort des Storage-Box-Hauptkontos ändern; restic-Passwort offline sichern.
   - Firewall für den Metrik-Port auf Codefield aktivieren (vorbereitet), `/api/prometheus/` auf lesende Abfragen beschränken.
   - Ungenutzte Volumes auf NC3 (rund 125 GB) nach Freigabe archivieren bzw. aufräumen.
2. **Offene Entscheidungen treffen:** Control-Plane-Server (Empfehlung: selber Provider/Standort), Speicherstrategie im Cluster, Ingress-Controller, BungeeCord oder Velocity, Aufbewahrungsregeln ([dockerminecraft.md](dockerminecraft.md), Abschnitt 8; [websites-monitoring.md](websites-monitoring.md), Abschnitt 6).
3. **Control Plane und Cluster-Netz (M1):** Server anmieten, WireGuard mit MTU 1420, K3s installieren, Datastore-Snapshots auf die Storage Box und Restore testen, die drei Worker aufnehmen.
4. **Minecraft-Prototyp (M2):** Spigot-Image per CI bauen und auf der Storage Box archivieren, Testserver als StatefulSet mit PVC, SFTP-Sidecar und mc-router, Monitoring im Cluster, Welt-Backup auf die Storage Box und vollständigen Restore nachweisen.
5. **Cubbermine-Verwaltung (M3):** Adminpanel auf die Cubbermine API umstellen, alle Bestandsfunktionen plus Restore in der Weboberfläche.
6. **Schrittweise migrieren (M4):** Server einzeln mit Backup und Rückfallmöglichkeit umziehen, Proxy und Lobby zuletzt; danach Websites und Dienste nach dem Adresskonzept (meckminecraft.de mit Workshop, cndrbrbr.de, zuletzt orbita2core auf codefield.de).
7. **Härtung und Betrieb (M5):** Monitoring, Alerts, regelmäßige Restore- und Ausfalltests inkl. Notfall-Restore aus der Storage Box.
8. **Optional HA ausbauen (M1b):** später zwei weitere Control-Plane-Server, sofern Bedarf besteht; die Netzwerkqualität lässt es zu.

## Dokumentation – empfohlene Lesereihenfolge

Die Dokumentation ist so geordnet, dass man **zuerst den heutigen Betrieb und die Messgrundlagen**, danach **die Kubernetes-Zielarchitektur und ihre technischen Teilkonzepte** und zuletzt **Funktionsumfang und Umsetzungsplan** kennenlernt. Die Messdaten und Skripte dienen zur Vertiefung beziehungsweise zur Überprüfung der Messergebnisse.

| Reihenfolge | Dokument | Warum lesen? |
| ---: | --- | --- |
| 1 | [altsystem.md](altsystem.md) | **Ausgangspunkt:** Heutige Docker-Compose-Hosts, Dienste, Zugänge und Betriebsrisiken verstehen. |
| 2 | [PreNetzwerkmessung.md](PreNetzwerkmessung.md) | **Machbarkeit:** Messauftrag, Verfahren und Ergebnisse zur Verbindungsqualität zwischen den Hosts nachvollziehen. |
| 3 | [messdaten/](messdaten/) | **Nachweise:** Die zur Netzwerkmessung abgelegten Rohdaten und Auswertungen einsehen. |
| 4 | [perfscripts/](perfscripts/) | **Reproduzierbarkeit:** Mess- und Auswerteskripte für eigene Prüfungen verwenden. |
| 5 | [architecture.md](architecture.md) | **Gesamtbild:** Den geplanten K3s-Cluster mit dedizierter Control Plane, drei Workern und Mermaid-Diagrammen verstehen. |
| 6 | [dockerminecraft.md](dockerminecraft.md) | **Minecraft-Technik:** Bestehende Images und das geplante Container-/Pod-Modell samt Speicher und Zugriffskonzept kennenlernen. |
| 7 | [websites-monitoring.md](websites-monitoring.md) | **Begleitdienste:** Künftige Domains, Websites, weitere Anwendungen und Monitoring im Cluster einordnen. |
| 8 | [registries.md](registries.md) | **Softwarebereitstellung:** GHCR, GitHub Actions, Image-Versionierung und die spätere Auslieferung an K3s verstehen. |
| 9 | [backups.md](backups.md) | **Datensicherung:** Backupkonzept mit Architektur (mineback-Tresor, Offsite-Kopie mit restic auf der Hetzner Storage Box, Windows-Rechner mit Kopia) und Schritt-für-Schritt-Anleitungen. |
| 10 | [features.md](features.md) | **Anforderungen:** Geplante Funktionen und deren Prioritäten mit dem heutigen Adminpanel vergleichen. |
| 11 | [planning.md](planning.md) | **Umsetzung:** Meilensteine, Abhängigkeiten, Abnahmekriterien und die schrittweise Migration durchgehen. |

**Für einen schnellen Einstieg** reichen zunächst die Punkte **1, 5, 9 und 10**. Wer die technischen Entscheidungen prüfen oder die Migration praktisch umsetzen möchte, liest die übrigen Dokumente in der angegebenen Reihenfolge.

Die Reihenfolge der Umsetzung und technische Entscheidungen werden anhand der Messungen und Pilotversuche überprüft.
