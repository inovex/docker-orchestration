# Compose

## Anforderungen:
[Docker 1.6+](https://docs.docker.com/installation)
[Docker-Compose](https://docs.docker.com/compose/install)

## Beispiel
Um das Beispiel lokal zu starten, muss sich der Anwender in dem Ordner mit diesem Beispiel
befinden.
```Bash
sudo docker-compose up -d 

# Zeige alle Container an
sudo docker-compose ps

# Ausgabe des Ports der ToDo Anwendung 
sudo docker-compose port todoApp 9090

# Mit einem einfachen curl kann getestet werden ob alles korrekt gestartet wurde
curl $(sudo docker-compose port todoApp 9090)

# Erstelle zwei neue ToDo Container
sudo docker-compose scale todoApp=3

# Nun kann gegen die drei Instanzen ein curl durchgeführt werden
curl -X PUT $(sudo docker-compose port --index=1 todoApp 9090)/?todo=duschen
curl $(sudo docker-compose port --index=2 todoApp 9090)
curl -X DELETE $(sudo docker-compose port --index=3 todoApp 9090)/?todo=duschen
curl $(sudo docker-compose port --index=1 todoApp 9090)
```

# Swarm
## Anforderungen
[Docker 1.6+](https://docs.docker.com/installation)
[Docker-Machine](https://docs.docker.com/machine/install-machine) 
[Virtualbox](https://www.virtualbox.org)

## Erstellung des Swarm-Clusters mit Docker-Machine
```Bash
# Erstellung des Tokens für das Swarm-Cluster
export TOKEN="$(sudo docker run swarm create)"

# Erstellung des Swarm Masters
docker-machine create \
    --driver virtualbox \
    --swarm \
    --virtualbox-memory 2048 \
    --swarm-master \
    --swarm-discovery token://$TOKEN \
    swarm-master

# Erstellung von zwei Swarm-Nodes
docker-machine create \
    --driver virtualbox \
    --virtualbox-memory 2048 \
    --swarm \
    --swarm-discovery token://$TOKEN \
    swarm-node-00

docker-machine create \
    --driver virtualbox \
    --virtualbox-memory 2048 \
    --swarm \
    --swarm-discovery token://$TOKEN \
    swarm-node-01

# Mit diesem Befehl überprüfen wir die Erstellung des Clusters
eval $(docker-machine env --swarm swarm-master)
docker info
```
## Beispiel
Die Erstellung des Redis-Master Containers
```Bash
docker run -d -p 6379:6379 redis
```

Die Erstellung der Redis-Slave Container
```Bash
# Wir benötigen die IP-Addresse des Redis-Masters
%TODO geht das in einem Einzeiler?
docker ps
export REDIS_MASTER="<IP-Redis-Master>"

# Nun können wir die zwei Redis-Slaves erstellen
docker run -d -p 6379:6379 -e REDISMASTER_PORT_6379_TCP_ADDR=$REDIS_MASTER -e REDISMASTER_PORT_6379_TCP_PORT=6379 johscheuer/redis-slave:v1
docker run -d -p 6379:6379 -e REDISMASTER_PORT_6379_TCP_ADDR=$REDIS_MASTER -e REDISMASTER_PORT_6379_TCP_PORT=6379 johscheuer/redis-slave:v1

# Bei dem versuch einen dritten Redis-Slave zu starten erhalten wir folgenden Fehler: "Error response from daemon: unable to find a node with port 6379 available"
# Welcher uns mitteilt, dass es keine Node in dem Swarm-Cluster gibt, die die Anforderung (Port 6379 frei) verfügbar ist.
```
Abschließend kann die ToDo-App gestartet werden
```Bash
# Wir benötigen die IP-Addressen der zwei Redis-Slaves, die des Redis-Masters haben wir noch abgespeichert
export REDIS_SLAVE_1="<IP-1>"
export REDIS_SLAVE_2="<IP-2>"

# Nun Starten wir zwei ToDo Container, die sich mit dem Redis-Slave 1 verbinden
docker run -d -e REDISMASTER_PORT_6379_TCP_ADDR=$REDIS_MASTER -e REDISMASTER_PORT_6379_TCP_PORT=6379 -e REDISSLAVE_PORT_6379_TCP_PORT=$REDIS_SLAVE_1 -e REDISSLAVE_PORT_6379_TCP_ADDR=6379 -p 9090:9090 johscheuer/todo-app:v1
docker run -d -e REDISMASTER_PORT_6379_TCP_ADDR=$REDIS_MASTER -e REDISMASTER_PORT_6379_TCP_PORT=6379 -e REDISSLAVE_PORT_6379_TCP_PORT=$REDIS_SLAVE_1 -e REDISSLAVE_PORT_6379_TCP_ADDR=6379 -p 9090:9090 johscheuer/todo-app:v1
# Der dritte ToDo App Container verbindet sich mit dem Redis-Slvae 2
docker run -d -e REDISMASTER_PORT_6379_TCP_ADDR=$REDIS_MASTER -e REDISMASTER_PORT_6379_TCP_PORT=6379 -e REDISSLAVE_PORT_6379_TCP_PORT=$REDIS_SLAVE_2 -e REDISSLAVE_PORT_6379_TCP_ADDR=6379 -p 9090:9090 johscheuer/todo-app:v1
```
