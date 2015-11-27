# Compose
## Linux
### Anforderungen:
- [Docker 1.9+](https://docs.docker.com/installation)
- [Docker-Compose 1.5.1+](https://docs.docker.com/compose/install)

### Beispiel
Um das Beispiel lokal zu starten, muss sich der Anwender in dem Ordner mit diesem Beispiel befinden.

Im ersten Schritt erstellen wir das benötigte Netzwerk und starten danach die Container.

```Bash
sudo docker network create --driver=bridge todoapp_network
sudo docker-compose up -d
```

Zeige alle Container an

```Bash
sudo docker-compose ps
```

Ausgabe des Ports der ToDo Anwendung

```Bash
sudo docker-compose port todoApp 3000
0.0.0.0:32768
```

Wir können diesen Port einfach verwenden und in einem beliebigen Browser localhost:32768 eingeben.

Jetzt können wir zwei neue ToDo Container erstellen

```Bash
sudo docker-compose scale todoApp=3
```

Nun können wir uns die Ports der drei Instanzen ausgeben lassen. Diese können entsprechend in dem Browser aufgerufen werden. Werden nun zwei Browserfenster gleichzeitig geöffnet und dabei unterschiedliche Ports verwendet, können wir sehen, dass die App Änderungen von einem Fenster in das andere übernimmt.

```Bash
sudo docker-compose port --index=1 todoApp 3000
sudo docker-compose port --index=2 todoApp 3000
sudo docker-compose port --index=3 todoApp 3000
```

## OS X und Windows
### Anforderungen:
- [Docker Toolbox](https://www.docker.com/docker-toolbox)

### Beispiel
Um das Beispiel lokal zu starten, muss sich der Anwender in dem Ordner mit diesem Beispiel befinden.

Zu erst müssen wir schauen ob unsere virtuelle Maschine schon am Laufen ist. Wenn diese noch nicht gestartet wurde starten wir diese:

```Bash
docker-machine status default
# Bei der Ausgabe: "Running" läuft die Machine schon
docker-machine start default
```

Im nächsten Schritt erstellen wir das benötigte Netzwerk und starten danach die Container.

```Bash
docker network create --driver=bridge todoapp_network
docker-compose up -d
```

Zeige alle Container an

```Bash
docker-compose ps
```

Ausgabe des Ports der ToDo Anwendung

```Bash
docker-compose port todoApp 3000
0.0.0.0:32768
```

Nun benötigen wir noch die IP-Addresse der virtuellen Maschine:

```Bash
docker-machine ip default
192.168.99.100
```

Wir können diesen Port und die IP einfach verwenden und in einem beliebigen Browser 192.168.99.100:32768 eingeben.

Jetzt können wir zwei neue ToDo Container erstellen

```Bash
docker-compose scale todoApp=3
```

Nun können wir uns die Ports der drei Instanzen ausgeben lassen. Diese können entsprechend in dem Browser aufgerufen werden. Werden nun zwei Browserfenster gleichzeitig geöffnet und dabei unterschiedliche Ports verwendet, können wir sehen, dass die App Änderungen von einem Fenster in das andere übernimmt.

```Bash
docker-compose port --index=1 todoApp 3000
docker-compose port --index=2 todoApp 3000
docker-compose port --index=3 todoApp 3000
```

# Swarm
## Anforderungen
- [Docker 1.9+](https://docs.docker.com/installation)
- [Docker-Machine](https://docs.docker.com/machine/install-machine)
- [Virtualbox](https://www.virtualbox.org)

oder
- [Docker Toolbox](https://www.docker.com/docker-toolbox)

## Vorkonfiguration

```Bash
docker-machine create \
    -d virtualbox \
    cluster-store

docker $(docker-machine config cluster-store) run -d \
    -p "8500:8500" \
    -h "consul" \
    progrium/consul -server -bootstrap -ui-dir /ui
```

## Erstellung des Swarm-Clusters mit Docker-Machine
Erstellung des Swarm Masters

```Bash
docker-machine create \
    --driver virtualbox \
    --swarm \
    --swarm-master \
    --virtualbox-memory 2048 \
    --swarm-discovery="consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-advertise=eth1:0" \
    swarm-master
```

Erstellung von zwei Swarm-Nodes

```Bash
docker-machine create \
    --driver virtualbox \
    --virtualbox-memory 2048 \
    --swarm \
    --swarm-discovery="consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-advertise=eth1:0" \
    swarm-node-00

docker-machine create \
    --driver virtualbox \
    --virtualbox-memory 2048 \
    --swarm \
    --swarm-discovery="consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-advertise=eth1:0" \
    swarm-node-01
```

Mit diesem Befehl überprüfen wir die Erstellung des Clusters

```Bash
eval $(docker-machine env --swarm swarm-master)
docker info
```

Nun erstellen wir abschließend noch ein Overlay Netzwerk, so dass die Hosts auch miteinander kommunizieren können.

```Bash
docker $(docker-machine config swarm-master) network create --driver=overlay todoapp_network
docker $(docker-machine config swarm-master) network ls
```

Dank des gemeinsamen Key-Value Store Consul ist das Netzwerk auf allen Nodes des Swarm Clusters verfügbar

```Bash
docker $(docker-machine config swarm-node-00) network ls
docker $(docker-machine config swarm-node-01) network ls
```

## Beispiel
Die Erstellung des Redis-Master Containers

```Bash
docker run -d -p 6379:6379 --name=redis-master --net=todoapp_network redis
```

Nun können wir die zwei Redis-Slaves erstellen

```Bash
docker run -d -p 6379:6379 --name=redis-slave --net=todoapp_network johscheuer/redis-slave:v1
```

Bei dem Versuch einen dritten Redis-Slave zu starten erhalten wir folgenden Fehler: "Error response from daemon: unable to find a node with port 6379 available". Welcher uns mitteilt, dass es keine Node in dem Swarm-Cluster gibt, die die Anforderung (Port 6379 frei) erfüllt verfügbar ist.

Abschließend kann die ToDo-App gestartet werden.

```Bash
docker run -d -p 3000:3000 --net=todoapp_network johscheuer/todo-app-web:v1
```

Es ist zu beachten, dass es in dem Swarm Cluster nur ein Container mit einem eindeutigen Namen geben darf. Würden man versuchen einen zweiten Redis Slave zu starten, würde dies zu einem Fehler führen.

```Bash
docker run -d -p 6379:6379 --name=redis-slave --net=todoapp_network johscheuer/redis-slave:v1
```

## Compse + Swarm + Networking
Wird können nun das Compose Beispiel auch auf dem Swarm Cluster starten. Hierfür entfernen wir die zuvor gestarteten Container.

```Bash
docker rm -f $(docker ps -q)
```

Nun können wir mit dem gewohnten Docker Compose Commando unsere Anwendung starten

```Bash
docker-compose up -d
docker-compose ps
```
