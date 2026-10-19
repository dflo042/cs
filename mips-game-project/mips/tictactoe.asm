################################################################################
#  tictactoe.asm  --  Two-player Tic-Tac-Toe for the MARS MIPS simulator
#
#  Module 4: MIPS Game Project  (Game 1 of 3)
#  Author : Dylan Flores
#
#  HOW TO RUN (MARS 4.5)
#    1. Open this file in MARS and assemble it (F3).
#    2. Tools -> Bitmap Display.  Set:
#         Unit Width  = 4      Unit Height = 4
#         Display Width = 256  Display Height = 256
#         Base address for display = 0x10008000 ($gp)
#       Click "Connect to MIPS".
#    3. Run (F5).  Type moves in the Run I/O console at the bottom of MARS.
#
#  GAME
#    Two players (X and O) take turns typing a cell number 1-9.
#    The board, marks, cell numbers and status text are drawn on the
#    64 x 64 pixel bitmap display; the console mirrors the board in text.
#    Invalid input (not a number, out of range, occupied cell) is rejected
#    with a message and the same player is asked again.
#
#  MEMORY MAP OF THE DISPLAY
#    64 x 64 pixels, one word (0x00RRGGBB) per pixel,
#    address(x, y) = 0x10008000 + (y * 64 + x) * 4
#
#  REGISTER / STACK CONVENTIONS USED
#    $a0-$a3 : arguments           $v0-$v1 : return values
#    $t0-$t9 : caller-saved temps  $s0-$s7 : callee-saved (pushed/popped)
#    draw_rect takes a 5th argument (color) on the stack at 0($sp).
################################################################################

        .eqv  DISPLAY_BASE  0x10008000
        .eqv  SCREEN_W      64
        .eqv  SCREEN_H      64
        .eqv  SCREEN_WORDS  4096          # 64 * 64

        .eqv  COLOR_BG      0x00202830    # dark slate background
        .eqv  COLOR_GRID    0x00E0E0E0    # light grey grid lines
        .eqv  COLOR_X       0x00FF5050    # red X
        .eqv  COLOR_O       0x0050A0FF    # blue O
        .eqv  COLOR_WIN     0x0050FF70    # green highlight for the winning line
        .eqv  COLOR_HINT    0x00606878    # dim cell numbers
        .eqv  COLOR_TEXT    0x00FFE060    # yellow status text

        .eqv  BOARD_X       8             # top-left pixel of the board
        .eqv  BOARD_Y       8
        .eqv  CELL_PITCH    16            # 15 pixel cell + 1 pixel line
        .eqv  CELL_SIZE     15

        .eqv  PLAYER_X      1
        .eqv  PLAYER_O      2

################################################################################
#  Small macros that wrap the print syscalls (procedures do the real work)
################################################################################
        .macro print_str(%label)
        la    $a0, %label
        li    $v0, 4
        syscall
        .end_macro

        .macro print_char(%reg)
        move  $a0, %reg
        li    $v0, 11
        syscall
        .end_macro

################################################################################
        .data
################################################################################
board:          .byte  0,0,0,0,0,0,0,0,0     # 0 = empty, 1 = X, 2 = O
                .align 2
win_lines:      .byte  0,1,2,  3,4,5,  6,7,8     # rows
                .byte  0,3,6,  1,4,7,  2,5,8     # columns
                .byte  0,4,8,  2,4,6             # diagonals
                .align 2
move_count:     .word  0
input_buf:      .space 64

