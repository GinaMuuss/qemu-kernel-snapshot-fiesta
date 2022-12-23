# qemu-kernel-snapshot-fiesta

This repo contains a makefile that will build you an environment for executing binaries for architecutres in qemu.
To do so it builds the linux kernel and busybox, creates an initramfs.
It then boots the kernel in qemu, after booting takes a snapshot.
You can then run your binary in the emulation, from the already booted kernel.

To build the snapshot for an architecture (for example `riscv64`) run:

```bash 
make riscv64.qcow2
```