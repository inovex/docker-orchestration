# Complie the go

Die aktuelle Version der Todo-App kann hier gefunden werden: https://github.com/johscheuer/todo-app-web

```
go get -u github.com/inovex/docker-orchestration/container-src/web-frontend
# On OSX
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/todo-app .
# Create the Docker image
docker build -t johscheuer/todo-app-web .
# Tag the image
docker tag johscheuer/todo-app-web johscheuer/todo-app-web:v2
```
