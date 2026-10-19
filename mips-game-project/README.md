# Assignment 4: MIPS Game Project

Tic-Tac-Toe, Blackjack and Hangman written in MIPS assembly for MARS 4.5, plus Java versions I wrote first to plan them out.

## Running the MIPS games

1. Open one of the files in `mips/` in MARS and assemble it (F3).
2. Tools -> Bitmap Display. Unit Width 4, Unit Height 4, Display Width 256, Display Height 256, Base address 0x10008000 ($gp). Click Connect to MIPS.
3. Run (F5). Type answers in the Run I/O box at the bottom.

Same display settings for all three games.

## Running the Java versions

```
cd java
javac TicTacToe.java Blackjack.java Hangman.java
java TicTacToe
java Blackjack
java Hangman
```

## Files

- `mips/tictactoe.asm`, `mips/blackjack.asm`, `mips/hangman.asm` - the games
- `java/` - Java planning versions, same procedure names and layout
- `display_renders/` - pictures of the bitmap display from my test runs
- `MIPS_Game_Project_Dylan_Flores.pdf` - the write up with design notes, tests and the code
