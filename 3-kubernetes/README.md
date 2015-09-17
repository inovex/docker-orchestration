# Kubernetes example

## Anforderungen
* [Vagrant 1.6.2+](https://www.vagrantup.com/downloads.html)
* [Virtualbox 4.3.28](https://www.virtualbox.org/wiki/Download_Old_Builds_4_3)

Für das Beispiel wird ein laufends Kubernetes Cluster benötigt, hierbei kann das Vagrant Beispiel von dem offiziellen [Github repo](https://github.com/kubernetes/kubernetes/blob/v1.0.1/docs/getting-started-guides/vagrant.md) verwendet werden.

Starten des Clusters
```Bash
# Zu erst laden wir die fertig gebauten Binaries von kubernetes
wget https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v1.0.1/kubernetes.tar.gz
# Danach führen wir folgende Befehle aus um das Cluster zu starten:
tar xfz kubernetes.tar.gz
cd kubernetes
# Diesen Patch müssen wir noch per Hand einspielen https://github.com/kubernetes/kubernetes/pull/12237/files
export KUBERNETES_PROVIDER=vagrant
export NUM_MINIONS=3
export KUBERNETES_MEMORY=1024 #Hier kann der Arbeitsspeicher eines Knotens angepasst werden
./cluster/kube-up.sh
```

## Beispiel 
Es wird angenommen, dass das Beispiel in dem home Ordner des aktuellen Benutzers unter docker-orchestration ausgecheckt wurde

Zuerst starten wir den Redis Master Replication-Controller
```Bash
./cluster/kubectl.sh create -f ~/docker-orchestration/3-kubernetes/redis-master-controller.json
# Überprüfung ob der Redis-Master Pod gestart wurde
# Dies kann einige Zei beanspruchen, da hierzu zu erst das Docker image heruntergeladen wird
./cluster/kubectl.sh get pods
```

Danach kann der Redis-Master Service gestartet werden, somit können andere Pods diesen Pod verwenden.
```Bash
./cluster/kubectl.sh create -f ~/docker-orchestration/3-kubernetes/redis-master-service.json
./cluster/kubectl.sh get service
```

Nun können wir den Redis-Slave starten
```Bash
./cluster/kubectl.sh create -f ~/docker-orchestration/3-kubernetes/redis-slave-controller.json
# Der Replciation Controller erstellt 2 redis-slave pods
./cluster/kubectl.sh get rc
# Warte bis die redis-slave pods gestartet wurden
./cluster/kubectl.sh get pods
```

und anschließend den dazugehörigen Service
```Bash
./cluster/kubectl.sh create -f ~/docker-orchestration/3-kubernetes/redis-slave-service.json
./cluster/kubectl.sh get service
```

Abschließend starten wir die ToDo-App Pods
```Bash
./cluster/kubectl.sh create -f ~/docker-orchestration/3-kubernetes/todo-app-controller.json
# Dieses mal benutzen wir das Label um die Ausgabe zu filtern
./cluster/kubectl.sh get pods -l name=todo-app
```

und auch hier werden wieder Services gestartet
```Bash
./cluster/kubectl.sh create -f ~/docker-orchestration/3-kubernetes/todo-app-service.json
# Wir können das Label bei allen Komponenten von kubernetes verwenden
./cluster/kubectl.sh get service -l name=todo-app
```

Nun können wir den aktuellen Status des Clusters verifizieren. Die Endpoints sind 
Endpunkte, auf die, vorrausgesetzt es handelt sich um "öffentlichte" bzw. erreichbare 
IP-Addressen, einfach zugegriffen werden kann:

```Bash
./cluster/kubectl.sh get rc
./cluster/kubectl.sh get pods
./cluster/kubectl.sh get services
./cluster/kubectl.sh get endpoints
# Da wir ja nur mit dem frontend interagieren möchten können wir auch hier das Label verwenden
./cluster/kubectl.sh get endpoints -l name=todo-app
# Über den Proxy ist ein bequemer Zugriff auf die endpoints möglich
# Wir verwenden den default User des Vagrant Beispiels und vertrauen dem selbst erstellten Zertifikat
curl -k -u vagrant:vagrant "https://10.245.1.2/api/v1/proxy/namespaces/default/services/todoapp"
```
Abschließend lassen wir die ToDo-App Pods skalieren und reduzieren die Anzahl auf 1 Pod und danach wieder auf 4 Pods
```Bash
./cluster/kubectl.sh scale --replicas=1 rc todo-app
./cluster/kubectl.sh scale --replicas=4 rc todo-app
```
