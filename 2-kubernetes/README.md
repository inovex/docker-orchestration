# Kubernetes example

## Anforderungen

- [Minikube](https://github.com/kubernetes/minikube/releases)
- [VirtualBox](https://www.virtualbox.org)
- [kubectl](http://kubernetes.io/docs/getting-started-guides/minikube/#install-kubectl)

### Starten des Clusters

Dieser Schritt ist nur notwendig wenn kein Kubernetes Cluster vorhanden ist. Mit Minikube wird ein lokales Kubernetes Cluster gestartet und kubectl konfiguriert. Alternativ kann auch [Vagrant](https://github.com/kubernetes/kubernetes/blob/master/docs/devel/local-cluster/vagrant.md) verwendet werden um ein Cluster zu starten, diese Möglichkeit ist aber seit Minikube veraltet und sollte nur zum Entwickeln verwendet werden.

```bash
$ minikube start --memory=4096 --cpus=2
```

Mit Kubectl können wir kontrollieren ob das Cluster erfolgreich gestart wurde

```bash
$ kubectl get nodes
NAME          STATUS    AGE
boot2docker   Ready     5m

$ kubectl cluster-info
Kubernetes master is running at https://192.168.64.20:8443
kubernetes-dashboard is running at https://192.168.64.20:8443/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard

$ kubectl get componentstatus
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health": "true"}
```

### Zugriff auf das Dashboard

Die Todo App kann auch über das mitgelieferte Dashboard von Kubernetes deployt werden. Das Dashboard kann über den folgenden Befehl aufgerufen werden.

```
$ minikube dashboard
```

## Beispiel

Es wird angenommen, dass das Beispiel in dem home Ordner des aktuellen Benutzers unter docker-orchestration ausgecheckt wurde

Zuerst starten wir den Redis Master Replication-Controller, dies kann einige Zeit beanspruchen, da hierzu zu erst das Docker image heruntergeladen wird.

```bash
$ kubectl create -f ~/docker-orchestration/2-kubernetes/redis-master-controller.yaml
# Überprüfung ob der Redis-Master Pod gestart wurde
$ kubectl get pods
```

Danach kann der Redis-Master Service gestartet werden, somit können andere Pods diesen Pod verwenden.

```bash
$ kubectl create -f ~/docker-orchestration/2-kubernetes/redis-master-service.yaml
# Überprüfen ob der Service erstellt wurde
$ kubectl get service
```

Nun können wir den Redis-Slave starten

```bash
$ kubectl create -f ~/docker-orchestration/2-kubernetes/redis-slave-controller.yaml
# Der Replciation Controller erstellt 2 redis-slave pods
$ kubectl get rc
# Warte bis die redis-slave pods gestartet wurden
$ kubectl get pods
```

und anschließend den dazugehörigen Service

```bash
$ kubectl create -f ~/docker-orchestration/2-kubernetes/redis-slave-service.yaml
# Überprüfen ob der Service erstellt wurde
$ kubectl get service
```

Abschließend starten wir die ToDo-App Pods

```bash
$ kubectl create -f ~/docker-orchestration/2-kubernetes/todo-app-controller.yaml
# Dieses mal benutzen wir das Label um die Ausgabe zu filtern
$ kubectl get pods -l name=todo-app
```

und auch hier werden wieder Services gestartet

```bash
$ kubectl create -f ~/docker-orchestration/2-kubernetes/todo-app-service.yaml
# Wir können das Label bei allen Komponenten von kubernetes verwenden
$ kubectl get service -l name=todo-app
```

Nun können wir den aktuellen Status des Clusters verifizieren. Die Endpoints sind Endpunkte, auf die, vorausgesetzt es handelt sich um "öffentlichte" bzw. erreichbare IP-Addressen, einfach zugegriffen werden kann:

```bash
$ kubectl get rc
NAME           DESIRED   CURRENT   AGE
redis-master   1         1         6m
redis-slave    2         2         3m
todo-app       3         3         1m

$ kubectl get po
NAME                 READY     STATUS    RESTARTS   AGE
redis-master-wzndh   1/1       Running   0          6m
redis-slave-b2e0a    1/1       Running   0          3m
redis-slave-knpxi    1/1       Running   0          3m
todo-app-0lhn6       1/1       Running   0          1m
todo-app-22hvu       1/1       Running   0          1m
todo-app-ybpdk       1/1       Running   0          1m

$ kubectl get svc
NAME           CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
kubernetes     10.0.0.1     <none>        443/TCP    17m
redis-master   10.0.0.31    <none>        6379/TCP   5m
redis-slave    10.0.0.36    <none>        6379/TCP   3m
todo-app       10.0.0.181   <none>        80/TCP     2m

$ kubectl get endpoints
NAME           ENDPOINTS                                         AGE
kubernetes     192.168.64.20:8443                                18m
redis-master   172.17.0.3:6379                                   6m
redis-slave    172.17.0.4:6379,172.17.0.5:6379                   3m
todo-app       172.17.0.6:3000,172.17.0.7:3000,172.17.0.8:3000   2m
```

Ein Blick in das Kubernetes Dashboard gibt eine gute Übersicht über die laufenden Pods und Replication-Controller.

Da wir den Service als Typ "ClusterIP" gestartet haben, können wir diesen über den Kubernetes Master aufrufen. Zu erst ermöglichen wir über einen Redirect, den Zugriff auf den API Server über localhost:

```bash
$ kubectl proxy --api-prefix=/api &
Starting to serve on 127.0.0.1:8001
```

Damit man sich davon überzeugen kann, dass der Service die Anfragen auch auf die unterschiedlichen Pods verteilt besitzt die Todo App eine kleine Schnittstelle welche die IP Adresse ausgibt:

```bash
$ watch -n 0.5 curl -s http://127.0.0.1:8001/api/v1/proxy/namespaces/default/services/todo-app/whoami
```

Der Proxy kann danach mit `pkill kubectl proxy` beendet werden.

### Scale down

Wir können nun die Anzahl der Todo App pods auf 1 reduzieren, da wir z.B. aktuell wenig Verkehr auf unserer Website haben. Das Beispiel von oben mit dem Erstellen und Löschen eines Eintrags funktioniert nun weiterhin obwohl der Pod nur auf einem Node im Cluster läuft, ist dieser von überall erreichbar.

```bash
$ kubectl scale --replicas=1 rc todo-app
```

### Scale up

Wenn wir nun wieder mehr Resourcen benötigen, können wir einfach wieder neue Pod Instanzen hinzufügen.

```bash
$ kubectl scale --replicas=5 rc todo-app
```

### Ausblick: Horizontal pod autoscaling

Seit der Version 1.1.1 von Kubernetes gibt es das Feature [horizontal-pod-autoscaling](http://kubernetes.io/docs/user-guide/horizontal-pod-autoscaling) welches das dynamische Skalieren der Pods im Cluster erlaubt.

## Hinweise

Bei der Verwendung eines public Cloud Providers wie z.B. GCE oder AWS kann der Service automatisch einen öffentlich erreichbaren Loadbalancer erstellen.
