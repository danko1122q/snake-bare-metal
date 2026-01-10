; -----------------------------------------------------------------------------
; Project: Snake Game - Bare Metal Boot Sector (x86 Real Mode)
; Version: 1.1.1
; Architecture: x86 (16-bit Real Mode)
; Environment: No OS (Direct BIOS Hardware Abstraction)
; -----------------------------------------------------------------------------

[ORG 0x7C00]             ; Bootloader entry point assigned by BIOS POST

; --- SYSTEM INITIALIZATION ---
; Prioritas utama: Menjamin kondisi register segmen dalam keadaan konsisten.
setup:
    xor ax, ax           ; Mengosongkan AX untuk inisialisasi segmentasi
    mov ds, ax           ; DS = 0000h (Data Segment)
    mov es, ax           ; ES = 0000h (Extra Segment)
    mov ss, ax           ; SS = 0000h (Stack Segment)
    mov sp, 0x7C00       ; Inisialisasi Stack Pointer (Tumbuh ke bawah dari 0x7C00)

    ; Konfigurasi Parameter Video (INT 10h)
    ; AH=01h: Set Cursor Type. CX=2000h mematikan kursor melalui bit ke-5 (bit visibilitas).
    mov ah, 0x01
    mov cx, 0x2000       
    int 0x10
    
    ; Konfigurasi I/O Keyboard (INT 16h)
    ; AH=03h, AL=05h: Set Repeat Rate. 
    ; BL=03h (Delay 250ms), BH=1Fh (30 chars/sec) untuk input yang responsif.
    mov ax, 0x0305
    mov bx, 0x031F       
    int 0x16

    ; Inisialisasi Struktur Data Body Snake
    ; Dialokasikan di memori eksternal 0x8000 untuk menghindari overflow sektor boot.
    mov word [SNAKE_BODY_PTR], 0x0000

; --- CORE EXECUTION LOOP ---
game_loop:
    call clear_screen    ; Prosedur pembersihan buffer video
    push word [snake_pos]; Shadowing head position untuk update segmentasi body
    
    ; Polling Keyboard (Non-blocking)
    ; INT 16h, AH=01h: Memeriksa keystroke di buffer tanpa menghentikan eksekusi.
    mov ah, 0x01
    int 0x16            
    jz no_new_input      ; Branch jika Zero Flag (ZF) set (tidak ada input baru)
    
    ; Pengambilan Input (Blocking Fetch)
    ; INT 16h, AH=00h: Mengambil ASCII (AL) dan Scan Code (AH) dari buffer.
    mov ah, 0x00
    int 0x16            
    jmp update_snakepos

no_new_input:
    mov al, [last_move]  ; Persistensi arah pergerakan (Inertia)

update_snakepos:
    cmp al, 0x1b         ; Evaluasi ESC key untuk Warm Reboot
    jne check_movement
    int 0x19             ; INT 19h: Bootstrap Loader (Reboot tanpa POST)

check_movement:
    ; Filter input untuk kendali WASD
    cmp al, 'a'
    je  left
    cmp al, 's'
    je  down
    cmp al, 'd'
    je  right
    cmp al, 'w'
    jne no_new_input     ; Abaikan input di luar skema kendali

; --- KINEMATICS & VECTOR LOGIC ---
; Pembaruan koordinat berdasarkan sistem kartesian layar (80x25)
up:
    dec byte [snake_y_pos]
    jmp move_done
left:
    dec byte [snake_x_pos]
    jmp move_done
right:
    inc byte [snake_x_pos]
    jmp move_done
down:
    inc byte [snake_y_pos]

move_done:
    mov [last_move], al  ; Cache arah terakhir yang valid
    mov si, SNAKE_BODY_PTR 
    pop ax               ; Retrieve posisi head lama dari stack

; --- DATA STRUCTURE MANAGEMENT (LINKED LIST SIMULATION) ---
; Menggeser posisi setiap segmen tubuh ke posisi segmen di depannya.
update_body:
    mov  bx, [si]        ; Load koordinat segmen saat ini
    test bx, bx          ; Sentinel check (Null terminator 0x0000)
    jz   done_update
    mov  [si], ax        ; Update koordinat segmen dengan posisi sebelumnya
    add  si, 2           ; Move pointer ke elemen berikutnya (Word alignment)
    mov  ax, bx          ; Oper koordinat lama untuk segmen selanjutnya
    jmp  update_body

done_update:
    ; Logika Ekspansi (Growth)
    ; Jika flag aktif, koordinat terakhir tidak dihapus, melainkan dijadikan segmen baru.
    cmp byte [grow_snake_flag], 1
    jne terminate_body
    mov word [si], ax    
    mov byte [grow_snake_flag], 0
    add si, 2

terminate_body:
    mov word [si], 0x0000 ; Menjamin integritas array dengan Null Terminator

; --- RENDERING ENGINE ---
print_stuff:
    ; Render Metadata: UI Score
    mov  dh, 0           ; Row
    mov  dl, 33          ; Column (Center-ish)
    call move_cursor
    mov  si, score_msg
    call print_string
    mov  ax, [score]
    call print_int

    ; Render Entity: Food
    mov  dx, [food_pos]
    call move_cursor
    mov  al, '*'         
    call print_char

    ; Render Entity: Snake Head
    mov  dx, [snake_pos]
    call move_cursor
    mov  al, 0x40        ; Simbol '@' sebagai indikator kepala
    call print_char

    ; Render Entity: Snake Body (Iterative Processing)
    mov  si, SNAKE_BODY_PTR