# 3 x 5 pixel font.  5 bytes per glyph, one byte per row, bit2 = left pixel.
# Index: 0-9 digits, 10-35 letters A-Z, 36 ' ', 37 '_', 38 '?', 39 '-', 40 ':', 41 '!'
font:           .byte 7,5,5,5,7   # 0
                .byte 2,6,2,2,7   # 1
                .byte 7,1,7,4,7   # 2
                .byte 7,1,7,1,7   # 3
                .byte 5,5,7,1,1   # 4
                .byte 7,4,7,1,7   # 5
                .byte 7,4,7,5,7   # 6
                .byte 7,1,1,1,1   # 7
                .byte 7,5,7,5,7   # 8
                .byte 7,5,7,1,7   # 9
                .byte 2,5,7,5,5   # A
                .byte 6,5,6,5,6   # B
                .byte 7,4,4,4,7   # C
                .byte 6,5,5,5,6   # D
                .byte 7,4,7,4,7   # E
                .byte 7,4,7,4,4   # F
                .byte 7,4,5,5,7   # G
                .byte 5,5,7,5,5   # H
                .byte 7,2,2,2,7   # I
                .byte 1,1,1,5,7   # J
                .byte 5,5,6,5,5   # K
                .byte 4,4,4,4,7   # L
                .byte 5,7,7,5,5   # M
                .byte 6,5,5,5,5   # N
                .byte 7,5,5,5,7   # O
                .byte 7,5,7,4,4   # P
                .byte 7,5,5,7,1   # Q
                .byte 6,5,6,5,5   # R
                .byte 7,4,7,1,7   # S
                .byte 7,2,2,2,2   # T
                .byte 5,5,5,5,7   # U
                .byte 5,5,5,5,2   # V
                .byte 5,5,7,7,5   # W
                .byte 5,5,2,5,5   # X
                .byte 5,5,2,2,2   # Y
                .byte 7,1,2,4,7   # Z
                .byte 0,0,0,0,0   # space
                .byte 0,0,0,0,7   # _
                .byte 7,1,3,0,2   # ?
                .byte 0,0,7,0,0   # -
                .byte 0,2,0,2,0   # :
                .byte 2,2,2,0,2   # !
                .align 2

# ---- strings drawn on the bitmap display ----
title_txt:      .asciiz "TIC TAC TOE"
x_turn_txt:     .asciiz "X TURN"
o_turn_txt:     .asciiz "O TURN"
x_wins_txt:     .asciiz "X WINS!"
o_wins_txt:     .asciiz "O WINS!"
draw_txt:       .asciiz "DRAW"

# ---- console strings ----
welcome_msg:    .asciiz "=== TIC-TAC-TOE (MIPS) ===\nTwo players take turns. Type the number of an empty cell (1-9).\nWatch the Bitmap Display for the graphics; the board is also printed here.\n\n"
prompt_x:       .asciiz "Player X, choose a cell (1-9): "
prompt_o:       .asciiz "Player O, choose a cell (1-9): "
err_not_num:    .asciiz "  ! That is not a whole number. Enter a digit from 1 to 9.\n"
err_range:      .asciiz "  ! Out of range. Enter a digit from 1 to 9.\n"
err_taken:      .asciiz "  ! That cell is already taken. Pick an empty one.\n"
msg_x_wins:     .asciiz "\n*** Player X wins! ***\n"
msg_o_wins:     .asciiz "\n*** Player O wins! ***\n"
msg_draw:       .asciiz "\n*** It's a draw. ***\n"
again_prompt:   .asciiz "Play again? (Y/N): "
err_yn:         .asciiz "  ! Please answer Y or N.\n"
bye_msg:        .asciiz "Thanks for playing!\n"
row_sep:        .asciiz "---+---+---\n"
cell_sep:       .asciiz " | "
newline:        .asciiz "\n"
space1:         .asciiz " "

################################################################################
        .text
        .globl main
################################################################################
main:
        print_str(welcome_msg)

new_game:
        jal     reset_game              # clear board + move counter
        jal     draw_board_screen       # background, title, grid, hints
        li      $s0, PLAYER_X           # $s0 = current player for the whole game

game_loop:
        jal     print_console_board
        move    $a0, $s0
        jal     show_turn_status        # "X TURN" / "O TURN" on the display

