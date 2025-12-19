# Snake Game with GRUB Boot Menu

This project contains a Snake game that runs directly on bare metal (without OS) with a GRUB boot menu.

---
![Demo1](docs/demo.png)
---

---
![Demo2](docs/demo1.png)
---
## File Structure

```
.
├── snake.asm       # Snake game source code (512 bytes)
├── grub.cfg        # GRUB boot menu configuration
├── Makefile        # Build script
└── README.md       # This file
```

## Prerequisites

Install the following tools:

### Ubuntu/Debian:
```bash
sudo apt-get install nasm qemu-system-x86 grub-pc-bin xorriso
```

### Arch Linux:
```bash
sudo pacman -S nasm qemu grub xorriso
```

### macOS (with Homebrew):
```bash
brew install nasm qemu grub xorriso
```

## Build Instructions

### 1. Build Snake Binary (512 bytes)
```bash
make snake.bin
```

### 2. Build RAW Image (for direct boot)
```bash
make img
```

### 3. Build ISO with GRUB Menu
```bash
make iso
```

or directly:
```bash
make
```

## Running the Game

### Run from ISO (with GRUB menu):
```bash
make run
```

### Run from RAW image (without menu):
```bash
make run-raw
```

## GRUB Boot Menu

When running the ISO, you will see the GRUB menu:

```
┌────────────────────────────────────┐
│ Snake Game - Play Now!             │
│ Shutdown                           │
└────────────────────────────────────┘
```

Select "Snake Game - Play Now!" to play.

## Game Controls

- **W A S D** - Move the snake
- **R** - Restart after game over
- **ESC** - Exit the program

## Important Notes

1. **snake.asm IS NOT MODIFIED** - Original file remains 512 bytes
2. **GRUB is only a bootloader** - GRUB menu will chainload snake.bin
3. **ISO contains**:
   - GRUB bootloader (~2MB)
   - snake.bin (512 bytes)
   - grub.cfg (menu configuration)

## Testing on Real Hardware

To burn to USB and boot on physical computer:

```bash
# Linux
sudo dd if=snake.iso of=/dev/sdX bs=4M status=progress

# macOS
sudo dd if=snake.iso of=/dev/diskX bs=4m
```

⚠️ **WARNING**: Make sure `/dev/sdX` or `/dev/diskX` is the correct USB drive!

## Troubleshooting

### Error: grub-mkrescue not found
Install `grub-pc-bin` (Ubuntu) or `grub` (Arch/macOS)

### Error: Binary size is not 512 bytes
Check snake.asm, ensure no modifications that change the binary size.

### QEMU cannot boot ISO
Try adding the `-boot d` flag:
```bash
qemu-system-i386 -boot d -cdrom snake.iso
```

## Clean Build

```bash
make clean
```

This will remove all build artifacts (*.bin, *.img, *.iso, iso/ folder)

## License

MIT License

---
