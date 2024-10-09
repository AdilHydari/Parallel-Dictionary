# HW4 Answer the following questions about threading and memory access

[Register](https://en.wikipedia.org/wiki/Processor_register)
[Cache](https://en.wikipedia.org/wiki/Cache_(computing))

1. Basic facts
    a. What does a computer's clock speed regulate? The speed of instructions executed
    b. We double the clock speed
      1. memory read is x1
      2. memory write is x1
      3. reading from cache is x2
      4. multiplication speed is x2
    c. Speed of each instruction in clock cycles.
    testing_latency.s:
      1. add %rax, %rbx 1
      2. mul %rax, %rbx 3
      3. div %rcx       20
      4. shl $1, %rax   1
    d. Assume the following memory read instructions are in cache,
       but the location being read is new. timing is 46-45-45
      1. mov (%rsi), %rax       46
      2. vmovdqa (%rsi), %ymm0  45
    e. Why can't we just double the clock speed to make our computer faster? Heat & Cost
    f. What is the fastest memory in a computer? Registers
    g. What is the 2nd fastest memory? Cache
    h. What makes main memory (DRAM) so much slower than the fastest memory? SRAM vs DRAM and a larger memory size
    i. How many integer registers are there on an x86-64 machine? 16
    j. How many vector registers are there on an AVX2 machine? 16
    k. How many integer registers are there on an ARM64 machine? 32
    l. Why might the ARM designers have chosen differently than Intel? Later design philosophy, less backwards compatibility
    m. A special called RIP on intel rip. What does it stand for: rip stands for register instruction pointer 
    n. Look up what it does: RIP register holds the memory address of the next instruction
    o. What is the register RSP on intel? rsp stands for register stack pointer
    p. What is L1 cache on x86 architecture? number of cores 1, size ~32kb-64kb
    q. What is L2 cache on x86 architecture? number of cores 1 (on modern processors), size 256kb-1mb
    r. What is L3 cache on x86 architecture? number of cores shared by all cores, size 8-30mb
    s. Approximately how long does it take light to travel 30cm? 1 ns

2. Class Survey
   a. Enter your name into a row of the spreadsheet and complete the data for your computer.
   b. If you have more than one computer you can pick the one you use. You may enter more than one.
https://docs.google.com/spreadsheets/d/10DiQJcTMTqcE1JjSKFx0AWUcOAqu75cQUcKsF0jtxBg/edit?usp=sharing

2. Basics of Multiprocessing
    a. What is a process?
    - A process is a running program that operates in its own separate memory address space.
    b. What is a thread?
    - A thread is a execution unit for a process, each thread can execute independently of each other but must merge into a single result at the end.
    c. Every thread requires at a minimum sp, pc/rip. Explain
    - Each thread maintains its own SP to make sure that the function calls and local variables are not accessed by other threads, as to interfere with each other.
    - The PC and RIP keeps track of where the thread is in execution, allowing the CPU to fetch and execute instructions in the correct order.
    d. A computer with 4 cores is running a job.
       1 thread, t=10s, 2 threads t=5s, 4 threads t=3s
       Neglecting hyperthreading, Why might it not be a good idea to run with 8 threads? 
      - In this case we are refering to software threads since we are using more threads than cores, which means that we will have to context switch and time slice our threads to make 8 software threads fit inside of those 4 cores. This introduces overhead for context switching and time slicing, as well as the threads competing for I/O bound resources. This means that the speed up is no longer linear, and may not even speed up the program past these 4 (hardware) threads. 


3. Explain the benchmark results for memory_timings.s.
   a. For each function run explain (in one line) what it is attempting to measure.
   - read_one: Measures the throughput of repeatedly reading a single 64-bit memory location.
   - read_memory_scalar: Throughput of sequentially reading 64-bit memory locations one at a time.
   - read_memory_sse: Throughput of sequentially reading 64-bit memory locations using SSE (128 bit).
   - read_memory_avx: Throughput of sequentially reading 64-bit memory locations using AVX (256 bit).
   - read_memory_sse_unaligned: Throughput of sequentially reading 64-bit memory locations using SSE (128 bit) without alignment.
   - read_memory_avx_unaligned: Throughput of sequentially reading 64-bit memory locations using AVX (256 bit) without alignment.
   - read_memory_every2: Throughput of reading every second 64-bit location
   - read_memory_everyk: Throughput of reading every k-th 64-bit location
   b. Why is write_one so much slower than read_one?

   c. Why is read_memory_avx faster than read_memory_scalar if both are reading the same amount of memory sequentially?
   d. Run on your computer (or a lab computer if yours is an ARM or you have some other problem). Report the results.
     1. Extra credit: if you write your own assembly code and test a different architecture, + 50%
     - memory_timingarm64.s
     2. Find the CPU and memory configuration for the machine you tested. This can be About... in windows, or in linux you can use lscpu and cat /proc/cpuinfo
     - lscpu output: 
     ```
     Architecture:             aarch64
  CPU op-mode(s):         64-bit
  Byte Order:             Little Endian
CPU(s):                   10
  On-line CPU(s) list:    0-9
Vendor ID:                Apple
  Model name:             Icestorm-M1-Pro
    Model:                0
    Thread(s) per core:   1
    Core(s) per socket:   2
    Socket(s):            1
    Stepping:             0x2
    Frequency boost:      enabled
    CPU(s) scaling MHz:   29%
    CPU max MHz:          2064.0000
    CPU min MHz:          600.0000
    BogoMIPS:             48.00
    Flags:                fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm jscvt fcma lrcpc dcpop sha3 asim
                          ddp sha512 asimdfhm dit uscat ilrcpc flagm ssbs sb paca pacg dcpodp flagm2 frint
  Model name:             Firestorm-M1-Pro
    Model:                0
    Thread(s) per core:   1
    Core(s) per socket:   8
    Socket(s):            1
    Stepping:             0x2
    CPU(s) scaling MHz:   84%
    CPU max MHz:          3228.0000
    CPU min MHz:          600.0000
    BogoMIPS:             48.00
    Flags:                fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm jscvt fcma lrcpc dcpop sha3 asim
                          ddp sha512 asimdfhm dit uscat ilrcpc flagm ssbs sb paca pacg dcpodp flagm2 frint
Caches (sum of all):      
  L1d:                    1.1 MiB (10 instances)
  L1i:                    1.8 MiB (10 instances)
  L2:                     28 MiB (3 instances)
NUMA:                     
  NUMA node(s):           1
  NUMA node0 CPU(s):      0-9
     ```
5. Explain what a cache is
   a. Explain what a cache miss is
   - 

6. Why is it so important to understand memory performance for parallel computing?
- A lot of CPU operations are memory bound, meaning that it is not the computing that is bottlenecked, but rather the speed at which the CPU can grab the next instruction to execute.
7. Why does pipelining on a modern CPU make benchmarking so difficult?
- CPU pipeling makes instruction processing non-deterministic, especially on modern CPUs with register renaming and Micro-Ops.
8. Why doesn't AMD define their own extensions to the instruction set, like more registers?
- AMD  follows intel for ISA extensions like AVX for the sake standardization across x86-64 processors. 
9. Why doesn't a CPU manufacturer design a computer with 1 million registers?
- At some point the logic connecting all of the registers together is too advanced and simply just becomes a cache. Also the issue of grabbing those registers from a register file, if we had a million registers our register file would grow accordingly, making the register file extremely slow. 
