    .global read_one
    .global read_memory_scalar
    .global read_memory_sse
    .global read_one_avx
    .global read_memory_avx
    .global read_memory_sse_unaligned
    .global read_memory_avx_unaligned
    .global read_memory_every2
    .global read_memory_everyk
    .global write_one
    .global write_one_avx
    .global write_memory_scalar
    .global write_memory_sse
    .global write_memory_avx

    .text

// Read one location repeatedly
// void read_one(uint64_t *data, int n);
read_one:
    LDR x2, [x0]             // Load 64-bit from [x0] into x2
    SUB x1, x1, #1           // n = n - 1
    CMP x1, #0
    BGT read_memory_scalar   // If n > 0, jump to read_memory_scalar
    RET

// Read 8 bytes (64 bits) at a time
// void read_memory_scalar(uint64_t *data, int n);
read_memory_scalar:
    LDR x2, [x0], #8         // Load 64-bit from [x0], then add 8 to x0
    SUB x1, x1, #1           // n = n - 1
    CMP x1, #0
    BGT read_memory_scalar   // Loop until all n locations have been read
    RET

// Read all even words, then odd
// void read_memory_every2(uint64_t *data, int n);
read_memory_every2:
    MOV x8, x0               // Save x0 to x8
    LDR x2, [x0]             // Read one 64-bit memory
    ADD x0, x0, #16          // Advance to next location
    SUB x1, x1, #2           // n = n - 2
    CMP x1, #0
    BGT read_memory_scalar   // If n > 0, jump to read_memory_scalar
    ADD x8, x8, #8           // Add 8 to x8 for odd locations
1:
    LDR x2, [x8]             // Read one 64-bit memory
    ADD x8, x8, #16          // Advance to next location
    SUB x1, x1, #2           // n = n - 2
    CMP x1, #0
    BGT 1b                   // Loop until all n locations have been read
    RET

// Read words skipping k, then go back and fill in the missing ones
// void read_memory_everyk(uint64_t *data, int n, int k);
read_memory_everyk:
    MOV x3, x1               // x3 = n
    MOV x4, x2               // x4 = k
    SDIV x5, x3, x4          // x5 = q = n / k
    MUL x6, x5, x4           // x6 = q * k
    SUB x7, x3, x6           // x7 = r = n - q * k
    MOV x10, x5              // x10 = q (quotient)
    MOV x11, x4              // x11 = k (number of passes)
    LSL x8, x4, #3           // x8 = k * 8 (bytes to advance each time)

.outer_loop:
    MOV x4, x0               // x4 = starting address of the array
    MOV x9, x10              // x9 = q = n / k
.inner_loop:
    LDR x2, [x4]             // Read one 64-bit memory
    ADD x4, x4, x8           // Advance by k * 8 bytes
    SUB x9, x9, #1           // q = q - 1
    CMP x9, #0
    BGT .inner_loop          // Loop until all n/k locations have been read

    ADD x0, x0, #8           // Move to next starting position
    SUB x11, x11, #1         // k passes left
    CMP x11, #0
    BGT .outer_loop          // Continue until all passes are done
    RET

// Read 16 bytes (128 bits) at a time (aligned)
// void read_memory_sse(uint64_t *data, int n);
read_memory_sse:
    LD1 {v0.2D}, [x0]         // Load 128 bits from [x0] into v0
    ADD x0, x0, #16           // Advance pointer
    SUB x1, x1, #2            // n = n - 2
    CMP x1, #0
    BGT read_memory_sse       // Loop until all n locations have been read
    RET

// Read one location repeatedly using AVX (256 bits)
// void read_one_avx(uint64_t *data, int n);
read_one_avx:
    LD1 {v0.2D}, [x0]          // Load first 16 bytes
    ADD x2, x0, #16            // Compute x0 + 16
    LD1 {v1.2D}, [x2]          // Load next 16 bytes
    SUB x1, x1, #4             // n = n - 4
    CMP x1, #0
    BGT read_memory_avx        // Keep going until all n locations have been read
    RET

