################################################################################
#  blackjack.asm  --  Blackjack (player vs. dealer) for the MARS MIPS simulator
#
#  Module 4: MIPS Game Project  (Game 2 of 3)
#  Author : Dylan Flores
#
#  HOW TO RUN (MARS 4.5)
#    1. Open this file in MARS and assemble it (F3).
#    2. Tools -> Bitmap Display.  Set:
#         Unit Width  = 4      Unit Height = 4
#         Display Width = 256  Display Height = 256
#         Base address for display = 0x10008000 ($gp)
#       Click "Connect to MIPS".
#    3. Run (F5).  Answer the prompts in the Run I/O console.
#
#  GAME
#    Standard blackjack against a dealer that must hit on 16 and stand on 17.
#    A 52-card deck is stored in a byte array and shuffled (Fisher-Yates) with
#    the MARS random syscall. Cards are drawn on the bitmap display (rank and
#    suit letter, red for hearts/diamonds, black for spades/clubs); the
#    dealer's second card is face down until the player stands.
#    Aces count 11 and automatically drop to 1 when a hand would bust.
#    The console mirrors every hand and result in text.
#
#  CARD ENCODING  (0..51)
#    rank = card % 13   (0 = Ace, 1..8 = 2..9, 9 = 10, 10 = J, 11 = Q, 12 = K)
#    suit = card / 13   (0 = Spades, 1 = Hearts, 2 = Diamonds, 3 = Clubs)
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

        .eqv  COLOR_FELT    0x00206838    # green table felt
        .eqv  COLOR_TEXT    0x00FFFFFF    # white labels
        .eqv  COLOR_GOLD    0x00FFD040    # yellow status text
        .eqv  COLOR_CARD    0x00F8F8F0    # card face
        .eqv  COLOR_BACK    0x002040A0    # card back (dark blue)
        .eqv  COLOR_BACK2   0x004878D0    # card back pattern (light blue)
        .eqv  COLOR_RED     0x00D82020    # hearts / diamonds
        .eqv  COLOR_BLACK   0x00101010    # spades / clubs

        .eqv  CARD_W        9
        .eqv  CARD_H        12
        .eqv  CARD_PITCH    10
        .eqv  DEALER_Y      7
        .eqv  PLAYER_Y      27
        .eqv  MAX_HAND      12

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
deck:           .space 52               # 52 card codes, shuffled each round
deck_pos:       .word  0                # next card to deal
player_hand:    .space MAX_HAND
dealer_hand:    .space MAX_HAND
player_count:   .word  0
dealer_count:   .word  0
wins:           .word  0
losses:         .word  0
pushes:         .word  0
cur_msg:        .word  0                # pointer to the message shown on row 48
input_buf:      .space 64
num_buf:        .space 12               # scratch for int_to_str

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

suit_letters:   .byte 'S','H','D','C'
                .align 2

# ---- strings drawn on the display ----
dealer_lbl:     .asciiz "DEALER"
player_lbl:     .asciiz "PLAYER"
you_lbl:        .asciiz "YOU"
dlr_lbl:        .asciiz "DLR"
w_lbl:          .asciiz "W"
l_lbl:          .asciiz "L"
p_lbl:          .asciiz "P"
unknown_lbl:    .asciiz "?"
msg_hit_stand:  .asciiz "H HIT  S STAND"
msg_blackjack:  .asciiz "BLACKJACK!"
msg_you_win:    .asciiz "YOU WIN"
msg_dealer_win: .asciiz "DEALER WINS"
msg_push:       .asciiz "PUSH"
msg_bust:       .asciiz "BUST"
msg_dealer_bust:.asciiz "DEALER BUSTS"

