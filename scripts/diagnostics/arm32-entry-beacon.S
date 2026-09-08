/* ARM32 entry beacon and unprivileged-CPU self-test. No libc or device access.
 * The test maps anonymous USER memory at the same numeric address; it never
 * maps physical RAM. Only the extracted 32-byte body belongs in a kernel.
 */
.syntax unified
.arch armv7-a
.arm

.section .text, "ax", %progbits
.global _start
_start:
    movw r6, #0xf000
    movt r6, #0x4440
    mov r0, r6
    mov r1, #4096
    mov r2, #3                  /* PROT_READ | PROT_WRITE */
    mov r3, #0x22               /* MAP_PRIVATE | MAP_ANONYMOUS; hint, not MAP_FIXED */
    mvn r4, #0
    mov r5, #0
    mov r7, #192                /* ARM EABI mmap2 */
    svc #0
    cmp r0, r6
    bne fail
    movw r0, #0x789a
    movt r0, #0x3456
    movw r1, #0x4567
    movt r1, #0x0123
    movw r2, #0xcdef
    movt r2, #0x89ab
    mov r8, r0
    mov r9, r1
    mov r10, r2
    mrs r11, cpsr
    bl entry_beacon
    mrs r12, cpsr
    cmp r11, r12
    bne fail
    cmp r0, r8
    bne fail
    cmp r1, r9
    bne fail
    cmp r2, r10
    bne fail
    add r6, r6, #0xff0
    ldr r4, [r6]
    cmp r4, #0xa5000000
    bne fail
    ldr r4, [r6, #4]
    cmp r4, r9
    bne fail
    ldr r4, [r6, #8]
    cmp r4, r10
    bne fail
    ldr r4, [r6, #12]
    tst r4, #0x200              /* Little-endian CPSR.E */
    bne fail
    and r4, r4, #0x3f
    cmp r4, #0x10               /* ARM user mode, not Thumb */
    bne fail
    mov r0, #1
    adr r1, success
    mov r2, #success_end-success
    mov r7, #4                  /* write stdout */
    svc #0
    mov r0, #0
    b exit
fail:
    mov r0, #1
exit:
    mov r7, #1                  /* exit */
    svc #0
success:
    .ascii "ARM32_ENTRY_BEACON_SELFTEST_OK\n"
success_end:

/* Eight ARM instructions; no stack, flags changes, branches or r0-r2 clobbers.
 * r3/r4 are scratch at Linux entry. Boot protocol requires MMU/data cache off.
 * Physical destination is the last 16 bytes of the existing 64-KiB console.
 */
.section .text.beacon, "ax", %progbits
.balign 4
.type entry_beacon, %function
entry_beacon:
    movw r3, #0xfff0
    movt r3, #0x4440
    mov r4, #0xa5000000
    str r4, [r3]
    str r1, [r3, #4]
    str r2, [r3, #8]
    mrs r4, cpsr
    str r4, [r3, #12]
    /* This return is for the self-test only; the generator excludes it. */
    bx lr
.size entry_beacon, .-entry_beacon
.section .note.GNU-stack, "", %progbits
