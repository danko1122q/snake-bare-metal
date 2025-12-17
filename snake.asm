; ============================================================
; Snake Game Boot Sector
; ------------------------------------------------------------
; A tiny snake game that runs directly on BIOS (real mode).
; No OS, no kernel, no filesystem.
;
; Loaded by BIOS at physical address 0x7C00.
; Keyboard input via INT 16h, video via INT 10h.
;
; Controls:
;   W A S D  - Move snake
;   R        - Restart after game over
;
; License: MIT
; ============================================================

	mov	ax, 0x07C0
	mov	ds, ax              ; DS points to boot sector location

	mov	ah, 0x01
	mov	cx, 0x2000
	int 	0x10              ; disable blinking cursor

	mov	ax, 0x0305
	mov	bx, 0x031F
	int	0x16              ; slow down keyboard repeat rate

; =========================
; MAIN GAME LOOP
; =========================
game_loop:
	call	clear_screen       ; wipe screen each frame

	push	word [snake_pos]   ; save current head position

	mov	ah, 0x01
	int	0x16              ; check if key is available
	jz	done_clear         ; no key -> reuse last direction

	mov	ah, 0x00
	int	0x16              ; read key from buffer
	jmp	update_snakepos

done_clear:
	mov	al, [last_move]    ; fallback to previous move

update_snakepos:
	cmp	al, 0x1b           ; ESC pressed?
	jne	no_exit
	int	0x20              ; terminate program

no_exit:
	cmp	al, 'a'
	je	left
	cmp	al, 's'
	je	down
	cmp	al, 'd'
	je	right
	cmp	al, 'w'
	jne	done_clear

up:
	dec	byte [snake_y_pos]
	jmp	move_done

left:
	dec	byte [snake_x_pos]
	jmp	move_done

right:
	inc	byte [snake_x_pos]
	jmp	move_done

down:
	inc	word [snake_y_pos]

move_done:
	mov	[last_move], al    ; remember direction

	mov	si, snake_body_pos
	pop	ax                 ; previous head position

update_body:
	mov	bx, [si]
	test	bx, bx
	jz	done_update        ; end of body reached
	mov	[si], ax
	add	si, 2
	mov	ax, bx
	jmp	update_body

done_update:
	cmp	byte [grow_snake_flag], 1
	jne	add_zero_snake

	mov	word [si], ax      ; extend snake
	mov	byte [grow_snake_flag], 0
	add	si, 2

add_zero_snake:
	mov	word [si], 0x0000

; =========================
; DRAW EVERYTHING
; =========================
print_stuff:
	; --- START MODIFICATION for CENTER TOP ---
	mov	dh, 0x00       ; DH = Baris 0 (Paling atas)
	mov	dl, 0x20       ; DL = Kolom 35 (0x23 dalam Hex) -> Tengah
	mov	dx, dx         ; Gabungkan DH dan DL ke DX
	call	move_cursor    ; Pindahkan kursor ke (Baris 0, Kolom 35)
	; --- END MODIFICATION ---

	mov	si, score_msg
	call	print_string

	mov	ax, [score]
	call	print_int

	mov	dx, [food_pos]
	call	move_cursor
	mov	al, 'O'
	call	print_char

	mov	dx, [snake_pos]
	call	move_cursor
	mov	al, '@'
	call	print_char

	mov	si, snake_body_pos

snake_body_print_loop:
	lodsw
	test	ax, ax
	jz	check_collisions

	mov	dx, ax
	call	move_cursor
	mov	al, 'o'
	call	print_char
	jmp	snake_body_print_loop

; =========================
; COLLISION CHECKS
; =========================

check_collisions:
	mov	bx, [snake_pos]

	cmp	bh, 25
	jge	game_over_hit_wall
	cmp	bh, 0
	jl	game_over_hit_wall
	cmp	bl, 80
	jge	game_over_hit_wall
	cmp	bl, 0
	jl	game_over_hit_wall

	mov	si, snake_body_pos

check_collisions_self:
	lodsw
	cmp	ax, bx
	je	game_over_hit_self
	or	ax, ax
	jne	check_collisions_self

; =========================
; FOOD HANDLING
; =========================
no_collision:
	mov	ax, [snake_pos]
	cmp	ax, [food_pos]
	jne	game_loop_continued

	inc	word [score]

	mov	bx, 24
	call	rand
	push	dx

	mov	bx, 78
	call	rand
	pop	cx

	mov	dh, cl
	mov	[food_pos], dx
	mov	byte [grow_snake_flag], 1

game_loop_continued:
	mov	cx, 0x0002
	mov	dx, 0x49F0
	mov	ah, 0x86
	int	0x15              ; delay
	jmp	game_loop

; =========================
; GAME OVER
; =========================
game_over_hit_self:
	push	self_msg
	jmp	game_over

game_over_hit_wall:
	push	wall_msg

game_over:
	call	clear_screen
	mov	si, hit_msg
	call	print_string
	pop	si
	call	print_string
	mov	si, retry_msg
	call	print_string

wait_for_r:
	mov	ah, 0x00
	int	0x16
	cmp	al, 'r'
	jne	wait_for_r

	mov	word [snake_pos], 0x0F0F
	and	word [snake_body_pos], 0
	and	word [score], 0
	mov	byte [last_move], 'd'
	jmp	game_loop

; =========================
; VIDEO ROUTINES
; =========================
clear_screen:
	mov	ax, 0x0700
	mov	bh, 0x0A           ; light red on black
	xor	cx, cx
	mov	dx, 0x1950
	int	0x10
	xor	dx, dx
	call	move_cursor
	ret

move_cursor:
	mov	ah, 0x02
	xor	bh, bh
	int 	0x10
	ret

print_string_loop:
	call	print_char

print_string:
	lodsb
	test	al, al
	jns	print_string_loop

print_char:
	and	al, 0x7F
	mov	ah, 0x0E
	int	0x10
	ret

print_int:
	push	bp
	mov	bp, sp

push_digits:
	xor	dx, dx
	mov	bx, 10
	div	bx
	push	dx
	test	ax, ax
	jnz	push_digits

pop_and_print_digits:
	pop	ax
	add	al, '0'
	call	print_char
	cmp	sp, bp
	jne	pop_and_print_digits
	pop	bp
	ret

; =========================
; RANDOM GENERATOR
; =========================
rand:
	mov	ah, 0x00
	int	0x1A
	mov	ax, dx
	xor	dx, dx
	div	bx
	inc	dx
	ret

; =========================
; TEXT DATA (7-bit encoded)
; =========================
retry_msg db '! press r to retr', 0xF9
hit_msg   db 'You hit', 0xA0
self_msg  db 'yoursel', 0xE6
wall_msg  db 'the wal', 0xEC
score_msg db 'v1.0.0 Score:', 0xA0

; =========================
; GAME STATE
; =========================
grow_snake_flag db 0
food_pos dw 0x0D0D
score dw 1
last_move db 'd'

snake_pos:
	snake_x_pos db 0x0F
	snake_y_pos db 0x0F

snake_body_pos dw 0x0000

; =========================
; BOOT SECTOR FOOTER
; =========================
times 510-($-$$) db 0
	db 0x55
	db 0xAA