ask_move:
        # ---- prompt the current player ----
        li      $t0, PLAYER_X
        bne     $s0, $t0, prompt_player_o
        print_str(prompt_x)
        j       read_move
prompt_player_o:
        print_str(prompt_o)

read_move:
        la      $a0, input_buf
        li      $a1, 64
        jal     read_line               # read one line into input_buf
        la      $a0, input_buf
        jal     parse_int               # $v0 = value, $v1 = 1 if valid number
        beqz    $v1, bad_number
        blt     $v0, 1, bad_range
        bgt     $v0, 9, bad_range
        addi    $s1, $v0, -1            # $s1 = cell index 0..8
        lb      $t0, board($s1)
        bnez    $t0, bad_taken

        # ---- legal move: record it and draw it ----
        sb      $s0, board($s1)
        lw      $t0, move_count
        addi    $t0, $t0, 1
        sw      $t0, move_count

        move    $a0, $s1                # cell
        move    $a1, $s0                # player
        jal     draw_mark

        move    $a0, $s0
        jal     check_win               # $v0 = winning line index or -1
        bgez    $v0, player_won

        lw      $t0, move_count
        li      $t1, 9
        beq     $t0, $t1, game_draw

        # switch player: 1 -> 2, 2 -> 1
        li      $t0, 3
        sub     $s0, $t0, $s0
        j       game_loop

bad_number:
        print_str(err_not_num)
        j       ask_move
bad_range:
        print_str(err_range)
        j       ask_move
bad_taken:
        print_str(err_taken)
        j       ask_move

player_won:
        move    $a0, $v0                # line index
        move    $a1, $s0                # player
        jal     highlight_line
        jal     print_console_board
        li      $t0, PLAYER_X
        bne     $s0, $t0, o_won
        print_str(msg_x_wins)
        la      $a0, x_wins_txt
        jal     show_status
        j       ask_again
o_won:
        print_str(msg_o_wins)
        la      $a0, o_wins_txt
        jal     show_status
        j       ask_again

game_draw:
        jal     print_console_board
        print_str(msg_draw)
        la      $a0, draw_txt
        jal     show_status

ask_again:
        print_str(again_prompt)
        la      $a0, input_buf
        li      $a1, 64
        jal     read_line
        lb      $t0, input_buf
        li      $t1, 'Y'
        beq     $t0, $t1, new_game
        li      $t1, 'y'
        beq     $t0, $t1, new_game
        li      $t1, 'N'
        beq     $t0, $t1, exit_game
        li      $t1, 'n'
        beq     $t0, $t1, exit_game
        print_str(err_yn)
        j       ask_again

exit_game:
        print_str(bye_msg)
        li      $v0, 10
        syscall

################################################################################
#  reset_game -- clears the board array and the move counter
################################################################################
reset_game:
        la      $t0, board
        li      $t1, 9
reset_loop:
        sb      $zero, 0($t0)
        addi    $t0, $t0, 1
        addi    $t1, $t1, -1
        bnez    $t1, reset_loop
        sw      $zero, move_count
        jr      $ra

################################################################################
#  check_win(player) -> $v0 = index (0-7) of the winning line, or -1
################################################################################
check_win:
        li      $t0, 0                  # line index
        la      $t1, win_lines
cw_loop:
        lb      $t2, 0($t1)
        lb      $t3, 1($t1)
        lb      $t4, 2($t1)
        lb      $t2, board($t2)
        lb      $t3, board($t3)
        lb      $t4, board($t4)
        bne     $t2, $a0, cw_next
        bne     $t3, $a0, cw_next
        bne     $t4, $a0, cw_next
        move    $v0, $t0                # all three belong to player -> win
        jr      $ra
cw_next:
        addi    $t1, $t1, 3
        addi    $t0, $t0, 1
        blt     $t0, 8, cw_loop
        li      $v0, -1
        jr      $ra

