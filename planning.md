# Cubbermine – Planung

**Entscheidung:** **Variante B** – ein gemeinsamer Kubernetes/K3s-Cluster. **Phase 1:** neuer dedizierter Control-Plane-Server + drei bestehende Worker (MeckMinecraft, NC3, Codefield). **Phase 2 optional:** drei dedizierte Control Planes + dieselben drei Worker.

**Stand:** 17.11.2026 (M2 um Container-Konzept und Archiv ergänzt; Adresskonzept und alle Web-/Begleitdienste aufgenommen; Hetzner Storage Box als gemeinsames Backup- und Archivziel für Bestand und Cluster). Dies ist ein Plan mit Abnahmekriterien, keine Aussage über erledigte Arbeit. Termine werden nach der technischen Bestandsaufnahme festgelegt.

## Meilensteine

### S – Sofortmaßnahmen im Bestand (parallel zu M0/M1, unabhängig vom Cluster)

Diese Punkte betreffen das laufende Altsystem ([altsystem.md](altsystem.md), Abschnitt 6) und werden nicht bis zur Migration aufgeschoben.

**Backup-Kopie an einem anderen Ort**

Heute liegen die Backups aller drei Hosts nur im mineback-Tresor auf NC3 (`/var/lib/mineback`, 831 GB). Alle drei Hosts stehen beim selben Provider, sehr wahrscheinlich im selben Rechenzentrum. Ein Ausfall von NC3 oder des Rechenzentrums, ein Fehler beim Provider oder ein kompromittierter Host würde Server **und** Backups treffen.

