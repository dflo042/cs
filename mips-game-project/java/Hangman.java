import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Random;

/**
 * Hangman.java -- Java planning / reference version of hangman.asm
 *
 * Module 4: MIPS Game Project (Game 3 of 3 - custom game)
 * Author  : Dylan Flores
 *
 * Written first to plan the MIPS version. The word table, the 26-entry
 * guessed[] flag array, the wrong-letter buffer and the six-part figure are
 * all the same as in hangman.asm, and the Display class models the MARS
 * Bitmap Display with the same geometry and 3x5 font.
 *
 * Run:  javac Hangman.java && java Hangman
 */
public class Hangman {

    static final int COLOR_BG = 0x181C28, COLOR_WOOD = 0xA0703A, COLOR_ROPE = 0xD0B070;
    static final int COLOR_BODY = 0xF0E0C0, COLOR_TEXT = 0xFFFFFF, COLOR_GOLD = 0xFFD040;
    static final int COLOR_BAD = 0xFF5050, COLOR_GOOD = 0x50FF70;
    static final int MAX_WRONG = 6, WORD_ROW_Y = 44, MISS_ROW_Y = 52;

    static final String[] WORD_TABLE = {
        "COMPUTER", "ASSEMBLY", "REGISTER", "PROCEDURE", "MEMORY", "BRANCH",
        "STACK", "SYSCALL", "PIPELINE", "COMPILER", "HARDWARE", "PROGRAM"
    };

    // ---- game state (mirrors .data) ----
    static String curWord = "";
    static final boolean[] guessed = new boolean[26];
    static final StringBuilder wrongBuf = new StringBuilder();
    static int wrongCount = 0, gamesWon = 0, gamesLost = 0;
    static final Random rng = new Random();
    static final Display display = new Display(COLOR_BG);
    static final BufferedReader in = new BufferedReader(new InputStreamReader(System.in));

    public static void main(String[] args) throws IOException {
        System.out.print("=== HANGMAN (Java reference) ===\n"
                + "I am thinking of a computer-architecture word.\n"
                + "Guess one letter at a time. You have 6 lives.\n\n");
        do {
            resetGame();
            drawScene();
            display.render();
            printState();
            while (true) {
                char letter = askLetter();                    // validated A-Z, not repeated
                guessed[letter - 'A'] = true;
                int n = countInWord(letter);
                if (n > 0) {
                    System.out.println("  Yes! '" + letter + "' appears " + n + " time(s).");
                } else {
                    wrongBuf.append(letter);
                    wrongCount++;
                    System.out.println("  No '" + letter + "' in the word.");
                }
                drawScene();
                printState();
                if (wordSolved()) {
                    gamesWon++;
                    display.drawText(30, 15, "YOU WIN", COLOR_GOOD);
                    display.render();
                    System.out.println("\n*** You got it! The word was " + curWord + ". ***");
                    break;
                }
                if (wrongCount >= MAX_WRONG) {
                    gamesLost++;
                    drawWordRow(true);                        // reveal missing letters in red
                    display.drawText(30, 15, "YOU LOSE", COLOR_BAD);
                    display.render();
                    System.out.println("\n*** Out of lives! The word was " + curWord + ". ***");
                    break;
                }
                display.render();
            }
            System.out.println("Score: " + gamesWon + " won, " + gamesLost + " lost.");
        } while (askYesNo("Play again? (Y/N): "));
        System.out.println("Thanks for playing!");
    }

    // ------------------------------------------------------------------
    //  Game state procedures
    // ------------------------------------------------------------------
    static void resetGame() {
        curWord = WORD_TABLE[rng.nextInt(WORD_TABLE.length)];
        java.util.Arrays.fill(guessed, false);
        wrongBuf.setLength(0);
        wrongCount = 0;
    }