################################################################################
#  highlight_line(line, player) -- redraws the 3 winning marks in green
################################################################################
highlight_line:
        addi    $sp, $sp, -16
        sw      $ra, 12($sp)
        sw      $s2, 8($sp)
        sw      $s3, 4($sp)
        sw      $s4, 0($sp)
        la      $s2, win_lines
        sll     $t0, $a0, 1             # line * 3 = line*2 + line
        add     $t0, $t0, $a0
        add     $s2, $s2, $t0           # $s2 -> first cell of the line
        move    $s3, $a1                # player
        li      $s4, 3                  # 3 cells
hl_loop:
        lb      $a0, 0($s2)
        move    $a1, $s3
        li      $a2, COLOR_WIN
        jal     draw_mark_color
        addi    $s2, $s2, 1
        addi    $s4, $s4, -1
        bnez    $s4, hl_loop
        lw      $ra, 12($sp)
        lw      $s2, 8($sp)
        lw      $s3, 4($sp)
        lw      $s4, 0($sp)
        addi    $sp, $sp, 16
        jr      $ra

################################################################################
#  print_console_board -- prints the text version of the board
################################################################################
print_console_board:
        addi    $sp, $sp, -8
        sw      $ra, 4($sp)
        sw      $s5, 0($sp)
        print_str(newline)
        li      $s5, 0                  # cell index 0..8
pcb_row:
        print_str(space1)
        move    $a0, $s5
        jal     print_cell
        print_str(cell_sep)
        addi    $a0, $s5, 1
        jal     print_cell
        print_str(cell_sep)
        addi    $a0, $s5, 2
        jal     print_cell
        print_str(newline)
        addi    $s5, $s5, 3
        bge     $s5, 9, pcb_done
        print_str(row_sep)
        j       pcb_row
pcb_done:
        print_str(newline)
        lw      $ra, 4($sp)
        lw      $s5, 0($sp)
        addi    $sp, $sp, 8
        jr      $ra

# print_cell(index): prints 'X', 'O' or the cell number if empty
print_cell:
        lb      $t0, board($a0)
        beqz    $t0, pc_empty
        li      $t1, 'X'
        li      $t2, PLAYER_X
        beq     $t0, $t2, pc_print
        li      $t1, 'O'
        j       pc_print
pc_empty:
        addi    $t1, $a0, '1'           # '1' + index
pc_print:
        print_char($t1)
        jr      $ra

################################################################################
#  show_turn_status(player) -- writes "X TURN" or "O TURN" on the display
################################################################################
show_turn_status:
        li      $t0, PLAYER_X
        bne     $a0, $t0, sts_o
        la      $a0, x_turn_txt
        j       show_status
sts_o:
        la      $a0, o_turn_txt
        # fall through into show_status

################################################################################
#  show_status(string) -- clears the status strip and draws the text
################################################################################
show_status:
        addi    $sp, $sp, -8
        sw      $ra, 4($sp)
        sw      $s6, 0($sp)
        move    $s6, $a0
        li      $a0, 0                  # clear the strip y = 57..63
        li      $a1, 57
        li      $a2, SCREEN_W
        li      $a3, 7
        li      $t0, COLOR_BG
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        li      $a0, 4
        li      $a1, 57
        move    $a2, $s6
        li      $a3, COLOR_TEXT
        jal     draw_text
        lw      $ra, 4($sp)
        lw      $s6, 0($sp)
        addi    $sp, $sp, 8
        jr      $ra

