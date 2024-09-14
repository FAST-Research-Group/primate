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

COPY . .

###############################################################################
####                          Primate Dependencies                         ####
###############################################################################

#Prepare to instal dependencies, by disabling prompts and updating apt, then 
#start installing dependencies
#  Java -> Chisel -> Primate
#  gnupg2 -> Chisel -> Primate
#  Misc. -> sbt -> Chisel -> Primate
#  Misc. -> Chisel -> Primate
#  Misc. -> Verilator -> Chisel -> Primate     #Consider wget http://archive.ubuntu.com/ubuntu/pool/main/b/bison/bison_3.5.1+dfsg-1_amd64.deb for bison instead of from apt in future (Updates)
#  Misc. -> cmake -> Primate
#  Misc. -> Script
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && apt-get update \
 && apt-get -y install openjdk-11-jdk \
 && apt-get -y install gnupg1 \ 
 && apt-get -y install apt-transport-https curl gnupg \
 && apt-get -y install git make clang curl g++ flex bison \ 
 && apt-get -y install git make autoconf g++ flex bison \
 && apt-get -y install build-essential libssl-dev \
 && apt-get -y install unzip \
 && apt-get -y install emacs vim \
 && apt-get -y install ccache
 
#sbt -> Chisel -> Primate
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list \
 && echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list \
 && curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --no-tty --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import \
 && chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg \
 && apt-get update \
 && apt-get -y install sbt=1.7.1

# Firtool and chisel need to match!
# https://www.chisel-lang.org/docs/appendix/versioning
WORKDIR /primate/deps
RUN curl -L https://github.com/llvm/circt/releases/download/firtool-1.37.2/firrtl-bin-linux-x64.tar.gz -o ./firtool.tar.gz
RUN tar -xzf firtool.tar.gz
RUN mv firtool-1.37.2 firtool
RUN rm firtool.tar.gz
ENV PATH="${PATH}:/primate/deps/firtool/bin/"

#Chisel -> Primate
#Tar based instal flow
WORKDIR /primate/dep
RUN curl -sL https://github.com/chipsalliance/chisel/archive/refs/tags/v3.6.0.zip -o v3.6.0.zip \
 && unzip v3.6.0.zip \
 && rm ./v3.6.0.zip
WORKDIR /primate/dep/chisel-3.6.0
RUN sbt compile \
 && sbt publishLocal
WORKDIR /primate

#Verilator -> Chisel -> Primate
WORKDIR /primate/dep
RUN git clone https://github.com/verilator/verilator
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

WORKDIR /primate
RUN git status
RUN git submodule init .
RUN git submodule update --init --recursive

WORKDIR /primate/primate-compiler
RUN git checkout primate

WORKDIR /primate/primate-arch-gen
# RUN git checkout tags/v0.1
RUN git checkout kayvan-arch-gen

WORKDIR /primate/primate-uarch
# RUN git checkout tags/v0.1

# Build arch-gen
WORKDIR /primate/primate-arch-gen/build
RUN cmake -G Ninja -DLLVM_TARGETS_TO_BUILD=host -DLLVM_ENABLE_PROJECTS=clang -DLLVM_PARALLEL_LINK_JOBS=1 -DLLVM_LINK_LLVM_DYLIB=true ../llvm/
RUN ninja

#Pull compiler and build
WORKDIR /primate/primate-compiler
RUN cmake -S llvm -B build -G Ninja -DLLVM_CCACHE_BUILD=On -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_PROJECTS='clang' -DLLVM_TARGETS_TO_BUILD='Primate;RISCV' -DLLVM_BUILD_TESTS=False -DCMAKE_INSTALL_PREFIX="/primate/primate-compiler/build" -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=Primate -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
RUN ninja -C ./build
WORKDIR /primate

###############################################################################
####                            Container Setup                            ####
###############################################################################

#Add an idle taks so that the user can freely access the container via exec
ENTRYPOINT ["sleep", "infinity"]
