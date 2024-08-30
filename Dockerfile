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
####                          Docker Boilerplate                           ####
###############################################################################

#Start the container by loading any linux OS, typically ubuntu but we used to do RHEL
FROM ubuntu:22.04

#Create a label for the image
LABEL version="0.1.0-ChiselMigrate"
LABEL description="Container for fully setup copy of primate"

#Create and set as the working directory
WORKDIR /primate

COPY . .

###############################################################################
####                            Dockerfile ARGS                            ####
###############################################################################

# primate release version. corresponds to the TAG from git (v$PRIMATE_VERSION)
ARG PRIMATE_VERSION="0.1"

# parallel link jobs when making LLVM. Increase at risk to your own DRAM
ARG PARALLEL_LINK_CMAKE="1"

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
 && apt-get -y install git make curl g++ flex bison \ 
 && apt-get -y install autoconf \
 && apt-get -y install wget \
 && apt-get -y install build-essential libssl-dev \
 && apt-get -y install unzip \
 && apt-get -y install emacs vim \
 && apt-get -y install ccache \
 && apt-get -y install cmake \
 && apt-get -y install help2man \
 && apt-get -y install openssh-server \
 && apt -y install lsb-release wget software-properties-common gnupg
 
# need clang-18 for cstdlib
RUN wget https://apt.llvm.org/llvm.sh
RUN chmod +x llvm.sh 
RUN ./llvm.sh 18

#sbt -> Chisel -> Primate
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list \
 && echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list \
 && curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --no-tty --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import \
 && chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg \
 && apt-get update \
 && apt-get -y install sbt

# Firtool and chisel need to match!
# https://www.chisel-lang.org/docs/appendix/versioning
WORKDIR /primate/deps
RUN curl -L https://github.com/llvm/circt/releases/download/firtool-1.62.0/firrtl-bin-linux-x64.tar.gz -o ./firtool.tar.gz
RUN tar -xzf firtool.tar.gz
RUN mv firtool-1.62.0 firtool
RUN rm firtool.tar.gz
ENV PATH="${PATH}:/primate/deps/firtool/bin/"

# Chisel
WORKDIR /primate/dep
RUN curl -sL https://github.com/chipsalliance/chisel/archive/refs/tags/v6.3.0.zip -o v6.3.0.zip \
 && unzip v6.3.0.zip \
 && rm ./v6.3.0.zip
WORKDIR /primate/dep/chisel-6.3.0
RUN sbt compile \
 && sbt publishLocal
WORKDIR /primate/dep
RUN git clone git@github.com:rameloni/tywaves-chisel-demo.git
WORKDIR /primate/dep/tywaves-chisel-demo
RUN make all


# Verilator -> Chisel -> Primate
WORKDIR /primate/dep
RUN git clone https://github.com/verilator/verilator
WORKDIR /primate/dep/verilator
RUN git checkout v4.228 && autoconf && ./configure && make -j 8 && make install

#cmake -> Primate
WORKDIR /primate

#ninja -> Primate
RUN apt-get -y install ninja-build

###############################################################################
####                             SSH Setup                                 ####
###############################################################################


RUN mkdir -p /root/.ssh && \
    chmod 0700 /root/.ssh
# See: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints

# Add the keys and set permissions
RUN --mount=type=secret,id=ssh_prv \
    cat /run/secrets/ssh_prv > /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa
    
RUN --mount=type=secret,id=ssh_pub \
    cat /run/secrets/ssh_pub > /root/.ssh/id_rsa.pub && \
    chmod 600 /root/.ssh/id_rsa.pub

###############################################################################
####                             Primate Setup                             ####
###############################################################################

WORKDIR /primate
RUN git status
RUN git submodule init .
RUN git submodule update --init --recursive


WORKDIR /primate/primate-compiler
RUN git checkout ff-llvm-18

WORKDIR /primate/primate-arch-gen
RUN git checkout tags/v${PRIMATE_VERSION}

WORKDIR /primate/primate-uarch
RUN git checkout chisel-6-migrate

ENV CC=/usr/bin/clang-18
ENV CXX=/usr/bin/clang++-18

#Build arch-gen
WORKDIR /primate/primate-arch-gen/build
RUN cmake -G Ninja -DLLVM_TARGETS_TO_BUILD=host -DLLVM_ENABLE_PROJECTS='clang;libc;libcxx;libcxxabi' -DLLVM_PARALLEL_LINK_JOBS=$PARALLEL_LINK_CMAKE -DLLVM_LINK_LLVM_DYLIB=true ../llvm/
RUN ninja

#Pull compiler and build
WORKDIR /primate/primate-compiler
RUN cmake -S llvm -B build -G Ninja -DLLVM_CCACHE_BUILD=On -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_PROJECTS='clang' -DLLVM_TARGETS_TO_BUILD='RISCV' -DLLVM_BUILD_TESTS=False -DCMAKE_INSTALL_PREFIX="./build" -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="Primate" -DLLVM_DEFAULT_TARGET_TRIPLE='primate32-unknown-linux-gnu'
# -DLLVM_ENABLE_RUNTIMES='libc;libcxx;libcxxabi'
RUN ninja -C ./build
WORKDIR /primate

###############################################################################
####                            Container Setup                            ####
###############################################################################

#Add an idle taks so that the user can freely access the container via exec
ENTRYPOINT ["sleep", "infinity"]
