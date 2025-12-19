; -----------------------------------------------------------------------------
; Snake Game - Bare Metal Boot Sector (x86 Real Mode)
; Version: 1.1.0
; Author: danko1122q
; -----------------------------------------------------------------------------

[ORG 0x7C00]                    ; Standard boot sector origin address

; --- INITIAL SETUP ---
setup:
    xor ax, ax                  ; Clear AX
    mov ds, ax                  ; Data Segment = 0
    mov es, ax                  ; Extra Segment = 0
    mov ss, ax                  ; Stack Segment = 0
    mov sp, 0x7C00              ; Set Stack Pointer below the code (grows down)

    ; Hide text cursor via BIOS (INT 10h, AH=01h)
    mov ah, 0x01
    mov cx, 0x2000              ; Set bit 13 to hide cursor
    int 0x10
    
    ; Adjust Keyboard Repeat Rate for smoother control (INT 16h, AX=0305h)
    mov ax, 0x0305
    mov bx, 0x031F              ; Repeat delay: 250ms, Repeat rate: 30 chars/sec
    int 0x16

    ; Reset snake body data in external RAM (Address 0x8000)
    mov word [SNAKE_BODY_PTR], 0x0000

; --- MAIN GAME LOOP ---
game_loop:
    call clear_screen           ; Refresh visual buffer
    push word [snake_pos]       ; Save current head position for body shifting
    
    ; Check for non-blocking keyboard input (INT 16h, AH=01h)
    mov ah, 0x01
    int 0x16           
    jz no_new_input             ; If no key pressed, skip reading buffer
    
    ; Get keystroke (INT 16h, AH=00h)
    mov ah, 0x00
    int 0x16           
    jmp update_snakepos

no_new_input:
    mov al, [last_move]         ; Continue in the same direction

update_snakepos:
    cmp al, 0x1b                ; ESC Key: Reboot system
    jne check_movement
    int 0x19

check_movement:
    ; Validate direction keys (W, A, S, D)
    cmp al, 'a'
    je  left
    cmp al, 's'
    je  down
    cmp al, 'd'
    je  right
    cmp al, 'w'
    jne no_new_input            ; If invalid key, keep moving in old direction

; --- MOVEMENT LOGIC ---
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
    mov [last_move], al         ; Store direction for next frame
    mov si, SNAKE_BODY_PTR 
    pop ax                      ; AX = previous head position

; --- SNAKE BODY SHIFTING ---
update_body:
    mov  bx, [si]               ; BX = current segment position
    test bx, bx                 ; Check for end of body (null terminator)
    jz   done_update
    mov  [si], ax               ; Replace current segment with previous segment's pos
    add  si, 2                  ; Advance pointer (2 bytes per coordinate)
    mov  ax, bx                 ; Keep current pos to pass to the next segment
    jmp  update_body

done_update:
    ; Growth Logic: If food was eaten, add a new segment at the end
    cmp byte [grow_snake_flag], 1
    jne terminate_body
    mov word [si], ax           ; Place new tail at the last shifted position
    mov byte [grow_snake_flag], 0
    add si, 2

terminate_body:
    mov word [si], 0x0000       ; Add null terminator at end of array

; --- RENDERING ---
print_stuff:
    ; Draw Score Counter
    mov  dh, 0                  ; Row 0
    mov  dl, 33                 ; Column 33
    call move_cursor
    mov  si, score_msg
    call print_string
    mov  ax, [score]
    call print_int

    ; Draw Food (ASCII 05h: Club symbol)
    mov  dx, [food_pos]
    call move_cursor
    mov  al, 0x05        
    call print_char

    ; Draw Snake Head (ASCII 02h: Smiley face)
    mov  dx, [snake_pos]
    call move_cursor
    mov  al, 0x02        
    call print_char

    ; Draw Snake Body Segments ('o')
    mov  si, SNAKE_BODY_PTR
snake_body_print_loop:
    lodsw                       ; Load AX from [SI], increment SI by 2
    test ax, ax                 ; Check for end of body
    jz   check_collisions
    mov  dx, ax                 ; DX = Position for move_cursor
    call move_cursor
    mov  al, 'o'
    call print_char
    jmp  snake_body_print_loop

; --- COLLISION DETECTION ---
check_collisions:
    mov bx, [snake_pos]         ; BH = Head Y, BL = Head X

    ; Boundary Collision (80x25 terminal)
    cmp bh, 25
    jge game_over_hit_wall
    cmp bh, 0
    jl  game_over_hit_wall
    cmp bl, 80
    jge game_over_hit_wall
    cmp bl, 0
    jl  game_over_hit_wall

    ; Self-Collision: Check if Head pos matches any Body pos
    mov si, SNAKE_BODY_PTR
self_collision_loop:
    lodsw
    test ax, ax                 ; End of body reached
    jz   no_collision
    cmp  ax, bx                 ; Does Head pos == Body segment pos?
    je   game_over_hit_self
    jmp  self_collision_loop

no_collision:
    ; Food Collision check
    mov ax, [snake_pos]
    cmp ax, [food_pos]
    jne apply_delay

    ; Food Eaten: Increment score and spawn new food
    inc word [score]
    mov  bx, 24                 ; Max Y range
    call rand
    mov  cl, dl                 ; CL = Random Y
    mov  bx, 78                 ; Max X range
    call rand
    mov  dh, cl                 ; DH = Y, DL = Random X
    mov  [food_pos], dx
    mov  byte [grow_snake_flag], 1

apply_delay:
    ; Frame Rate Control (INT 15h, AH=86h: Wait)
    mov cx, 0x0002              ; High word of microseconds
    mov dx, 0x49F0              ; Low word (~150ms delay)
    mov ah, 0x86
    int 0x15
    jmp game_loop               ; Repeat next frame

; --- GAME OVER HANDLERS ---
game_over_hit_self:
    mov si, self_msg
    jmp game_over
game_over_hit_wall:
    mov si, wall_msg

game_over:
    call clear_screen
    mov  dh, 12                 ; Center Y
    mov  dl, 21                 ; Center X
    call move_cursor
    mov  si, hit_msg
    call print_string           ; Prints "YOU HIT "
    call print_string           ; Prints "YOURSELF" or "THE WALL"
    mov  si, retry_msg
    call print_string

wait_for_r:
    xor ah, ah
    int 0x16
    cmp al, 'r'                 ; Wait for 'r' key to restart
    jne wait_for_r
    
    ; Reset Game State Variables
    mov word [snake_pos], 0x0F0F
    mov word [SNAKE_BODY_PTR], 0
    mov word [score], 0
    mov byte [last_move], 'd'
    jmp game_loop

; --- UTILITY FUNCTIONS ---

clear_screen:
    mov ax, 0x0700              ; Clear full screen
    mov bh, 0x0A                ; Green text on black
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
    int 0x1A                    ; Get system timer ticks
    mov ax, dx
    xor dx, dx
    div bx                      ; AX % BX
    ret

; --- DATA SECTION ---
retry_msg       db '!! PRESS "r" TO RETRY', 0
hit_msg         db 'YOU HIT ', 0
self_msg        db 'YOURSELF', 0
wall_msg        db 'THE WALL', 0
score_msg       db 'V1.1.0 SCORE:', 0
grow_snake_flag db 0
food_pos        dw 0x0D0D
score           dw 0
last_move       db 'd'
snake_pos:
    snake_x_pos db 0x0F
    snake_y_pos db 0x0F

SNAKE_BODY_PTR  EQU 0x8000 

; --- BOOT SIGNATURE ---
times 510-($-$$) db 0
dw 0xAA55
