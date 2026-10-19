################################################################################
#  hangman.asm  --  Hangman (custom game) for the MARS MIPS simulator
#
#  Module 4: MIPS Game Project  (Game 3 of 3 - my own custom game)
#  Author : Dylan Flores
#
#  HOW TO RUN (MARS 4.5)
#    1. Open this file in MARS and assemble it (F3).
#    2. Tools -> Bitmap Display.  Set:
#         Unit Width  = 4      Unit Height = 4
#         Display Width = 256  Display Height = 256
#         Base address for display = 0x10008000 ($gp)
#       Click "Connect to MIPS".
#    3. Run (F5).  Type single letters in the Run I/O console.
#
#  GAME
#    The program picks a random computer-architecture word from a word table.
#    The player guesses one letter at a time.  Correct letters are revealed in
#    the word row on the bitmap display; each wrong guess draws one more part
#    of the hanged figure (head, body, two arms, two legs = 6 lives).  Wrong
#    letters are listed in red.  Input is validated: exactly one character,
#    must be a letter (upper or lower case accepted), repeats are rejected
#    without costing a life.
#
#  DATA STRUCTURES
#    word_table  : array of pointers to NUL-terminated upper-case words
#    guessed[26] : byte flags, guessed[c - 'A'] = 1 once letter c is tried
#    wrong_buf   : the wrong letters in the order they were guessed
#
#  REGISTER / STACK CONVENTIONS USED
#    $a0-$a3 arguments, $v0-$v1 results, $t* caller-saved, $s* callee-saved
#    and saved on the stack by every procedure that uses them.
#    draw_rect takes a 5th argument (color) on the stack at 0($sp).
################################################################################

        .eqv  DISPLAY_BASE  0x10008000
        .eqv  SCREEN_W      64
        .eqv  SCREEN_H      64
        .eqv  SCREEN_WORDS  4096

        .eqv  COLOR_BG      0x00181C28    # night blue background
        .eqv  COLOR_WOOD    0x00A0703A    # gallows
        .eqv  COLOR_ROPE    0x00D0B070
        .eqv  COLOR_BODY    0x00F0E0C0    # figure
        .eqv  COLOR_TEXT    0x00FFFFFF
        .eqv  COLOR_GOLD    0x00FFD040
        .eqv  COLOR_BAD     0x00FF5050
        .eqv  COLOR_GOOD    0x0050FF70

        .eqv  MAX_WRONG     6
        .eqv  WORD_COUNT    12
        .eqv  WORD_ROW_Y    44
        .eqv  MISS_ROW_Y    52

        .macro print_str(%label)
        la    $a0, %label
        li    $v0, 4
        syscall
        .end_macro

        .macro print_int(%reg)
        move  $a0, %reg
        li    $v0, 1
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
w0:             .asciiz "COMPUTER"
w1:             .asciiz "ASSEMBLY"
w2:             .asciiz "REGISTER"
w3:             .asciiz "PROCEDURE"
w4:             .asciiz "MEMORY"
w5:             .asciiz "BRANCH"
w6:             .asciiz "STACK"
w7:             .asciiz "SYSCALL"
w8:             .asciiz "PIPELINE"
w9:             .asciiz "COMPILER"
w10:            .asciiz "HARDWARE"
w11:            .asciiz "PROGRAM"
                .align 2
word_table:     .word  w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11

cur_word:       .word  0                # pointer to the secret word
wrong_count:    .word  0
games_won:      .word  0
games_lost:     .word  0
guessed:        .space 26               # 1 = letter already tried
wrong_buf:      .space 8                # wrong letters, NUL-terminated
                .align 2
input_buf:      .space 64
num_buf:        .space 12

