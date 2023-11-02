#syntax=docker/dockerfile:1

###############################################################################
####                           Dockerfile Notes                            ####
###############################################################################

#Before using this Dockerfile, ensure that the docker daemon is running by:
#Windows				Start Docker
#Windows (WSL)				Start Docker and enable WSL integration
#Ubuntu 				Run 'sudo service docker start' or start docker desktop
#Arch & Manjaro 			Run 'sudo dockerd&'

#In order to build and run the container you can use the commands:
#Build New image	 		docker build -t primate-container . 
#Check images 				docker images
#Run primate image			docker run -d primate-container 
#Check running images (get id) 		docker ps
#Connect to running image 		docker exec -it <Container ID> sh

###############################################################################
####                            Dockerfile Notes                           ####
###############################################################################

#Start the container by loading any linux OS, typically ubuntu but we used to do RHEL
FROM ubuntu:20.04

#Create a label for the image
LABEL version="0.1.0"
LABEL description="Container for fully setup copy of primate"

#Create and set as the working directory
WORKDIR /primate

###############################################################################
####                          Primate Dependencies                         ####
###############################################################################

#Prepare to instal dependencies, by disabling prompts and updating apt, then 
#start installing dependencies
#  Java -> Chisel -> Primate
#  gnupg2 -> Chisel -> Primate
#  Misc. -> sbt -> Chisel -> Primate
#  Misc. -> Chisel -> Primate
#  Misc. -> Verilator -> Chisel -> Primate
#  Misc. -> cmake -> Primate
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && apt-get update \
 && apt-get -y install default-jdk \
 && apt-get -y install gnupg1 \ 
 && apt-get -y install apt-transport-https curl gnupg \
 && apt-get -y install git make clang curl g++ flex bison \
 && apt-get -y install git make autoconf g++ flex bison \
 && apt-get -y install build-essential libssl-dev
 
#sbt -> Chisel -> Primate
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list \
 && echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list \
 && curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --no-tty --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import \
 && chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg \
 && apt-get update \
 && apt-get -y install sbt

#Chisel -> Primate
WORKDIR /primate/dep
RUN git clone https://github.com/chipsalliance/chisel.git
WORKDIR /primate/dep/chisel
RUN git pull \
 && git checkout 3.4-release \
 && sbt compile \
 && sbt publishLocal
WORKDIR /primate

#Verilator -> Chisel -> Primate
WORKDIR /primate/dep
RUN git clone http://git.veripool.org/git/verilator
WORKDIR /primate/dep/verilator
RUN git pull \
 && git checkout v4.016 \
 && autoconf \
 && ./configure \
 && make \
 && make install
WORKDIR /primate

#cmake -> Primate
WORKDIR /primate/dep
RUN curl -sL https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0.tar.gz -o cmake-3.20.0.tar.gz \
 && tar -xzf cmake-3.20.0.tar.gz
WORKDIR /primate/dep/cmake-3.20.0
RUN ./bootstrap && make && make install 
WORKDIR /primate

#ninja -> Primate
RUN apt-get -y install ninja-build

###############################################################################
####                             Primate Setup                             ####
###############################################################################

#Build arch-gen
COPY ./primate-arch-gen ./primate-arch-gen
WORKDIR /primate/primate-arch-gen/build
RUN cmake -G Ninja -DLLVM_TARGETS_TO_BUILD=host -DLLVM_ENABLE_PROJECTS=clang -DLLVM_PARALLEL_LINK_JOBS=1 -DLLVM_LINK_LLVM_DYLIB=true ../llvm/
RUN ninja
WORKDIR /primate

#Build sample application Packet Reassembler
COPY ./primate-uarch ./primate-uarch
#WORKDIR /primate/primate-uarch/apps/pktReassembly
#RUN ./build.sh
WORKDIR /primate

#Copy Top level files
COPY ./.gitmodules ./.gitmodules
COPY ./README.md ./README.md
COPY ./create_image.sh ./create_image.sh

###############################################################################
####                            Container Setup                            ####
###############################################################################

#Add an idle taks so that the user can freely access the container via exec
ENTRYPOINT ["sleep", "infinity"]
