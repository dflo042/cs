import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Random;

/**
 * Blackjack.java -- Java planning / reference version of blackjack.asm
 *
 * Module 4: MIPS Game Project (Game 2 of 3)
 * Author  : Dylan Flores
 *
 * Written first to plan the MIPS version. The deck and hands are plain int
 * arrays with explicit counters (exactly what the .asm does with byte arrays
 * and word counters), the card encoding is identical (rank = card % 13,
 * suit = card / 13), and the Display class models the MARS Bitmap Display
 * with the same card layout and 3x5 font.
 *
 * Run:  javac Blackjack.java && java Blackjack
 */
public class Blackjack {

    // ---- constants (mirror the .eqv values) ----
    static final int COLOR_FELT = 0x206838, COLOR_TEXT = 0xFFFFFF, COLOR_GOLD = 0xFFD040;
    static final int COLOR_CARD = 0xF8F8F0, COLOR_BACK = 0x2040A0, COLOR_BACK2 = 0x4878D0;
    static final int COLOR_RED = 0xD82020, COLOR_BLACK = 0x101010;
    static final int CARD_W = 9, CARD_H = 12, CARD_PITCH = 10, DEALER_Y = 7, PLAYER_Y = 27;
    static final int MAX_HAND = 12;
    static final char[] SUIT_LETTERS = {'S', 'H', 'D', 'C'};

    // ---- game state (mirrors .data) ----
    static final int[] deck = new int[52];
    static int deckPos = 0;
    static final int[] playerHand = new int[MAX_HAND];
    static final int[] dealerHand = new int[MAX_HAND];
    static int playerCount = 0, dealerCount = 0;
    static int wins = 0, losses = 0, pushes = 0;
    static String curMsg = "";
    static final Random rng = new Random();            // syscall 40/42 in MIPS
    static final Display display = new Display(COLOR_FELT);
    static final BufferedReader in = new BufferedReader(new InputStreamReader(System.in));

    public static void main(String[] args) throws IOException {
        System.out.print("=== BLACKJACK (Java reference) ===\n"
                + "Get closer to 21 than the dealer without going over.\n"
                + "Dealer hits on 16 and stands on 17. Aces count 11 or 1.\n");
        do {
            playRound();
            System.out.println("Record: " + wins + " won, " + losses + " lost, " + pushes + " pushed.");
        } while (askYesNo("Play another round? (Y/N): "));
        System.out.println("Thanks for playing!");
    }

    // ------------------------------------------------------------------
    //  One round (the round_start .. round_end section of main in the .asm)
    // ------------------------------------------------------------------
    static void playRound() throws IOException {
        System.out.println("\n---------------- NEW ROUND ----------------");
        shuffleDeck();
        playerCount = dealerCount = 0;
        dealCard(playerHand, true);
        dealCard(dealerHand, false);
        dealCard(playerHand, true);
        dealCard(dealerHand, false);

        curMsg = "H HIT  S STAND";
        redrawTable(true);
        display.render();
        System.out.println("Dealer shows : " + cardName(dealerHand[0]) + " [??]");
        printPlayerLine();

        // natural blackjack check
        if (handValue(playerHand, playerCount) == 21) {
            if (handValue(dealerHand, dealerCount) == 21) {
                finish("PUSH", "\n*** Both have blackjack - push. ***", 0);
            } else {
                finish("BLACKJACK!", "\n*** BLACKJACK! You win! ***", 1);
            }
            printDealerFull();
            return;
        }

        // player's turn
        while (true) {
            System.out.print("(H)it or (S)tand? ");
            String s = readLine().trim().toUpperCase();
            char c = s.isEmpty() ? ' ' : s.charAt(0);
            if (c == 'H') {
                int card = dealCard(playerHand, true);
                System.out.println("You draw     : " + cardName(card));
                redrawTable(true);
                display.render();
                printPlayerLine();
                int total = handValue(playerHand, playerCount);
                if (total > 21) {
                    finish("BUST", "\n*** BUST! You went over 21. Dealer wins. ***", -1);
                    return;
                }
                if (total == 21) {
                    System.out.println("You have 21 - standing automatically.");
                    break;
                }
            } else if (c == 'S') {
                break;
            } else {
                System.out.println("  ! Please type H to hit or S to stand.");
            }
        }

        // dealer's turn: hit on 16 or less, stand on 17 or more
        redrawTable(false);
        System.out.println("Dealer reveals: " + handString(dealerHand, dealerCount));
        while (handValue(dealerHand, dealerCount) < 17) {
            int card = dealCard(dealerHand, false);
            System.out.println("Dealer hits  : " + cardName(card));
            redrawTable(false);
        }
        int d = handValue(dealerHand, dealerCount);
        int p = handValue(playerHand, playerCount);
        printDealerFull();
        if (d > 21)      finish("DEALER BUSTS", "\n*** Dealer busts! You win! ***", 1);
        else if (p > d)  finish("YOU WIN", "\n*** You win! ***", 1);
        else if (p < d)  finish("DEALER WINS", "\n*** Dealer wins. ***", -1);
        else             finish("PUSH", "\n*** Push - it's a tie. ***", 0);
    }