# ---- console strings ----
welcome:        .asciiz "=== BLACKJACK (MIPS) ===\nGet closer to 21 than the dealer without going over.\nDealer hits on 16 and stands on 17. Aces count 11 or 1.\n\n"
round_hdr:      .asciiz "\n---------------- NEW ROUND ----------------\n"
c_dealer_shows: .asciiz "Dealer shows : "
c_hidden:       .asciiz " [??]"
c_your_hand:    .asciiz "Your hand    : "
c_total:        .asciiz "   (total "
c_close:        .asciiz ")\n"
c_prompt:       .asciiz "(H)it or (S)tand? "
c_bad_hs:       .asciiz "  ! Please type H to hit or S to stand.\n"
c_you_draw:     .asciiz "You draw     : "
c_21_stand:     .asciiz "You have 21 - standing automatically.\n"
c_bust:         .asciiz "\n*** BUST! You went over 21. Dealer wins. ***\n"
c_dealer_hand:  .asciiz "Dealer hand  : "
c_dealer_reveal:.asciiz "Dealer reveals: "
c_dealer_hits:  .asciiz "Dealer hits  : "
c_dealer_bust:  .asciiz "\n*** Dealer busts! You win! ***\n"
c_you_win:      .asciiz "\n*** You win! ***\n"
c_dealer_wins:  .asciiz "\n*** Dealer wins. ***\n"
c_push:         .asciiz "\n*** Push - it's a tie. ***\n"
c_blackjack:    .asciiz "\n*** BLACKJACK! You win! ***\n"
c_both_bj:      .asciiz "\n*** Both have blackjack - push. ***\n"
c_record1:      .asciiz "Record: "
c_record2:      .asciiz " won, "
c_record3:      .asciiz " lost, "
c_record4:      .asciiz " pushed.\n"
c_again:        .asciiz "Play another round? (Y/N): "
c_bad_yn:       .asciiz "  ! Please answer Y or N.\n"
c_bye:          .asciiz "Thanks for playing!\n"
newline:        .asciiz "\n"
space1:         .asciiz " "
rank_10:        .asciiz "10"

################################################################################
        .text
        .globl main
################################################################################
main:
        print_str(welcome)
        # seed the random generator (id 0) from the system clock
        li      $v0, 30
        syscall                         # $a0 = low 32 bits of time
        move    $a1, $a0
        li      $a0, 0
        li      $v0, 40
        syscall

round_start:
        print_str(round_hdr)
        jal     shuffle_deck
        sw      $zero, player_count
        sw      $zero, dealer_count

        la      $a0, player_hand
        la      $a1, player_count
        jal     deal_card
        la      $a0, dealer_hand
        la      $a1, dealer_count
        jal     deal_card
        la      $a0, player_hand
        la      $a1, player_count
        jal     deal_card
        la      $a0, dealer_hand
        la      $a1, dealer_count
        jal     deal_card

        la      $t0, msg_hit_stand
        sw      $t0, cur_msg
        li      $a0, 1                  # dealer's 2nd card hidden
        jal     redraw_table
        jal     print_table_hidden

        # natural blackjack check
        la      $a0, player_hand
        lw      $a1, player_count
        jal     hand_value
        li      $t0, 21
        bne     $v0, $t0, player_turn
        la      $a0, dealer_hand
        lw      $a1, dealer_count
        jal     hand_value
        li      $t0, 21
        beq     $v0, $t0, both_blackjack
        la      $t0, msg_blackjack
        sw      $t0, cur_msg
        lw      $t1, wins
        addi    $t1, $t1, 1
        sw      $t1, wins
        li      $a0, 0
        jal     redraw_table
        jal     print_dealer_full
        print_str(c_blackjack)
        j       round_end
both_blackjack:
        la      $t0, msg_push
        sw      $t0, cur_msg
        lw      $t1, pushes
        addi    $t1, $t1, 1
        sw      $t1, pushes
        li      $a0, 0
        jal     redraw_table
        jal     print_dealer_full
        print_str(c_both_bj)
        j       round_end

player_turn:
        print_str(c_prompt)
        la      $a0, input_buf
        li      $a1, 64
        jal     read_line
        lb      $a0, input_buf
        jal     to_upper
        li      $t0, 'H'
        beq     $v0, $t0, player_hits
        li      $t0, 'S'
        beq     $v0, $t0, dealer_turn
        print_str(c_bad_hs)
        j       player_turn

player_hits:
        la      $a0, player_hand
        la      $a1, player_count
        jal     deal_card
        move    $s2, $v0                # keep the card (print_str clobbers $v0)
        print_str(c_you_draw)
        move    $a0, $s2
        jal     print_card
        print_str(newline)
        li      $a0, 1
        jal     redraw_table
        jal     print_player_line
        la      $a0, player_hand
        lw      $a1, player_count
        jal     hand_value
        bgt     $v0, 21, player_bust
        li      $t0, 21
        bne     $v0, $t0, player_turn
        print_str(c_21_stand)
        j       dealer_turn

