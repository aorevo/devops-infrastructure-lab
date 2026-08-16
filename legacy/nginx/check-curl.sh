#!/bin/bash

set -uo pipefail

for i in {1..6}; do
    curl -s http://devops-pet.local:8080/api/info
    echo
done