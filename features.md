# Cubbermine – Features

**Zielvariante B:** Eine zentrale Minecraft-Hosting-Plattform auf **einem gemeinsamen K3s-Cluster mit drei Nodes** (MeckMinecraft, NC3, Codefield).

**Legende:** P0 = MVP, P1 = Ausbau, P2 = optional. Status aller Einträge: **geplant**; es wird keine Implementierung im Repository behauptet.

## P0 – MVP

| Feature | Beschreibung | Akzeptanzkriterium |
| --- | --- | --- |
| Gemeinsamer K3s-Cluster | 3 Hosts über gesichertes privates Node-Netz verbunden | Alle drei Nodes erscheinen `Ready` und Pods erreichen clusterinterne Services |
| Node-/Kapazitätsübersicht | CPU, RAM, Storage, Pod-Status pro Node | Dashboard/API zeigt aktuelle Messwerte und Warnungen |
| Minecraft-Server erstellen | Servertyp, Image/Version, RAM, CPU, Storage auswählen | Ein gültiger Antrag erzeugt genau eine nutzbare Instanz |
| Server starten/stoppen/neustarten | Lifecycle über Kubernetes steuern | Statuswechsel ist nachvollziehbar und Welt bleibt erhalten |
| Persistente Welten | PVC je Minecraft-Instanz | Pod-Neuanlage verliert keine Weltdaten |
| Minecraft-TCP-Zugang | Öffentlicher Proxy routet zu internen Minecraft-Services | Externer Client erreicht den vorgesehenen Server |
| Konfiguration | Umgebungsvariablen und serverbezogene Einstellungen | Änderungen validiert und kontrolliert ausgerollt |
| Serverstatus und Logs | Laufzustand, Ereignisse und aktuelle Logs | Fehlerursache und betroffener Pod sind im Adminpanel erkennbar |
| Backup/Restore | Welt-Backups außerhalb des Nodes | Test-Restore einer Welt erfolgreich |
| Zugriffssicherheit | Anmeldung, Rollen, RBAC, keine offenen Backend-Ports | Nicht autorisierte Aktionen werden verweigert |
| Quotas und Limits | CPU/RAM/Storage je Instanz begrenzen | Unzulässige Anfragen werden vor Provisionierung abgelehnt |

## P1 – Ausbau

| Feature | Beschreibung | Akzeptanzkriterium |
| --- | --- | --- |
| Automatische Node-Wahl | Scheduler/Labels/Affinity berücksichtigen Kapazität | Platzierung ist reproduzierbar und begründet |
| Mod-/Plugin-Verwaltung | Freigegebene Plugins/Mods versionsgebunden installieren | Update und Rollback möglich |
| Vorlagen | Paper, Spigot, Forge und weitere Profile | Neue Server aus versionierten Vorlagen startbar |
| Mehrere Projekte/Mandanten | Namespace-Trennung und Rechte | Zugriff auf fremde Ressourcen ist technisch verhindert |
| Monitoring/Alerts | Prometheus/Grafana mit Alarmen | Node-/Pod-Ausfälle lösen Benachrichtigung aus |
| Wartungsmodus/Migration | Welten sichern, Dienst umstellen | Kontrollierter Wechsel mit Restore-/Rollback-Test |
| DNS und Domains | Verbindungsadressen zentral verwalten | DNS/Proxy-Zuordnung ist dokumentiert |
| API und Audit | Dokumentierte REST API, Audit-Ereignisse | Jede administrative Änderung nachvollziehbar |

## P2 – optional

- Self-Service-Bestellung und Benutzerportal
- Zeitgesteuerter Start/Stop und automatische Ressourcenprofile
- API-basierte Erweiterungen oder Kubernetes Operator/CRD
- Billing/Kostenrechnung
- Automatisches Failover bei geeigneter Storage- und Control-Plane-Architektur (kein MVP-Versprechen)

## Grundsätze / Nicht-Ziele

- Ein Minecraft-Server hat standardmäßig genau **einen aktiv schreibenden Pod**; horizontales Skalieren einer Welt ist kein MVP-Feature.
- Ein gemeinsamer Cluster bedeutet **nicht** automatisch Storage-Failover, unterbrechungsfreie Live-Migration oder HA.
- Kein unkontrollierter Zugriff von Spielern auf Kubernetes API, Docker-Socket oder Host-Dateisystem.
- Bestandssysteme werden erst nach getesteter Migration ersetzt.

Technische Details: [architecture.md](architecture.md). Reihenfolge und Gates: [planning.md](planning.md).