player_bust:
        la      $t0, msg_bust
        sw      $t0, cur_msg
        lw      $t1, losses
        addi    $t1, $t1, 1
        sw      $t1, losses
        li      $a0, 0
        jal     redraw_table
        print_str(c_bust)
        j       round_end

dealer_turn:
        li      $a0, 0                  # reveal the hole card
        jal     redraw_table
        print_str(c_dealer_reveal)
        la      $a0, dealer_hand
        lw      $a1, dealer_count
        jal     print_hand
        print_str(newline)
        li      $s3, 0                  # $s3 = 1 once the dealer has hit
dealer_loop:
        la      $a0, dealer_hand
        lw      $a1, dealer_count
        jal     hand_value
        bge     $v0, 17, dealer_done    # stands on 17 or more
        la      $a0, dealer_hand
        la      $a1, dealer_count
        jal     deal_card
        move    $s2, $v0                # keep the card (print_str clobbers $v0)
        print_str(c_dealer_hits)
        move    $a0, $s2
        jal     print_card
        print_str(newline)
        li      $s3, 1
        li      $a0, 0
        jal     redraw_table
        j       dealer_loop

dealer_done:
        move    $s0, $v0                # dealer total
        la      $a0, player_hand
        lw      $a1, player_count
        jal     hand_value
        move    $s1, $v0                # player total
        jal     print_dealer_full       # final dealer hand with total
        bgt     $s0, 21, dealer_busted
        bgt     $s1, $s0, player_wins
        blt     $s1, $s0, dealer_wins
        # push
        la      $t0, msg_push
        sw      $t0, cur_msg
        lw      $t1, pushes
        addi    $t1, $t1, 1
        sw      $t1, pushes
        print_str(c_push)
        j       round_end_redraw
dealer_busted:
        la      $t0, msg_dealer_bust
        sw      $t0, cur_msg
        lw      $t1, wins
        addi    $t1, $t1, 1
        sw      $t1, wins
        print_str(c_dealer_bust)
        j       round_end_redraw
player_wins:
        la      $t0, msg_you_win
        sw      $t0, cur_msg
        lw      $t1, wins
        addi    $t1, $t1, 1
        sw      $t1, wins
        print_str(c_you_win)
        j       round_end_redraw
dealer_wins:
        la      $t0, msg_dealer_win
        sw      $t0, cur_msg
        lw      $t1, losses
        addi    $t1, $t1, 1
        sw      $t1, losses
        print_str(c_dealer_wins)

round_end_redraw:
        li      $a0, 0
        jal     redraw_table
round_end:
        print_str(c_record1)
        lw      $t0, wins
        print_int($t0)
        print_str(c_record2)
        lw      $t0, losses
        print_int($t0)
        print_str(c_record3)
        lw      $t0, pushes
        print_int($t0)
        print_str(c_record4)

ask_again:
        print_str(c_again)
        la      $a0, input_buf
        li      $a1, 64
        jal     read_line
        lb      $a0, input_buf
        jal     to_upper
        li      $t0, 'Y'
        beq     $v0, $t0, round_start
        li      $t0, 'N'
        beq     $v0, $t0, exit_game
        print_str(c_bad_yn)
        j       ask_again

exit_game:
        print_str(c_bye)
        li      $v0, 10
        syscall

################################################################################
#  ======================  DECK / HAND PROCEDURES  ======================
################################################################################

# shuffle_deck: fills deck with 0..51 then Fisher-Yates shuffles it
shuffle_deck:
        la      $t0, deck
        li      $t1, 0
sd_fill:
        sb      $t1, 0($t0)
        addi    $t0, $t0, 1
        addi    $t1, $t1, 1
        blt     $t1, 52, sd_fill
        sw      $zero, deck_pos

        li      $t2, 51                 # i = 51 down to 1
