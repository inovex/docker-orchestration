# Compose

## Linux

### Anforderungen:

- [Docker 1.10+](https://docs.docker.com/installation)
- [Docker-Compose 1.8+](https://docs.docker.com/compose/install)
- Kernel 3.16+

#### OSX / MacOS

- [Docker for Mac](https://docs.docker.com/docker-for-mac)

#### Windows

- [Docker for Windows](https://docs.docker.com/docker-for-windows)

### Installation Docker-Compose (Linux)

```bash
# Zuerst zu dem user root wechseln
su
curl -L https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && \
chmod +x /usr/local/bin/docker-compose
exit
# Test ob docker-compose korrekt installiert wurde
docker-compose version
```

### Beispiel

Um das Beispiel lokal zu starten, muss sich der Anwender in dem Ordner mit diesem Beispiel befinden.

Im ersten Schritt erstellen wir das benötigte Netzwerk und starten danach die Container.

```bash
sudo docker network create todoapp_network
sudo docker-compose up -d
```

Zeige alle Container an

```bash
sudo docker-compose ps
sudo docker network inspect todoapp_network
```

Ausgabe des Ports der ToDo Anwendung

```bash
sudo docker-compose port todoApp 3000
0.0.0.0:32768
```

Wir können diesen Port einfach verwenden und in einem beliebigen Browser localhost:32768 eingeben.

Jetzt können wir zwei neue ToDo Container erstellen

```bash
sudo docker-compose scale todoApp=3
```

Nun können wir uns die Ports der drei Instanzen ausgeben lassen. Diese können entsprechend in dem Browser aufgerufen werden. Werden nun zwei Browserfenster gleichzeitig geöffnet und dabei unterschiedliche Ports verwendet, können wir sehen, dass die App Änderungen von einem Fenster in das andere übernimmt.

```bash
sudo docker-compose port --index=1 todoApp 3000
sudo docker-compose port --index=2 todoApp 3000
sudo docker-compose port --index=3 todoApp 3000
```

## Compose v2

- [Docker 1.10+](https://docs.docker.com/installation)
- [Docker-Compose 1.8+](https://docs.docker.com/compose/install)
- Kernel 3.16+

### Beispiel

Um das Beispiel lokal zu starten, muss sich der Anwender in dem Ordner mit diesem Beispiel befinden.

Im ersten Schritt starten wir alle Container.

```bash
sudo docker-compose -f docker-compose_v2.yml up -d
```

Zeige alle Container an

```bash
sudo docker-compose -f docker-compose_v2.yml ps
sudo docker network inspect todoapp_network
```

Ausgabe des Ports der ToDo Anwendung

```bash
sudo docker-compose -f docker-compose_v2.yml port todoApp 3000
0.0.0.0:32768
```

Wir können diesen Port einfach verwenden und in einem beliebigen Browser localhost:32768 eingeben.

Jetzt können wir einen neuen Redis Slave Container erstellen

```bash
sudo docker-compose -f docker-compose_v2.yml scale redis-slave=2
```

Nun können wir in einem neuen Terminalfenster, mithilfe von watch, alle 500ms von dem frontend Container eine DNS Anfrage auf den Redis Slave ausführen.

```bash
watch -n 0.5 sudo docker exec $(sudo docker ps -f name=1_docker_tools_todoApp_1 -q) getent hosts  redis-slave
```

Im nächsten Schritt können wir den ersten Redis Slave beenden. Wenn wir nun wieder in das Terminalfenster der DNS Abfrage schauen sehen wir die IP-Addresse des Redis Slave 2.

```bash
sudo docker kill $(sudo docker ps -f name=1_docker_tools_redis-slave_1 -q)
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
# Zuerst zu dem user root wechseln
su
curl -L https://github.com/docker/machine/releases/download/v0.8.0/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine && \
  chmod +x /usr/local/bin/docker-machine
exit
# Test ob docker-machine korrekt installiert wurde
docker-machine version
```

## Erstellung des Swarm-Clusters mit Docker-Machine

Erstellung des Swarm Managers

```bash
docker-machine create \
    --driver virtualbox \
    swarm-manager
```

Erstellung von zwei Swarm-Nodes

```bash
docker-machine create \
    --driver virtualbox \
    swarm-node-00

docker-machine create \
    --driver virtualbox \
    swarm-node-01
```

Mit diesem Befehl überprüfen wir die Erstellung der 3 Nodes

```bash
docker-machine ls --filter name=swarm-*
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
docker-machine ssh swarm-node-00 docker swarm join \
--token SWMTKN-1-4219r91yfhay6rlktwxgo2zk3bpmotsw6053hyq42w5whplk5f-42mtrmkf4dovww8jqft7p5y96  \
192.168.99.100:2377

docker-machine ssh swarm-node-01 docker swarm join \
--token SWMTKN-1-4219r91yfhay6rlktwxgo2zk3bpmotsw6053hyq42w5whplk5f-42mtrmkf4dovww8jqft7p5y96  \
192.168.99.100:2377
```

Now we switch to context to use the `swarm-manager`

```bash
eval $(docker-machine env swarm-manager)
docker node ls
```

Nun erstellen wir abschließend noch ein Overlay Netzwerk, so dass die Hosts auch miteinander kommunizieren können.

```bash
docker network create -d overlay todoapp_network
docker network ls
```

## Beispiel

Die Erstellung des Redis-Master Containers

```bash
docker service create --replicas=1 --name=redis-master --network=todoapp_network johscheuer/redis-master:v2
```

Nun können wir den Redis-Slave erstellen

```bash
docker service create --replicas=2 --name=redis-slave --network=todoapp_network johscheuer/redis-slave:v2
```

Es ist zu beachten, dass es in dem Swarm Cluster nur ein Service mit einem eindeutigen Namen geben darf. Würden man versuchen einen zweiten Service `redis-slave` zu starten, würde dies zu einem Fehler führen.

```bash
$ docker service create --replicas=2 --name=redis-slave --network=todoapp_network johscheuer/redis-slave:v2
Error response from daemon: rpc error: code = 2 desc = name conflicts with an existing object
```

Anschließend starten wir noch die ToDo-App:

```bash
docker service create --replicas=3 -p 3000:3000 --name=todo-app --network=todoapp_network johscheuer/todo-app-web:v2
```

Mit den folgenden Befehlen können wir den aktuellen Status der Serivces betrachten:

```bash
docker serivce ls
...

docker service ps todo-app
```

Durch das Mesh-Routing werden alle ankommenden Requests auf alle Tasks des Service verteilt, es ist also egal unter welcher Node der Service angefragt wird.

```bash
watch -n 0.2 curl -s $(docker-machine ip swarm-manager):3000/whoami
```

Abschließend kann die todo-app noch einfach über den folgenden Befehl skaliert werden:

```bash
docker service scale todo-app=100
```

## Compse + Swarm + Networking

Aktuell unterstützt der [Swarm Mode Compose nicht](https://github.com/docker/compose/issues/3656) allerdings kann Compose mit Swarm (ohne Swarm Mode) verwendet werden.