- [x] Ziel festgelegt (Entscheidung 16.11.2026): **Hetzner Storage Box mit restic**, also anderer Provider als netcup. Standort **Helsinki (HEL1)** statt Falkenstein (FSN1), um möglichst weit vom netcup-Rechenzentrum entfernt zu sein. Dasselbe Ziel dient später als Archiv für den Cluster (M2).
- [x] Storage Box **BX21 in Helsinki** bestellt (Zugangsdaten nicht im öffentlichen Repo) (Entscheidung 16.11.2026; 5 TB, 10,90 €/Monat zzgl. MwSt., ca. 12,97 € brutto). Begründung: Der Tresor hat heute 831 GB; die längere Aufbewahrung und die Box-Snapshots brauchen zusätzlichen Platz, und auch das Cluster-Archiv (Images, Welt-Backups) soll dort liegen. BX11 (1 TB, 3,20 €/Monat zzgl. MwSt., ca. 3,81 € brutto) wäre schon beim Start fast voll. Größere Stufen: BX31 10 TB 20,80 €, BX41 20 TB 40,60 € (jeweils zzgl. MwSt.). Preise laut Hetzner-Website am 16.11.2026; Datenverkehr unbegrenzt, keine Mindestlaufzeit, Wechsel der Stufe möglich. Eine Einrichtungsgebühr wird auf der Seite erwähnt, aber nicht beziffert, deshalb bei der Bestellung prüfen.
- [x] **Umgesetzt 16.11.2026 als Skript** `/usr/local/sbin/mineback-offsite` mit Timer `mineback-offsite.timer` (täglich 03:30, 25 MB/s, niedrige Priorität) auf NC3; Repository `restic-mineback` auf der Box, gesichert werden `/var/lib/mineback/store` und `/etc/mineback/mineback.toml`. Erstlauf (~830 GB) gestartet am 16.11.2026, 23:35, abgeschlossen am 17.11.2026, 04:07. Ursprünglich geplant als mineback-Feature **T9 „Offsite replication“** (in mineback geplant, noch nicht umgesetzt): **restic** sichert `store/` des Tresors in ein Repository auf der Storage Box (Zugang per SSH auf Port 23, eigener Unterbenutzer nur für dieses Verzeichnis); `public/` wird nicht kopiert, weil es sich daraus neu erzeugen lässt. Weil `store/` nur ergänzt wird, ist eine abgebrochene Übertragung nie inkonsistent. Bis T9 fertig ist, übergangsweise ein Skript mit systemd-Timer auf NC3.
- [x] **Verschlüsselung beim Absender:** Die Spieldaten liegen im Tresor unverschlüsselt (nur Geheimnisse sind mit `age` verschlüsselt); restic verschlüsselt das Repository immer. Das restic-Passwort liegt nur auf NC3 und offline, nicht auf der Storage Box.
- [ ] Zweiter Zugang zum Aufräumen (`restic forget --prune`, Box-Snapshots einschalten) — nicht auf NC3; offen.
- [ ] Passwort der Storage Box ändern (wurde im Chat genannt).
- [ ] **Schlüssel getrennt sichern:** restic-Passwort liegt in `/root/.config/restic/mineback-offsite.pass` auf NC3 und muss zusätzlich offline aufbewahrt werden. Den `age`-Schlüssel des Tresors (`/etc/mineback/vault_identity.txt`) und den Schlüssel der Offsite-Kopie offline aufbewahren (Papier/USB, mindestens zwei Orte). Ohne sie ist die Kopie wertlos.
- [x] **Zeitplan und Bandbreite:** täglich 03:30 (nach den Agenten um 02:15), 25 MB/s, niedrige CPU- und Plattenpriorität; Erstlauf (~830 GB, ca. 10 h) ohne Zeitfenster am Stück. Seit 17.11.2026 werden außerdem Zugangsdateien außerhalb des Tresors mitgesichert (`mineback-offsite-collect`, siehe [backups.md](backups.md)).
- [ ] **Längere Aufbewahrung in der Kopie** als im Tresor (dort nur `keep_last = 1` plus markierte Stände): Vorschlag täglich 14 Tage, wöchentlich 8 Wochen, monatlich 12 Monate; Löschungen im Tresor dürfen nicht sofort in die Kopie durchschlagen.
- [x] (Schreibschutz getestet: Löschen eines Snapshots mit dem NC3-Schlüssel → `403 Forbidden`; Zugang über das Hauptkonto, noch kein Unterbenutzer) Zugang zur Kopie so einrichten, dass NC3 nur schreiben, aber keine alten Stände löschen kann, damit ein kompromittierter Host die Kopie nicht zerstören kann: Der SSH-Schlüssel von NC3 bekommt in der Storage Box einen festen Befehl `rclone serve restic --stdio --append-only <repo>` (laut restic-Forum auf der Storage Box möglich, nicht offiziell von Hetzner beschrieben, deshalb zuerst testen). Aufräumen (`restic forget --prune`) läuft mit einem zweiten Schlüssel, der nicht auf NC3 liegt. Zusätzlich automatische **Box-Snapshots** (BX21: bis zu 20) als zweite Absicherung; sie zählen gegen den Speicherplatz.
- [ ] **Überwachung:** Metrik `mineback_offsite_last_success_timestamp_seconds` (Textfile-Collector auf NC3) ist eingerichtet; Grafana-Alarm steht noch aus (Erstlauf abgeschlossen). Ziel: Alter der letzten erfolgreichen Offsite-Kopie als Metrik, Grafana-Alarm per Discord, wenn sie älter als 36 Stunden ist.
- [ ] **Restore-Test aus der Kopie:** einen Server von einem Rechner außerhalb von NC3 aus der Offsite-Kopie wiederherstellen (mineback `drill`), danach regelmäßig wiederholen.

**Sicherheit und Ordnung**

- [x] Prometheus (:9090) und Grafana (:3000) auf MeckMinecraft nur noch lokal; Grafana über `https://grafana.meckminecraft.de` (erledigt 16.11.2026).
- [x] Omasys (:3000) auf NC3 nur noch lokal (erledigt 16.11.2026; dabei fehlte eine `.env`, Omasys lief kurz mit Standard-Zugangsdaten — jetzt `.env` mit festen Werten).
- [ ] Metrik-Port 9940 auf Codefield auf MeckMinecraft beschränken: Skript `/root/fw-metrics.sh` und Unit `mc-firewall.service` liegen bereit (wie auf NC3); Aktivierung durch den Admin: `systemctl enable --now mc-firewall`.
- [ ] `/api/prometheus/` auf MeckMinecraft auf lesende Abfragen beschränken (heute vollständig offen).
- [x] Prometheus-Daten vom anonymen in ein benanntes Volume übernommen; feste Versionen Prometheus v3.11.0, Grafana 12.4.2, Ollama 0.35.0 (jeweils bitgleich mit den bisher laufenden Images; erledigt 16.11.2026).
- [x] Lokale Änderungen von minecraftDash eingecheckt (Commit `d7dc594`); node_exporter-Passwort aus `prometheus.yml` in `secrets/` außerhalb von Git verschoben, `.gitignore` für `secrets/` und `*.bak-*` (erledigt 16.11.2026).
- [ ] Ungenutzte Volumes und manuelle Backup-Ordner auf NC3 aufräumen: Liste erstellt (16.11.2026), Freigabe offen. Größte Posten: `minecraft_mcsrv25` (69 GB, alte Welten u. a. `Ehleworlds`, `creative`, `ehle25`), `minecraft_run` (17 GB), `/root/hostMC/backup` (21 GB), `/root/hostMC/backup2` (18 GB), `/root/mcag` (17 GB). Vorschlag: vor dem Löschen auf die Storage Box archivieren.