sd_loop:
        li      $a0, 0                  # generator id
        addi    $a1, $t2, 1             # upper bound (exclusive) = i + 1
        li      $v0, 42
        syscall                         # $a0 = j in [0, i]
        la      $t0, deck
        add     $t3, $t0, $t2           # &deck[i]
        add     $t4, $t0, $a0           # &deck[j]
        lb      $t5, 0($t3)
        lb      $t6, 0($t4)
        sb      $t6, 0($t3)
        sb      $t5, 0($t4)             # swap
        addi    $t2, $t2, -1
        bgtz    $t2, sd_loop
        jr      $ra

# deal_card(hand_addr, count_addr) -> $v0 = card dealt; appends to the hand.
# Reshuffles if the deck is somehow exhausted (defensive edge case).
deal_card:
        addi    $sp, $sp, -12
        sw      $ra, 8($sp)
        sw      $s0, 4($sp)
        sw      $s1, 0($sp)
        move    $s0, $a0
        move    $s1, $a1
        lw      $t0, deck_pos
        blt     $t0, 52, dc_ok
        jal     shuffle_deck
        lw      $t0, deck_pos
dc_ok:
        lb      $v0, deck($t0)
        addi    $t0, $t0, 1
        sw      $t0, deck_pos
        lw      $t1, 0($s1)             # current count
        bge     $t1, MAX_HAND, dc_done  # hand full: ignore (cannot happen in play)
        add     $t2, $s0, $t1
        sb      $v0, 0($t2)
        addi    $t1, $t1, 1
        sw      $t1, 0($s1)
dc_done:
        lw      $ra, 8($sp)
        lw      $s0, 4($sp)
        lw      $s1, 0($sp)
        addi    $sp, $sp, 12
        jr      $ra

# card_value(card) -> $v0 = 11 for an ace, 10 for 10/J/Q/K, else the pip value
card_value:
        li      $t0, 13
        div     $a0, $t0
        mfhi    $t1                     # rank
        bnez    $t1, cv_not_ace
        li      $v0, 11
        jr      $ra
cv_not_ace:
        addi    $v0, $t1, 1             # rank 1..8 -> 2..9, 9 -> 10
        ble     $v0, 10, cv_ret
        li      $v0, 10                 # J, Q, K
cv_ret:
        jr      $ra

# hand_value(hand_addr, count) -> $v0 = best total (aces drop from 11 to 1)
hand_value:
        addi    $sp, $sp, -20
        sw      $ra, 16($sp)
        sw      $s0, 12($sp)
        sw      $s1, 8($sp)
        sw      $s2, 4($sp)
        sw      $s3, 0($sp)
        move    $s0, $a0                # pointer
        move    $s1, $a1                # remaining
        li      $s2, 0                  # total
        li      $s3, 0                  # aces counted as 11
hv_loop:
        blez    $s1, hv_adjust
        lb      $a0, 0($s0)
        jal     card_value
        add     $s2, $s2, $v0
        li      $t0, 11
        bne     $v0, $t0, hv_next
        addi    $s3, $s3, 1
hv_next:
        addi    $s0, $s0, 1
        addi    $s1, $s1, -1
        j       hv_loop
hv_adjust:
        ble     $s2, 21, hv_done
        blez    $s3, hv_done
        addi    $s2, $s2, -10           # one ace: 11 -> 1
        addi    $s3, $s3, -1
        j       hv_adjust
hv_done:
        move    $v0, $s2
        lw      $ra, 16($sp)
        lw      $s0, 12($sp)
        lw      $s1, 8($sp)
        lw      $s2, 4($sp)
        lw      $s3, 0($sp)
        addi    $sp, $sp, 20
        jr      $ra

# to_upper(char) -> $v0 = upper-case version of an ASCII letter
to_upper:
        move    $v0, $a0
        blt     $a0, 'a', tu_ret
        bgt     $a0, 'z', tu_ret
        addi    $v0, $a0, -32
tu_ret:
        jr      $ra

################################################################################
#  ======================  CONSOLE OUTPUT  ======================
################################################################################

# print_card(card): prints e.g. "AS", "10H", "KD" followed by a space
print_card:
        addi    $sp, $sp, -8
        sw      $ra, 4($sp)
        sw      $s0, 0($sp)
        move    $s0, $a0
        li      $t0, 13
        div     $s0, $t0
        mfhi    $t1                     # rank
        mflo    $t2                     # suit
        bnez    $t1, pc_not_ace
        li      $t3, 'A'
        j       pc_one_char