# 3 x 5 pixel font (see tictactoe.asm for the index layout)
font:           .byte 7,5,5,5,7, 2,6,2,2,7, 7,1,7,4,7, 7,1,7,1,7, 5,5,7,1,1
                .byte 7,4,7,1,7, 7,4,7,5,7, 7,1,1,1,1, 7,5,7,5,7, 7,5,7,1,7
                .byte 2,5,7,5,5, 6,5,6,5,6, 7,4,4,4,7, 6,5,5,5,6, 7,4,7,4,7
                .byte 7,4,7,4,4, 7,4,5,5,7, 5,5,7,5,5, 7,2,2,2,7, 1,1,1,5,7
                .byte 5,5,6,5,5, 4,4,4,4,7, 5,7,7,5,5, 6,5,5,5,5, 7,5,5,5,7
                .byte 7,5,7,4,4, 7,5,5,7,1, 6,5,6,5,5, 7,4,7,1,7, 7,2,2,2,2
                .byte 5,5,5,5,7, 5,5,5,5,2, 5,5,7,7,5, 5,5,2,5,5, 5,5,2,2,2
                .byte 7,1,2,4,7, 0,0,0,0,0, 0,0,0,0,7, 7,1,3,0,2, 0,0,7,0,0
                .byte 0,2,0,2,0, 2,2,2,0,2
                .align 2

# ---- display strings ----
title_txt:      .asciiz "HANGMAN"
lives_txt:      .asciiz "LIVES"
miss_txt:       .asciiz "MISS"
win_txt:        .asciiz "YOU WIN"
lose_txt:       .asciiz "YOU LOSE"

# ---- console strings ----
welcome:        .asciiz "=== HANGMAN (MIPS) ===\nI am thinking of a computer-architecture word.\nGuess one letter at a time. You have 6 lives.\n\n"
c_word:         .asciiz "Word : "
c_lives:        .asciiz "   Lives: "
c_missed:       .asciiz "   Missed: "
c_prompt:       .asciiz "Guess a letter: "
c_err_len:      .asciiz "  ! Enter exactly one letter.\n"
c_err_alpha:    .asciiz "  ! That is not a letter (A-Z only).\n"
c_err_dup:      .asciiz "  ! You already tried that letter.\n"
c_hit1:         .asciiz "  Yes! '"
c_hit2:         .asciiz "' appears "
c_hit3:         .asciiz " time(s).\n"
c_miss1:        .asciiz "  No '"
c_miss2:        .asciiz "' in the word.\n"
c_win:          .asciiz "\n*** You got it! The word was "
c_lose:         .asciiz "\n*** Out of lives! The word was "
c_period:       .asciiz ". ***\n"
c_score1:       .asciiz "Score: "
c_score2:       .asciiz " won, "
c_score3:       .asciiz " lost.\n"
c_again:        .asciiz "Play again? (Y/N): "
c_bad_yn:       .asciiz "  ! Please answer Y or N.\n"
c_bye:          .asciiz "Thanks for playing!\n"
newline:        .asciiz "\n"
space1:         .asciiz " "

################################################################################
        .text
        .globl main
################################################################################
main:
        print_str(welcome)
        li      $v0, 30                 # seed generator 0 from the clock
        syscall
        move    $a1, $a0
        li      $a0, 0
        li      $v0, 40
        syscall

new_game:
        jal     reset_game              # picks a word, clears guesses
        jal     draw_scene
        jal     print_state

turn:
        print_str(c_prompt)
        la      $a0, input_buf
        li      $a1, 64
        jal     read_line               # $v0 = length without newline
        li      $t0, 1
        bne     $v0, $t0, bad_length
        lb      $a0, input_buf
        jal     to_upper
        move    $s0, $v0                # $s0 = guessed letter (upper case)
        blt     $s0, 'A', bad_alpha
        bgt     $s0, 'Z', bad_alpha
        addi    $t0, $s0, -65           # index 0..25
        lb      $t1, guessed($t0)
        bnez    $t1, bad_dup
        li      $t1, 1
        sb      $t1, guessed($t0)       # remember the guess

        move    $a0, $s0
        jal     count_in_word           # $v0 = occurrences of the letter
        beqz    $v0, wrong_guess
        move    $s1, $v0
        print_str(c_hit1)
        print_char($s0)
        print_str(c_hit2)
        print_int($s1)
        print_str(c_hit3)
        j       after_guess