################################################################################
#  draw_board_screen -- background, title, grid lines, dim cell numbers
################################################################################
draw_board_screen:
        addi    $sp, $sp, -8
        sw      $ra, 4($sp)
        sw      $s7, 0($sp)

        li      $a0, COLOR_BG
        jal     fill_screen

        li      $a0, 10
        li      $a1, 1
        la      $a2, title_txt
        li      $a3, COLOR_TEXT
        jal     draw_text

        # two vertical grid lines (1 x 47) at x = 23 and x = 39
        li      $a0, 23
        li      $a1, BOARD_Y
        li      $a2, 1
        li      $a3, 47
        li      $t0, COLOR_GRID
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4

        li      $a0, 39
        li      $a1, BOARD_Y
        li      $a2, 1
        li      $a3, 47
        li      $t0, COLOR_GRID
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4

        # two horizontal grid lines (47 x 1) at y = 23 and y = 39
        li      $a0, BOARD_X
        li      $a1, 23
        li      $a2, 47
        li      $a3, 1
        li      $t0, COLOR_GRID
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4

        li      $a0, BOARD_X
        li      $a1, 39
        li      $a2, 47
        li      $a3, 1
        li      $t0, COLOR_GRID
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4

        # dim cell numbers 1..9 in the top-left corner of each cell
        li      $s7, 0
dbs_hint:
        move    $a0, $s7
        jal     cell_origin             # $v0 = x0, $v1 = y0
        addi    $a0, $v0, 1
        addi    $a1, $v1, 1
        addi    $a2, $s7, '1'
        li      $a3, COLOR_HINT
        jal     draw_glyph
        addi    $s7, $s7, 1
        blt     $s7, 9, dbs_hint

        lw      $ra, 4($sp)
        lw      $s7, 0($sp)
        addi    $sp, $sp, 8
        jr      $ra

################################################################################
#  cell_origin(index) -> $v0 = x0, $v1 = y0 (top-left pixel of the cell)
################################################################################
cell_origin:
        li      $t0, 3
        div     $a0, $t0
        mflo    $t1                     # row
        mfhi    $t2                     # column
        mul     $v0, $t2, CELL_PITCH
        addi    $v0, $v0, BOARD_X
        mul     $v1, $t1, CELL_PITCH
        addi    $v1, $v1, BOARD_Y
        jr      $ra

################################################################################
#  draw_mark(cell, player) -- draws X in red or O in blue
#  draw_mark_color(cell, player, color) -- same but with an explicit color
################################################################################
draw_mark:
        li      $a2, COLOR_X
        li      $t0, PLAYER_X
        beq     $a1, $t0, draw_mark_color
        li      $a2, COLOR_O
draw_mark_color:
        addi    $sp, $sp, -20
        sw      $ra, 16($sp)
        sw      $s0, 12($sp)
        sw      $s1, 8($sp)
        sw      $s2, 4($sp)
        sw      $s3, 0($sp)
        move    $s2, $a1                # player
        move    $s3, $a2                # color
        jal     cell_origin
        move    $s0, $v0                # x0
        move    $s1, $v1                # y0

        # erase the cell interior (removes the hint digit)
        move    $a0, $s0
        move    $a1, $s1
        li      $a2, CELL_SIZE
        li      $a3, CELL_SIZE
        li      $t0, COLOR_BG
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4

        move    $a0, $s0
        move    $a1, $s1
        move    $a2, $s3
        li      $t0, PLAYER_X
        bne     $s2, $t0, dmc_o
        jal     draw_x_mark
        j       dmc_done
dmc_o:
        jal     draw_o_mark
dmc_done:
        lw      $ra, 16($sp)
        lw      $s0, 12($sp)
        lw      $s1, 8($sp)
        lw      $s2, 4($sp)
        lw      $s3, 0($sp)
        addi    $sp, $sp, 20
        jr      $ra

# draw_x_mark(x0, y0, color): two 2-pixel-thick diagonals inside the cell
draw_x_mark:
        addi    $sp, $sp, -20
        sw      $ra, 16($sp)
        sw      $s0, 12($sp)
        sw      $s1, 8($sp)
        sw      $s2, 4($sp)
        sw      $s3, 0($sp)
        move    $s0, $a0
        move    $s1, $a1
        move    $s2, $a2
        li      $s3, 0                  # i = 0..10
