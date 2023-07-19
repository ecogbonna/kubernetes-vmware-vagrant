#!/bin/bash
trap "exit" SIGINT        # trap [action] [signal] i.e. while running below code, if you receive signal interrupt, run the "exit" command
mkdir /var/htdocs

while :
do
  echo $(date) Writing fortune to /var/htdocs/index.html
  /usr/games/fortune > /var/htdocs/index.html
  sleep 10
done