    /** Asks until the input is exactly one letter that has not been tried. */
    static char askLetter() throws IOException {
        while (true) {
            System.out.print("Guess a letter: ");
            String s = readLine();
            if (s.length() != 1) { System.out.println("  ! Enter exactly one letter."); continue; }
            char c = Character.toUpperCase(s.charAt(0));
            if (c < 'A' || c > 'Z') { System.out.println("  ! That is not a letter (A-Z only)."); continue; }
            if (guessed[c - 'A'])   { System.out.println("  ! You already tried that letter."); continue; }
            return c;
        }
    }

    static int countInWord(char letter) {
        int n = 0;
        for (int i = 0; i < curWord.length(); i++) if (curWord.charAt(i) == letter) n++;
        return n;
    }

    static boolean wordSolved() {
        for (int i = 0; i < curWord.length(); i++) if (!guessed[curWord.charAt(i) - 'A']) return false;
        return true;
    }

    static void printState() {
        StringBuilder sb = new StringBuilder("Word : ");
        for (int i = 0; i < curWord.length(); i++) {
            char c = curWord.charAt(i);
            sb.append(guessed[c - 'A'] ? c : '_').append(' ');
        }
        sb.append("   Lives: ").append(MAX_WRONG - wrongCount).append("   Missed: ").append(wrongBuf);
        System.out.println(sb);
    }

    // ------------------------------------------------------------------
    //  Scene drawing (same geometry as the .asm)
    // ------------------------------------------------------------------
    static void drawScene() {
        display.fillScreen(COLOR_BG);
        display.drawText(30, 1, "HANGMAN", COLOR_GOLD);
        display.drawText(30, 8, "LIVES", COLOR_TEXT);
        display.drawText(54, 8, "" + (MAX_WRONG - wrongCount), COLOR_GOLD);
        drawGallows();
        drawFigure(wrongCount);
        drawWordRow(false);
        display.drawText(2, MISS_ROW_Y, "MISS", COLOR_TEXT);
        display.drawText(22, MISS_ROW_Y, wrongBuf.toString(), COLOR_BAD);
    }

    static void drawGallows() {
        display.drawRect(2, 38, 22, 1, COLOR_WOOD);     // base
        display.drawRect(5, 4, 1, 34, COLOR_WOOD);      // pole
        display.drawRect(5, 4, 13, 1, COLOR_WOOD);      // beam
        display.drawRect(17, 5, 1, 3, COLOR_ROPE);      // rope
    }

    /** Draws the first `parts` of: head, body, left arm, right arm, left leg, right leg. */
    static void drawFigure(int parts) {
        if (parts >= 1) {                                // head: 5x5 ring
            display.drawRect(15, 8, 5, 5, COLOR_BODY);
            display.drawRect(16, 9, 3, 3, COLOR_BG);
            display.drawPixel(15, 8, COLOR_BG);  display.drawPixel(19, 8, COLOR_BG);
            display.drawPixel(15, 12, COLOR_BG); display.drawPixel(19, 12, COLOR_BG);
        }
        if (parts >= 2) display.drawRect(17, 13, 1, 9, COLOR_BODY);   // body
        if (parts >= 3) drawDiag(16, 14, -1);                          // left arm
        if (parts >= 4) drawDiag(18, 14, 1);                           // right arm
        if (parts >= 5) drawDiag(16, 22, -1);                          // left leg
        if (parts >= 6) drawDiag(18, 22, 1);                           // right leg
    }

    static void drawDiag(int x, int y, int dx) {
        for (int i = 0; i < 4; i++) display.drawPixel(x + i * dx, y + i, COLOR_BODY);
    }

    static void drawWordRow(boolean revealAll) {
        for (int i = 0; i < curWord.length(); i++) {
            char c = curWord.charAt(i);
            int x = 2 + 4 * i;
            if (guessed[c - 'A'])      display.drawGlyph(x, WORD_ROW_Y, c, COLOR_TEXT);
            else if (revealAll)        display.drawGlyph(x, WORD_ROW_Y, c, COLOR_BAD);
            else                       display.drawGlyph(x, WORD_ROW_Y, '_', COLOR_GOLD);
        }
    }

    // ------------------------------------------------------------------
    //  Input helpers
    // ------------------------------------------------------------------
    static String readLine() throws IOException {
        String s = in.readLine();
        if (s == null) { System.out.println("\nInput ended. Goodbye."); System.exit(0); }
        return s;
    }