wrong_guess:
        lw      $t0, wrong_count
        la      $t1, wrong_buf
        add     $t1, $t1, $t0
        sb      $s0, 0($t1)             # append to the miss list
        sb      $zero, 1($t1)
        addi    $t0, $t0, 1
        sw      $t0, wrong_count
        print_str(c_miss1)
        print_char($s0)
        print_str(c_miss2)

after_guess:
        jal     draw_scene
        jal     print_state
        jal     word_solved             # $v0 = 1 if every letter is revealed
        bnez    $v0, game_won
        lw      $t0, wrong_count
        blt     $t0, MAX_WRONG, turn

        # ---- lost ----
        lw      $t0, games_lost
        addi    $t0, $t0, 1
        sw      $t0, games_lost
        li      $a0, 1
        jal     draw_word_row           # reveal the whole word (missing letters in red)
        li      $a0, 30
        li      $a1, 15
        la      $a2, lose_txt
        li      $a3, COLOR_BAD
        jal     draw_text
        print_str(c_lose)
        lw      $a0, cur_word
        li      $v0, 4
        syscall
        print_str(c_period)
        j       show_score

game_won:
        lw      $t0, games_won
        addi    $t0, $t0, 1
        sw      $t0, games_won
        li      $a0, 30
        li      $a1, 15
        la      $a2, win_txt
        li      $a3, COLOR_GOOD
        jal     draw_text
        print_str(c_win)
        lw      $a0, cur_word
        li      $v0, 4
        syscall
        print_str(c_period)

show_score:
        print_str(c_score1)
        lw      $t0, games_won
        print_int($t0)
        print_str(c_score2)
        lw      $t0, games_lost
        print_int($t0)
        print_str(c_score3)

ask_again:
        print_str(c_again)
        la      $a0, input_buf
        li      $a1, 64
        jal     read_line
        lb      $a0, input_buf
        jal     to_upper
        li      $t0, 'Y'
        beq     $v0, $t0, new_game
        li      $t0, 'N'
        beq     $v0, $t0, exit_game
        print_str(c_bad_yn)
        j       ask_again

bad_length:
        print_str(c_err_len)
        j       turn
bad_alpha:
        print_str(c_err_alpha)
        j       turn
bad_dup:
        print_str(c_err_dup)
        j       turn

exit_game:
        print_str(c_bye)
        li      $v0, 10
        syscall

################################################################################
#  ======================  GAME STATE PROCEDURES  ======================
################################################################################

# reset_game: random word, clear guessed[] and the miss list
reset_game:
        li      $a0, 0
        li      $a1, WORD_COUNT
        li      $v0, 42
        syscall                         # $a0 = random index
        sll     $t0, $a0, 2
        lw      $t0, word_table($t0)
        sw      $t0, cur_word
        sw      $zero, wrong_count
        sb      $zero, wrong_buf
        la      $t0, guessed
        li      $t1, 26
rg_loop:
        sb      $zero, 0($t0)
        addi    $t0, $t0, 1
        addi    $t1, $t1, -1
        bnez    $t1, rg_loop
        jr      $ra

# count_in_word(letter) -> $v0 = how many times the letter occurs in the word
count_in_word:
        lw      $t0, cur_word
        li      $v0, 0
ciw_loop:
        lb      $t1, 0($t0)
        beqz    $t1, ciw_done
        bne     $t1, $a0, ciw_next
        addi    $v0, $v0, 1
ciw_next:
        addi    $t0, $t0, 1
        j       ciw_loop
ciw_done:
        jr      $ra

# word_solved -> $v0 = 1 if every letter of the word has been guessed
word_solved:
        lw      $t0, cur_word
ws_loop:
        lb      $t1, 0($t0)
        beqz    $t1, ws_yes
        addi    $t1, $t1, -65
        lb      $t2, guessed($t1)
        beqz    $t2, ws_no
        addi    $t0, $t0, 1
        j       ws_loop
ws_yes:
        li      $v0, 1
        jr      $ra
ws_no:
        li      $v0, 0
        jr      $ra

# to_upper(char) -> $v0
to_upper:
        move    $v0, $a0
        blt     $a0, 'a', tu_ret
        bgt     $a0, 'z', tu_ret
        addi    $v0, $a0, -32
