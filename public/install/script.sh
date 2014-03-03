#!/bin/bash

# $1=hostname
# $2=username

ssh-keyscan -H $1 >>~/.ssh/known_hosts

cat /etc/apt/sources.list | grep -v $1 >/etc/apt/sources.list.bk
mv -f /etc/apt/sources.list.bk /etc/apt/sources.list

echo "deb [arch=amd64] ssh://$2@$1:/urm/users/$2 ubuntu stable" >>/etc/apt/sources.list
apt-get --allow-unauthenticated update
apt-get -y --allow-unauthenticated install uhuru-ucc