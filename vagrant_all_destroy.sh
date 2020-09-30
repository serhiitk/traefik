#!/bin/bash

if [[ -d "$(pwd)/hosts" ]]
then
  for i in $(find $(pwd)/hosts/ -type f -name Vagrantfile | xargs dirname)
  do
    cd $i
    vagrant destroy -f
  done
fi
