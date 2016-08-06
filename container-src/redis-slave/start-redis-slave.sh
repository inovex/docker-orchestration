#!/bin/sh
redis-server --protected-mode no --slaveof redis-master 6379