pc_not_ace:
        li      $t4, 9
        bne     $t1, $t4, pc_not_ten
        print_str(rank_10)
        j       pc_suit
pc_not_ten:
        li      $t4, 10
        beq     $t1, $t4, pc_jack
        li      $t4, 11
        beq     $t1, $t4, pc_queen
        li      $t4, 12
        beq     $t1, $t4, pc_king
        addi    $t3, $t1, '1'           # rank 1..8 -> '2'..'9'
        j       pc_one_char
pc_jack:
        li      $t3, 'J'
        j       pc_one_char
pc_queen:
        li      $t3, 'Q'
        j       pc_one_char
pc_king:
        li      $t3, 'K'
pc_one_char:
        print_char($t3)
pc_suit:
        li      $t0, 13
        div     $s0, $t0
        mflo    $t2
        lb      $t3, suit_letters($t2)
        print_char($t3)
        print_str(space1)
        lw      $ra, 4($sp)
        lw      $s0, 0($sp)
        addi    $sp, $sp, 8
        jr      $ra

# print_hand(hand_addr, count): prints every card in the hand
print_hand:
        addi    $sp, $sp, -12
        sw      $ra, 8($sp)
        sw      $s0, 4($sp)
        sw      $s1, 0($sp)
        move    $s0, $a0
        move    $s1, $a1
ph_loop:
        blez    $s1, ph_done
        lb      $a0, 0($s0)
        jal     print_card
        addi    $s0, $s0, 1
        addi    $s1, $s1, -1
        j       ph_loop
ph_done:
        lw      $ra, 8($sp)
        lw      $s0, 4($sp)
        lw      $s1, 0($sp)
        addi    $sp, $sp, 12
        jr      $ra

# print_player_line: "Your hand    : 7H AD   (total 18)"
print_player_line:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        print_str(c_your_hand)
        la      $a0, player_hand
        lw      $a1, player_count
        jal     print_hand
        print_str(c_total)
        la      $a0, player_hand
        lw      $a1, player_count
        jal     hand_value
        print_int($v0)
        print_str(c_close)
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

# print_table_hidden: dealer's first card + [??], then the player line
print_table_hidden:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        print_str(c_dealer_shows)
        lb      $a0, dealer_hand
        jal     print_card
        print_str(c_hidden)
        print_str(newline)
        jal     print_player_line
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

# print_dealer_full: the whole dealer hand with its total
print_dealer_full:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        print_str(c_dealer_hand)
        la      $a0, dealer_hand
        lw      $a1, dealer_count
        jal     print_hand
        print_str(c_total)
        la      $a0, dealer_hand
        lw      $a1, dealer_count
        jal     hand_value
        print_int($v0)
        print_str(c_close)
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

################################################################################
#  ======================  TABLE DRAWING  ======================
################################################################################

# redraw_table(hide_dealer): repaints the whole display from the game state
redraw_table:
        addi    $sp, $sp, -8
        sw      $ra, 4($sp)
        sw      $s0, 0($sp)
        move    $s0, $a0                # hide flag

        li      $a0, COLOR_FELT
        jal     fill_screen

        li      $a0, 2
        li      $a1, 1
        la      $a2, dealer_lbl
        li      $a3, COLOR_TEXT
        jal     draw_text

        la      $a0, dealer_hand
        lw      $a1, dealer_count
        li      $a2, DEALER_Y
        move    $a3, $s0
        jal     draw_hand

        li      $a0, 2
        li      $a1, 21
        la      $a2, player_lbl
        li      $a3, COLOR_TEXT
        jal     draw_text

        la      $a0, player_hand
        lw      $a1, player_count
        li      $a2, PLAYER_Y
        li      $a3, 0
        jal     draw_hand

        move    $a0, $s0
        jal     draw_scores

        li      $a0, 2
        li      $a1, 48
        lw      $a2, cur_msg
        li      $a3, COLOR_GOLD
        jal     draw_text

        jal     draw_record

        lw      $ra, 4($sp)
        lw      $s0, 0($sp)
        addi    $sp, $sp, 8
        jr      $ra