**Gate:** Eine verschlüsselte Kopie aller Backups liegt an einem anderen Standort, wird überwacht und ein Restore daraus ist nachgewiesen; die offenen HTTP-Ports sind geschlossen.

### M0 – Inventarisierung und Architekturentscheidungen

- [ ] Inventare aller Hosts verifizieren: CPU, RAM, Disk, Netzwerk, Firewall, laufende Container, Volumes und Compose-Dateien.
- [ ] Abhängigkeiten, öffentliche Ports, DNS, Proxy, Backup-Stand und Speicherorte dokumentieren.
- [x] Netz-Latenz/RTT, Bandbreite, Paketverlust, MTU zwischen den drei Hosts messen (Phase A, 14.–17.11.2026, Ergebnis A – Geeignet, siehe [PreNetzwerkmessung.md](PreNetzwerkmessung.md)).
- [ ] Neuen dedizierten Control-Plane-Server planen und anmieten (Richtwert: 2–4 vCPU, 4–8 GiB RAM, 40–80 GB SSD; tatsächlichen Bedarf prüfen).
- [ ] Phase-1-Topologie festhalten: genau eine dedizierte K3s-Control-Plane, drei reine Worker; Single Point of Failure ausdrücklich akzeptieren oder überarbeiten.
- [ ] Datastore und Sicherung/Wiederherstellung der einzelnen Control Plane festlegen; Sicherungsziel ist die Hetzner Storage Box (eigenes restic-Repository, Zugang nur anhängen).
- [ ] Anforderungen an optionalen Phase-2-Ausbau auf drei Control Planes (etcd-Quorum, privater API-Load-Balancer, Migration) erfassen.
- [ ] Speicherstrategie wählen (lokale PVCs + Node-Pinning oder getesteter verteilter Storage).
- [ ] Minecraft-Proxy und Anforderungen an Mandantentrennung festlegen; Anmeldung und Rollen (Schüler/Lehrkraft, E-Mail + Passwort + Code) aus dem bestehenden Adminpanel als Ausgangspunkt übernehmen.

**Gate:** Architekturentscheidung und Risikoliste schriftlich freigegeben.

### M1 – Privates Cluster-Netz und K3s-Labor

- [ ] Privates WireGuard-/Overlay-Netz mit definierten Node-IP-Adressen aufbauen.
- [ ] Firewall/SSH/Kubernetes-API absichern und benötigte Cluster-Ports dokumentieren.
- [ ] K3s-Ingress/ServiceLB so einrichten, dass er die Ports 80/443 der Hosts noch nicht belegt (dort laufen die bestehenden Caddy-Instanzen), siehe [websites-monitoring.md](websites-monitoring.md), Abschnitt 2.6.
- [ ] K3s nichtproduktiv **auf dem neuen dedizierten Control-Plane-Host** installieren; Minecraft-Workloads dort ausschließen.
- [ ] CNI, DNS, StorageClass und grundlegende Pod-Kommunikation testen.
- [ ] MeckMinecraft, NC3 und Codefield kontrolliert als **drei Worker in denselben Cluster** aufnehmen.
- [ ] Worker-Ausfall, Rejoin und Recovery prüfen; separaten Ausfall der einzigen Control Plane simulieren und Auswirkungen dokumentieren.
- [ ] Datastore-Backup der Control Plane einrichten (Snapshot → restic → Storage Box, eigener Schlüssel nur anhängen) und Restore auf einem frischen Server praktisch testen.
- [ ] Ausgehenden Zugang der Nodes zur Storage Box (SSH, Port 23) in Firewall/NetworkPolicy vorsehen.

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

**Monitoring im Cluster** (Konzept: [websites-monitoring.md](websites-monitoring.md))

