.data

msg:
    .ascii        "0"
len = . - msg

.text

.globl _start
_start: 
        mov x0, 57         /* input*/
        mov x5, 10         /* helpful number*/

        add x2, xzr, xzr        /* load 0 to a2*/
        add x3, x0, xzr         /* load a0 to a3*/

loop:   
        cmp x3, xzr
        b.eq end /* if nothing is left -> exit*/
        mov x4, x3
        udiv x4, x4, x5                  /* a4 := a3/a5*/
        mul x4, x4, x5
        sub x4, x3, x4                  /* a4 := a3 - a5*a4*/
        add x2, x4, x2
        udiv x3, x3, x5                  /* a3 := a3/a5*/
        b loop

end:    
    /* syscall write(int fd, const void *buf, size_t count) */
    mov     x0, 1      /* fd := STDOUT_FILENO */
    ldr     x1, =msg    /* buf := msg */
    strb    w2,[x1,0]     // store register r0 to address pointed to by (r1 + (0 * size)) where size is 8 bytes for 64-bit stores
    ldr     x2, =len    /* count := len */
    mov     w8, 64     /* write is syscall //64 */
    svc     0          /* invoke syscall */

    /* syscall exit(int status) */
    mov     x0, 0      /* status := 0 */
    mov     w8, 93     /* exit is syscall //93 */
    svc     0          /* invoke syscall */

