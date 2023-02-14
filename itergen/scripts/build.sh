#!/bin/bash
#Copied from intended run directory
#Runs from <primate home>/primate-uarch/apps/pktReassembly

TARGET=pkt_reassembly_tail
CUR_DIR=$(pwd)
cd ../../../
PRIMATE_DIR=$(pwd)
LLVM_DIR=$PRIMATE_DIR/primate-arch-gen
UARCH_DIR=$PRIMATE_DIR/primate-uarch
CHISEL_SRC_DIR=$UARCH_DIR/chisel/Gorilla++/src
cd $UARCH_DIR/compiler/engineCompiler/multiThread/
make clean && make
cd $UARCH_DIR/apps/common/build/
make clean && make
cd $CUR_DIR/sw
$LLVM_DIR/build/bin/clang -emit-llvm -S -O3 "${TARGET}.cpp"
$LLVM_DIR/build/bin/opt -enable-new-pm=0 -load $LLVM_DIR/build/lib/LLVMPrimate.so -primate < "${TARGET}.ll" > /dev/null
mv primate.cfg $CHISEL_SRC_DIR/main/scala/
mv header.scala $CHISEL_SRC_DIR/main/scala/
cp input.txt $UARCH_DIR/chisel/Gorilla++/
mv primate_assembler.h $UARCH_DIR/apps/scripts/
cd $UARCH_DIR/apps/scripts/
make clean && make
cd $CUR_DIR/sw
$UARCH_DIR/apps/scripts/primate_assembler "${TARGET}.s" primate_pgm.bin
mv primate_pgm.bin $UARCH_DIR/chisel/Gorilla++/
cd $CUR_DIR/hw
cp $UARCH_DIR/templates/primate.template ./
python3 $UARCH_DIR/apps/scripts/scm.py
cp *.scala $CHISEL_SRC_DIR/main/scala/
[[ -e *.v ]] && cp *.v $CHISEL_SRC_DIR/main/resources/
[[ -e *.sv ]] && cp *.sv $CHISEL_SRC_DIR/main/resources/
rm primate.template
rm primate.scala
cd $UARCH_DIR/templates
cp *.scala $CHISEL_SRC_DIR/main/scala/
cp *.v $CHISEL_SRC_DIR/main/resources/
cd $CUR_DIR