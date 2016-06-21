#!/bin/bash

#sudo -u troll
# swap off
# swapoff -a

#sudo -u troll
cd  /home/troll/works/code/mojo/queue
perl /usr/local/bin/morbo script/queue reload --listen 'http://*:3000' 
#exit 1
#read -n 1
#perl /usr/local/bin/hypnotoad script/queue --listen http://*:3000 &


# sudo /usr/sbin/service nginx reload
