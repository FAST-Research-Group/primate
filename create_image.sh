#! /bin/bash

# NOTE: that docker-engine must have access to a large ammount of memory in order to build the container, as 
# LLVM takes a ~24-32GB of RAM. Additionally, the final image, with all layers will be about 36GB in size

# The purpose of this script is to initialize the submodules of the primate top-level git repo, and then to 
# Create a docker image

#Commands
#	-prune		Clear old containers
#	-clear		Clear all containers
#	-exec 		Run the container after building

if [ -z "$(ls -A ./primate-arch-gen)" ]; then
	echo "Populating submodules, this can take awhile as llvm is large and must be downloaded"
	git submodule update --init --recursive
elif [ -z "$(ls -A ./primate-uarch)" ]; then
	echo "Populating submodules, this can take awhile if primate-arch-gen is not already populated"
	git submodule update --init --recursive
else
	echo "Git submodules already popluated"
fi

if [[ "$@" == *"-prune"* ]]; then
	echo "Cound -prune in arguments, pruning docker images older than 1 month"
	docker image prune --all --filter "until=720h"
elif [[ "$@" == *"-clear"* ]]; then
	echo "Cound -clear in arguments, pruning docker images older than 1 hour"
	docker image prune --all --filter "until=1h"	
fi

#Rebuild Docker container, based on changes to src files
docker build -t primate-container -m 24g .

if [[ "$@" == *"-exec"* ]]; then
	echo "Found -exec in arguments, launching bash in docker container"
	docker run -d -p 80:80 --name primate-instance primate-container
	docker start primate-instance
	docker exec -it primate-instance bash
fi

