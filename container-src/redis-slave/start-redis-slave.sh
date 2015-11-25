#!/bin/bash

echo "Start redis slave redis-master 6379"

redis-server --slaveof redis-master 6379
