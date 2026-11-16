# Cubbermine – Features

**Zielvariante B:** Eine zentrale Minecraft-Hosting-Plattform auf **einem gemeinsamen K3s-Cluster mit vier Nodes in Phase 1**: einer neu angemieteten dedizierten Control Plane und drei bestehenden Worker-Nodes (MeckMinecraft, NC3, Codefield). Optionaler Phase-2-Ausbau auf drei Control Planes plus drei Worker.

**Legende:** P0 = MVP, P1 = Ausbau, P2 = optional. Status aller Einträge: **geplant** für Cubbermine; dieses Repository enthält noch keine Implementierung. Einträge mit **(Bestand)** gibt es heute schon im Adminpanel von minecraftHostingServer; sie müssen in Cubbermine mindestens gleichwertig vorhanden sein, bevor ein Server umzieht.

## Bestand: heutiges Adminpanel

Auf MeckMinecraft (`admin.meckminecraft.de`) und NC3 (`admin.cndrbrbr.de`) läuft bereits eine Weboberfläche zur Verwaltung der Minecraft-Server. Sie ist der Ausgangspunkt für die Cubbermine-Weboberfläche. In Cubbermine werden beide Instanzen zu **einer gemeinsamen Weboberfläche** für alle Server zusammengeführt; auf welchem Node ein Server läuft, sieht der Nutzer nicht. PuTTY wird für die Verwaltung nicht mehr genutzt; für Dateien verwenden Schüler weiterhin FileZilla (SFTP).

| Bereich | Heute vorhanden |
| --- | --- |
| Anmeldung | E-Mail + Passwort, danach 6-stelliger Code per E-Mail; Einladung per Mail; Sitzungen mit Zeitlimit |
| Rollen | Schüler sehen nur den ihnen zugewiesenen Server; Lehrkräfte (Admins) sehen und verwalten alle Server |
| Server | Status, Version, Spieler online; Start, Stopp, Neustart |
| Plugins | Installation aus dem Plugin-Katalog (passende Jar zur Minecraft-Version), Upload eigener Plugins, Entfernen; Pflicht-Plugins (Prometheus-Exporter) gesperrt |
| Spieler | Whitelist pflegen, Operator-Rechte vergeben/entziehen, sofort per RCON |
| Einstellungen | `server.properties` im Browser bearbeiten, geschützte Schlüssel, Rückgängig |
| Lehrkräfte | Server an Schüler zuweisen und freigeben (optional zurücksetzen), Konten einladen/löschen, weitere Admins, Lobby nur für Admins |
| Protokoll | die letzten 40 Aktionen (wer hat was auf welchem Server getan) |
| Dateien | FileZilla/SFTP je Server, chroot auf den eigenen Server (außerhalb der Weboberfläche) |
| Backups | Wiederherstellen nur über den Steuerbefehl `restore <datum>` bzw. `restore latest`, **nicht** in der Weboberfläche |

Monitoring mit Prometheus/Grafana und Discord-Alerts läuft ebenfalls bereits (auf MeckMinecraft).

## P0 – MVP

| Feature | Beschreibung | Akzeptanzkriterium |
| --- | --- | --- |
| Gemeinsamer K3s-Cluster | Dedizierte Control Plane auf neuem vierten Host, drei bestehende Worker über gesichertes privates Netz | Control Plane und alle drei Worker erscheinen `Ready`; interner Pod-Verkehr funktioniert |
| Dedizierte Control Plane | K3s-Steuerung getrennt von Minecraft-Last; keine regulären Spielserver-Pods auf dem Control-Plane-Host | K3s-API nur administrativ erreichbar; Minecraft-Pods laufen ausschließlich auf Workern |
| Control-Plane-Backup & Recovery | Sicherung des K3s-Datastores und getestete Wiederherstellung | Wiederanlauf der Single Control Plane ist dokumentiert und im Test erfolgreich |
| SPOF-Transparenz | Bei nur einer Control Plane Ausfallfolgen sichtbar dokumentieren | Ausfalltest bestätigt Grenzen von Scheduling und Verwaltung; laufende Pods und Abhängigkeiten werden getrennt bewertet |
| Node-/Kapazitätsübersicht | CPU, RAM, Storage, Pod-Status pro Node | Dashboard/API zeigt aktuelle Messwerte und Warnungen |
| Minecraft-Server erstellen | Servertyp, Image/Version, RAM, CPU, Storage auswählen | Ein gültiger Antrag erzeugt genau eine nutzbare Instanz |
| Server starten/stoppen/neustarten **(Bestand)** | Lifecycle über Kubernetes steuern (`replicas 1/0`), bedient über die Weboberfläche | Statuswechsel ist nachvollziehbar und Welt bleibt erhalten |
| Persistente Welten | PVC je Minecraft-Instanz | Pod-Neuanlage verliert keine Weltdaten |
| Minecraft-TCP-Zugang | Öffentlicher Proxy routet zu internen Minecraft-Services | Externer Client erreicht den vorgesehenen Server |
| Konfiguration **(Bestand)** | `server.properties` in der Weboberfläche bearbeiten (geschützte Schlüssel, Rückgängig); technische Einstellungen über ConfigMap/Secret | Änderungen validiert und kontrolliert ausgerollt |
| Serverstatus und Logs **(Status: Bestand)** | Laufzustand, Version, Spieler online, Ereignisse und aktuelle Logs | Fehlerursache und betroffener Pod sind in der Weboberfläche erkennbar |
| Plugin-Verwaltung **(Bestand)** | Plugins aus dem Katalog passend zur Minecraft-Version installieren, eigene Plugins hochladen, entfernen; Pflicht-Plugins gesperrt | Funktionsumfang wie im heutigen Adminpanel |
| Spielerverwaltung **(Bestand)** | Whitelist und Operator-Rechte ohne Neustart (RCON) | Änderung wirkt sofort im laufenden Server |
| Serverzuweisung **(Bestand)** | Lehrkräfte weisen Server Schülern zu, geben sie frei und setzen sie optional zurück | Schüler sieht nur seinen Server; nach Freigabe sofort kein Zugriff mehr |
| Dateizugang per SFTP **(Bestand)** | FileZilla-Zugang je Server mit bisherigem Port und Schlüssel (SFTP-Sidecar) | Schüler erreicht nur die Dateien des eigenen Servers |
| Backup/Restore | Welt-Backups außerhalb des Nodes | Test-Restore einer Welt erfolgreich |
| Restore in der Weboberfläche **(neu)** | Backups des Servers mit Datum, Art (automatisch/vor Migration, Versionswechsel, `wipe`) und Minecraft-Version anzeigen; Backup auswählen und ganz oder in Teilen (Welten, Plugins, Konfiguration) zurückspielen. Vorher wird der aktuelle Stand automatisch gesichert, der Server gestoppt und danach wieder gestartet. Schüler für ihren eigenen Server, Lehrkräfte für alle | Restore läuft ohne Steuerbefehl vollständig über die Weboberfläche; Bestätigungsdialog; Backups einer neueren Minecraft-Version als der laufenden werden abgelehnt; Eintrag im Aktionsprotokoll; der vorherige Stand lässt sich wiederum zurückholen |
| Zugriffssicherheit **(Anmeldung/Rollen: Bestand)** | Anmeldung mit Passwort + E-Mail-Code, Rollen Schüler/Lehrkraft, RBAC, keine offenen Backend-Ports; kein Shell-/SSH-Befehlszugang für Nutzer | Nicht autorisierte Aktionen werden verweigert |
| Aktionsprotokoll **(Bestand)** | Wer hat was auf welchem Server getan | Jede Aktion in der Weboberfläche ist nachvollziehbar |
| Quotas und Limits | CPU/RAM/Storage je Instanz begrenzen | Unzulässige Anfragen werden vor Provisionierung abgelehnt |