    /** Updates the record, the display message and prints the console result. */
    static void finish(String displayMsg, String consoleMsg, int outcome) {
        if (outcome > 0) wins++; else if (outcome < 0) losses++; else pushes++;
        curMsg = displayMsg;
        redrawTable(false);
        display.render();
        System.out.println(consoleMsg);
    }

    // ------------------------------------------------------------------
    //  Deck / hand procedures
    // ------------------------------------------------------------------
    static void shuffleDeck() {
        for (int i = 0; i < 52; i++) deck[i] = i;
        for (int i = 51; i > 0; i--) {                 // Fisher-Yates
            int j = rng.nextInt(i + 1);
            int t = deck[i]; deck[i] = deck[j]; deck[j] = t;
        }
        deckPos = 0;
    }

    static int dealCard(int[] hand, boolean toPlayer) {
        if (deckPos >= 52) shuffleDeck();             // defensive: never happens in a round
        int card = deck[deckPos++];
        int count = toPlayer ? playerCount : dealerCount;
        if (count < MAX_HAND) {
            hand[count] = card;
            if (toPlayer) playerCount++; else dealerCount++;
        }
        return card;
    }

    static int cardValue(int card) {
        int rank = card % 13;
        if (rank == 0) return 11;                      // ace
        return Math.min(rank + 1, 10);                 // 2..10, face cards = 10
    }

    static int handValue(int[] hand, int count) {
        int total = 0, aces = 0;
        for (int i = 0; i < count; i++) {
            int v = cardValue(hand[i]);
            total += v;
            if (v == 11) aces++;
        }
        while (total > 21 && aces > 0) { total -= 10; aces--; }
        return total;
    }

    static char rankChar(int rank) {
        if (rank == 0) return 'A';
        if (rank == 10) return 'J';
        if (rank == 11) return 'Q';
        if (rank == 12) return 'K';
        return (char) ('1' + rank);                    // 1..8 -> '2'..'9'
    }

    static String cardName(int card) {
        int rank = card % 13, suit = card / 13;
        return (rank == 9 ? "10" : String.valueOf(rankChar(rank))) + SUIT_LETTERS[suit];
    }

    static String handString(int[] hand, int count) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < count; i++) sb.append(cardName(hand[i])).append(' ');
        return sb.toString();
    }

    static void printPlayerLine() {
        System.out.println("Your hand    : " + handString(playerHand, playerCount)
                + "   (total " + handValue(playerHand, playerCount) + ")");
    }

    static void printDealerFull() {
        System.out.println("Dealer hand  : " + handString(dealerHand, dealerCount)
                + "   (total " + handValue(dealerHand, dealerCount) + ")");
    }

    // ------------------------------------------------------------------
    //  Table drawing (same geometry as the .asm)
    // ------------------------------------------------------------------
    static void redrawTable(boolean hideDealer) {
        display.fillScreen(COLOR_FELT);
        display.drawText(2, 1, "DEALER", COLOR_TEXT);
        drawHand(dealerHand, dealerCount, DEALER_Y, hideDealer);
        display.drawText(2, 21, "PLAYER", COLOR_TEXT);
        drawHand(playerHand, playerCount, PLAYER_Y, false);
        display.drawText(2, 41, "YOU", COLOR_TEXT);
        display.drawText(16, 41, "" + handValue(playerHand, playerCount), COLOR_GOLD);
        display.drawText(30, 41, "DLR", COLOR_TEXT);
        display.drawText(44, 41, hideDealer ? "?" : "" + handValue(dealerHand, dealerCount), COLOR_GOLD);
        display.drawText(2, 48, curMsg, COLOR_GOLD);
        display.drawText(2, 55, "W", COLOR_TEXT);  display.drawText(8, 55, "" + wins, COLOR_GOLD);
        display.drawText(22, 55, "L", COLOR_TEXT); display.drawText(28, 55, "" + losses, COLOR_GOLD);
        display.drawText(42, 55, "P", COLOR_TEXT); display.drawText(48, 55, "" + pushes, COLOR_GOLD);
    }

    static void drawHand(int[] hand, int count, int y, boolean hideSecond) {
        for (int i = 0; i < count; i++) {
            drawCard(2 + i * CARD_PITCH, y, hand[i], !(hideSecond && i == 1));
        }
    }

    static void drawCard(int x, int y, int card, boolean faceUp) {
        if (!faceUp) {
            display.drawRect(x, y, CARD_W, CARD_H, COLOR_BACK);
            display.drawRect(x + 2, y + 2, 5, 8, COLOR_BACK2);
            display.drawRect(x + 3, y + 3, 3, 6, COLOR_BACK);
            return;
        }
        display.drawRect(x, y, CARD_W, CARD_H, COLOR_CARD);
        int rank = card % 13, suit = card / 13;
        int ink = (suit == 1 || suit == 2) ? COLOR_RED : COLOR_BLACK;
        if (rank == 9) display.drawText(x + 1, y + 1, "10", ink);
        else display.drawGlyph(x + 1, y + 1, rankChar(rank), ink);
        display.drawGlyph(x + 5, y + 6, SUIT_LETTERS[suit], ink);
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
