; ------------------------------------------------------------
    ; Snake Game Boot Sector - FIXED VERSION
    ; ------------------------------------------------------------
    [ORG 0x7C00]

    ; INITIAL SETUP
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov ah, 0x01
    mov cx, 0x2000      ; Sembunyikan kursor
    int 0x10
    
    mov ax, 0x0305
    mov bx, 0x031F      ; Keyboard repeat rate
    int 0x16

    mov word [SNAKE_BODY_PTR], 0x0000

game_loop:
    call clear_screen
    push word [snake_pos]
    
    mov  ah, 0x01
    int  0x16           ; Cek input keyboard
    jz   done_clear
    mov  ah, 0x00
    int  0x16           ; Ambil tombol
    jmp  update_snakepos

done_clear:
    mov al, [last_move]

update_snakepos:
    cmp al, 0x1b        ; ESC untuk reboot
    jne no_exit
    int 0x19

no_exit:
    cmp al, 'a'
    je  left
    cmp al, 's'
    je  down
    cmp al, 'd'
    je  right
    cmp al, 'w'
    jne done_clear

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
    mov [last_move], al
    mov si, SNAKE_BODY_PTR 
    pop ax                 ; Koordinat kepala lama untuk update body

update_body:
    mov  bx, [si]
    test bx, bx
    jz   done_update
    mov  [si], ax
    add  si, 2
    mov  ax, bx
    jmp  update_body

done_update:
    cmp byte [grow_snake_flag], 1
    jne add_zero_snake
    mov word [si], ax
    mov byte [grow_snake_flag], 0
    add si, 2

add_zero_snake:
    mov word [si], 0x0000

print_stuff:
    mov  dh, 0
    mov  dl, 33
    call move_cursor
    mov  si, score_msg
    call print_string
    mov  ax, [score]
    call print_int

    ; Render Food
    mov  dx, [food_pos]
    call move_cursor
    mov  al, 0x05        
    call print_char

    ; Render Snake Head
    mov  dx, [snake_pos]
    call move_cursor
    mov  al, 0x02        
    call print_char

    ; Render Snake Body
    mov  si, SNAKE_BODY_PTR
snake_body_print_loop:
    lodsw
    test ax, ax
    jz   check_collisions
    mov  dx, ax
    call move_cursor
    mov  al, 'o'
    call print_char
    jmp  snake_body_print_loop

check_collisions:
    mov bx, [snake_pos]
    ; Wall Collisions
    cmp bh, 25
    jge game_over_hit_wall
    cmp bh, 0
    jl  game_over_hit_wall
    cmp bl, 80
    jge game_over_hit_wall
    cmp bl, 0
    jl  game_over_hit_wall

    ; Self Collision
    mov si, SNAKE_BODY_PTR
check_collisions_self:
    lodsw
    test ax, ax
    jz   no_collision
    cmp  ax, bx
    je   game_over_hit_self
    jmp  check_collisions_self

no_collision:
    mov ax, [snake_pos]
    cmp ax, [food_pos]
    jne game_loop_continued

    inc word [score]
    mov  bx, 24
    call rand
    mov  cl, dl
    mov  bx, 78
    call rand
    mov  dh, cl
    mov  [food_pos], dx
    mov  byte [grow_snake_flag], 1

game_loop_continued:
    mov cx, 0x0002
    mov dx, 0x49F0
    mov ah, 0x86
    int 0x15
    jmp game_loop

game_over_hit_self:
    mov si, self_msg
    jmp game_over
game_over_hit_wall:
    mov si, wall_msg

game_over:
    call clear_screen
    mov  dh, 12
    mov  dl, 21
    call move_cursor
    mov  si, hit_msg
    call print_string
    ; (si saat ini berisi self_msg atau wall_msg)
    call print_string
    mov  si, retry_msg
    call print_string

wait_for_r:
    xor ah, ah
    int 0x16
    cmp al, 'r'
    jne wait_for_r
    ; Reset State
    mov word [snake_pos], 0x0F0F
    mov word [SNAKE_BODY_PTR], 0
    mov word [score], 0
    mov byte [last_move], 'd'
    jmp game_loop

clear_screen:
    mov ax, 0x0700
    mov bh, 0x0A
    xor cx, cx
    mov dx, 0x194F
    int 0x10
    ret

move_cursor:
    mov ah, 0x02
    xor bh, bh
    int 0x10
    ret

print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done: ret

print_char:
    mov ah, 0x0E
    int 0x10
    ret

print_int:
    mov bx, 10
    xor cx, cx
.push_digits:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .push_digits
.pop_digits:
    pop ax
    add al, '0'
    call print_char
    loop .pop_digits
    ret

rand:
    xor ah, ah
    int 0x1A
    mov ax, dx
    xor dx, dx
    div bx
    ret

; --- DATA ---
retry_msg db '!! PRESS "r" TO RETRY', 0
hit_msg   db 'YOU HIT ', 0
self_msg  db 'YOURSELF', 0
wall_msg  db 'THE WALL', 0
score_msg db 'V1.1.0 SCORE:', 0
grow_snake_flag db 0
food_pos dw 0x0D0D
score dw 0
last_move db 'd'
snake_pos:
    snake_x_pos db 0x0F
    snake_y_pos db 0x0F

SNAKE_BODY_PTR EQU 0x8000 

times 510-($-$$) db 0
dw 0xAA55
