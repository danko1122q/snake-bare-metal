; ============================================================
; Snake Game Boot Sector
; ------------------------------------------------------------
; Copyright (c) 2025 Davanico Ady Nugroho
;
; Licensed under the MIT License.
; You may use, copy, modify, and distribute this project,
; provided the original copyright notice and license are preserved.
;
; Description:
; A tiny Snake game that runs directly on BIOS,
; without an OS, filesystem, or external libraries.
; Keyboard input via INT 16h, video via INT 10h.
;
; Controls:
;   W A S D - Move snake
;   R       - Restart after game over
; ============================================================

    ; --------------------------
    ; INITIAL SETUP
    ; --------------------------
	mov	ax, 0x07C0
	mov	ds, ax              ; DS points to boot sector location

	mov	ah, 0x01
	mov	cx, 0x2000
	int 	0x10              ; disable blinking cursor on screen

	mov	ax, 0x0305
	mov	bx, 0x031F
	int	0x16              ; adjust keyboard repeat rate (slower)

; =========================
; MAIN GAME LOOP
; =========================
game_loop:
	call	clear_screen       ; clear screen each frame for redraw

	push	word [snake_pos]   ; save current head position (for updating body)

	mov	ah, 0x01
	int	0x16              ; check if a key is pressed
	jz	done_clear         ; if no key pressed, use last direction

	mov	ah, 0x00
	int	0x16              ; read key from keyboard buffer
	jmp	update_snakepos

done_clear:
	mov	al, [last_move]    ; fallback to previous direction if no key pressed

; -------------------------
; UPDATE SNAKE POSITION
; -------------------------
update_snakepos:
	cmp	al, 0x1b           ; check if ESC pressed
	jne	no_exit
	int	0x20              ; terminate program if ESC

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
	dec	byte [snake_y_pos] ; move up (decrease Y)
	jmp	move_done

left:
	dec	byte [snake_x_pos] ; move left (decrease X)
	jmp	move_done

right:
	inc	byte [snake_x_pos] ; move right (increase X)
	jmp	move_done

down:
	inc	byte [snake_y_pos] ; move down (increase Y)

move_done:
	mov	[last_move], al    ; save current move for next iteration

; -------------------------
; UPDATE SNAKE BODY
; -------------------------
	mov	si, snake_body_pos
	pop	ax                 ; previous head position

update_body:
	mov	bx, [si]            ; read next body segment
	test	bx, bx
	jz	done_update         ; if zero, end of snake body
	mov	[si], ax            ; shift previous position to current segment
	add	si, 2               ; move to next segment
	mov	ax, bx             ; next iteration: current becomes previous
	jmp	update_body

done_update:
	cmp	byte [grow_snake_flag], 1
	jne	add_zero_snake      ; if no growth, append zero at end

	mov	word [si], ax        ; grow snake by adding new head position
	mov	byte [grow_snake_flag], 0
	add	si, 2

add_zero_snake:
	mov	word [si], 0x0000    ; mark end of snake body

; =========================
; DRAW EVERYTHING
; =========================
print_stuff:
	; --- Move cursor to center top for score ---
	mov	dh, 0x00       ; row 0 (top)
	mov	dl, 0x20       ; column 32 (roughly center)
	mov	dx, dx         ; combine DH/DL into DX
	call	move_cursor

	mov	si, score_msg
	call	print_string     ; print score message

	mov	ax, [score]
	call	print_int        ; print numeric score

	; draw food
	mov	dx, [food_pos]
	call	move_cursor
	mov	al, 'O'
	call	print_char

	; draw snake head
	mov	dx, [snake_pos]
	call	move_cursor
	mov	al, '@'
	call	print_char

	; draw snake body
	mov	si, snake_body_pos

snake_body_print_loop:
	lodsw
	test	ax, ax
	jz	check_collisions   ; if zero, end of body
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

	; check wall collision
	cmp	bh, 25
	jge	game_over_hit_wall
	cmp	bh, 0
	jl	game_over_hit_wall
	cmp	bl, 80
	jge	game_over_hit_wall
	cmp	bl, 0
	jl	game_over_hit_wall

	; check self collision
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

	inc	word [score]       ; increase score

	mov	bx, 24
	call	rand              ; generate new Y for food
	push	dx

	mov	bx, 78
	call	rand              ; generate new X for food
	pop	cx

	mov	dh, cl
	mov	[food_pos], dx     ; store new food position
	mov	byte [grow_snake_flag], 1 ; grow snake on next update

game_loop_continued:
	mov	cx, 0x0002
	mov	dx, 0x49F0
	mov	ah, 0x86
	int	0x15                  ; small delay
	jmp	game_loop

; =========================
; GAME OVER HANDLING
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

	; reset game state
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
	mov	bh, 0x0A           ; background color attribute
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
	int	0x1A               ; get system timer
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
; GAME STATE VARIABLES
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
