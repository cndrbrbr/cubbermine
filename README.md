# Cubbermine

**Minecraft Hosting on Kubernetes (K3s)**

Cubbermine ist ein Projekt zur Weiterentwicklung einer bestehenden Minecraft-Hosting-Infrastruktur von **Docker Compose** zu einem **gemeinsamen Kubernetes-/K3s-Cluster**. Ziel ist eine zentral verwaltete Plattform, über die Minecraft-Server bereitgestellt und betrieben werden können.

> **Projektstatus:** Architektur- und Planungsphase. Die bestehende Infrastruktur läuft weiterhin mit Docker Compose; die Kubernetes-Migration ist geplant.

## Bisherige Aktivitäten

- Die bestehende Docker-Compose-Infrastruktur auf drei Hosts wurde inventarisiert: **MeckMinecraft** (`185.170.113.136`), **NC3** (`2.56.99.112`) und **Codefield** (`89.58.11.96`).
- Eine **K3s-Zielarchitektur** wurde entwickelt: ein zusätzlicher dedizierter Control-Plane-Server und die drei bestehenden Hosts als Worker-Nodes.
- Ein möglicher späterer Ausbau auf **drei Control Planes** für höhere Verfügbarkeit wurde beschrieben.
- Anforderungen, Funktionsumfang und Migrationsschritte wurden dokumentiert.
- Für die Kommunikation zwischen den Hosts wurde ein **Netzwerkmessauftrag** mit Latenz-, Paketverlust-, Routing- und Durchsatzmessungen erstellt.
- Im Verzeichnis [`messdaten/`](messdaten/) liegen bereits Messskripte und Messdaten zur Vorbereitung der Netzwerkanalyse. Eine abschließende Eignungsbewertung ist damit noch nicht dokumentiert.

## Anstehende Arbeiten

1. **Netzwerkmessungen auswerten:** Verbindungen zwischen den drei bestehenden Hosts hinsichtlich RTT, Jitter, Paketverlust und Durchsatz beurteilen.
2. **Cluster-Netzwerk planen:** WireGuard/VPN, Routing, DNS, Firewall und MTU festlegen und testen.
3. **Control Plane bereitstellen:** Zusätzlichen Server auswählen, dimensionieren und K3s installieren; Backup und Wiederherstellung testen.
4. **Drei Worker einbinden:** MeckMinecraft, NC3 und Codefield in denselben K3s-Cluster aufnehmen.
5. **Minecraft-Prototyp umsetzen:** Einen Testserver mit StatefulSet, persistentem Speicher, internem Service und Minecraft-Proxy betreiben.
6. **Cubbermine-Verwaltung entwickeln:** API/Adminpanel für Erstellen, Starten, Stoppen, Überwachen und Verwalten von Minecraft-Instanzen.
7. **Schrittweise migrieren:** Bestehende Server, Welten, Plugins und Konfigurationen mit Backup- und Rollback-Konzept übertragen.
8. **Optional HA ausbauen:** Später zwei weitere Control-Plane-Server ergänzen, sofern Bedarf und Netzwerkqualität dies zulassen.

## Dokumentation

| Dokument | Inhalt |
| --- | --- |
| [architecture.md](architecture.md) | Aktuelle Infrastruktur und K3s-Zielarchitektur mit Mermaid-Diagrammen |
| [features.md](features.md) | Geplanter Funktionsumfang und Prioritäten |
| [planning.md](planning.md) | Meilensteine, Aufgaben und Migrationsplanung |
| [PreNetzwerkmessung.md](PreNetzwerkmessung.md) | Messauftrag zur Prüfung der Verbindungen zwischen den Hosts |
| [messdaten/](messdaten/) | Messskripte und bislang abgelegte Messdaten |

Die Reihenfolge der Umsetzung und technische Entscheidungen werden anhand der Messungen und Pilotversuche überprüft.
