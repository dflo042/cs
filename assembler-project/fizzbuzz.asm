# Assignment 3, Part 5: FizzBuzz for 1 through 100

.data
fizztext: .asciiz "Fizz"
buzztext: .asciiz "Buzz"
fizzbuzztext: .asciiz "FizzBuzz"

.text
main:
#Start and I
li $t1, 1
#End
li $t2, 101
#Divisors
li $t3, 3
li $t5, 5
li $t8, 15

loop:
#Divisible by 15
rem $t0, $t1, $t8
beq $t0, $zero, fizzbuzz
#Divisible by 3
rem $t0, $t1, $t3
beq $t0, $zero, fizz
#Divisible by 5
rem $t0, $t1, $t5
beq $t0, $zero, buzz

#Otherwise print the number
move $a0, $t1
li $v0, 1
syscall
j next

fizzbuzz:
li $v0, 4
la $a0, fizzbuzztext
syscall
j next

fizz:
li $v0, 4
la $a0, fizztext
syscall
j next

buzz:
li $v0, 4
la $a0, buzztext
syscall

next:
#Print newline
li $a0, 10
li $v0, 11
syscall

#Increments
addi $t1, $t1, 1
#Loop back
bne $t1, $t2, loop

#Exit
li $v0, 10
syscall
