# Cubbermine – Planung

**Entscheidung:** **Variante B** – ein gemeinsamer Kubernetes/K3s-Cluster. **Phase 1:** neuer dedizierter Control-Plane-Server + drei bestehende Worker (MeckMinecraft, NC3, Codefield). **Phase 2 optional:** drei dedizierte Control Planes + dieselben drei Worker.

**Stand:** 14.11.2026. Dies ist ein Plan mit Abnahmekriterien, keine Aussage über erledigte Arbeit. Termine werden nach der technischen Bestandsaufnahme festgelegt.

## Meilensteine

### M0 – Inventarisierung und Architekturentscheidungen

- [ ] Inventare aller Hosts verifizieren: CPU, RAM, Disk, Netzwerk, Firewall, laufende Container, Volumes und Compose-Dateien.
- [ ] Abhängigkeiten, öffentliche Ports, DNS, Proxy, Backup-Stand und Speicherorte dokumentieren.
- [ ] Netz-Latenz/RTT, Bandbreite, Paketverlust, MTU zwischen den drei Hosts messen.
- [ ] Neuen dedizierten Control-Plane-Server planen und anmieten (Richtwert: 2–4 vCPU, 4–8 GiB RAM, 40–80 GB SSD; tatsächlichen Bedarf prüfen).
- [ ] Phase-1-Topologie festhalten: genau eine dedizierte K3s-Control-Plane, drei reine Worker; Single Point of Failure ausdrücklich akzeptieren oder überarbeiten.
- [ ] Datastore und Sicherung/Wiederherstellung der einzelnen Control Plane festlegen.
- [ ] Anforderungen an optionalen Phase-2-Ausbau auf drei Control Planes (etcd-Quorum, privater API-Load-Balancer, Migration) erfassen.
- [ ] Speicherstrategie wählen (lokale PVCs + Node-Pinning oder getesteter verteilter Storage).
- [ ] Minecraft-Proxy, Auth und Anforderungen an Mandantentrennung festlegen.

**Gate:** Architekturentscheidung und Risikoliste schriftlich freigegeben.

### M1 – Privates Cluster-Netz und K3s-Labor

- [ ] Privates WireGuard-/Overlay-Netz mit definierten Node-IP-Adressen aufbauen.
- [ ] Firewall/SSH/Kubernetes-API absichern und benötigte Cluster-Ports dokumentieren.
- [ ] K3s nichtproduktiv **auf dem neuen dedizierten Control-Plane-Host** installieren; Minecraft-Workloads dort ausschließen.
- [ ] CNI, DNS, StorageClass und grundlegende Pod-Kommunikation testen.
- [ ] MeckMinecraft, NC3 und Codefield kontrolliert als **drei Worker in denselben Cluster** aufnehmen.
- [ ] Worker-Ausfall, Rejoin und Recovery prüfen; separaten Ausfall der einzigen Control Plane simulieren und Auswirkungen dokumentieren.
- [ ] Datastore-Backup und Restore der Control Plane praktisch testen.

**Gate:** Dedizierte Control Plane und alle drei Worker `Ready`; Cluster-Kommunikation funktioniert über private IPs; keine ungewollt öffentlichen Admin-Endpunkte.

### M1b – Phase-2-HA-Entscheidung (optionaler späterer Ausbau)

- [ ] Betriebserfahrung und tatsächliche Verfügbarkeitsanforderungen aus Phase 1 sammeln.
- [ ] Netzwerklatenz, Zuverlässigkeit und Ausfallzonen für drei etcd-Control-Plane-Mitglieder verifizieren.
- [ ] Zwei weitere Control-Plane-Server und private Kubernetes-API-/Load-Balancer-Adresse planen.
- [ ] Unterstützten Datastore-/HA-Migrationsweg in Testumgebung erproben; etcd-Snapshots und Recovery testen.
- [ ] Dokumentieren, dass Control-Plane-HA kein Storage- oder Minecraft-Failover garantiert.

**Gate (optional):** Drei Control Planes bilden ein stabiles Quorum und der Ausfall eines Mitglieds ist erfolgreich getestet.

### M2 – Minecraft-Workload-Prototyp

- [ ] Ein Minecraft-StatefulSet (1 Replica) mit PVC, ConfigMap und Service bereitstellen.
- [ ] Minecraft-TCP-Proxy als separaten öffentlichen Einstieg einrichten.
- [ ] Backends ausschließlich intern erreichbar machen.
- [ ] RAM/CPU/Storage-Limits, Startverhalten, Restart und Readiness validieren.
- [ ] Backup, externe Ablage und vollständigen Restore einer Testwelt durchführen.
- [ ] Node-Absturz mit lokalem/nichtlokalem Storage reproduzieren und dokumentieren.

**Gate:** Testspieler verbinden sich; Daten überstehen Pod-Neustart; Backup/Restore ist nachgewiesen.

