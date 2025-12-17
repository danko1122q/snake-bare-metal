# Snake Game dengan GRUB Boot Menu

Proyek ini berisi game Snake yang berjalan langsung di bare metal (tanpa OS) dengan boot menu GRUB.

## Struktur File

```
.
├── snake.asm       # Source code game Snake (512 byte)
├── grub.cfg        # Konfigurasi GRUB boot menu
├── Makefile        # Build script
└── README.md       # File ini
```

## Prasyarat

Install tools berikut:

### Ubuntu/Debian:
```bash
sudo apt-get install nasm qemu-system-x86 grub-pc-bin xorriso
```

### Arch Linux:
```bash
sudo pacman -S nasm qemu grub xorriso
```

### macOS (dengan Homebrew):
```bash
brew install nasm qemu grub xorriso
```

## Cara Build

### 1. Build Binary Snake (512 byte)
```bash
make snake.bin
```

### 2. Build RAW Image (untuk boot langsung)
```bash
make img
```

### 3. Build ISO dengan GRUB Menu
```bash
make iso
```
atau langsung:
```bash
make
```

## Cara Menjalankan

### Jalankan dari ISO (dengan GRUB menu):
```bash
make run
```

### Jalankan dari RAW image (tanpa menu):
```bash
make run-raw
```

## Boot Menu GRUB

Saat menjalankan ISO, Anda akan melihat menu GRUB:

```
┌────────────────────────────────────┐
│ Snake Game - Play Now!             │
│ Shutdown                           │
└────────────────────────────────────┘
```

Pilih "Snake Game - Play Now!" untuk bermain.

## Kontrol Game

- **W A S D** - Gerakkan ular
- **R** - Restart setelah game over
- **ESC** - Keluar dari program

## Catatan Penting

1. **snake.asm TIDAK DIUBAH** - File asli tetap 512 byte
2. **GRUB hanya sebagai bootloader** - Menu GRUB akan mem-chainload snake.bin
3. **ISO berisi**:
   - GRUB bootloader (~2MB)
   - snake.bin (512 byte)
   - grub.cfg (konfigurasi menu)

## Testing di Hardware Real

Untuk burn ke USB dan boot di komputer fisik:

```bash
# Linux
sudo dd if=snake.iso of=/dev/sdX bs=4M status=progress

# macOS
sudo dd if=snake.iso of=/dev/diskX bs=4m
```

⚠️ **HATI-HATI**: Pastikan `/dev/sdX` atau `/dev/diskX` adalah USB drive yang benar!

## Troubleshooting

### Error: grub-mkrescue not found
Install `grub-pc-bin` (Ubuntu) atau `grub` (Arch/macOS)

### Error: Binary size is not 512 bytes
Cek snake.asm, pastikan tidak ada modifikasi yang mengubah ukuran binary.

### QEMU tidak bisa boot ISO
Coba tambahkan flag `-boot d`:
```bash
qemu-system-i386 -boot d -cdrom snake.iso
```

## Clean Build

```bash
make clean
```

Akan menghapus semua file hasil build (*.bin, *.img, *.iso, folder iso/)

## Lisensi

MIT License