- [ ] Voraussetzung: Sofortmaßnahmen „Sicherheit und Ordnung“ aus Abschnitt S erledigt.
- [ ] kube-prometheus-stack im Namespace `monitoring` mit PVC und festgelegter Aufbewahrung installieren; bisherige Compose-Ziele zusätzlich statisch scrapen.
- [ ] Minecraft-Pods per `PodMonitor` (Port 9940) erfassen; Labels `server_name` und `machine` beibehalten.
- [ ] Grafana mit bestehenden Dashboards, Alert-Regeln und Discord-Benachrichtigung aus Git provisionieren (Webhook und Admin-Passwort als Secret), Ingress mit TLS.
- [ ] Entscheiden, ob Prometheus-Historie und Grafana-Datenbank übernommen werden; ggf. kopieren.
- [ ] Externen Wächter (Uptime-Check) und Watchdog-Alert einrichten, damit ein Cluster-Ausfall gemeldet wird.
- [ ] Backup-Jobs überwachen (ersetzt `mineback-freshness`).
- [ ] Erreichbarkeits-Checks für Omasys, NonameQuiz/Ollama, Kookie und orbita2core ergänzen.

**Archiv für Minecraft-Images**

Ein Image lässt sich später nicht zuverlässig neu bauen: BuildTools wird immer in der neuesten Fassung geladen, und Plugin-Downloads können sich ändern oder verschwinden. Jedes Image, das je produktiv lief, wird deshalb aufbewahrt.

- [ ] Registry festlegen (z. B. GHCR privat oder eigene Registry wie Zot/Harbor) und Zugang per `imagePullSecret` einrichten.
- [ ] Regel: Image-Tags sind unveränderlich; Tags, die ein Server verwendet oder verwendet hat, werden nie gelöscht.
- [ ] Zusätzlich jedes freigegebene Image als OCI-Archiv (`skopeo copy … oci-archive:` bzw. `docker save`) mit Prüfsumme auf die **Hetzner Storage Box** legen (eigenes Verzeichnis bzw. restic-Repository, Zugang der CI nur anhängen), damit ein Ausfall oder Verlust der Registry abgedeckt ist.
- [ ] Zu jedem Image Build-Metadaten ablegen: Minecraft-Version, BuildTools-Build, Liste und Prüfsummen der Plugin-Jars, Git-Commit des Dockerfiles.
- [ ] Wiederherstellung testen: Image aus dem Archiv in eine leere Registry laden und einen Pod damit starten.

**Archiv für Welt-Backups**

- [x] Archivspeicher: **Hetzner Storage Box** aus Abschnitt S (anderer Provider und Standort als die Nodes, die alle im selben Rechenzentrum stehen); Welt-Backups per restic, Image-Archive (OCI) in einem eigenen Verzeichnis bzw. Unterbenutzer. Ein Backup auf einem Node des Clusters zählt nicht als Archiv.
- [ ] Backup-Job je Server: RCON `save-off` + `save-all flush`, `cfg`/`plugins`/`worlds` als ZIP im bisherigen `backup.sh`-Format, Upload ins Archiv, `save-on`.
- [ ] Aufbewahrung festlegen und automatisieren, Vorschlag: täglich 14 Tage, wöchentlich 8 Wochen, monatlich 12 Monate; zusätzlich ein Backup vor jeder Migration, jedem Versionswechsel und jedem `wipe`, das nicht automatisch gelöscht wird.
- [ ] Prüfsummen und Verschlüsselung der Archive; Zugangsdaten nur als Secret.
- [ ] Zu jedem Backup festhalten, mit welchem Image-Tag es erstellt wurde (Restore nur mit passender oder neuerer Version).
- [ ] Bestehende Backups ins Archiv übernehmen bzw. in den neuen Ablauf überführen: mineback-Tresor auf NC3 (`/var/lib/mineback`, 831 GB, Backups aller drei Hosts, nginx :8088 für `BACKUP_URL`) sowie manuelle Sicherungen in `/root/hostMC/backup*` (siehe [altsystem.md](altsystem.md), 3.5).
- [ ] Vollständigen Restore einer Testwelt aus dem Archiv in ein neues PVC durchführen; Restore-Test regelmäßig wiederholen (siehe M5).
- [ ] Überwachung: Alarm, wenn ein Backup fehlt, fehlschlägt oder das Archiv voll läuft (Belegung der Storage Box, 5 TB; bei Bedarf auf BX31 wechseln).
- [ ] Aufbewahrung auf der Storage Box mit dem Admin-Zugang (nicht im Cluster) per `restic forget --prune` umsetzen; Box-Snapshots als zusätzliche Absicherung.