dx_loop:
        addi    $a0, $s0, 2
        add     $a0, $a0, $s3           # x0 + 2 + i
        addi    $a1, $s1, 2
        add     $a1, $a1, $s3           # y0 + 2 + i
        move    $a2, $s2
        jal     draw_pixel
        addi    $a0, $s0, 3
        add     $a0, $a0, $s3           # x0 + 3 + i   (thickness)
        addi    $a1, $s1, 2
        add     $a1, $a1, $s3
        move    $a2, $s2
        jal     draw_pixel
        addi    $a0, $s0, 12
        sub     $a0, $a0, $s3           # x0 + 12 - i
        addi    $a1, $s1, 2
        add     $a1, $a1, $s3
        move    $a2, $s2
        jal     draw_pixel
        addi    $a0, $s0, 11
        sub     $a0, $a0, $s3           # x0 + 11 - i
        addi    $a1, $s1, 2
        add     $a1, $a1, $s3
        move    $a2, $s2
        jal     draw_pixel
        addi    $s3, $s3, 1
        ble     $s3, 10, dx_loop
        lw      $ra, 16($sp)
        lw      $s0, 12($sp)
        lw      $s1, 8($sp)
        lw      $s2, 4($sp)
        lw      $s3, 0($sp)
        addi    $sp, $sp, 20
        jr      $ra

# draw_o_mark(x0, y0, color): 11x11 ring, 2 pixels thick, rounded corners
draw_o_mark:
        addi    $sp, $sp, -16
        sw      $ra, 12($sp)
        sw      $s0, 8($sp)
        sw      $s1, 4($sp)
        sw      $s2, 0($sp)
        move    $s0, $a0
        move    $s1, $a1
        move    $s2, $a2

        addi    $a0, $s0, 2
        addi    $a1, $s1, 2
        li      $a2, 11
        li      $a3, 11
        addi    $sp, $sp, -4
        sw      $s2, 0($sp)
        jal     draw_rect               # outer square in the mark color
        addi    $sp, $sp, 4

        addi    $a0, $s0, 4
        addi    $a1, $s1, 4
        li      $a2, 7
        li      $a3, 7
        li      $t0, COLOR_BG
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect               # hollow centre
        addi    $sp, $sp, 4

        # knock out the four corners so the ring looks round
        addi    $a0, $s0, 2
        addi    $a1, $s1, 2
        li      $a2, COLOR_BG
        jal     draw_pixel
        addi    $a0, $s0, 12
        addi    $a1, $s1, 2
        li      $a2, COLOR_BG
        jal     draw_pixel
        addi    $a0, $s0, 2
        addi    $a1, $s1, 12
        li      $a2, COLOR_BG
        jal     draw_pixel
        addi    $a0, $s0, 12
        addi    $a1, $s1, 12
        li      $a2, COLOR_BG
        jal     draw_pixel

        lw      $ra, 12($sp)
        lw      $s0, 8($sp)
        lw      $s1, 4($sp)
        lw      $s2, 0($sp)
        addi    $sp, $sp, 16
        jr      $ra

################################################################################
#  ======================  GRAPHICS LIBRARY  ======================
################################################################################

# fill_screen(color): writes color to all 4096 display words
fill_screen:
        li      $t0, DISPLAY_BASE
        li      $t1, SCREEN_WORDS
fs_loop:
        sw      $a0, 0($t0)
        addi    $t0, $t0, 4
        addi    $t1, $t1, -1
        bnez    $t1, fs_loop
        jr      $ra

# draw_pixel(x, y, color): sets one pixel; silently ignores out-of-range coords
draw_pixel:
        bltz    $a0, dp_done
        bltz    $a1, dp_done
        bge     $a0, SCREEN_W, dp_done
        bge     $a1, SCREEN_H, dp_done
        sll     $t0, $a1, 6             # y * 64
        add     $t0, $t0, $a0           # + x
        sll     $t0, $t0, 2             # * 4 bytes per pixel
        li      $t1, DISPLAY_BASE
        add     $t0, $t0, $t1
        sw      $a2, 0($t0)