# draw_hand(hand_addr, count, y, hide_second): draws a row of cards at x = 2 + 10*i
draw_hand:
        addi    $sp, $sp, -24
        sw      $ra, 20($sp)
        sw      $s0, 16($sp)
        sw      $s1, 12($sp)
        sw      $s2, 8($sp)
        sw      $s3, 4($sp)
        sw      $s4, 0($sp)
        move    $s0, $a0                # pointer
        move    $s1, $a1                # count
        move    $s2, $a2                # y
        move    $s3, $a3                # hide flag
        li      $s4, 0                  # index
dh_loop:
        bge     $s4, $s1, dh_done
        mul     $a0, $s4, CARD_PITCH
        addi    $a0, $a0, 2             # x
        move    $a1, $s2                # y
        add     $t0, $s0, $s4
        lb      $a2, 0($t0)             # card
        li      $a3, 1                  # face up
        beqz    $s3, dh_draw
        li      $t1, 1
        bne     $s4, $t1, dh_draw
        li      $a3, 0                  # second card face down
dh_draw:
        jal     draw_card
        addi    $s4, $s4, 1
        j       dh_loop
dh_done:
        lw      $ra, 20($sp)
        lw      $s0, 16($sp)
        lw      $s1, 12($sp)
        lw      $s2, 8($sp)
        lw      $s3, 4($sp)
        lw      $s4, 0($sp)
        addi    $sp, $sp, 24
        jr      $ra

# draw_card(x, y, card, face_up): 9 x 12 card with rank and suit letter
draw_card:
        addi    $sp, $sp, -24
        sw      $ra, 20($sp)
        sw      $s0, 16($sp)
        sw      $s1, 12($sp)
        sw      $s2, 8($sp)
        sw      $s3, 4($sp)
        sw      $s4, 0($sp)
        move    $s0, $a0                # x
        move    $s1, $a1                # y
        move    $s2, $a2                # card
        move    $s3, $a3                # face_up
        bnez    $s3, dcard_face

        # ---- face down: dark back with a light inner rectangle ----
        move    $a0, $s0
        move    $a1, $s1
        li      $a2, CARD_W
        li      $a3, CARD_H
        li      $t0, COLOR_BACK
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        addi    $a0, $s0, 2
        addi    $a1, $s1, 2
        li      $a2, 5
        li      $a3, 8
        li      $t0, COLOR_BACK2
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        addi    $a0, $s0, 3
        addi    $a1, $s1, 3
        li      $a2, 3
        li      $a3, 6
        li      $t0, COLOR_BACK
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4
        j       dcard_done

dcard_face:
        move    $a0, $s0
        move    $a1, $s1
        li      $a2, CARD_W
        li      $a3, CARD_H
        li      $t0, COLOR_CARD
        addi    $sp, $sp, -4
        sw      $t0, 0($sp)
        jal     draw_rect
        addi    $sp, $sp, 4

        # ink color from the suit: hearts(1)/diamonds(2) red, else black
        li      $t0, 13
        div     $s2, $t0
        mflo    $t1                     # suit
        mfhi    $t2                     # rank
        li      $s4, COLOR_BLACK
        li      $t3, 1
        beq     $t1, $t3, dcard_red
        li      $t3, 2
        bne     $t1, $t3, dcard_rank
dcard_red:
        li      $s4, COLOR_RED
dcard_rank:
        # rank glyph(s) at (x+1, y+1)
        li      $t3, 9
        bne     $t2, $t3, dcard_single
        addi    $a0, $s0, 1             # "10" needs two glyphs
        addi    $a1, $s1, 1
        la      $a2, rank_10
        move    $a3, $s4
        jal     draw_text
        j       dcard_suit
dcard_single:
        move    $a0, $t2
        jal     rank_char               # $v0 = 'A','2'..'9','J','Q','K'
        addi    $a0, $s0, 1
        addi    $a1, $s1, 1
        move    $a2, $v0
        move    $a3, $s4
        jal     draw_glyph
dcard_suit:
        li      $t0, 13
        div     $s2, $t0
        mflo    $t1
        lb      $a2, suit_letters($t1)
        addi    $a0, $s0, 5
        addi    $a1, $s1, 6
        move    $a3, $s4
        jal     draw_glyph
