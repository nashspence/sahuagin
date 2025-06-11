#!/bin/bash
set -e

service postgresql start

if [ -d /tmp/.ssh ]; then
  cp -r /tmp/.ssh /root/
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/*
fi

sudo -u postgres createdb sahuagin || true
sudo -u postgres psql -d sahuagin -f /workspace/sql/00_init.sql || true