dp_done:
        jr      $ra

# draw_rect(x, y, w, h, color-on-stack): filled rectangle.
# The 5th argument is read from 0($sp) BEFORE the prologue moves $sp.
draw_rect:
        lw      $t9, 0($sp)             # color (5th argument)
        addi    $sp, $sp, -28
        sw      $ra, 24($sp)
        sw      $s0, 20($sp)
        sw      $s1, 16($sp)
        sw      $s2, 12($sp)
        sw      $s3, 8($sp)
        sw      $s4, 4($sp)
        sw      $s5, 0($sp)
        move    $s0, $a0                # x
        move    $s1, $a1                # y
        move    $s2, $a2                # w
        move    $s3, $a3                # h
        move    $s4, $t9                # color
        li      $s5, 0                  # row
dr_row:
        bge     $s5, $s3, dr_done
        li      $t8, 0                  # column (kept in $t8; draw_pixel never touches it)
dr_col:
        bge     $t8, $s2, dr_next_row
        add     $a0, $s0, $t8
        add     $a1, $s1, $s5
        move    $a2, $s4
        jal     draw_pixel
        addi    $t8, $t8, 1
        j       dr_col
dr_next_row:
        addi    $s5, $s5, 1
        j       dr_row
dr_done:
        lw      $ra, 24($sp)
        lw      $s0, 20($sp)
        lw      $s1, 16($sp)
        lw      $s2, 12($sp)
        lw      $s3, 8($sp)
        lw      $s4, 4($sp)
        lw      $s5, 0($sp)
        addi    $sp, $sp, 28
        jr      $ra

# glyph_index(char) -> $v0 = index into the font table
glyph_index:
        blt     $a0, '0', gi_not_digit
        bgt     $a0, '9', gi_not_digit
        addi    $v0, $a0, -48           # '0'..'9' -> 0..9
        jr      $ra
gi_not_digit:
        blt     $a0, 'A', gi_not_upper
        bgt     $a0, 'Z', gi_not_upper
        addi    $v0, $a0, -55           # 'A' (65) -> 10
        jr      $ra
gi_not_upper:
        blt     $a0, 'a', gi_symbol
        bgt     $a0, 'z', gi_symbol
        addi    $v0, $a0, -87           # 'a' (97) -> 10
        jr      $ra
gi_symbol:
        li      $v0, 36
        beq     $a0, ' ', gi_ret
        li      $v0, 37
        beq     $a0, '_', gi_ret
        li      $v0, 39
        beq     $a0, '-', gi_ret
        li      $v0, 40
        beq     $a0, ':', gi_ret
        li      $v0, 41
        beq     $a0, '!', gi_ret
        li      $v0, 38                 # anything else prints as '?'
gi_ret:
        jr      $ra

# draw_glyph(x, y, char, color): draws one 3x5 character
draw_glyph:
        addi    $sp, $sp, -28
        sw      $ra, 24($sp)
        sw      $s0, 20($sp)
        sw      $s1, 16($sp)
        sw      $s2, 12($sp)
        sw      $s3, 8($sp)
        sw      $s4, 4($sp)
        sw      $s5, 0($sp)
        move    $s0, $a0                # x
        move    $s1, $a1                # y
        move    $s3, $a3                # color
        move    $a0, $a2
        jal     glyph_index
        la      $s2, font
        sll     $t0, $v0, 2             # index * 5 = index*4 + index
        add     $t0, $t0, $v0
        add     $s2, $s2, $t0           # $s2 -> first row byte
        li      $s4, 0                  # row 0..4
dg_row:
        lb      $s5, 0($s2)             # row bits: bit2 bit1 bit0 = left..right
        li      $t8, 0                  # column 0..2 (kept in $t8)
dg_col:
        li      $t1, 4
        srlv    $t1, $t1, $t8           # mask = 4 >> col
        and     $t1, $t1, $s5
        beqz    $t1, dg_skip
        add     $a0, $s0, $t8
        add     $a1, $s1, $s4
        move    $a2, $s3
        jal     draw_pixel