tu_ret:
        jr      $ra

# print_state: "Word : _ E _ _   Lives: 4   Missed: XZ"
print_state:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        print_str(c_word)
        lw      $t5, cur_word
ps_loop:
        lb      $t6, 0($t5)
        beqz    $t6, ps_after_word
        addi    $t7, $t6, -65
        lb      $t7, guessed($t7)
        bnez    $t7, ps_show
        li      $t6, '_'
ps_show:
        print_char($t6)                 # macro only touches $a0/$v0
        print_str(space1)
        addi    $t5, $t5, 1
        j       ps_loop
ps_after_word:
        print_str(c_lives)
        lw      $t0, wrong_count
        li      $t1, MAX_WRONG
        sub     $t0, $t1, $t0
        print_int($t0)
        print_str(c_missed)
        la      $a0, wrong_buf
        li      $v0, 4
        syscall
        print_str(newline)
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

################################################################################
#  ======================  SCENE DRAWING  ======================
################################################################################

# draw_scene: repaints everything from the current game state
draw_scene:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        li      $a0, COLOR_BG
        jal     fill_screen
        li      $a0, 30
        li      $a1, 1
        la      $a2, title_txt
        li      $a3, COLOR_GOLD
        jal     draw_text
        jal     draw_lives
        jal     draw_gallows
        lw      $a0, wrong_count
        jal     draw_figure
        li      $a0, 0
        jal     draw_word_row
        jal     draw_miss_row
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

# draw_lives: "LIVES n" at (30, 8)
draw_lives:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        li      $a0, 30
        li      $a1, 8
        la      $a2, lives_txt
        li      $a3, COLOR_TEXT
        jal     draw_text
        lw      $t0, wrong_count
        li      $a2, MAX_WRONG
        sub     $a2, $a2, $t0
        li      $a0, 54
        li      $a1, 8
        li      $a3, COLOR_GOLD
        jal     draw_number
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

# draw_gallows: base, pole, beam and rope
draw_gallows:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        li      $a0, 2                  # base  (22 x 1) at y = 38
        li      $a1, 38
        li      $a2, 22
        li      $a3, 1
        li      $t0, COLOR_WOOD
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        li      $a0, 5                  # pole  (1 x 34) at x = 5
        li      $a1, 4
        li      $a2, 1
        li      $a3, 34
        li      $t0, COLOR_WOOD
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        li      $a0, 5                  # beam  (13 x 1) at y = 4
        li      $a1, 4
        li      $a2, 13
        li      $a3, 1
        li      $t0, COLOR_WOOD
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        li      $a0, 17                 # rope  (1 x 3) at x = 17
        li      $a1, 5
        li      $a2, 1
        li      $a3, 3
        li      $t0, COLOR_ROPE
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

# draw_figure(parts): draws the first `parts` body parts (0..6)
draw_figure:
        addi    $sp, $sp, -8
        sw      $ra, 4($sp)
        sw      $s0, 0($sp)
        move    $s0, $a0
        blez    $s0, df_done
        # 1: head - 5x5 ring centred on x = 17
        li      $a0, 15
        li      $a1, 8
        li      $a2, 5
        li      $a3, 5
        li      $t0, COLOR_BODY
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        li      $a0, 16
        li      $a1, 9
        li      $a2, 3
        li      $a3, 3
        li      $t0, COLOR_BG
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        li      $a0, 15
        li      $a1, 8
        li      $a2, COLOR_BG
        jal     draw_pixel
        li      $a0, 19
        li      $a1, 8
        li      $a2, COLOR_BG
        jal     draw_pixel
        li      $a0, 15
        li      $a1, 12
        li      $a2, COLOR_BG
        jal     draw_pixel
        li      $a0, 19
        li      $a1, 12
        li      $a2, COLOR_BG
        jal     draw_pixel
        li      $t0, 1
        beq     $s0, $t0, df_done
        # 2: body - 1 x 9 line
        li      $a0, 17
        li      $a1, 13
        li      $a2, 1
        li      $a3, 9
        li      $t0, COLOR_BODY
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        li      $t0, 2
        beq     $s0, $t0, df_done
        # 3: left arm - diagonal down-left from (16,14)
        li      $a0, 16
        li      $a1, 14
        li      $a2, -1
        jal     draw_diag
        li      $t0, 3
        beq     $s0, $t0, df_done
        # 4: right arm - diagonal down-right from (18,14)
        li      $a0, 18
        li      $a1, 14
        li      $a2, 1
        jal     draw_diag
        li      $t0, 4
        beq     $s0, $t0, df_done
        # 5: left leg from (16,22)
        li      $a0, 16
        li      $a1, 22
        li      $a2, -1
        jal     draw_diag
        li      $t0, 5
        beq     $s0, $t0, df_done
        # 6: right leg from (18,22)
        li      $a0, 18
        li      $a1, 22
        li      $a2, 1
        jal     draw_diag
