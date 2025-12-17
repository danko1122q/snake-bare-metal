ASM       = nasm
ASMFLAGS  = -f bin
TARGET    = snake
BOOT_BIN  = $(TARGET)_boot.bin
KERNEL_BIN= $(TARGET)_kernel.bin
IMG       = $(TARGET).img
ISO       = $(TARGET).iso

all: iso

# --- Target 1: Membuat Boot Sector untuk ISOLINUX (512 bytes) ---
$(BOOT_BIN): snake.asm
	$(ASM) $(ASMFLAGS) $< -o $@
	@size=$$(stat -f%z $(BOOT_BIN) 2>/dev/null || stat -c%s $(BOOT_BIN) 2>/dev/null); \
	if [ $$size -ne 512 ]; then \
		echo "ERROR: $(BOOT_BIN) size is $$size bytes, must be exactly 512!"; \
		exit 1; \
	fi

# --- Target 2: Membuat Kernel/Boot Sector Mentah (512 bytes) ---
$(KERNEL_BIN): snake.asm
	$(ASM) $(ASMFLAGS) $< -o $@
	@size=$$(stat -f%z $(KERNEL_BIN) 2>/dev/null || stat -c%s $(KERNEL_BIN) 2>/dev/null); \
	if [ $$size -ne 512 ]; then \
		echo "ERROR: $(KERNEL_BIN) size is $$size bytes, must be exactly 512!"; \
		exit 1; \
	fi

# RAW image = EXACTLY 512 bytes
img: $(KERNEL_BIN)
	@echo "Creating raw boot image ($(IMG)) from $(KERNEL_BIN)..."
	@cp $(KERNEL_BIN) $(IMG)
	@size=$$(stat -f%z $(IMG) 2>/dev/null || stat -c%s $(IMG) 2>/dev/null); \
	echo "Image created successfully: $(IMG). Size: $$size bytes."

# Create ISO with ISOLINUX bootloader
iso: $(BOOT_BIN)
	@echo "Creating ISO with ISOLINUX menu..."
	@rm -rf iso
	@mkdir -p iso/boot/isolinux
	@cp $(BOOT_BIN) iso/boot/snake.bin
	@echo "Checking for isolinux.bin..."
	@if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then \
		cp /usr/lib/ISOLINUX/isolinux.bin iso/boot/isolinux/; \
	elif [ -f /usr/lib/syslinux/isolinux.bin ]; then \
		cp /usr/lib/syslinux/isolinux.bin iso/boot/isolinux/; \
	elif [ -f /usr/share/syslinux/isolinux.bin ]; then \
		cp /usr/share/syslinux/isolinux.bin iso/boot/isolinux/; \
	else \
		echo "ERROR: isolinux.bin not found!"; \
		echo "Install with: sudo apt-get install isolinux"; \
		exit 1; \
	fi
	@if [ -f /usr/lib/syslinux/modules/bios/ldlinux.c32 ]; then \
		cp /usr/lib/syslinux/modules/bios/ldlinux.c32 iso/boot/isolinux/; \
	elif [ -f /usr/lib/ISOLINUX/ldlinux.c32 ]; then \
		cp /usr/lib/ISOLINUX/ldlinux.c32 iso/boot/isolinux/; \
	elif [ -f /usr/share/syslinux/ldlinux.c32 ]; then \
		cp /usr/share/syslinux/ldlinux.c32 iso/boot/isolinux/; \
	fi
	@echo "Creating isolinux.cfg..."
	@echo "DEFAULT menu.c32" > iso/boot/isolinux/isolinux.cfg
	@echo "TIMEOUT 1000" >> iso/boot/isolinux/isolinux.cfg
	@echo "PROMPT 0" >> iso/boot/isolinux/isolinux.cfg
	@echo "" >> iso/boot/isolinux/isolinux.cfg
	@echo "MENU TITLE Snake Game Boot Menu by danko1122" >> iso/boot/isolinux/isolinux.cfg
	@echo "" >> iso/boot/isolinux/isolinux.cfg
	@echo "LABEL snake" >> iso/boot/isolinux/isolinux.cfg
	@echo "    MENU LABEL Snake Game - Play Now!" >> iso/boot/isolinux/isolinux.cfg
	@echo "    MENU DEFAULT" >> iso/boot/isolinux/isolinux.cfg
	@echo "    KERNEL /boot/snake.bin" >> iso/boot/isolinux/isolinux.cfg
	@echo "" >> iso/boot/isolinux/isolinux.cfg
	@echo "LABEL poweroff" >> iso/boot/isolinux/isolinux.cfg
	@echo "    MENU LABEL Power Off" >> iso/boot/isolinux/isolinux.cfg
	@echo "    COM32 poweroff.c32" >> iso/boot/isolinux/isolinux.cfg
	@echo "Copying modules..."
	@for module in menu.c32 poweroff.c32 libutil.c32; do \
		if [ -f /usr/lib/syslinux/modules/bios/$$module ]; then \
			cp /usr/lib/syslinux/modules/bios/$$module iso/boot/isolinux/ 2>/dev/null || true; \
		elif [ -f /usr/lib/ISOLINUX/$$module ]; then \
			cp /usr/lib/ISOLINUX/$$module iso/boot/isolinux/ 2>/dev/null || true; \
		elif [ -f /usr/share/syslinux/$$module ]; then \
			cp /usr/share/syslinux/$$module iso/boot/isolinux/ 2>/dev/null || true; \
		fi; \
	done
	@echo "Building ISO image..."
	@xorriso -as mkisofs \
		-o $(ISO) \
		-b boot/isolinux/isolinux.bin \
		-c boot/isolinux/boot.cat \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		-V "SNAKE_GAME" \
		iso > /dev/null 2>&1
	@if [ -f $(ISO) ]; then \
		echo "ISO created successfully: $(ISO)"; \
		ls -lh $(ISO) | awk '{print "Size:", $$5}'; \
	else \
		echo "Failed to create ISO"; \
		exit 1; \
	fi

run-raw: img
	qemu-system-i386 -drive format=raw,file=$(IMG)

run: iso
	@if [ -f $(ISO) ]; then \
		qemu-system-i386 -cdrom $(ISO); \
	else \
		echo "ERROR: $(ISO) not found. Run 'make iso' first."; \
		exit 1; \
	fi

clean:
	rm -f $(BOOT_BIN) $(KERNEL_BIN) *.img *.iso *.bin
	rm -rf iso

.PHONY: all img iso run run-raw clean
