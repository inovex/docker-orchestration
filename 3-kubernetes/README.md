# Kubernetes example
## Anforderungen
- [Vagrant 1.6.2+](https://www.vagrantup.com/downloads.html)
- [Virtualbox 4.3.28+](https://www.virtualbox.org/wiki/Download_Old_Builds_4_3)

Für das Beispiel wird ein laufends Kubernetes Cluster benötigt, hierbei kann das Vagrant Beispiel von dem offiziellen [Github repo](https://github.com/kubernetes/kubernetes/blob/v1.1.1/docs/getting-started-guides/vagrant.md) verwendet werden.

Starten des Clusters

```Bash
# Zu erst laden wir die fertig gebauten Binaries von kubernetes
wget https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v1.1.1/kubernetes.tar.gz
# Danach führen wir folgende Befehle aus um das Cluster zu starten:
tar xfz kubernetes.tar.gz
cd kubernetes
export KUBERNETES_PROVIDER=vagrant
export NUM_MINIONS=3
export KUBERNETES_MEMORY=1024 #Hier kann der Arbeitsspeicher eines Knotens angepasst werden
./cluster/kube-up.sh
```

Mit Kubectl können wir kontrollieren ob das Cluster erfolgreich gestart wurde

```Bash
./cluster/kubectl.sh get nodes
NAME         LABELS                              STATUS
10.245.1.3   kubernetes.io/hostname=10.245.1.3   Ready
10.245.1.4   kubernetes.io/hostname=10.245.1.4   Ready
10.245.1.5   kubernetes.io/hostname=10.245.1.5   Ready

./cluster/kubectl.sh cluster-info                                                                                                                                      17:34:13
Kubernetes master is running at https://10.245.1.2
KubeDNS is running at https://10.245.1.2/api/v1/proxy/namespaces/kube-system/services/kube-dns
KubeUI is running at https://10.245.1.2/api/v1/proxy/namespaces/kube-system/services/kube-ui
```

## Beispiel
Es wird angenommen, dass das Beispiel in dem home Ordner des aktuellen Benutzers unter docker-orchestration ausgecheckt wurde

Zuerst starten wir den Redis Master Replication-Controller, dies kann einige Zeit beanspruchen, da hierzu zu erst das Docker image heruntergeladen wird.

```Bash
./cluster/kubectl.sh create -f ~/docker-orchestration/3-kubernetes/redis-master-controller.json
# Überprüfung ob der Redis-Master Pod gestart wurde
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

Nun können wir den aktuellen Status des Clusters verifizieren. Die Endpoints sind  Endpunkte, auf die, vorrausgesetzt es handelt sich um "öffentlichte" bzw. erreichbare  IP-Addressen, einfach zugegriffen werden kann:

```Bash
./cluster/kubectl.sh get rc
./cluster/kubectl.sh get pods
./cluster/kubectl.sh get svc
./cluster/kubectl.sh get endpoints
```

Nun benötigen wir den nodePort, dies ist der Port, der auf allen Kubernetes nodes geöffnet wurde und auf die Todo App verweist.

```Bash
./cluster/kubectl.sh get svc todo-app -o json | grep nodePort
```

Mit diesem Port können wir mit dem Cluster nun interagieren z.B. verwenden wir Node 1 (10.245.1.3) mit den nodePort 30505 (dieser ist bei allen Nodes gleich). Wenn wir nun in den Browser 10.245.1.3:30505 eingeben sehen wir unsere Todo App.

Damit man sich davon überzeugen kann, dass der Service die Anfragen auch auf die unterschiedlichen Pods verteilt besitzt die Todo App eine kleine Schnittstelle welche die IP Adresse ausgibt:

```Bash
watch -n 1 curl -s http://10.245.1.3:30505/whoami
```

### Scale down
Wir können nun die Anzahl der Todo App pods auf 1 reduzieren, da wir z.B. aktuell wenig Verkehr auf unserer Website haben. Das Beispiel von oben mit dem Erstellen und Löschen eines Eintrags funktioniert nun weiterhin ob wohl der Pod nur auf einem Node im Cluster läuft, ist dieser von überall erreichbar.

```Bash
./cluster/kubectl.sh scale --replicas=1 rc todo-app
```

### Scale up
Wenn wir nun wieder mehr Resourcen benötigen, können wir einfach wieder neue Pod Instanzen hinzufügen.

```Bash
./cluster/kubectl.sh scale --replicas=4 rc todo-app
```

### Ausblick: Horizontal pod autoscaling
Mit der Version 1.1.1 von Kubernetes kommt das (beta) feature [horizontal-pod-autoscaling](https://github.com/kubernetes/kubernetes/tree/v1.1.1-beta.1/docs/user-guide/horizontal-pod-autoscaling) welches das dynamische Skalieren der Pods im Cluster erlaubt.

## Hinweise
Bei der Verwendung eines public Cloud Providers wie z.B. GCE oder AWS kann der Service automatisch einen öffentlich erreichbaren Loadbalancer erstellen.
