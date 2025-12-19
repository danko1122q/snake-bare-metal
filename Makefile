ASM       = nasm
ASMFLAGS  = -f bin
TARGET    = snake
BOOT_BIN  = $(TARGET)_boot.bin
ISO       = $(TARGET).iso

all: iso

# Build the 512-byte binary
$(BOOT_BIN): snake.asm
	$(ASM) $(ASMFLAGS) $< -o $@
	@size=$$(stat -c%s $(BOOT_BIN) 2>/dev/null || stat -f%z $(BOOT_BIN) 2>/dev/null); \
	if [ $$size -ne 512 ]; then \
		echo "ERROR: $(BOOT_BIN) size is $$size bytes, must be exactly 512!"; \
		exit 1; \
	fi

# Create bootable ISO using ISOLINUX
iso: $(BOOT_BIN)
	@echo "Creating ISO directory structure..."
	rm -rf iso_root
	mkdir -p iso_root/boot/isolinux
	cp $(BOOT_BIN) iso_root/boot/snake.bin
	
	@echo "Searching and copying ISOLINUX modules..."
	@# Copying necessary .c32 modules for the menu and poweroff functionality
	@for dir in /usr/lib/ISOLINUX /usr/lib/syslinux/modules/bios /usr/share/syslinux /usr/lib/syslinux; do \
		if [ -f $$dir/isolinux.bin ]; then cp $$dir/isolinux.bin iso_root/boot/isolinux/; fi; \
		if [ -f $$dir/ldlinux.c32 ]; then cp $$dir/ldlinux.c32 iso_root/boot/isolinux/; fi; \
		if [ -f $$dir/menu.c32 ]; then cp $$dir/menu.c32 iso_root/boot/isolinux/; fi; \
		if [ -f $$dir/libutil.c32 ]; then cp $$dir/libutil.c32 iso_root/boot/isolinux/; fi; \
		if [ -f $$dir/poweroff.c32 ]; then cp $$dir/poweroff.c32 iso_root/boot/isolinux/; fi; \
	done

	@echo "Generating isolinux.cfg..."
	@echo "UI menu.c32" > iso_root/boot/isolinux/isolinux.cfg
	@echo "PROMPT 0" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "TIMEOUT 100" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "MENU TITLE Snake Game Boot Menu" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "LABEL snake" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "    MENU LABEL Snake Game - Play Now!" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "    KERNEL /boot/snake.bin" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "LABEL poweroff" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "    MENU LABEL Power Off" >> iso_root/boot/isolinux/isolinux.cfg
	@echo "    COM32 poweroff.c32" >> iso_root/boot/isolinux/isolinux.cfg

	@echo "Building ISO image with xorriso..."
	xorriso -as mkisofs \
		-o $(ISO) \
		-b boot/isolinux/isolinux.bin \
		-c boot/isolinux/boot.cat \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		-V "SNAKE_ISO" \
		iso_root
	@rm -rf iso_root

# Run in QEMU. Added -no-reboot to ensure QEMU closes on poweroff.
run: iso
	qemu-system-i386 -cdrom $(ISO) -no-reboot

clean:
	rm -f *.bin *.iso
	rm -rf iso_root

.PHONY: all iso run clean
