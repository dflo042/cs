import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

/**
 * TicTacToe.java -- Java planning / reference version of tictactoe.asm
 *
 * Module 4: MIPS Game Project (Game 1 of 3)
 * Author  : Dylan Flores
 *
 * This program was written first to plan the MIPS version. Every static
 * method here maps to a procedure with the same name in tictactoe.asm, the
 * board is the same 9-byte array, and the Display class simulates the MARS
 * Bitmap Display (64 x 64 words at 0x10008000) with the same 3x5 font and
 * the same drawing routines. The display is printed as text after every
 * move using half-block characters (two pixel rows per text line).
 *
 * Run:  javac TicTacToe.java && java TicTacToe
 */
public class TicTacToe {

    // ---- constants (mirror the .eqv values in the .asm file) ----
    static final int COLOR_BG   = 0x202830;
    static final int COLOR_GRID = 0xE0E0E0;
    static final int COLOR_X    = 0xFF5050;
    static final int COLOR_O    = 0x50A0FF;
    static final int COLOR_WIN  = 0x50FF70;
    static final int COLOR_HINT = 0x606878;
    static final int COLOR_TEXT = 0xFFE060;
    static final int BOARD_X = 8, BOARD_Y = 8, CELL_PITCH = 16, CELL_SIZE = 15;
    static final int PLAYER_X = 1, PLAYER_O = 2;

    // ---- game state (mirrors the .data section) ----
    static final int[] board = new int[9];          // 0 empty, 1 X, 2 O
    static final int[][] WIN_LINES = {
        {0, 1, 2}, {3, 4, 5}, {6, 7, 8},             // rows
        {0, 3, 6}, {1, 4, 7}, {2, 5, 8},             // columns
        {0, 4, 8}, {2, 4, 6}                         // diagonals
    };
    static int moveCount = 0;
    static final Display display = new Display(COLOR_BG);
    static final BufferedReader in = new BufferedReader(new InputStreamReader(System.in));

    public static void main(String[] args) throws IOException {
        System.out.print("=== TIC-TAC-TOE (Java reference) ===\n"
                + "Two players take turns. Type the number of an empty cell (1-9).\n\n");
        boolean playing = true;
        while (playing) {
            resetGame();
            drawBoardScreen();
            int player = PLAYER_X;
            while (true) {
                printConsoleBoard();
                showStatus(player == PLAYER_X ? "X TURN" : "O TURN");
                display.render();
                int cell = askMove(player);           // validated 0..8
                board[cell] = player;
                moveCount++;
                drawMark(cell, player, player == PLAYER_X ? COLOR_X : COLOR_O);
                int line = checkWin(player);
                if (line >= 0) {
                    highlightLine(line, player);
                    printConsoleBoard();
                    showStatus(player == PLAYER_X ? "X WINS!" : "O WINS!");
                    display.render();
                    System.out.println("\n*** Player " + (player == PLAYER_X ? "X" : "O") + " wins! ***");
                    break;
                }
                if (moveCount == 9) {
                    printConsoleBoard();
                    showStatus("DRAW");
                    display.render();
                    System.out.println("\n*** It's a draw. ***");
                    break;
                }
                player = 3 - player;                  // 1 <-> 2
            }
            playing = askYesNo("Play again? (Y/N): ");
        }
        System.out.println("Thanks for playing!");
    }

    // ------------------------------------------------------------------
    //  Game logic (one method per MIPS procedure)
    // ------------------------------------------------------------------
    static void resetGame() {
        for (int i = 0; i < 9; i++) board[i] = 0;
        moveCount = 0;
    }

    /** Asks until the player types a legal, empty cell. Returns index 0..8. */
    static int askMove(int player) throws IOException {
        while (true) {
            System.out.print("Player " + (player == PLAYER_X ? "X" : "O") + ", choose a cell (1-9): ");
            String line = readLine();
            int value = parseInt(line);              // -1 if not a number
            if (value < 0) {
                System.out.println("  ! That is not a whole number. Enter a digit from 1 to 9.");
            } else if (value < 1 || value > 9) {
                System.out.println("  ! Out of range. Enter a digit from 1 to 9.");
            } else if (board[value - 1] != 0) {
                System.out.println("  ! That cell is already taken. Pick an empty one.");
            } else {
                return value - 1;
            }
        }
    }

    /** Returns the index of the winning line for player, or -1. */
    static int checkWin(int player) {
        for (int i = 0; i < WIN_LINES.length; i++) {
            int[] l = WIN_LINES[i];
            if (board[l[0]] == player && board[l[1]] == player && board[l[2]] == player) return i;
        }
        return -1;
    }

    static void highlightLine(int line, int player) {
        for (int cell : WIN_LINES[line]) drawMark(cell, player, COLOR_WIN);
    }

    static void printConsoleBoard() {
        StringBuilder sb = new StringBuilder("\n");
        for (int r = 0; r < 3; r++) {
            sb.append(' ').append(cellChar(r * 3)).append(" | ").append(cellChar(r * 3 + 1))
              .append(" | ").append(cellChar(r * 3 + 2)).append('\n');
            if (r < 2) sb.append("---+---+---\n");
        }
        System.out.println(sb);
    }

    static char cellChar(int idx) {
        if (board[idx] == PLAYER_X) return 'X';
        if (board[idx] == PLAYER_O) return 'O';
        return (char) ('1' + idx);
    }