df_done:
        lw      $ra, 4($sp)
        lw      $s0, 0($sp)
        addi    $sp, $sp, 8
        jr      $ra

# draw_diag(x, y, dx): 4 pixels stepping (dx, +1) each time, in the body color
draw_diag:
        addi    $sp, $sp, -20
        sw      $ra, 16($sp)
        sw      $s0, 12($sp)
        sw      $s1, 8($sp)
        sw      $s2, 4($sp)
        sw      $s3, 0($sp)
        move    $s0, $a0
        move    $s1, $a1
        move    $s2, $a2
        li      $s3, 4
dd_loop:
        move    $a0, $s0
        move    $a1, $s1
        li      $a2, COLOR_BODY
        jal     draw_pixel
        add     $s0, $s0, $s2
        addi    $s1, $s1, 1
        addi    $s3, $s3, -1
        bnez    $s3, dd_loop
        lw      $ra, 16($sp)
        lw      $s0, 12($sp)
        lw      $s1, 8($sp)
        lw      $s2, 4($sp)
        lw      $s3, 0($sp)
        addi    $sp, $sp, 20
        jr      $ra

# draw_word_row(reveal_all): letters guessed -> white, unknown -> gold '_'
# (or red letter when reveal_all = 1 after a loss)
draw_word_row:
        addi    $sp, $sp, -16
        sw      $ra, 12($sp)
        sw      $s0, 8($sp)
        sw      $s1, 4($sp)
        sw      $s2, 0($sp)
        move    $s2, $a0                # reveal flag
        lw      $s0, cur_word
        li      $s1, 2                  # x position
dwr_loop:
        lb      $a2, 0($s0)
        beqz    $a2, dwr_done
        addi    $t0, $a2, -65
        lb      $t0, guessed($t0)
        li      $a3, COLOR_TEXT
        bnez    $t0, dwr_draw
        li      $a3, COLOR_BAD
        bnez    $s2, dwr_draw           # reveal missing letters in red
        li      $a2, '_'
        li      $a3, COLOR_GOLD
dwr_draw:
        move    $a0, $s1
        li      $a1, WORD_ROW_Y
        jal     draw_glyph
        addi    $s1, $s1, 4
        addi    $s0, $s0, 1
        j       dwr_loop
dwr_done:
        lw      $ra, 12($sp)
        lw      $s0, 8($sp)
        lw      $s1, 4($sp)
        lw      $s2, 0($sp)
        addi    $sp, $sp, 16
        jr      $ra

# draw_miss_row: "MISS" label followed by the wrong letters in red
draw_miss_row:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        li      $a0, 2
        li      $a1, MISS_ROW_Y
        la      $a2, miss_txt
        li      $a3, COLOR_TEXT
        jal     draw_text
        li      $a0, 22
        li      $a1, MISS_ROW_Y
        la      $a2, wrong_buf
        li      $a3, COLOR_BAD
        jal     draw_text
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

# draw_number(x, y, value, color)
draw_number:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        move    $t8, $a0                # x
        move    $t7, $a1                # y
        move    $t6, $a3                # color
        move    $a0, $a2
        la      $a1, num_buf
        jal     int_to_str
        move    $a0, $t8
        move    $a1, $t7
        la      $a2, num_buf
        move    $a3, $t6
        jal     draw_text
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

