nproc=4

%.aarch64: aarch64
	echo $@

aarch64:
	$(eval ARCH=arm64)
	$(eval QEMU_SUFFIX=aarch64)
	$(eval CROSS_COMPILE = aarch64-linux-gnu-)
	$(eval ADDITIONAL_QEMU_ARGS=-cpu cortex-a53 -smp 2 -m 2048 -bios /usr/share/edk2/aarch64/QEMU_EFI.fd)

%.riscv64: riscv64
	echo $@

riscv64:
	$(eval ARCH=riscv)
	$(eval QEMU_SUFFIX=riscv64)
	$(eval CROSS_COMPILE = riscv64-linux-gnu-)
	$(eval ADDITIONAL_QEMU_ARGS=)

%.aarch64.o: %.aarch64.asm
	aarch64-linux-gnu-as $< -g -o $@

%.aarch64.elf: %.aarch64.o
	mkdir -p share
	aarch64-linux-gnu-ld -o share/$@ $<


%.riscv64.o: %.riscv64.asm
	riscv64-linux-gnu-as $< -g -o $@

%.riscv64.elf: %.riscv64.o
	mkdir -p share
	riscv64-linux-gnu-ld -o share/$@ $<

snapshots: 
	mkdir -p snapshots

%.kernel: %
	ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) make -C linux defconfig
	ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) make -C linux -j$(nproc)


%.qcow2: snapshots %.busyboxinit
	qemu-img create -f qcow2 snapshots/$@ 32M
	qemu-system-$(QEMU_SUFFIX) -nographic -monitor unix:qemu-monitor-socket.$*,server,nowait -machine virt -kernel linux/arch/$(ARCH)/boot/Image -append "root=/dev/vda ro console=ttyS0" -drive file=$*.busyboxinit,format=raw,id=hd0,readonly=on,if=none -device virtio-blk-device,drive=hd0 -virtfs local,path=./share,mount_tag=sda,security_model=mapped,readonly=on -drive if=none,format=qcow2,file=snapshots/$@ $(ADDITIONAL_QEMU_ARGS) &
	sleep 60
	echo "savevm snapshot1" | socat - unix-connect:qemu-monitor-socket.$*
	echo "quit" | socat - unix-connect:qemu-monitor-socket.$*

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


%.run: % %.elf
	echo $(ADDITIONAL_QEMU_ARGS)
	echo -e "\n mount -t 9p -o trans=virtio sda /mnt\n /mnt/$*.elf > /mnt/output \n halt -f" | qemu-system-$(QEMU_SUFFIX) -nographic -monitor unix:qemu-monitor-socket.$(ARCH),server,nowait -machine virt -kernel linux/arch/$(ARCH)/boot/Image -append "root=/dev/vda ro console=ttyS0" -drive file=$(QEMU_SUFFIX).busyboxinit,format=raw,id=hd0,readonly=on,if=none -device virtio-blk-device,drive=hd0 -virtfs local,path=./share,mount_tag=sda,security_model=mapped -drive if=none,format=qcow2,file=snapshots/$(QEMU_SUFFIX).qcow2 $(ADDITIONAL_QEMU_ARGS) -loadvm snapshot1

clean:
	rm -r snapshots

cleanall: clean
	make -C linux clean
	make -C busybox clean