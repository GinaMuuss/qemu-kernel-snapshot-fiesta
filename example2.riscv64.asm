.global _start      # Provide program starting address to linker

_start: li  a0, 55              # input
        li  a5, 10              # helpful number

        mv a2, zero             # load 0 to a2
        mv a3, a0               # load a0 to a3

loop:   beqz a3, end # if nothing is left -> exit
        remu a4, a3, a5
        add a2, a4, a2
        divu a3, a3, a5
        j loop


# Setup the parameters to exit the program
# and then call Linux to do it.
end:    addi  a0, zero, 1      # 1 = StdOut
        la    a1, buf   # load address of buf
        sb    a2, (a1)  # overwrite buf with our word
        addi  a2, zero, 1     # length of our string
        addi  a7, zero, 64     # linux write system call
        ecall                # Call linux to output the string
        addi    a0, zero, 0   # Use 0 return code
        addi    a7, zero, 93  # Service command code 93 terminates
        ecall               # Call linux to terminate the program

.data
buf:      .ascii "0"