    static boolean askYesNo(String prompt) throws IOException {
        while (true) {
            System.out.print(prompt);
            String s = readLine().trim();
            if (s.equalsIgnoreCase("Y")) return true;
            if (s.equalsIgnoreCase("N")) return false;
            System.out.println("  ! Please answer Y or N.");
        }
    }

    // ------------------------------------------------------------------
    //  Display: software model of the MARS Bitmap Display (see TicTacToe.java)
    // ------------------------------------------------------------------
    static class Display {
        static final int W = 64, H = 64;
        final int[] pixels = new int[W * H];
        final int background;
        static final int[] FONT = {
            7,5,5,5,7, 2,6,2,2,7, 7,1,7,4,7, 7,1,7,1,7, 5,5,7,1,1,
            7,4,7,1,7, 7,4,7,5,7, 7,1,1,1,1, 7,5,7,5,7, 7,5,7,1,7,
            2,5,7,5,5, 6,5,6,5,6, 7,4,4,4,7, 6,5,5,5,6, 7,4,7,4,7,
            7,4,7,4,4, 7,4,5,5,7, 5,5,7,5,5, 7,2,2,2,7, 1,1,1,5,7,
            5,5,6,5,5, 4,4,4,4,7, 5,7,7,5,5, 6,5,5,5,5, 7,5,5,5,7,
            7,5,7,4,4, 7,5,5,7,1, 6,5,6,5,5, 7,4,7,1,7, 7,2,2,2,2,
            5,5,5,5,7, 5,5,5,5,2, 5,5,7,7,5, 5,5,2,5,5, 5,5,2,2,2,
            7,1,2,4,7, 0,0,0,0,0, 0,0,0,0,7, 7,1,3,0,2, 0,0,7,0,0,
            0,2,0,2,0, 2,2,2,0,2
        };
        Display(int background) { this.background = background; fillScreen(background); }
        void fillScreen(int color) { java.util.Arrays.fill(pixels, color); }
        void drawPixel(int x, int y, int color) {
            if (x < 0 || y < 0 || x >= W || y >= H) return;
            pixels[y * W + x] = color;
        }
        void drawRect(int x, int y, int w, int h, int color) {
            for (int r = 0; r < h; r++) for (int c = 0; c < w; c++) drawPixel(x + c, y + r, color);
        }
        static int glyphIndex(char ch) {
            if (ch >= '0' && ch <= '9') return ch - '0';
            if (ch >= 'A' && ch <= 'Z') return ch - 'A' + 10;
            if (ch >= 'a' && ch <= 'z') return ch - 'a' + 10;
            switch (ch) {
                case ' ': return 36; case '_': return 37; case '-': return 39;
                case ':': return 40; case '!': return 41; default: return 38;
            }
        }
        void drawGlyph(int x, int y, char ch, int color) {
            int base = glyphIndex(ch) * 5;
            for (int row = 0; row < 5; row++) {
                int bits = FONT[base + row];
                for (int col = 0; col < 3; col++)
                    if ((bits & (4 >> col)) != 0) drawPixel(x + col, y + row, color);
            }
        }
        void drawText(int x, int y, String s, int color) {
            for (int i = 0; i < s.length(); i++) drawGlyph(x + 4 * i, y, s.charAt(i), color);
        }
        void render() {
            StringBuilder sb = new StringBuilder();
            sb.append('+').append("-".repeat(W)).append("+\n");
            for (int y = 0; y < H; y += 2) {
                sb.append('|');
                for (int x = 0; x < W; x++) {
                    boolean top = pixels[y * W + x] != background;
                    boolean bot = pixels[(y + 1) * W + x] != background;
                    sb.append(top && bot ? '#' : top ? '"' : bot ? '.' : ' ');   // ASCII-safe
                }
                sb.append("|\n");
            }
            sb.append('+').append("-".repeat(W)).append("+\n");
            System.out.print(sb);
        }
    }
}