### M3 – Cubbermine Control API / MVP

- [ ] Ressourcen- und Berechtigungsmodell definieren.
- [ ] Provisionierung als idempotente API/Controller implementieren.
- [ ] Create, Start, Stop, Restart, Status und Delete (ohne Datenlöschung) implementieren.
- [ ] Separate bestätigungspflichtige Datenlöschung mit Retention/Backup.
- [ ] Logs, Events und Node-Kapazität bereitstellen.
- [ ] Adminpanel integrieren; Auth, RBAC und Quotas prüfen.
- [ ] Tests für Fehlerfälle, doppelte Requests und unzureichende Ressourcen.

**Gate:** Eine Minecraft-Instanz lässt sich über das Adminpanel vollständig verwalten.

### M4 – Gestaffelte Migration

- [ ] Reihenfolge festlegen: zuerst nichtkritische Instanz, dann weitere Minecraft-Server, zuletzt Proxy/produktive Lobby.
- [ ] Für jede Instanz: Wartungsfenster, konsistentes Backup, Plugins/Mod-Versionen, Konfiguration, Welt-Import und Port-/DNS-Umschaltung planen.
- [ ] Funktion, Minecraft-Version, Plugins und Datenintegrität nach dem Umzug testen.
- [ ] Rückfall auf Compose vorbereiten; niemals zwei Server gleichzeitig dieselbe Welt beschreiben lassen.
- [ ] Omasys, NonameQuiz, Workshop-Websites und Monitoring **separat** hinsichtlich Migration bewerten.

**Gate:** Abgenommene Minecraft-Server sind stabil, Wiederherstellung und Rollback sind erprobt.

### M5 – Härtung und Betrieb

- [ ] Monitoring, Alerts, zentrale Logs, Dashboards und Kapazitätswarnungen einrichten.
- [ ] Dokumentierte Update-/Patch-/Zertifikatsprozesse.
- [ ] RBAC, NetworkPolicies, Secret-Management und Pod-Security prüfen.
- [ ] Wiederkehrende Restore- und Ausfalltests.
- [ ] Betriebshandbuch, SLOs und Verantwortlichkeiten definieren.

**Gate:** Produktivbetrieb und Recovery-Prozesse sind dokumentiert und getestet.

## Priorisierter Backlog

| Priorität | Aufgabe | Abhängigkeit |
| --- | --- | --- |
| P0 | Netzwerkmessungen und WireGuard-Konzept | Host-Inventar |
| P0 | Dedizierten vierten Control-Plane-Server beschaffen | Ressourcen- und Netzwerkplanung |
| P0 | Single-Control-Plane-Backup, Restore und Ausfalltest | Dedizierte Control Plane |
| P2 | Optionale Erweiterung auf drei Control Planes / etcd-HA | Netzwerkmessungen, Datastore-Migrationsprobe |
| P0 | Persistenter Storage samt Restore | Storage-Auswahl |
| P0 | Gemeinsamen K3s-Cluster aufbauen | Control Plane, VPN |
| P0 | StatefulSet + Service + Proxy-Pilot | K3s, Storage |
| P0 | Cubbermine API + Basis-UI | Kubernetes-Pilot |
| P0 | Sicherheitsgrundlagen/Monitoring | Cluster |
| P1 | Migration von mc1 bis mc5, Lobby/Proxy | MVP-Abnahme |
| P1 | Mods/Plugins, Templates, Multi-Tenant | API und Quotas |
| P2 | Automatisches Failover / Self-Service | HA-/Storage-Nachweis |

## Definition of Done pro Workload

1. Konfiguration und Version dokumentiert.
2. Daten-Backup vorhanden und Restore getestet.
3. PVC, Service und Security-Policies definiert.
4. Zugriff/Proxy-Routing und Logs überprüft.
5. RAM/CPU unter realer Last überprüft.
6. Rollback-Schritte dokumentiert.
7. Fachliche Abnahme nach erfolgreichem Test.

## Risiken

- Hohe Latenz und instabiles Cluster-Netz über mehrere Provider/Standorte.
- Die einzelne Control Plane in Phase 1 bleibt ein **Single Point of Failure**; Kubernetes-API und Controller können ausfallen, während bestehende Workloads eventuell weiterlaufen.
- Bei Phase-2-HA können Quorum-/Control-Plane-Ausfälle insbesondere durch hohe Latenz und ungeeignete Netzwerk-Topologie auftreten.
- Lokale Weltdaten verhindern transparente Verschiebung zwischen Nodes.
- Doppelter Weltzugriff verursacht Datenverlust.
- Unterschiedliche Java-/Minecraft-/Plugin-Versionen bei Migration.
- Kollisionen mit bestehenden öffentlichen Ports und Reverse Proxies.

Siehe [architecture.md](architecture.md) für Architekturdiagramme und [features.md](features.md) für den Funktionsumfang.