dcard_done:
        lw      $ra, 20($sp)
        lw      $s0, 16($sp)
        lw      $s1, 12($sp)
        lw      $s2, 8($sp)
        lw      $s3, 4($sp)
        lw      $s4, 0($sp)
        addi    $sp, $sp, 24
        jr      $ra

# rank_char(rank 0..12) -> $v0 = ASCII character for the rank (10 handled by caller)
rank_char:
        li      $v0, 'A'
        beqz    $a0, rc_ret
        li      $v0, 'J'
        li      $t0, 10
        beq     $a0, $t0, rc_ret
        li      $v0, 'Q'
        li      $t0, 11
        beq     $a0, $t0, rc_ret
        li      $v0, 'K'
        li      $t0, 12
        beq     $a0, $t0, rc_ret
        addi    $v0, $a0, '1'           # 1..8 -> '2'..'9'
rc_ret:
        jr      $ra

# draw_scores(hide_dealer): row 41 -> "YOU nn DLR nn" (or "DLR ?" while hidden)
draw_scores:
        addi    $sp, $sp, -8
        sw      $ra, 4($sp)
        sw      $s0, 0($sp)
        move    $s0, $a0
        li      $a0, 2
        li      $a1, 41
        la      $a2, you_lbl
        li      $a3, COLOR_TEXT
        jal     draw_text
        la      $a0, player_hand
        lw      $a1, player_count
        jal     hand_value
        li      $a0, 16
        li      $a1, 41
        move    $a2, $v0
        li      $a3, COLOR_GOLD
        jal     draw_number
        li      $a0, 30
        li      $a1, 41
        la      $a2, dlr_lbl
        li      $a3, COLOR_TEXT
        jal     draw_text
        beqz    $s0, ds_show_dealer
        li      $a0, 44
        li      $a1, 41
        la      $a2, unknown_lbl
        li      $a3, COLOR_GOLD
        jal     draw_text
        j       ds_done
ds_show_dealer:
        la      $a0, dealer_hand
        lw      $a1, dealer_count
        jal     hand_value
        li      $a0, 44
        li      $a1, 41
        move    $a2, $v0
        li      $a3, COLOR_GOLD
        jal     draw_number
ds_done:
        lw      $ra, 4($sp)
        lw      $s0, 0($sp)
        addi    $sp, $sp, 8
        jr      $ra

# draw_record: row 55 -> "W n L n P n"
draw_record:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        li      $a0, 2
        li      $a1, 55
        la      $a2, w_lbl
        li      $a3, COLOR_TEXT
        jal     draw_text
        li      $a0, 8
        li      $a1, 55
        lw      $a2, wins
        li      $a3, COLOR_GOLD
        jal     draw_number
        li      $a0, 22
        li      $a1, 55
        la      $a2, l_lbl
        li      $a3, COLOR_TEXT
        jal     draw_text
        li      $a0, 28
        li      $a1, 55
        lw      $a2, losses
        li      $a3, COLOR_GOLD
        jal     draw_number
        li      $a0, 42
        li      $a1, 55
        la      $a2, p_lbl
        li      $a3, COLOR_TEXT
        jal     draw_text
        li      $a0, 48
        li      $a1, 55
        lw      $a2, pushes
        li      $a3, COLOR_GOLD
        jal     draw_number
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

# draw_number(x, y, value, color): converts value to decimal text and draws it
draw_number:
        addi    $sp, $sp, -4
        sw      $ra, 0($sp)
        move    $t9, $a2
        move    $a2, $a3                # keep color in $a2 for a moment
        move    $a3, $a1                # y
        move    $t8, $a0                # x
        move    $a0, $t9                # value
        la      $a1, num_buf
        move    $t7, $a2                # color
        jal     int_to_str
        move    $a0, $t8
        move    $a1, $a3
        la      $a2, num_buf
        move    $a3, $t7
        jal     draw_text
        lw      $ra, 0($sp)
        addi    $sp, $sp, 4
        jr      $ra

# int_to_str(value >= 0, buffer): writes the decimal digits + NUL
int_to_str:
        move    $t0, $a1
        li      $t1, 10
        li      $t2, 0                  # digit count
        bnez    $a0, its_push
        li      $t3, '0'
        sb      $t3, 0($t0)
        sb      $zero, 1($t0)
        jr      $ra
its_push:                               # push digits (reversed) on the stack
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
