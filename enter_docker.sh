#!/bin/bash

# Check the provided argument and run into the docker container
if [ -z "$1" ] || [ "$1" == "root" ]; then
    docker exec -it opencda_container bash
elif [ "$1" == "opencda" ]; then
    docker exec -it --user opencda opencda_container bash
else
    echo "Usage: . enter_docker.sh [no argument|root|opencda]"
fi
