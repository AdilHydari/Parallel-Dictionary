# using llvm-mca
# RUN: llvm-mca -march=x86-64 testing_latency.s | FileCheck %s 

.text
add %rax, %rbx
mul %rax, %rbx
div %rcx
shl $1, %rax

