public class testcase {
    static int passed = 0, failed = 0;
    static void check(String name, String expected, String actual) {
        boolean ok = expected.equals(actual);
        if (ok) passed++; else failed++;
        System.out.printf("[%s] %-45s expected=%s actual=%s%n",
                ok ? "PASS" : "FAIL", name, expected, actual);
    }
    public static void main(String[] args) {
        check("zero -> binary", "0", Baseconverter.toBinary(Baseconverter.parse("0", 10)));
        check("zero -> octal", "0", Baseconverter.toOctal(Baseconverter.parse("0", 10)));
        check("zero -> hex", "0", Baseconverter.toHex(Baseconverter.parse("0", 10)));
        check("zero -> decimal", "0", Baseconverter.toDecimal(Baseconverter.parse("0", 2)));
        int max = Baseconverter.parse("4294967295", 10);
        check("max unsigned -> binary", "11111111111111111111111111111111", Baseconverter.toBinary(max));
        check("max unsigned -> octal", "37777777777", Baseconverter.toOctal(max));
        check("max unsigned -> hex", "FFFFFFFF", Baseconverter.toHex(max));
        check("max unsigned -> unsigned decimal", "4294967295", Baseconverter.toUnsignedDecimal(max));
        check("hex FFFFFFFF -> unsigned decimal", "4294967295",
                Baseconverter.toUnsignedDecimal(Baseconverter.parse("FFFFFFFF", 16)));
        int minusOne = Baseconverter.parse("-1", 10);
        check("-1 -> binary (two's complement)", "11111111111111111111111111111111", Baseconverter.toBinary(minusOne));
        check("-1 -> hex (two's complement)", "FFFFFFFF", Baseconverter.toHex(minusOne));
        check("-1 -> signed decimal", "-1", Baseconverter.toDecimal(minusOne));
        int minInt = Baseconverter.parse("-2147483648", 10);
        check("-2147483648 -> binary", "10000000000000000000000000000000", Baseconverter.toBinary(minInt));
        check("-2147483648 -> hex", "80000000", Baseconverter.toHex(minInt));
        check("binary 1000...0 -> signed decimal", "-2147483648",
                Baseconverter.toDecimal(Baseconverter.parse("10000000000000000000000000000000", 2)));
        check("255 -> binary", "11111111", Baseconverter.toBinary(Baseconverter.parse("255", 10)));
        check("FF hex -> octal", "377", Baseconverter.toOctal(Baseconverter.parse("FF", 16)));
        check("777 octal -> decimal", "511", Baseconverter.toDecimal(Baseconverter.parse("777", 8)));
        check("ASCII NUL -> 0", "0", Integer.toString((int) '\0'));
        check("ASCII 'A' -> 65", "65", Integer.toString((int) 'A'));
        check("ASCII DEL -> 127", "127", Integer.toString((int) (char) 127));
        System.out.printf("%n%d passed, %d failed%n", passed, failed);
        System.exit(failed == 0 ? 0 : 1);
    }
}