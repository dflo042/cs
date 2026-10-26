# Rebuilt by Disassembler.java from fizzbuzz.mhc-bin
# text starts at 0x00400000 with 45 instructions
# data starts at 0x10010000 with 19 bytes

.data
.byte 70, 105, 122, 122, 0, 66, 117, 122
.byte 122, 0, 70, 105, 122, 122, 66, 117
.byte 122, 122, 0

.text
main:
addiu $t1, $zero, 1
addiu $t2, $zero, 101
addiu $t3, $zero, 3
addiu $t5, $zero, 5
addiu $t8, $zero, 15
L1:
bne $t8, $zero, L2
break
L2:
div $t1, $t8
mfhi $t0
beq $t0, $zero, L5
bne $t3, $zero, L3
break
L3:
div $t1, $t3
mfhi $t0
beq $t0, $zero, L6
bne $t5, $zero, L4
break
L4:
div $t1, $t5
mfhi $t0
beq $t0, $zero, L7
addu $a0, $zero, $t1
addiu $v0, $zero, 1
syscall
j L8
L5:
addiu $v0, $zero, 4
lui $at, 4097
ori $a0, $at, 10
syscall
j L8
L6:
addiu $v0, $zero, 4
lui $at, 4097
ori $a0, $at, 0
syscall
j L8
L7:
addiu $v0, $zero, 4
lui $at, 4097
ori $a0, $at, 5
syscall
L8:
addiu $a0, $zero, 10
addiu $v0, $zero, 11
syscall
addi $t1, $t1, 1
bne $t1, $t2, L1
addiu $v0, $zero, 10
syscall
