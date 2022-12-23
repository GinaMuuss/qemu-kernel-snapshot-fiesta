nproc=4

arm64:
	$(eval ARCH = arm64)
	$(eval CROSS_COMPILE = aarch64-linux-gnu-)

riscv64:
	$(eval ARCH = riscv)
	$(eval CROSS_COMPILE = riscv64-linux-gnu-)

%.o.riscv64: %.asm
	riscv64-linux-gnu-as $< -g -o $@

%.elf.riscv64: %.o.riscv64
	mkdir -p share
	riscv64-linux-gnu-ld -o share/$@ $<

snapshots: 
	mkdir -p snapshots

%.kernel: %
	ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) make -C linux defconfig
	ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) make -C linux -j$(nproc)


%.qcow2: snapshots %.busyboxinit
ifneq ("$(wildcard snapshots/$*.qcow2)","")
	echo "snapshot exists, so we assume everything else exists as well"
else
	qemu-img create -f qcow2 snapshots/$@ 32M
	qemu-system-$* -nographic -monitor unix:qemu-monitor-socket.$*,server,nowait -machine virt -kernel linux/arch/$(ARCH)/boot/Image -append "root=/dev/vda ro console=ttyS0" -drive file=$*.busyboxinit,format=raw,id=hd0,readonly=on -device virtio-blk-device,drive=hd0 -virtfs local,path=./share,mount_tag=sda,security_model=mapped,readonly=on -drive if=none,format=qcow2,file=snapshots/$*.qcow2 &
	sleep 10
	echo "savevm snapshot1" | socat - unix-connect:qemu-monitor-socket.$*
	echo "quit" | socat - unix-connect:qemu-monitor-socket.$*
endif

.PRECIOUS: %.busyboxinit

%.busyboxinit: % %.kernel
ifneq ("$(wildcard $@)","")
	echo "busybox initramfs exists, so we assume everything else exists as well"
else
	sudo umount rootfs.$* -f || true
	touch $@
	dd if=/dev/zero of=$@ bs=1M count=1024
	mkfs.ext4 $@
	mkdir -p rootfs.$*
	sudo mount $@ rootfs.$*
	sudo mkdir -p rootfs.$*/{bin,dev,etc,lib,mnt,proc,sbin,sys,tmp,var}
	ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) make -C busybox defconfig
	sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/g' busybox/.config
	ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) make -C busybox -j$(nproc)
	ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) make -C busybox install
	sudo cp -r busybox/_install/* rootfs.$*
	sudo mkdir rootfs.$*/etc/init.d/
	echo "mount -t proc proc /proc && mount -t sysfs sysfs /sys" | sudo tee rootfs.$*/etc/init.d/rcS
	sudo chmod +x rootfs.$*/etc/init.d/rcS
	sudo umount rootfs.$*
endif


run: example.elf.riscv64
	echo -e "\n mount -t 9p -o trans=virtio sda /mnt\n /mnt/example.elf > /mnt/output \n halt -f" | qemu-system-riscv64 -nographic -machine virt -kernel linux/arch/riscv/boot/Image -append "root=/dev/vda ro console=ttyS0" -drive file=busyboxinit,format=raw,id=hd0,readonly=on -device virtio-blk-device,drive=hd0 -virtfs local,path=./share,mount_tag=sda,security_model=mapped -drive if=none,format=qcow2,file=snapshots/riscv64.qcow2 -loadvm snapshot1

run2: example2.elf.riscv64
	echo -e "\n mount -t 9p -o trans=virtio sda /mnt\n /mnt/example2.elf > /mnt/output \n halt -f" | qemu-system-riscv64 -nographic -machine virt -kernel linux/arch/riscv/boot/Image -append "root=/dev/vda ro console=ttyS0" -drive file=busyboxinit,format=raw,id=hd0,readonly=on -device virtio-blk-device,drive=hd0 -virtfs local,path=./share,mount_tag=sda,security_model=mapped -drive if=none,format=snapshots/qcow2,file=qcow2 -loadvm snapshot1

clean:
	rm -r snapshots

cleanall: clean
	make -C linux clean
	make -C busybox clean