// Read 32 bytes (256 bits) at a time (aligned)
// void read_memory_avx(uint64_t *data, int n);
read_memory_avx:
    LD1 {v0.2D}, [x0]          // Load first 16 bytes
    ADD x2, x0, #16            // Compute x0 + 16
    LD1 {v1.2D}, [x2]          // Load next 16 bytes
    ADD x0, x0, #32            // Advance pointer
    SUB x1, x1, #4             // n = n - 4
    CMP x1, #0
    BGT read_memory_avx        // Loop until all n locations have been read
    RET

// Read 16 bytes (128 bits) at a time (unaligned)
// void read_memory_sse_unaligned(uint64_t *data, int n);
read_memory_sse_unaligned:
    LD1 {v0.2D}, [x0]          // Load 16 bytes (128 bits)
    ADD x0, x0, #16            // Advance pointer
    SUB x1, x1, #2             // n = n - 2
    CMP x1, #0
    BGT read_memory_sse_unaligned // Loop until all n locations have been read
    RET

// Read 32 bytes (256 bits) at a time (unaligned)
// void read_memory_avx_unaligned(uint64_t *data, int n);
read_memory_avx_unaligned:
    LD1 {v0.2D}, [x0]          // Load first 16 bytes (128 bits)
    ADD x2, x0, #16            // Compute x0 + 16
    LD1 {v1.2D}, [x2]          // Load next 16 bytes (128 bits)
    ADD x0, x0, #32            // Advance pointer
    SUB x1, x1, #4             // n = n - 4
    CMP x1, #0
    BGT read_memory_avx_unaligned // Loop until all n locations have been read
    RET

// Write repeatedly to one 64-bit memory location
// void write_one(uint64_t *data, int n);
write_one:
    MOV x2, #1                // x2 = 1
1:
    STR x2, [x0]              // Store 1 to [x0]
    SUB x1, x1, #1            // n = n - 1
    CMP x1, #0
    BGT 1b                    // Loop until all n locations have been written
    RET

// Write repeatedly to one 64-bit memory location using AVX
// void write_one_avx(uint64_t *data, int n);
write_one_avx:
    MOV x3, #1
    DUP v0.2D, x3             // Set v0 to [1, 1]
    DUP v1.2D, x3             // Set v1 to [1, 1]
1:
    ST2 {v0.2D, v1.2D}, [x0]   // Store v0 and v1 together (32 bytes)
    ADD x0, x0, #32            // Advance pointer
    SUB x1, x1, #4             // n = n - 4
    CMP x1, #0
    BGT 1b                     // Loop until all n locations have been written
    RET

// Write 8 bytes (64 bits) at a time
// void write_memory_scalar(uint64_t *data, int n);
write_memory_scalar:
    MOV x2, #1                // x2 = 1
1:
    STR x2, [x0]              // Store 1 to [x0]
    ADD x0, x0, #8            // Advance pointer
    SUB x1, x1, #1            // n = n - 1
    CMP x1, #0
    BGT 1b                    // Loop until all n locations have been written
    RET

// Write 16 bytes (128 bits) at a time
// void write_memory_sse(uint64_t *data, int n);
write_memory_sse:
    MOV x2, #1
    DUP v0.2D, x2             // Set v0 to [1, 1]
1:
    ST1 {v0.2D}, [x0]          // Store first 16 bytes
    ADD x3, x0, #16            // Compute x0 + 16
    ST1 {v0.2D}, [x3]          // Store next 16 bytes
    ADD x0, x0, #32            // Advance pointer
    SUB x1, x1, #4             // n = n - 4
    CMP x1, #0
    BGT 1b                     // Loop until all n locations have been written
    RET

// Write 32 bytes (256 bits) at a time
// void write_memory_avx(uint64_t *data, int n);
write_memory_avx:
    MOV x2, #1
    DUP v0.2D, x2             // Set v0 to [1, 1]
    DUP v1.2D, x2             // Set v1 to [1, 1]
1:
    ST2 {v0.2D, v1.2D}, [x0]   // Store v0 and v1 together (32 bytes)
    ADD x0, x0, #32            // Advance pointer
    SUB x1, x1, #4             // n = n - 4
    CMP x1, #0
    BGT 1b                     // Loop until all n locations have been written
    RET