dg_skip:
        addi    $t8, $t8, 1
        blt     $t8, 3, dg_col
        addi    $s2, $s2, 1
        addi    $s4, $s4, 1
        blt     $s4, 5, dg_row
        lw      $ra, 24($sp)
        lw      $s0, 20($sp)
        lw      $s1, 16($sp)
        lw      $s2, 12($sp)
        lw      $s3, 8($sp)
        lw      $s4, 4($sp)
        lw      $s5, 0($sp)
        addi    $sp, $sp, 28
        jr      $ra

# draw_text(x, y, string, color): draws a NUL-terminated string, 4 px per char
draw_text:
        addi    $sp, $sp, -20
        sw      $ra, 16($sp)
        sw      $s0, 12($sp)
        sw      $s1, 8($sp)
        sw      $s2, 4($sp)
        sw      $s3, 0($sp)
        move    $s0, $a0
        move    $s1, $a1
        move    $s2, $a2
        move    $s3, $a3
dt_loop:
        lb      $a2, 0($s2)
        beqz    $a2, dt_done
        move    $a0, $s0
        move    $a1, $s1
        move    $a3, $s3
        jal     draw_glyph
        addi    $s0, $s0, 4
        addi    $s2, $s2, 1
        j       dt_loop
dt_done:
        lw      $ra, 16($sp)
        lw      $s0, 12($sp)
        lw      $s1, 8($sp)
        lw      $s2, 4($sp)
        lw      $s3, 0($sp)
        addi    $sp, $sp, 20
        jr      $ra

################################################################################
#  ======================  INPUT LIBRARY  ======================
################################################################################

# read_line(buffer, size): reads one line (syscall 8) and strips the newline.
# Returns $v0 = number of characters kept.
read_line:
        move    $t0, $a0                # remember buffer start
        li      $v0, 8
        syscall
        li      $v0, 0
rl_scan:
        lb      $t1, 0($t0)
        beqz    $t1, rl_done
        li      $t2, '\n'
        beq     $t1, $t2, rl_strip
        li      $t2, '\r'
        beq     $t1, $t2, rl_strip
        addi    $t0, $t0, 1
        addi    $v0, $v0, 1
        j       rl_scan
rl_strip:
        sb      $zero, 0($t0)
rl_done:
        jr      $ra

# parse_int(buffer) -> $v0 = value, $v1 = 1 if the whole line was a valid
# non-negative integer (surrounding spaces allowed), else $v1 = 0.
parse_int:
        li      $v0, 0
        li      $v1, 0
        li      $t3, 0                  # digit count
pi_skip_lead:
        lb      $t0, 0($a0)
        li      $t1, ' '
        bne     $t0, $t1, pi_digits
        addi    $a0, $a0, 1
        j       pi_skip_lead
pi_digits:
        lb      $t0, 0($a0)
        beqz    $t0, pi_end
        li      $t1, ' '
        beq     $t0, $t1, pi_trail
        blt     $t0, '0', pi_bad
        bgt     $t0, '9', pi_bad
        addi    $t0, $t0, -48
        mul     $v0, $v0, 10
        add     $v0, $v0, $t0
        addi    $t3, $t3, 1
        bgt     $t3, 9, pi_bad          # absurdly long number -> reject (no overflow)
        addi    $a0, $a0, 1
        j       pi_digits
pi_trail:                               # only spaces may follow the digits
        lb      $t0, 0($a0)
        beqz    $t0, pi_end
        li      $t1, ' '
        bne     $t0, $t1, pi_bad
        addi    $a0, $a0, 1
        j       pi_trail
pi_end:
        beqz    $t3, pi_bad             # no digits at all (empty line)
        li      $v1, 1
        jr      $ra
pi_bad:
        li      $v0, -1
        li      $v1, 0
        jr      $ra
