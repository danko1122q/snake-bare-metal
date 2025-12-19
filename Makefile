ASM       = nasm
ASMFLAGS  = -f bin
TARGET    = snake
BOOT_BIN  = $(TARGET)_boot.bin
KERNEL_BIN= $(TARGET)_kernel.bin
IMG       = $(TARGET).img
ISO       = $(TARGET).iso

all: iso

# --- Target 1: Build Boot Sector ---
$(BOOT_BIN): snake.asm
	$(ASM) $(ASMFLAGS) $< -o $@
	@size=$$(stat -c%s $(BOOT_BIN) 2>/dev/null || stat -f%z $(BOOT_BIN) 2>/dev/null); \
	if [ $$size -ne 512 ]; then \
		echo "ERROR: $(BOOT_BIN) size is $$size bytes, must be exactly 512!"; \
		exit 1; \
	fi

# --- Target 2: Build Raw Kernel ---
$(KERNEL_BIN): snake.asm
	$(ASM) $(ASMFLAGS) $< -o $@
	@size=$$(stat -c%s $(KERNEL_BIN) 2>/dev/null || stat -f%z $(KERNEL_BIN) 2>/dev/null); \
	if [ $$size -ne 512 ]; then \
		echo "ERROR: $(KERNEL_BIN) size is $$size bytes, must be exactly 512!"; \
		exit 1; \
	fi

img: $(KERNEL_BIN)
	@echo "Creating raw boot image ($(IMG))..."
	cp $(KERNEL_BIN) $(IMG)

iso: $(BOOT_BIN)
	@echo "Creating ISO directory structure..."
	rm -rf iso_root
	mkdir -p iso_root/boot/isolinux
	cp $(BOOT_BIN) iso_root/boot/snake.bin
	@# Mencari lokasi isolinux.bin secara otomatis
	@for dir in /usr/lib/ISOLINUX /usr/lib/syslinux /usr/share/syslinux /usr/lib/syslinux/modules/bios; do \
		if [ -f $$dir/isolinux.bin ]; then cp $$dir/isolinux.bin iso_root/boot/isolinux/; fi; \
		if [ -f $$dir/ldlinux.c32 ]; then cp $$dir/ldlinux.c32 iso_root/boot/isolinux/; fi; \
		if [ -f $$dir/menu.c32 ]; then cp $$dir/menu.c32 iso_root/boot/isolinux/; fi; \
		if [ -f $$dir/libutil.c32 ]; then cp $$dir/libutil.c32 iso_root/boot/isolinux/; fi; \
		if [ -f $$dir/poweroff.c32 ]; then cp $$dir/poweroff.c32 iso_root/boot/isolinux/; fi; \
	done
	@echo "DEFAULT snake" > iso_root/boot/isolinux/isolinux.cfg
	@echo "LABEL snake" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "  KERNEL /boot/snake.bin" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "Building ISO image..."
	xorriso -as mkisofs \
		-o $(ISO) \
		-b boot/isolinux/isolinux.bin \
		-c boot/isolinux/boot.cat \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		-V "SNAKE_GAME" \
		iso_root
	@rm -rf iso_root

run-raw: img
	qemu-system-i386 -drive format=raw,file=$(IMG)

run: iso
	qemu-system-i386 -cdrom $(ISO)

clean:
	rm -f *.bin *.img *.iso
	rm -rf iso_root

.PHONY: all img iso run run-raw clean