## P1 – Ausbau

| Feature | Beschreibung | Akzeptanzkriterium |
| --- | --- | --- |
| Automatische Node-Wahl | Scheduler/Labels/Affinity berücksichtigen Kapazität | Platzierung ist reproduzierbar und begründet |
| Mod-Verwaltung und Plugin-Rollback | Forge-Mods wie Plugins aus einem Katalog verwalten; Update und Rollback von Plugin-Versionen (die Plugin-Installation selbst ist P0) | Update und Rollback möglich |
| Vorlagen | Paper, Spigot, Forge und weitere Profile | Neue Server aus versionierten Vorlagen startbar |
| Mehrere Projekte/Mandanten | Namespace-Trennung und Rechte; in der gemeinsamen Weboberfläche z. B. Lehrkräfte nur für die Server ihres Projekts (heute getrennt durch die zwei Instanzen) | Zugriff auf fremde Ressourcen ist technisch verhindert |
| Monitoring/Alerts **(Server-Metriken: Bestand)** | Prometheus/Grafana mit Alarmen; bestehende Dashboards und Discord-Alerts übernehmen, um Node-/Pod-Sicht erweitern | Node-/Pod-Ausfälle lösen Benachrichtigung aus |
| Wartungsmodus/Migration | Welten sichern, Dienst umstellen | Kontrollierter Wechsel mit Restore-/Rollback-Test |
| DNS und Domains | Verbindungsadressen zentral verwalten | DNS/Proxy-Zuordnung ist dokumentiert |
| API und Audit | Dokumentierte REST API, vollständiges Audit über das heutige Aktionsprotokoll hinaus (auch API- und Kubernetes-Ereignisse) | Jede administrative Änderung nachvollziehbar |

## Phase 2 – optionaler HA-Ausbau

- Zwei zusätzliche dedizierte Control-Plane-Hosts (insgesamt drei) und ein stabiler privater Kubernetes-API-Endpunkt.
- Embedded-etcd-HA mit dokumentierten Quorum- und Ausfalltests; nur nach Prüfung der Netzwerklatenzen und Datastore-Migration.
- Bestehende drei Worker bleiben als Minecraft-Ausführungsorte erhalten.
- HA der Control Plane ist nicht gleich HA der Minecraft-Welten oder des Storage.

## P2 – optional

- Self-Service-Bestellung neuer Server (heute weisen Lehrkräfte vorhandene Server zu; ein Benutzerportal für Schüler gibt es bereits)
- Zeitgesteuerter Start/Stop und automatische Ressourcenprofile
- API-basierte Erweiterungen oder Kubernetes Operator/CRD
- Billing/Kostenrechnung
- Automatisches Failover bei geeigneter Storage- und Control-Plane-Architektur (kein MVP-Versprechen)

## Grundsätze / Nicht-Ziele

- Ein Minecraft-Server hat standardmäßig genau **einen aktiv schreibenden Pod**; horizontales Skalieren einer Welt ist kein MVP-Feature.
- Ein gemeinsamer Cluster bedeutet **nicht** automatisch Storage-Failover, unterbrechungsfreie Live-Migration oder HA.
- Kein unkontrollierter Zugriff von Spielern auf Kubernetes API, Docker-Socket oder Host-Dateisystem.
- Bestandssysteme werden erst nach getesteter Migration ersetzt; Funktionen des heutigen Adminpanels dürfen dabei nicht wegfallen.

Technische Details: [architecture.md](architecture.md). Reihenfolge und Gates: [planning.md](planning.md).