**Gate:** Testspieler verbinden sich; Daten überstehen Pod-Neustart; Cluster und Pilotserver erscheinen in Grafana und lösen Alerts aus; das produktive Image liegt in Registry und Archiv und lässt sich aus dem Archiv wiederherstellen; Backup ins Archiv und vollständiger Restore einer Welt sind nachgewiesen.

### M3 – Cubbermine Control API / MVP

Ausgangspunkt ist das bestehende Adminpanel aus minecraftHostingServer (Weboberfläche auf MeckMinecraft und NC3, siehe [features.md](features.md), Abschnitt „Bestand“). Es steuert die Server heute über SSH und RCON je Server; in Cubbermine spricht es stattdessen mit der Cubbermine API. PuTTY wird nicht mehr genutzt, FileZilla bleibt (SFTP-Sidecar, M2).

- [ ] Ressourcen- und Berechtigungsmodell definieren; Rollen Schüler (nur zugewiesener Server) und Lehrkraft (alle Server) aus dem Bestand übernehmen und auf Kubernetes-RBAC/Namespaces abbilden.
- [ ] Provisionierung als idempotente API/Controller implementieren.
- [ ] Create, Start, Stop, Restart, Status und Delete (ohne Datenlöschung) implementieren.
- [ ] Restore in der Weboberfläche: Backups des Servers aus dem Archiv auflisten, Auswahl ganz oder in Teilen (Welten, Plugins, Konfiguration) zurückspielen; vorher automatisches Sicherungs-Backup, Stopp/Start, Versionsprüfung, Bestätigung, Eintrag im Aktionsprotokoll (siehe [features.md](features.md)).
- [ ] Separate bestätigungspflichtige Datenlöschung mit Retention/Backup.
- [ ] Logs, Events und Node-Kapazität bereitstellen.
- [ ] Adminpanel von SSH/RCON je Server auf die Cubbermine API umstellen (statt Neuentwicklung); Anmeldung, Rollen, RBAC und Quotas prüfen.
- [ ] Alle Bestandsfunktionen über die API bereitstellen: Plugins (Katalog, Upload, Entfernen), Spieler (Whitelist, Operator), `server.properties` bearbeiten, Serverzuweisung/Freigabe/Zurücksetzen, Aktionsprotokoll.
- [ ] Tests für Fehlerfälle, doppelte Requests und unzureichende Ressourcen.

**Gate:** Eine Minecraft-Instanz lässt sich über das Adminpanel vollständig verwalten, mindestens im Umfang des heutigen Adminpanels und einschließlich Restore eines Backups aus dem Archiv; das Adminpanel braucht keinen SSH-Zugang zu den Servern mehr.

### M4 – Gestaffelte Migration

- [ ] Reihenfolge festlegen: zuerst nichtkritische Instanz, dann weitere Minecraft-Server, zuletzt Proxy/produktive Lobby.
- [ ] Für jede Instanz: Wartungsfenster, konsistentes Backup, Plugins/Mod-Versionen, Konfiguration, Welt-Import und Port-/DNS-Umschaltung planen.
- [ ] Funktion, Minecraft-Version, Plugins und Datenintegrität nach dem Umzug testen.
- [ ] Rückfall auf Compose vorbereiten; niemals zwei Server gleichzeitig dieselbe Welt beschreiben lassen.
- [ ] Adminpanel umziehen: Die beiden Instanzen (`admin.meckminecraft.de`, `admin.cndrbrbr.de`) werden zu **einer gemeinsamen Cubbermine-Weboberfläche** für alle Server zusammengeführt (Entscheidung 16.11.2026; auf welchem Node ein Server läuft, spielt im Cluster keine Rolle). Konten beider Instanzen zusammenführen (gleiche E-Mail = ein Konto), Rollen, Serverzuweisungen und Aktionsprotokolle übernehmen; Servernamen eindeutig machen: Die NC3-Server werden zu `nc3-mc1` … `nc3-mc5`, die MeckMinecraft-Server behalten `mc1` … `mc5` (Entscheidung 16.11.2026); Kartenadressen `karte-ehle`, `karte-softsurvival`, `karte-workshop`, `karte-inigresso` unter meckminecraft.de; Hauptadresse ist **`admin.meckminecraft.de`** (Entscheidung 16.11.2026), `admin.cndrbrbr.de` leitet dorthin um; Schüler-SFTP-Schlüssel bleiben gültig.
**Adressen und Web-/Begleitdienste** (Konzept und Adresstabellen: [websites-monitoring.md](websites-monitoring.md); Entscheidung 16.11.2026: **meckminecraft.de** = Minecraft, **cndrbrbr.de** = andere Themen, **codefield.de** = orbita2core)

