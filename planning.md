# Cubbermine – Planung

**Entscheidung:** **Variante B** – ein gemeinsamer Kubernetes/K3s-Cluster. **Phase 1:** neuer dedizierter Control-Plane-Server + drei bestehende Worker (MeckMinecraft, NC3, Codefield). **Phase 2 optional:** drei dedizierte Control Planes + dieselben drei Worker.

**Stand:** 16.11.2026 (M2 um Container-Konzept und Archiv ergänzt). Dies ist ein Plan mit Abnahmekriterien, keine Aussage über erledigte Arbeit. Termine werden nach der technischen Bestandsaufnahme festgelegt.

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

Grundlage ist das Container- und Pod-Konzept in [dockerminecraft.md](dockerminecraft.md) (Analyse von minecraftHostingServer und theDocks/mcserverdockB, Image-Aufbau, Pod-Aufbau, offene Entscheidungen in Abschnitt 8).

**Image und Pod**

- [ ] Offene Entscheidungen aus [dockerminecraft.md](dockerminecraft.md), Abschnitt 8 treffen (Registry, Versionsliste, SFTP-Sidecar, Storage, Proxy).
- [ ] Spigot-Image `cubbermine/spigot:<mc-version>-<build>` per CI bauen (Multi-Stage: BuildTools, Plugin-Katalog, GraalVM 25 Laufzeit, Nicht-root, Java als PID 1).
- [ ] Image lokal gegen die Kopie eines bestehenden `mcN_data`-Volumes testen: Welt, Plugins, Whitelist und Ops werden unverändert übernommen.
- [ ] Ein Minecraft-StatefulSet (1 Replica) mit PVC, ConfigMap, Secret und Service bereitstellen; initContainer für Konfiguration und Plugin-Sync.
- [ ] SFTP-Sidecar mit bisherigem Port und Schülerschlüssel anbinden.
- [ ] Start/Stopp über `replicas: 1/0`, Versionswechsel über Image-Tag nachweisen.
- [ ] Minecraft-TCP-Proxy als separaten öffentlichen Einstieg einrichten.
- [ ] Backends ausschließlich intern erreichbar machen (NetworkPolicy: Spielport nur vom Proxy, RCON nur von der API).
- [ ] RAM/CPU/Storage-Limits, Startverhalten, Restart, Probes und Speichern der Welt bei SIGTERM validieren.
- [ ] Node-Absturz mit lokalem/nichtlokalem Storage reproduzieren und dokumentieren.

**Archiv für Minecraft-Images**

Ein Image lässt sich später nicht zuverlässig neu bauen: BuildTools wird immer in der neuesten Fassung geladen, und Plugin-Downloads können sich ändern oder verschwinden. Jedes Image, das je produktiv lief, wird deshalb aufbewahrt.

- [ ] Registry festlegen (z. B. GHCR privat oder eigene Registry wie Zot/Harbor) und Zugang per `imagePullSecret` einrichten.
- [ ] Regel: Image-Tags sind unveränderlich; Tags, die ein Server verwendet oder verwendet hat, werden nie gelöscht.
- [ ] Zusätzlich jedes freigegebene Image als OCI-Archiv (`skopeo copy … oci-archive:` bzw. `docker save`) mit Prüfsumme ins Archiv außerhalb des Clusters legen, damit ein Ausfall oder Verlust der Registry abgedeckt ist.
- [ ] Zu jedem Image Build-Metadaten ablegen: Minecraft-Version, BuildTools-Build, Liste und Prüfsummen der Plugin-Jars, Git-Commit des Dockerfiles.
- [ ] Wiederherstellung testen: Image aus dem Archiv in eine leere Registry laden und einen Pod damit starten.

**Archiv für Welt-Backups**

