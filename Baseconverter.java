import java.util.Scanner;
public class Baseconverter {
    public static int parse(String value, int base) {
        if (value.startsWith("-")) {
            return -Integer.parseUnsignedInt(value.substring(1), base);
        }
        return Integer.parseUnsignedInt(value, base);
    }
    public static String toBinary(int n) { return Integer.toBinaryString(n); }
    public static String toOctal(int n) { return Integer.toOctalString(n); }
    public static String toHex(int n) { return Integer.toHexString(n).toUpperCase(); }
    public static String toDecimal(int n) { return Integer.toString(n); } // signed
    public static String toUnsignedDecimal(int n) { return Integer.toUnsignedString(n); }
    public static String convertAll(String value, int base) {
        int n = parse(value, base);
        return "Input: " + value + " (base " + base + ")\n" +
                "Binary: " + toBinary(n) + "\n" +
                "Octal: " + toOctal(n) + "\n" +
                "Decimal (signed): " + toDecimal(n) + "\n" +
                "Decimal (unsigned): " + toUnsignedDecimal(n) + "\n" +
                "Hexadecimal: " + toHex(n) + "\n";
    }
    public static void main(String[] args) {
        if (args.length == 2) {
            System.out.print(convertAll(args[0], Integer.parseInt(args[1])));
            return;
        }
        Scanner in = new Scanner(System.in);
        System.out.print("Enter a value: ");
        String value = in.nextLine().trim();
        System.out.print("Enter its base (2, 8, 10, 16): ");
        int base = Integer.parseInt(in.nextLine().trim());
        System.out.print(convertAll(value, base));
    }
}