- [ ] Neue Adressen ankündigen (Homepage, Weboberfläche, E-Mail an Lehrkräfte), besonders die Minecraft-Adressen, die sich nicht weiterleiten lassen (`codefield.de:25565`, `cndrbrbr.de:25565–25569`).
- [ ] Ingress mit TLS für alle Domains, neue DNS-Einträge unter `meckminecraft.de` und `codefield.de`, dauerhafte Weiterleitungen von den alten Adressen (`admin.cndrbrbr.de`, `karte*.cndrbrbr.de`, `*.codefield.de` des Workshops).
- [ ] **mc-router** auf Port 25565 (Entscheidung 16.11.2026, [websites-monitoring.md](websites-monitoring.md), Abschnitt 2.4): `meckminecraft.de` und Standardziel → BungeeCord/Lobby, `workshop.meckminecraft.de` → Workshop-Server, `nc3-mcN.meckminecraft.de` → bisherige NC3-Server; Einträge automatisch über Service-Annotationen; nur Server mit `online-mode=true` direkt erreichbar, BungeeCord-Backends per NetworkPolicy abschirmen; PROXY-Protokoll zu BungeeCord; Forge-Server `nc3-mc1` testen; automatischen Serverstart im Pilot ausprobieren.
- [ ] **meckminecraft.de** umziehen: Homepage als Image, `/api/prometheus/` nur noch lesend, Grafana unter `grafana.meckminecraft.de`, BlueMaps unter `karte-*.meckminecraft.de`; danach Caddy auf MeckMinecraft stoppen und 80/443 an den Ingress übergeben.
- [ ] **JavaScript-Workshop nach meckminecraft.de** umziehen: Workshop-Server als StatefulSet nach [dockerminecraft.md](dockerminecraft.md); Homepage `workshop.meckminecraft.de`, IDE `javascript.meckminecraft.de`, Upload `upload.meckminecraft.de` (jsmn, :25580), Karte `karte-workshop.meckminecraft.de`; Kurstexte und IDE auf feste codefield.de-Verweise prüfen; `codefield.de` leitet bis zum orbita2core-Umzug auf den Workshop weiter.
- [ ] **cndrbrbr.de (NC3)** umziehen in den Namespace `cndrbrbr`: Omasys (Deployment + PVC + Secrets), NonameQuiz (Web als Image, KI-Proxy, Ollama fest auf NC3 mit Modell-PVC und **niedrigerer Priorität als Minecraft** (PriorityClass, kleine CPU-Requests, Limit 6 CPU, 8 GiB RAM; Entscheidung 16.11.2026)), Kookie (Web mit Basic Auth, Daten-PVC, vierteljährlicher Import als CronJob statt `kookie-import.timer`); Omasys- und Kookie-Daten in den Backup-Ablauf aufnehmen; danach `omasys-caddy` stoppen und 80/443 an den Ingress übergeben.
- [ ] **orbita2core auf codefield.de** umziehen (nach dem Workshop): Orbital-Knoten als StatefulSets mit ihren Daten, Sim-Agenten, Adressen `node1–3.codefield.de` und `agent1–3.codefield.de` auf Port 443 (Entscheidung 16.11.2026, Zusatzports 35581–35593 entfallen), Clients auf die neuen Adressen umstellen; **Einstiegsseite von orbita2core** unter `codefield.de` neu erstellen (statische Seite mit Projektbeschreibung, Links und Hinweis auf den umgezogenen Workshop, Entscheidung 16.11.2026); danach `caddy-proxy` auf Codefield stoppen.
- [ ] Alte Compose-Stacks (minecraftDash, javascriptMinecraftWorkshopServer, caddy-proxy, omasys, nonamequiz-deploy, kookie, testo2c) bis zur Abnahme gestoppt aufbewahren, danach abbauen; Debian-node_exporter entfernen.

