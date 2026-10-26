# Assembler and Disassembler Project

Assignment 5 for CS 240. A MIPS assembler and disassembler written in Java and
tested on my FizzBuzz program from Assignment 3.

## Files

| File | What it is |
|---|---|
| `Assembler.java` | reads a .asm file and writes a .mhc-ascii and a .mhc-bin file |
| `Disassembler.java` | reads either machine code file and writes a .asm file |
| `fizzbuzz.asm` | my original FizzBuzz source |
| `fizzbuzz.mhc-ascii` | FizzBuzz machine code as readable 0 and 1 characters |
| `fizzbuzz.mhc-bin` | FizzBuzz machine code as raw bytes |
| `fizzbuzz_rebuilt.asm` | what the disassembler gives back from fizzbuzz.mhc-bin |
| `tests/` | test inputs and `run_tests.sh` and the saved `test_log.txt` |

## How to run

```
javac Assembler.java Disassembler.java
java Assembler fizzbuzz.asm                    writes fizzbuzz.mhc-ascii and fizzbuzz.mhc-bin
java Disassembler fizzbuzz.mhc-bin out.asm     works with the .mhc-ascii file too
java Assembler out.asm                         should give the same two machine code files back
```

To run every test from this folder

```
sh tests/run_tests.sh
```

If `Mars.jar` is in this folder the tests also compare my machine code against
the MARS dump of the same program and run the original and rebuilt FizzBuzz in
MARS to check they print the same thing.

## File layout

Both machine code files hold the same list of 32 bit words. The .mhc-bin file
stores each word as four bytes with the most significant byte first so the
opcode is the first byte on disk. The .mhc-ascii file stores each word as 32
`0` and `1` characters on its own line. Blank lines separate the three parts.

| Word | Meaning |
|---|---|
| 0 | the letters `MHC1` as a word (0x4D484331) so the disassembler knows what it is reading |
| 1 | text start address. always 0x00400000 like MARS |
| 2 | number of instruction words |
| 3 | data start address. always 0x10010000 like MARS |
| 4 | number of data bytes |
| 5 and on | the instruction words then the data bytes four per word in address order padded with zeros |

The header is what lets the disassembler tell instructions from data. Word 2
says how many words after the header are instructions and word 4 says how
many bytes after that are data.

Data bytes are written in address order. The assembler builds `.word` values
little endian like MARS does so a `.word 7` becomes the bytes 07 00 00 00.
Strings and `.byte` values are stored exactly as given.

## What the assembler supports

Directives `.text` `.data` `.globl` `.asciiz` `.ascii` `.word` `.byte` `.space` `.align`.

Real instructions `add addu sub subu and or xor nor slt sltu sll srl sra jr jalr
mult multu div divu mfhi mflo syscall break addi addiu slti sltiu andi ori xori
lui lw sw lb lbu lh lhu sb sh beq bne j jal`.

Pseudoinstructions `li la move rem div nop b beqz bnez blt bgt ble bge` and
`lw` or `sw` with a label. They expand the same way MARS 4.5 expands them so the
machine code comes out identical to a MARS dump.

| Pseudo | Becomes |
|---|---|
| `li $t1, 1` | `addiu $t1, $zero, 1` (ori for 32768 to 65535 and lui plus ori for bigger) |
| `la $a0, label` | `lui $at, hi` then `ori $a0, $at, lo` |
| `move $a0, $t1` | `addu $a0, $zero, $t1` |
| `rem $t0, $t1, $t8` | `bne $t8, $zero, 1` then `break` then `div $t1, $t8` then `mfhi $t0` |

Labels can go on their own line or in front of an instruction or data. Comments
start with `#`. Registers can be names like `$t0` or numbers like `$8`.

Anything else stops with a message that says the line number and what was
wrong. For example

```
error line 3 unsupported instruction mul in mul $t1, $t0, $t0
error line 3 label nowhere is not defined anywhere
error line 2 immediate 40000 does not fit in 16 signed bits
```

## What the disassembler does

It reads the header and decodes every instruction word back to MARS syntax.
Branch and jump targets get labels named `L1` `L2` and so on and the first
instruction is labeled `main`. The data bytes come back as `.byte` lines so
the exact bytes are kept. Comments and the original label names and
pseudoinstruction spellings are not recovered. The rebuilt program assembles to
the exact same bytes and prints the same FizzBuzz output in MARS.

Bad input stops with a message. A binary file that is not a multiple of four
bytes or whose header does not match its length is rejected and so is a text
line that is not exactly 32 zeros and ones. An opcode or funct I do not support
reports the word and its address.