# int_to_str(value >= 0, buffer)
int_to_str:
        move    $t0, $a1
        li      $t1, 10
        li      $t2, 0
        bnez    $a0, its_push
        li      $t3, '0'
        sb      $t3, 0($t0)
        sb      $zero, 1($t0)
        jr      $ra
its_push:
        beqz    $a0, its_pop
        div     $a0, $t1
        mfhi    $t3
        mflo    $a0
        addi    $t3, $t3, '0'
        addi    $sp, $sp, -4
        sw      $t3, 0($sp)
        addi    $t2, $t2, 1
        j       its_push
its_pop:
        beqz    $t2, its_end
        lw      $t3, 0($sp)
        addi    $sp, $sp, 4
        sb      $t3, 0($t0)
        addi    $t0, $t0, 1
        addi    $t2, $t2, -1
        j       its_pop
its_end:
        sb      $zero, 0($t0)
        jr      $ra

################################################################################
#  ======================  GRAPHICS LIBRARY  ======================
#  (shared with the other two games; see tictactoe.asm for commentary)
################################################################################
fill_screen:
        li      $t0, DISPLAY_BASE
        li      $t1, SCREEN_WORDS
fs_loop:
        sw      $a0, 0($t0)
        addi    $t0, $t0, 4
        addi    $t1, $t1, -1
        bnez    $t1, fs_loop
        jr      $ra

draw_pixel:
        bltz    $a0, dp_done
        bltz    $a1, dp_done
        bge     $a0, SCREEN_W, dp_done
        bge     $a1, SCREEN_H, dp_done
        sll     $t0, $a1, 6
        add     $t0, $t0, $a0
        sll     $t0, $t0, 2
        li      $t1, DISPLAY_BASE
        add     $t0, $t0, $t1
        sw      $a2, 0($t0)
dp_done:
        jr      $ra

# draw_rect(x, y, w, h, color-on-stack)
draw_rect:
        lw      $t9, 0($sp)
        addi    $sp, $sp, -28
        sw      $ra, 24($sp)
        sw      $s0, 20($sp)
        sw      $s1, 16($sp)
        sw      $s2, 12($sp)
        sw      $s3, 8($sp)
        sw      $s4, 4($sp)
        sw      $s5, 0($sp)
        move    $s0, $a0
        move    $s1, $a1
        move    $s2, $a2
        move    $s3, $a3
        move    $s4, $t9
        li      $s5, 0
dr_row:
        bge     $s5, $s3, dr_done
        li      $t8, 0
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

glyph_index:
        blt     $a0, '0', gi_not_digit
        bgt     $a0, '9', gi_not_digit
        addi    $v0, $a0, -48
        jr      $ra
gi_not_digit:
        blt     $a0, 'A', gi_not_upper
        bgt     $a0, 'Z', gi_not_upper
        addi    $v0, $a0, -55
        jr      $ra
gi_not_upper:
        blt     $a0, 'a', gi_symbol
        bgt     $a0, 'z', gi_symbol
        addi    $v0, $a0, -87
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
        li      $v0, 38
gi_ret:
        jr      $ra

draw_glyph:
        addi    $sp, $sp, -28
        sw      $ra, 24($sp)
        sw      $s0, 20($sp)
        sw      $s1, 16($sp)
        sw      $s2, 12($sp)
        sw      $s3, 8($sp)
        sw      $s4, 4($sp)
        sw      $s5, 0($sp)
        move    $s0, $a0
        move    $s1, $a1
        move    $s3, $a3
        move    $a0, $a2
        jal     glyph_index
        la      $s2, font
        sll     $t0, $v0, 2
        add     $t0, $t0, $v0
        add     $s2, $s2, $t0
        li      $s4, 0
dg_row:
        lb      $s5, 0($s2)
        li      $t8, 0
dg_col:
        li      $t1, 4
        srlv    $t1, $t1, $t8
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
# read_line(buffer, size): syscall 8, strips the trailing newline, $v0 = length
read_line:
        move    $t0, $a0
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
