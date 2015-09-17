# Fleet example

## Anforderungen
* [Vagrant](https://www.vagrantup.com/downloads.html) 1.6+
* [Virtualbox](https://www.virtualbox.org) 4.3.10+

Ein laufendes CoreOS Cluster mit mindestens 3 Knoten. Es kann das offizielle CoreOS vagrant Setup von [Github](https://github.com/coreos/coreos-vagrant) verwendet werden.

```Bash
git clone https://github.com/coreos/coreos-vagrant.git
cd coreos-vagrant
cp user-data.sample user-data
cp config.rb.sample config.rb
# Wir wollen 3 CoreOS Knoten erstellen
sed -i 's/$num_instances=1/$num_instances=3/g' config.rb
# Discovery Token erstellen und in die Zwischenablage kopieren
echo $(curl -s https://discovery.etcd.io/new)
# in user-data im ersten Abschnitt "etcd:" das führende "#" vor discovery entfernen und danach den Eintrag https://discovery.etcd.io/<Token> mit dem gerade eben erstellen token ersetzen

# Nun starten wir das Cluster
vagrant up
```

Damit das Beispiel auch auch problemlos funktioniert, errstellen wir noch auch allen Knoten die Datei /etc/hosts, diese
stellt sicher, dass die Namen der Knoten richtig aufgelöst werden. Dies können wir einfach über den Befehl

```Bash
for i in {1..3}; do vagrant ssh core-0$i -c 'sudo bash -c "echo -e \"172.17.8.101 core-01\n172.17.8.102 core-02\n172.17.8.103 core-03\" > /etc/hosts" && cat /etc/hosts'; done
```

erledigen, dieser muss für alle drei Knoten auf dem Host (dies ist die Maschine auf der wir vagrant up ausgeführt haben) 
ausgeführt werden.

Zu erst verbindet sich der Anwender mit einem Knoten des Cluster über vagrant:
```Bash
vagrant ssh core-01
```

## Beispiel

Mit dem Kommando
```Bash
  fleetctl list-machines
```

kann sich der Admin alle verfügbaren Knoten in dem fleet Cluster
anzeigen lassen. Nun können die Beispiel-Dateien geladen werden 
```Bash
git clone https://github.com/inovex/docker-orchestration.git && cd docker-orchestration/2-fleet
```
Nun können wir den Redis-Master und den Sicde-Kick starten:
```Bash
fleetctl start redis-master.service
fleetctl start redis-master-discovery.service
```

Über die folgenden Befehle überprüfen wir den ergolfreichen Start
```Bash
fleetctl list-unit-files
fleetctl list-units
```
Nun können wir die Redis-Slaves und deren Side-Kicks starten
```Bash
fleetctl submit redis-slave\@.service
fleetctl start redis-slave\@{1,2}
fleetctl submit redis-slave-discovery\@.service
fleetctl start redis-slave-discovery\@{1,2}
```
Nun können die Einheiten wieder überprüft werden.
```Bash
fleetctl list-units
```

Abschließend starten wir die ToDo Services und deren Side-Kicks
```Bash
fleetctl submit todo-app\@.service
fleetctl start todo-app\@{1,2}
fleetctl submit todo-app-discovery\@.service
fleetctl start todo-app-discovery\@{1,2}
```

Nun können wir mit den ToDo Services interagieren
```Bash
curl $(etcdctl get /services/db/todo-app@1/host):$(etcdctl get /services/db/todo-app@1/port)
curl $(etcdctl get /services/db/todo-app@2/host):$(etcdctl get /services/db/todo-app@2/port)/?todo=duschen -X PUT
curl $(etcdctl get /services/db/todo-app@1/host):$(etcdctl get /services/db/todo-app@1/port)
curl $(etcdctl get /services/db/todo-app@2/host):$(etcdctl get /services/db/todo-app@2/port)/?todo=duschen -X DELETE
curl $(etcdctl get /services/db/todo-app@1/host):$(etcdctl get /services/db/todo-app@1/port)
```
