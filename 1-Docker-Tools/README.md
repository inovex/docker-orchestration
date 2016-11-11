# Compose

## Anforderungen:

### Linux

- [Docker 1.10+](https://docs.docker.com/installation)
- [Docker-Compose 1.8+](https://docs.docker.com/compose/install)
- Kernel 3.16+

#### Installation Docker-Compose (Linux)

```bash
$ sudo sh -c "curl -L -o /usr/local/bin/docker-compose \
              https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` && \
              chmod +x /usr/local/bin/docker-compose"
# Test ob docker-compose korrekt installiert wurde
$ docker-compose version
```

### OSX / MacOS

- [Docker for Mac](https://docs.docker.com/docker-for-mac)

### Windows

- [Docker for Windows](https://docs.docker.com/docker-for-windows)

## Beispiel

Um das Beispiel lokal zu starten, muss sich der Anwender in dem Ordner mit diesem Beispiel befinden.

Im ersten Schritt erstellen wir das Netzwerk (das könnte Compose auch für uns tun) und starten alle Container.

```bash
$ sudo docker network create todoapp_network
$ sudo docker-compose up -d
```

Nun können wir uns alle Container anzeigen lassen

```bash
$ sudo docker-compose ps
$ sudo docker network inspect todoapp_network
```

Ausgabe des Ports der ToDo Anwendung

```bash
$ sudo docker-compose port todoApp 3000
0.0.0.0:32768
```

Wir können diesen Port einfach verwenden und in einem beliebigen Browser localhost:32768 eingeben.

Jetzt können wir einen neuen Redis Slave Container erstellen

```bash
$ sudo docker-compose scale redis-slave=2
```

Nun können wir in einem neuen Terminalfenster, mithilfe von watch, alle 500ms von dem frontend Container eine DNS Anfrage auf den Redis Slave ausführen und sehen, dass die Anfragen auf die unterschiedlichen Redis-Slave Container verteilt werden.

```bash
$ watch -n 0.5 sudo docker exec $(sudo docker ps -f name=1dockertools_todoApp_1 -q) getent hosts  redis-slave
```

Wir könenn natürlich auch die Frontend Container skalieren lassen:

```bash
$ sudo docker-compose scale todoApp=3
```

Nun können wir uns die Ports der drei Instanzen ausgeben lassen. Diese können entsprechend in dem Browser aufgerufen werden. Werden nun zwei Browserfenster gleichzeitig geöffnet und dabei unterschiedliche Ports verwendet, können wir sehen, dass die App Änderungen von einem Fenster in das andere übernimmt.

```bash
$ sudo docker-compose port --index=1 todoApp 3000
$ sudo docker-compose port --index=2 todoApp 3000
$ sudo docker-compose port --index=3 todoApp 3000
```

# Swarm

## Anforderungen

- [Docker 1.9+](https://docs.docker.com/installation)
- [Docker-Machine](https://docs.docker.com/machine/install-machine)
- [Virtualbox](https://www.virtualbox.org)

oder

- [Docker Toolbox](https://www.docker.com/docker-toolbox)

## Installation Docker-Machine (Linux)

```bash
$ sudo sh -c "curl -L -o /usr/local/bin/docker-machine \
              https://github.com/docker/machine/releases/download/v0.8.0/docker-machine_linux-amd64  && \
              chmod +x /usr/local/bin/docker-machine"
# Test ob docker-machine korrekt installiert wurde
$ docker-machine version
```

## Vorkonfiguration

```bash
$ docker-machine create \
    -d virtualbox \
    cluster-store

$ docker $(docker-machine config cluster-store) run -d \
    -p "8500:8500" \
    -h "consul" \
    progrium/consul -server -bootstrap -ui-dir /ui
```

## Erstellung des Swarm-Clusters mit Docker-Machine

Erstellung des Swarm Masters

```bash
$ docker-machine create \
    --driver virtualbox \
    --swarm \
    --swarm-master \
    --swarm-discovery="consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-advertise=eth1:0" \
    swarm-master
```

Erstellung von zwei Swarm-Nodes

```bash
$ docker-machine create \
    --driver virtualbox \
    --swarm \
    --swarm-discovery="consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-advertise=eth1:0" \
    swarm-node-00

$ docker-machine create \
    --driver virtualbox \
    --swarm \
    --swarm-discovery="consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip cluster-store):8500" \
    --engine-opt="cluster-advertise=eth1:0" \
    swarm-node-01
```

Mit diesem Befehl überprüfen wir die Erstellung des Clusters

```bash
$ eval $(docker-machine env --swarm swarm-master)
$ docker info
```

Nun erstellen wir abschließend noch ein Overlay Netzwerk, so dass die Hosts auch miteinander kommunizieren können.

```bash
$ docker network create -d overlay todoapp_network

$ docker network ls
NETWORK ID          NAME                   DRIVER              SCOPE
471c06f5c6a9        swarm-master/bridge    bridge              local
2d2e137cf49e        swarm-master/host      host                local
79c3481145a2        swarm-master/none      null                local
5aa3e1ecc41e        swarm-node-00/bridge   bridge              local
a191e965b3d3        swarm-node-00/host     host                local
f49d2627afb1        swarm-node-00/none     null                local
d76ee4cc9c54        swarm-node-01/bridge   bridge              local
70e4c90dbf05        swarm-node-01/host     host                local
22ee9ac4c41b        swarm-node-01/none     null                local
fb49711a7996        todoapp_network        overlay             global

$ docker $(docker-machine config swarm-master) network ls
```

Dank des gemeinsamen Key-Value Store Consul ist das Netzwerk auf allen Nodes des Swarm Clusters verfügbar

```bash
$ docker $(docker-machine config swarm-node-00) network ls
$ docker $(docker-machine config swarm-node-01) network ls
```

## Beispiel

Die Erstellung des Redis-Master Containers

```bash
$ docker run -d -p 6379:6379 --name=redis-master --network=todoapp_network johscheuer/redis-master:v2
```

Nun können wir den Redis-Slave erstellen

```bash
$ docker run -d -p 6379:6379 --name=redis-slave --network=todoapp_network johscheuer/redis-slave:v2
```

Bei dem Versuch einen dritten Redis-Slave zu starten erhalten wir folgenden Fehler: "docker: Error response from daemon: Conflict: The name redis-slave is already assigned. You have to delete (or rename) that container to be able to assign redis-slave to a container again.. See 'docker run --help'.". Welcher uns mitteilt, dass in dem Swarm-Cluster schon ein Container mit dem Namen `redis-slave` gibt.

Abschließend kann die bis zu drei mal ToDo-App gestartet werden.

```bash
$ docker run -d -p 3000:3000 --network=todoapp_network johscheuer/todo-app-web:v2
```

Nun kann auch die ToDo-App zugegriffen werden, hierfür muss der Anwender zu erst schauen auf welchem Knoten die Todo-App läuft und kann danach einfach über die IP des Knoten und den Port `3000` auf die Applikation zugreifen. In dem folgenden Code Beispiel rufen wir die IP-Adresse des `swarm-master` ab.

```bash
$ docker-machine ip swarm-master
```

## Compse + Swarm + Networking

Wir können nun das Compose Beispiel auch auf dem Swarm Cluster starten. Hierfür entfernen wir die zuvor gestarteten Container.

```bash
$ docker rm -f $(docker ps -q)
```

Nun können wir mit dem gewohnten Docker Compose Commando unsere Anwendung starten

```bash
$ docker-compose up -d

$ docker-compose ps

$ docker-compose port todoApp 3000
```

# Swarm Mode

## Anforderungen

- [Docker 1.12+](https://docs.docker.com/installation)
- [Docker-Machine](https://docs.docker.com/machine/install-machine)
- [Virtualbox](https://www.virtualbox.org)

oder

- [Docker Toolbox](https://www.docker.com/docker-toolbox)

## Installation Docker-Machine (Linux)

```bash
$ sudo sh -c "curl -L -o /usr/local/bin/docker-machine \
              https://github.com/docker/machine/releases/download/v0.8.0/docker-machine_linux-amd64  && \
              chmod +x /usr/local/bin/docker-machine"
# Test ob docker-machine korrekt installiert wurde
$ docker-machine version
```

## Erstellung des Swarm-Clusters mit Docker-Machine

Erstellung des Swarm Managers

```bash
$ docker-machine create \
    --driver virtualbox \
    swarm-manager
```

Erstellung von zwei Swarm-Nodes

```bash
$ docker-machine create \
    --driver virtualbox \
    swarm-node-00

$ docker-machine create \
    --driver virtualbox \
    swarm-node-01
```

Mit diesem Befehl überprüfen wir die Erstellung der 3 Nodes

```bash
$ docker-machine ls --filter name=swarm-*
```

### Initialisierung von Swarm

Zu erst müssen wir den Knoten `swarm-manager` mit dem folgenden Befehl zum Swarm manager für das neue Cluster ernennen.

```bash
$ docker-machine ssh swarm-manager docker swarm init --advertise-addr $(docker-machine ip swarm-manager):2377

Swarm initialized: current node (cm6ptof891cs42i6vs0rb2ay1) is now a manager.

To add a worker to this swarm, run the following command:
    docker swarm join \
    --token SWMTKN-1-4219r91yfhay6rlktwxgo2zk3bpmotsw6053hyq42w5whplk5f-42mtrmkf4dovww8jqft7p5y96 \
    192.168.99.100:2377

To add a manager to this swarm, run the following command:
    docker swarm join \
    --token SWMTKN-1-4219r91yfhay6rlktwxgo2zk3bpmotsw6053hyq42w5whplk5f-7pc7zqbhxc0bh54bt36dmiotk \
    192.168.99.100:2377
```

Im nächsten Schritt fügen wir die beiden Knoten `swarm-node-00` und `swarm-node-01` dem CLuster hinzu, adzu wird der Token von dem vorherigen Kommando benötigt:

```bash
$ docker-machine ssh swarm-node-00 docker swarm join \
--token SWMTKN-1-4219r91yfhay6rlktwxgo2zk3bpmotsw6053hyq42w5whplk5f-42mtrmkf4dovww8jqft7p5y96  \
192.168.99.100:2377

$ docker-machine ssh swarm-node-01 docker swarm join \
--token SWMTKN-1-4219r91yfhay6rlktwxgo2zk3bpmotsw6053hyq42w5whplk5f-42mtrmkf4dovww8jqft7p5y96  \
192.168.99.100:2377
```

Now we switch to context to use the `swarm-manager`

```bash
$ eval $(docker-machine env swarm-manager)
$ docker node ls
```

Nun erstellen wir abschließend noch ein Overlay Netzwerk, so dass die Container auf den Hosts auch miteinander kommunizieren können.

```bash
$ docker network create -d overlay todoapp_network
$ docker network ls
```

## Beispiel

Die Erstellung des Redis-Master Containers

```bash
$ docker service create --replicas=1 --name=redis-master --network=todoapp_network johscheuer/redis-master:v2
```

Nun können wir den Redis-Slave erstellen

```bash
$ docker service create --replicas=2 --name=redis-slave --network=todoapp_network johscheuer/redis-slave:v2
```

Es ist zu beachten, dass es in dem Swarm Cluster nur ein Service mit einem eindeutigen Namen geben darf. Würden man versuchen einen zweiten Service `redis-slave` zu starten, würde dies zu einem Fehler führen.

```bash
$ docker service create --replicas=2 --name=redis-slave --network=todoapp_network johscheuer/redis-slave:v2
Error response from daemon: rpc error: code = 2 desc = name conflicts with an existing object
```

Anschließend starten wir noch die ToDo-App:

```bash
$ docker service create --replicas=1 -p 3000:3000 --name=todo-app --network=todoapp_network johscheuer/todo-app-web:v2
```

Mit den folgenden Befehlen können wir den aktuellen Status der Serivces betrachten:

```bash
$ docker service ls
ID            NAME          REPLICAS  IMAGE                       COMMAND
39rje3ly9b7g  redis-master  1/1       johscheuer/redis-master:v2
3ettoyfix71k  todo-app      1/1       johscheuer/todo-app-web:v2
5mmlc2ilaq85  redis-slave   2/2       johscheuer/redis-slave:v2

$ docker service ps todo-app
```

Durch das Mesh-Routing werden alle ankommenden Requests auf alle Tasks des Service verteilt, es ist also egal unter welcher Node der Service angefragt wird.

```bash
$ watch -n 0.2 curl -s $(docker-machine ip swarm-manager):3000/whoami
```

Abschließend kann die todo-app noch einfach über den folgenden Befehl skaliert werden:

```bash
$ docker service scale todo-app=100
```

Wird der oben genannte Befehl nun noch einmal ausgeführt, so kann der Anweder sehen, dass die Anfragen auch wirklich auf die Container verteilt werden.

## Compose + Swarm Mode

Aktuell unterstützt der [Swarm Mode Compose nicht](https://github.com/docker/compose/issues/3656) allerdings kann Compose mit Swarm (ohne Swarm Mode) verwendet werden. Alternativ gibt es das experimentelle [Docker Stacks and Distributed Application Bundles](https://github.com/docker/docker/blob/master/experimental/docker-stacks-and-bundles.md).