snake_body_print_loop:
    lodsw                ; Atomic Load: AX = [SI], SI += 2
    test ax, ax          ; Cek akhir array tubuh
    jz   check_collisions
    mov  dx, ax          ; Siapkan posisi untuk BIOS cursor set
    call move_cursor
    mov  al, 'o'
    call print_char
    jmp  snake_body_print_loop

; --- COLLISION & PHYSICS ENGINE ---
check_collisions:
    mov bx, [snake_pos]  ; Register caching untuk optimasi perbandingan

    ; Boundary Check: Validasi koordinat terhadap resolusi TTY (80x25)
    cmp bh, 25
    jge game_over_hit_wall
    cmp bh, 0
    jl  game_over_hit_wall
    cmp bl, 80
    jge game_over_hit_wall
    cmp bl, 0
    jl  game_over_hit_wall

    ; Self-Collision Check: Linear search pada array koordinat tubuh
    mov si, SNAKE_BODY_PTR
self_collision_loop:
    lodsw
    test ax, ax          
    jz   no_collision
    cmp  ax, bx          ; Head-to-Body intersection check
    je   game_over_hit_self
    jmp  self_collision_loop

no_collision:
    ; Food Intersection Check
    mov ax, [snake_pos]
    cmp ax, [food_pos]
    jne apply_delay

    ; Event: Food Consumed
    inc word [score]
    mov  bx, 24          ; Boundary Y
    call rand
    mov  cl, dl          
    mov  bx, 78          ; Boundary X
    call rand
    mov  dh, cl          ; Konstruksi koordinat DX (DH:Y, DL:X)
    mov  [food_pos], dx
    mov  byte [grow_snake_flag], 1

apply_delay:
    ; Frame Rate Limiter (Timing Control)
    ; INT 15h, AH=86h: Menggunakan BIOS wait (CX:DX dalam mikrosekon)
    mov cx, 0x0002       
    mov dx, 0x49F0       ; Durasi delay ~150ms
    mov ah, 0x86
    int 0x15
    jmp game_loop        

; --- EXCEPTION HANDLERS (GAME OVER) ---
game_over_hit_self:
    mov si, self_msg
    jmp game_over
game_over_hit_wall:
    mov si, wall_msg

game_over:
    call clear_screen
    mov  dh, 12          ; Kalkulasi tengah layar Y
    mov  dl, 21          ; Kalkulasi tengah layar X
    call move_cursor
    mov  si, hit_msg
    call print_string    
    call print_string    ; Print penyebab kekalahan (Wall/Self)
    mov  si, retry_msg
    call print_string

wait_for_r:
    xor ah, ah           ; Blocking read untuk restart
    int 0x16
    cmp al, 'r'          
    jne wait_for_r
    
    ; Reset State: Mengembalikan variabel ke kondisi awal (Cold Start)
    mov word [snake_pos], 0x0F0F
    mov word [SNAKE_BODY_PTR], 0
    mov word [score], 0
    mov byte [last_move], 'd'
    jmp game_loop

; --- SYSTEM UTILITIES (BIOS WRAPPERS) ---

clear_screen:
    ; Memanfaatkan fungsi scroll window untuk membersihkan layar
    mov ax, 0x0700       ; AH=07 (Scroll down), AL=00 (Clear all)
    mov bh, 0x0A         ; Attribute: Green on Black
    xor cx, cx           ; Upper left (0,0)
    mov dx, 0x194F       ; Lower right (25,80)
    int 0x10
    ret

move_cursor:
    mov ah, 0x02         ; Set Cursor Position
    xor bh, bh           ; Page number 0
    int 0x10
    ret

print_string:
    lodsb                ; Load string byte ke AL
    test al, al          ; Cek NULL terminator
    jz .done
    mov ah, 0x0E         ; Teletype output
    int 0x10
    jmp print_string
.done: ret

print_char:
    mov ah, 0x0E         ; BIOS Teletype
    int 0x10
    ret

print_int:
    ; Algoritma konversi Integer ke ASCII melalui metode rekursif/stack
    mov bx, 10
    xor cx, cx
.push_digits:
    xor dx, dx
    div bx               ; AX / 10, sisa di DX
    push dx
    inc cx
    test ax, ax
    jnz .push_digits
.pop_digits:
    pop ax
    add al, '0'          ; Konversi digit ke karakter ASCII
    call print_char
    loop .pop_digits
    ret

rand:
    ; PRNG sederhana menggunakan BIOS System Timer Ticks
    xor ah, ah
    int 0x1A             ; CX:DX = ticks sejak tengah malam
    mov ax, dx           ; Ambil low word ticks
    xor dx, dx
    div bx               ; Modulo terhadap limit di BX
    ret

; --- DATA SEGMENT (STORAGE) ---
retry_msg       db '!! PRESS "r" TO RETRY', 0
hit_msg         db 'YOU HIT ', 0
self_msg        db 'YOURSELF', 0
wall_msg        db 'THE WALL', 0
score_msg       db 'V1.1.1 SCORE:', 0
grow_snake_flag db 0
food_pos        dw 0x0D0D
score           dw 0
last_move       db 'd'
snake_pos:
    snake_x_pos db 0x0F
    snake_y_pos db 0x0F

; Alokasi RAM Dinamis di luar segmen kode
SNAKE_BODY_PTR  EQU 0x8000 

; --- BOOT LOADER TERMINATION ---
times 510-($-$$) db 0    ; Padding hingga 510 bytes
dw 0xAA55                ; BIOS Boot Signature (Magic Number)