- [ ] Archivspeicher außerhalb der Worker-Nodes festlegen (S3-kompatibler Objektspeicher oder Storage-Box beim Provider bzw. an einem anderen Standort); ein Backup auf demselben Host wie der Server zählt nicht als Archiv.
- [ ] Backup-Job je Server: RCON `save-off` + `save-all flush`, `cfg`/`plugins`/`worlds` als ZIP im bisherigen `backup.sh`-Format, Upload ins Archiv, `save-on`.
- [ ] Aufbewahrung festlegen und automatisieren, Vorschlag: täglich 14 Tage, wöchentlich 8 Wochen, monatlich 12 Monate; zusätzlich ein Backup vor jeder Migration, jedem Versionswechsel und jedem `wipe`, das nicht automatisch gelöscht wird.
- [ ] Prüfsummen und Verschlüsselung der Archive; Zugangsdaten nur als Secret.
- [ ] Zu jedem Backup festhalten, mit welchem Image-Tag es erstellt wurde (Restore nur mit passender oder neuerer Version).
- [ ] Bestehende Backups (Backup-Server auf NC3, `BACKUP_URL`; mineback auf Codefield) ins Archiv übernehmen bzw. in den neuen Ablauf überführen.
- [ ] Vollständigen Restore einer Testwelt aus dem Archiv in ein neues PVC durchführen; Restore-Test regelmäßig wiederholen (siehe M5).
- [ ] Überwachung: Alarm, wenn ein Backup fehlt, fehlschlägt oder das Archiv voll läuft.

**Gate:** Testspieler verbinden sich; Daten überstehen Pod-Neustart; das produktive Image liegt in Registry und Archiv und lässt sich aus dem Archiv wiederherstellen; Backup ins Archiv und vollständiger Restore einer Welt sind nachgewiesen.

### M3 – Cubbermine Control API / MVP

- [ ] Ressourcen- und Berechtigungsmodell definieren.
- [ ] Provisionierung als idempotente API/Controller implementieren.
- [ ] Create, Start, Stop, Restart, Status und Delete (ohne Datenlöschung) implementieren.
- [ ] Restore in der Weboberfläche: Backups des Servers aus dem Archiv auflisten, Auswahl ganz oder in Teilen (Welten, Plugins, Konfiguration) zurückspielen; vorher automatisches Sicherungs-Backup, Stopp/Start, Versionsprüfung, Bestätigung, Eintrag im Aktionsprotokoll (siehe [features.md](features.md)).
- [ ] Separate bestätigungspflichtige Datenlöschung mit Retention/Backup.
- [ ] Logs, Events und Node-Kapazität bereitstellen.
- [ ] Adminpanel integrieren; Auth, RBAC und Quotas prüfen.
- [ ] Tests für Fehlerfälle, doppelte Requests und unzureichende Ressourcen.

**Gate:** Eine Minecraft-Instanz lässt sich über das Adminpanel vollständig verwalten, einschließlich Restore eines Backups aus dem Archiv.

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
| P0 | Image-Pipeline, Registry und Image-Archiv | Konzept [dockerminecraft.md](dockerminecraft.md) |
| P0 | Welt-Backup-Archiv außerhalb der Nodes mit Aufbewahrung und Restore-Test | Wahl des Archivspeichers |
| P0 | Gemeinsamen K3s-Cluster aufbauen | Control Plane, VPN |
| P0 | StatefulSet + Service + Proxy-Pilot | K3s, Storage |
| P0 | Cubbermine API + Basis-UI | Kubernetes-Pilot |
| P0 | Sicherheitsgrundlagen/Monitoring | Cluster |
| P1 | Migration von mc1 bis mc5, Lobby/Proxy | MVP-Abnahme |
| P1 | Mods/Plugins, Templates, Multi-Tenant | API und Quotas |
| P2 | Automatisches Failover / Self-Service | HA-/Storage-Nachweis |

## Definition of Done pro Workload

1. Konfiguration und Version dokumentiert.
2. Daten-Backup im Archiv vorhanden und Restore aus dem Archiv getestet; verwendetes Image ist archiviert.
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
- Images lassen sich nicht reproduzierbar neu bauen (BuildTools, Plugin-Downloads); ohne Image-Archiv sind alte Welten ggf. nicht mehr startbar.
- Backups auf demselben Host oder im selben Rechenzentrum gehen bei einem Ausfall mit verloren.
- Unterschiedliche Java-/Minecraft-/Plugin-Versionen bei Migration.
- Kollisionen mit bestehenden öffentlichen Ports und Reverse Proxies.

Siehe [architecture.md](architecture.md) für Architekturdiagramme und [features.md](features.md) für den Funktionsumfang.