**Gate:** Abgenommene Minecraft-Server sind stabil, Wiederherstellung und Rollback sind erprobt; alle Dienste sind unter den neuen Adressen erreichbar, die alten HTTP-Adressen leiten weiter.

### M5 – Härtung und Betrieb

- [ ] Monitoring ergänzen: zentrale Logs, Kapazitätswarnungen, Alerts für Nodes, PVCs und Zertifikatsablauf (Grundausbau in M2).
- [ ] Dokumentierte Update-/Patch-/Zertifikatsprozesse.
- [ ] RBAC, NetworkPolicies, Secret-Management und Pod-Security prüfen.
- [ ] Wiederkehrende Restore- und Ausfalltests, darunter mindestens einmal jährlich ein **Notfall-Restore aus der Storage Box** ohne Zugriff auf Cluster und Nodes (neuer Server, Schlüssel und Passwörter aus der Offline-Kopie).
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
| P0 | Welt-Backup-Archiv auf der Hetzner Storage Box mit Aufbewahrung und Restore-Test | Storage Box (vorhanden) |
| P0 | Datastore-Snapshots der Control Plane auf die Storage Box | Dedizierte Control Plane |
| P0 | Gemeinsamen K3s-Cluster aufbauen | Control Plane, VPN |
| P0 | StatefulSet + Service + Proxy-Pilot | K3s, Storage |
| P0 | Cubbermine API + Umstellung des bestehenden Adminpanels auf die API | Kubernetes-Pilot |
| P0 | Sicherheitsgrundlagen/Monitoring (kube-prometheus-stack, Grafana, externer Wächter) | Cluster |
| P0 | **Offsite-Kopie der Backups** mit restic auf Hetzner Storage Box BX21 in Helsinki (verschlüsselt, append-only, überwacht, Restore-Test) – Abschnitt S | Bestellung der Storage Box |
| P0 | Sofortmaßnahmen im Bestand: Prometheus/Grafana (meck) und Omasys (NC3) nicht öffentlich, Prometheus-Volume, minecraftDash einchecken – Abschnitt S | – |
| P1 | Adresskonzept umsetzen: Ingress, Weiterleitungen, Minecraft-Router | Ingress, DNS |
| P1 | meckminecraft.de und JavaScript-Workshop (von codefield.de) in den Cluster | Ingress, Monitoring, Minecraft-Pilot |
| P1 | Omasys, NonameQuiz/Ollama, Kookie (cndrbrbr.de) in den Cluster | Ingress, Backup-Ablauf |
| P1 | orbita2core auf codefield.de in den Cluster | Workshop-Umzug |
| P1 | Migration von mc1 bis mc5, Lobby/Proxy und Adminpanel (Konten, Zuweisungen) | MVP-Abnahme |
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
- Die Storage Box ist eine einzelne Kopie bei einem Anbieter an einem Ort; sie schützt gegen Ausfälle bei netcup, nicht gegen einen gleichzeitigen Verlust von Produktivsystemen und Box. Box-Snapshots und Restore-Tests mindern das Risiko; eine zweite Offsite-Kopie ist bei Bedarf möglich.
- Backups auf demselben Host oder im selben Rechenzentrum gehen bei einem Ausfall mit verloren. **Heute der Fall:** der Tresor aller Hosts liegt auf NC3 (Gegenmaßnahme: Abschnitt S).
- Gehen die Schlüssel der verschlüsselten Offsite-Kopie verloren, ist die Kopie unbrauchbar; sie müssen offline und getrennt aufbewahrt werden.
- Unterschiedliche Java-/Minecraft-/Plugin-Versionen bei Migration.
- Kollisionen mit bestehenden öffentlichen Ports und Reverse Proxies.
- Geänderte Minecraft-Adressen (Workshop, NC3-Server) lassen sich nicht weiterleiten; ohne rechtzeitige Ankündigung finden Schüler ihre Server nicht mehr.
- Die CPU-Inferenz von Ollama auf NC3 kann die Minecraft-Server auf demselben Node ausbremsen; Gegenmaßnahme: Ollama mit niedrigerer Priorität als Minecraft. Im Gegenzug antwortet NonameQuiz unter Minecraft-Last langsamer oder ist kurz nicht verfügbar.

Siehe [architecture.md](architecture.md) für Architekturdiagramme und [features.md](features.md) für den Funktionsumfang.