    // ------------------------------------------------------------------
    //  Drawing (same geometry as the .asm)
    // ------------------------------------------------------------------
    static void drawBoardScreen() {
        display.fillScreen(COLOR_BG);
        display.drawText(10, 1, "TIC TAC TOE", COLOR_TEXT);
        display.drawRect(23, BOARD_Y, 1, 47, COLOR_GRID);
        display.drawRect(39, BOARD_Y, 1, 47, COLOR_GRID);
        display.drawRect(BOARD_X, 23, 47, 1, COLOR_GRID);
        display.drawRect(BOARD_X, 39, 47, 1, COLOR_GRID);
        for (int i = 0; i < 9; i++) {
            display.drawGlyph(cellX(i) + 1, cellY(i) + 1, (char) ('1' + i), COLOR_HINT);
        }
    }

    static int cellX(int idx) { return BOARD_X + (idx % 3) * CELL_PITCH; }
    static int cellY(int idx) { return BOARD_Y + (idx / 3) * CELL_PITCH; }

    static void drawMark(int cell, int player, int color) {
        int x0 = cellX(cell), y0 = cellY(cell);
        display.drawRect(x0, y0, CELL_SIZE, CELL_SIZE, COLOR_BG);   // erase hint digit
        if (player == PLAYER_X) drawXMark(x0, y0, color);
        else drawOMark(x0, y0, color);
    }

    static void drawXMark(int x0, int y0, int color) {
        for (int i = 0; i <= 10; i++) {
            display.drawPixel(x0 + 2 + i, y0 + 2 + i, color);
            display.drawPixel(x0 + 3 + i, y0 + 2 + i, color);
            display.drawPixel(x0 + 12 - i, y0 + 2 + i, color);
            display.drawPixel(x0 + 11 - i, y0 + 2 + i, color);
        }
    }

    static void drawOMark(int x0, int y0, int color) {
        display.drawRect(x0 + 2, y0 + 2, 11, 11, color);
        display.drawRect(x0 + 4, y0 + 4, 7, 7, COLOR_BG);
        display.drawPixel(x0 + 2, y0 + 2, COLOR_BG);
        display.drawPixel(x0 + 12, y0 + 2, COLOR_BG);
        display.drawPixel(x0 + 2, y0 + 12, COLOR_BG);
        display.drawPixel(x0 + 12, y0 + 12, COLOR_BG);
    }

    static void showStatus(String text) {
        display.drawRect(0, 57, 64, 7, COLOR_BG);
        display.drawText(4, 57, text, COLOR_TEXT);
    }

    // ------------------------------------------------------------------
    //  Input helpers (read_line / parse_int in the .asm)
    // ------------------------------------------------------------------
    static String readLine() throws IOException {
        String s = in.readLine();
        if (s == null) {                       // EOF: end cleanly instead of looping
            System.out.println("\nInput ended. Goodbye.");
            System.exit(0);
        }
        return s;
    }

    /** Non-negative integer with optional surrounding spaces, else -1. */
    static int parseInt(String s) {
        s = s.trim();
        if (s.isEmpty() || s.length() > 9) return -1;
        int v = 0;
        for (char c : s.toCharArray()) {
            if (c < '0' || c > '9') return -1;
            v = v * 10 + (c - '0');
        }
        return v;
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
    //  Display: a software model of the MARS Bitmap Display
    // ------------------------------------------------------------------
    static class Display {
        static final int W = 64, H = 64;
        final int[] pixels = new int[W * H];        // same layout as memory at 0x10008000
        final int background;

        // 3x5 font, 5 bytes per glyph, bit 2 = left pixel. Same table as the .asm.
        static final int[] FONT = {
            7,5,5,5,7, 2,6,2,2,7, 7,1,7,4,7, 7,1,7,1,7, 5,5,7,1,1,   // 0-4
            7,4,7,1,7, 7,4,7,5,7, 7,1,1,1,1, 7,5,7,5,7, 7,5,7,1,7,   // 5-9
            2,5,7,5,5, 6,5,6,5,6, 7,4,4,4,7, 6,5,5,5,6, 7,4,7,4,7,   // A-E
            7,4,7,4,4, 7,4,5,5,7, 5,5,7,5,5, 7,2,2,2,7, 1,1,1,5,7,   // F-J
            5,5,6,5,5, 4,4,4,4,7, 5,7,7,5,5, 6,5,5,5,5, 7,5,5,5,7,   // K-O
            7,5,7,4,4, 7,5,5,7,1, 6,5,6,5,5, 7,4,7,1,7, 7,2,2,2,2,   // P-T
            5,5,5,5,7, 5,5,5,5,2, 5,5,7,7,5, 5,5,2,5,5, 5,5,2,2,2,   // U-Y
            7,1,2,4,7, 0,0,0,0,0, 0,0,0,0,7, 7,1,3,0,2, 0,0,7,0,0,   // Z, space, _, ?, -
            0,2,0,2,0, 2,2,2,0,2                                      // :, !
        };

        Display(int background) { this.background = background; fillScreen(background); }

        void fillScreen(int color) { java.util.Arrays.fill(pixels, color); }

        void drawPixel(int x, int y, int color) {
            if (x < 0 || y < 0 || x >= W || y >= H) return;   // ignore out of range
            pixels[y * W + x] = color;                           // address = base + (y*64+x)*4
        }

        void drawRect(int x, int y, int w, int h, int color) {
            for (int r = 0; r < h; r++)
                for (int c = 0; c < w; c++) drawPixel(x + c, y + r, color);
        }

        static int glyphIndex(char ch) {
            if (ch >= '0' && ch <= '9') return ch - '0';
            if (ch >= 'A' && ch <= 'Z') return ch - 'A' + 10;
            if (ch >= 'a' && ch <= 'z') return ch - 'a' + 10;
            switch (ch) {
                case ' ': return 36; case '_': return 37; case '-': return 39;
                case ':': return 40; case '!': return 41; default: return 38;   // '?'
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

        /** Prints the frame buffer as text: two pixel rows per line (# = both lit, " = top, . = bottom). */
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
