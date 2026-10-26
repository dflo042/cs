import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/*
 * Assembler.java
 * Reads a MIPS assembly file and writes two machine code files.
 *   name.mhc-ascii  readable text with one 32 bit word per line as 0 and 1 characters
 *   name.mhc-bin    the same words as raw bytes
 *
 * Run with
 *   javac Assembler.java
 *   java Assembler fizzbuzz.asm
 *
 * Both files start with a five word header so the disassembler can tell
 * instructions from data. See README.md for the layout.
 */
public class Assembler {

    static final int TEXT_START = 0x00400000;
    static final int DATA_START = 0x10010000;
    static final int MAGIC = 0x4D484331; // the letters M H C 1

    // register names in number order so $t0 is 8 and so on
    static final String[] REG_NAMES = {
        "zero","at","v0","v1","a0","a1","a2","a3",
        "t0","t1","t2","t3","t4","t5","t6","t7",
        "s0","s1","s2","s3","s4","s5","s6","s7",
        "t8","t9","k0","k1","gp","sp","fp","ra" };

    // R type instructions and their funct codes
    static final Map<String,Integer> RTYPE = new HashMap<>();
    // I type instructions and their opcodes
    static final Map<String,Integer> ITYPE = new HashMap<>();
    static {
        RTYPE.put("add", 0x20);  RTYPE.put("addu", 0x21);
        RTYPE.put("sub", 0x22);  RTYPE.put("subu", 0x23);
        RTYPE.put("and", 0x24);  RTYPE.put("or", 0x25);
        RTYPE.put("xor", 0x26);  RTYPE.put("nor", 0x27);
        RTYPE.put("slt", 0x2a);  RTYPE.put("sltu", 0x2b);
        RTYPE.put("sll", 0x00);  RTYPE.put("srl", 0x02);  RTYPE.put("sra", 0x03);
        RTYPE.put("jr", 0x08);   RTYPE.put("jalr", 0x09);
        RTYPE.put("mult", 0x18); RTYPE.put("multu", 0x19);
        RTYPE.put("div", 0x1a);  RTYPE.put("divu", 0x1b);
        RTYPE.put("mfhi", 0x10); RTYPE.put("mflo", 0x12);
        RTYPE.put("syscall", 0x0c); RTYPE.put("break", 0x0d);

        ITYPE.put("addi", 0x08); ITYPE.put("addiu", 0x09);
        ITYPE.put("slti", 0x0a); ITYPE.put("sltiu", 0x0b);
        ITYPE.put("andi", 0x0c); ITYPE.put("ori", 0x0d);
        ITYPE.put("xori", 0x0e); ITYPE.put("lui", 0x0f);
        ITYPE.put("lw", 0x23);   ITYPE.put("sw", 0x2b);
        ITYPE.put("lb", 0x20);   ITYPE.put("lbu", 0x24);
        ITYPE.put("lh", 0x21);   ITYPE.put("lhu", 0x25);
        ITYPE.put("sb", 0x28);   ITYPE.put("sh", 0x29);
        ITYPE.put("beq", 0x04);  ITYPE.put("bne", 0x05);
    }

    // one source line that is an instruction waiting to be encoded
    static class Line {
        int number;          // line number in the source file for error messages
        String text;         // the instruction without the label or comment
        int address;         // where it will land in the text segment
        Line(int number, String text, int address) {
            this.number = number; this.text = text; this.address = address;
        }
    }

    // thrown for anything wrong in the input
    static class AsmError extends Exception {
        AsmError(String msg) { super(msg); }
    }

    Map<String,Integer> labels = new HashMap<>();
    List<Line> lines = new ArrayList<>();      // text segment after pseudoinstruction expansion
    ByteArrayOutputStream data = new ByteArrayOutputStream();
    List<Integer> words = new ArrayList<>();   // encoded text words

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("usage  java Assembler program.asm [outputbase]");
            System.exit(2);
        }
        String in = args[0];
        String base = args.length > 1 ? args[1] : in.replaceAll("\\.asm$", "");
        try {
            Assembler a = new Assembler();
            a.assemble(in);
            a.writeAscii(base + ".mhc-ascii");
            a.writeBin(base + ".mhc-bin");
            System.out.println("assembled " + a.words.size() + " instructions and "
                + a.data.size() + " data bytes");
            System.out.println("wrote " + base + ".mhc-ascii and " + base + ".mhc-bin");
        } catch (AsmError e) {
            System.err.println("error " + e.getMessage());
            System.exit(1);
        } catch (IOException e) {
            System.err.println("error could not read or write a file. " + e.getMessage());
            System.exit(1);
        }
    }

    // ---------------------------------------------------------------- pass 1
    // Split the file into text and data. Expand pseudoinstructions so every
    // text line is one real instruction and the addresses of the labels are known.
    void assemble(String path) throws IOException, AsmError {
        List<String> src = new ArrayList<>();
        try (BufferedReader r = new BufferedReader(new FileReader(path))) {
            String s;
            while ((s = r.readLine()) != null) src.add(s);
        }

        boolean inText = true;   // MARS defaults to .text if nothing is said
        int textAddr = TEXT_START;
        for (int i = 0; i < src.size(); i++) {
            int num = i + 1;
            String line = stripComment(src.get(i)).trim();
            if (line.isEmpty()) continue;

            // a label can sit in front of anything else on the line
            while (line.matches("[A-Za-z_][A-Za-z0-9_]*\\s*:.*")) {
                int colon = line.indexOf(':');
                String name = line.substring(0, colon).trim();
                if (labels.containsKey(name))
                    throw new AsmError("line " + num + " label " + name + " is defined twice");
                labels.put(name, inText ? textAddr : DATA_START + data.size());
                line = line.substring(colon + 1).trim();
            }
            if (line.isEmpty()) continue;

            if (line.startsWith(".")) {
                String[] parts = line.split("\\s+", 2);
                String dir = parts[0].toLowerCase();
                String arg = parts.length > 1 ? parts[1].trim() : "";
                switch (dir) {
                    case ".text": inText = true; break;
                    case ".data": inText = false; break;
                    case ".globl": break;   // nothing to do
                    case ".asciiz": case ".ascii": case ".word": case ".byte": case ".space": case ".align":
                        if (inText) throw new AsmError("line " + num + " " + dir + " is only allowed in the .data section");
                        // a label right before data needs to point at the aligned spot
                        if (dir.equals(".word") || dir.equals(".align")) fixLabelAfterAlign(dir, arg, num);
                        emitData(dir, arg, num);
                        break;
                    default:
                        throw new AsmError("line " + num + " unsupported directive " + dir);
                }
                continue;
            }

            if (!inText) throw new AsmError("line " + num + " instruction " + line + " is in the .data section");

            for (String real : expand(line, num)) {
                lines.add(new Line(num, real, textAddr));
                textAddr += 4;
            }
        }

        // ------------------------------------------------------------ pass 2
        for (Line l : lines) words.add(encode(l));
    }

    // .word is word aligned in MARS. If a label was just placed on an odd
    // address move it forward to where the data will really go.
    void fixLabelAfterAlign(String dir, String arg, int num) throws AsmError {
        int align = 4;
        if (dir.equals(".align")) align = 1 << parseInt(arg, num);
        int here = DATA_START + data.size();
        int aligned = (here + align - 1) / align * align;
        if (aligned != here) {
            for (Map.Entry<String,Integer> e : labels.entrySet())
                if (e.getValue() == here) e.setValue(aligned);
        }
    }

    void emitData(String dir, String arg, int num) throws AsmError {
        switch (dir) {
            case ".asciiz":
            case ".ascii": {
                if (!arg.startsWith("\"") || !arg.endsWith("\"") || arg.length() < 2)
                    throw new AsmError("line " + num + " " + dir + " needs a string in double quotes");
                byte[] s = unescape(arg.substring(1, arg.length() - 1), num).getBytes(StandardCharsets.US_ASCII);
                data.write(s, 0, s.length);
                if (dir.equals(".asciiz")) data.write(0);
                break;
            }
            case ".word": {
                while (data.size() % 4 != 0) data.write(0);
                for (String v : arg.split(",")) {
                    int w = parseInt(v.trim(), num);
                    // bytes go out in address order and MARS memory is little endian
                    data.write(w & 0xff); data.write((w >> 8) & 0xff);
                    data.write((w >> 16) & 0xff); data.write((w >> 24) & 0xff);
                }
                break;
            }
            case ".byte":
                for (String v : arg.split(",")) {
                    int b = parseInt(v.trim(), num);
                    if (b < -128 || b > 255) throw new AsmError("line " + num + " byte value " + v.trim() + " does not fit in 8 bits");
                    data.write(b & 0xff);
                }
                break;
            case ".space": {
                int n = parseInt(arg, num);
                for (int i = 0; i < n; i++) data.write(0);
                break;
            }
            case ".align": {
                int align = 1 << parseInt(arg, num);
                while (data.size() % align != 0) data.write(0);
                break;
            }
        }
    }

    // Turn one source instruction into one or more real instructions.
    // The expansions are the same ones MARS uses so the machine code matches.
    List<String> expand(String line, int num) throws AsmError {
        String[] p = splitInstr(line);
        String op = p[0];
        String[] a = Arrays.copyOfRange(p, 1, p.length);
        List<String> out = new ArrayList<>();
        switch (op) {
            case "li": {
                need(a, 2, op, num);
                long v = parseLong(a[1], num);
                if (v < -32768 || v > 0xffffffffL) throw new AsmError("line " + num + " li value " + a[1] + " does not fit in 32 bits");
                if (v >= -32768 && v <= 32767) out.add("addiu " + a[0] + ", $zero, " + v);
                else if (v >= 0 && v <= 65535) out.add("ori " + a[0] + ", $zero, " + v);
                else {
                    out.add("lui $at, " + ((v >> 16) & 0xffff));
                    out.add("ori " + a[0] + ", $at, " + (v & 0xffff));
                }
                break;
            }
            case "la": {
                need(a, 2, op, num);
                // the label may be defined later in the file so it is looked up in pass 2
                out.add("lui $at, %hi(" + a[1] + ")");
                out.add("ori " + a[0] + ", $at, %lo(" + a[1] + ")");
                break;
            }
            case "move":
                need(a, 2, op, num);
                out.add("addu " + a[0] + ", $zero, " + a[1]);
                break;
            case "rem":
            case "div":
                if (op.equals("div") && a.length == 2) { out.add(line); break; }
                need(a, 3, op, num);
                if (isNumber(a[2])) throw new AsmError("line " + num + " " + op + " with an immediate is not supported. Put the value in a register first");
                out.add("bne " + a[2] + ", $zero, 1");   // skip the break when the divisor is not zero
                out.add("break");
                out.add("div " + a[1] + ", " + a[2]);
                out.add(op.equals("rem") ? "mfhi " + a[0] : "mflo " + a[0]);
                break;
            case "nop": out.add("sll $zero, $zero, 0"); break;
            case "b": need(a, 1, op, num); out.add("beq $zero, $zero, " + a[0]); break;
            case "beqz": need(a, 2, op, num); out.add("beq " + a[0] + ", $zero, " + a[1]); break;
            case "bnez": need(a, 2, op, num); out.add("bne " + a[0] + ", $zero, " + a[1]); break;
            case "blt": need(a, 3, op, num); out.add("slt $at, " + a[0] + ", " + a[1]); out.add("bne $at, $zero, " + a[2]); break;
            case "bgt": need(a, 3, op, num); out.add("slt $at, " + a[1] + ", " + a[0]); out.add("bne $at, $zero, " + a[2]); break;
            case "ble": need(a, 3, op, num); out.add("slt $at, " + a[1] + ", " + a[0]); out.add("beq $at, $zero, " + a[2]); break;
            case "bge": need(a, 3, op, num); out.add("slt $at, " + a[0] + ", " + a[1]); out.add("beq $at, $zero, " + a[2]); break;
            case "lw": case "sw": case "lb": case "lbu": case "lh": case "lhu": case "sb": case "sh":
                need(a, 2, op, num);
                if (a[1].contains("(") || isNumber(a[1])) { out.add(line); break; }
                // lw $t0, label  becomes lui $at then lw $t0, lo($at)
                out.add("lui $at, %hi(" + a[1] + ")");
                out.add(op + " " + a[0] + ", %lo(" + a[1] + ")($at)");
                break;
            default:
                if (!RTYPE.containsKey(op) && !ITYPE.containsKey(op) && !op.equals("j") && !op.equals("jal"))
                    throw new AsmError("line " + num + " unsupported instruction " + op + " in " + line);
                out.add(line);
        }
        return out;
    }

    // ------------------------------------------------------------- encoding
    int encode(Line l) throws AsmError {
        String[] p = splitInstr(l.text);
        String op = p[0];
        String[] a = Arrays.copyOfRange(p, 1, p.length);
        int num = l.number;

        if (op.equals("j") || op.equals("jal")) {
            need(a, 1, op, num);
            int target = labelOrNumber(a[0], num);
            if ((target & 0xF0000000) != (l.address & 0xF0000000))
                throw new AsmError("line " + num + " jump target " + a[0] + " is not in the same 256MB block");
            return ((op.equals("j") ? 2 : 3) << 26) | ((target >> 2) & 0x03ffffff);
        }

        if (RTYPE.containsKey(op)) {
            int funct = RTYPE.get(op);
            int rs = 0, rt = 0, rd = 0, sh = 0;
            switch (op) {
                case "syscall": case "break": need(a, 0, op, num); break;
                case "sll": case "srl": case "sra":
                    need(a, 3, op, num);
                    rd = reg(a[0], num); rt = reg(a[1], num); sh = parseInt(a[2], num);
                    if (sh < 0 || sh > 31) throw new AsmError("line " + num + " shift amount " + a[2] + " must be 0 to 31");
                    break;
                case "jr": need(a, 1, op, num); rs = reg(a[0], num); break;
                case "jalr":
                    if (a.length == 1) { rd = 31; rs = reg(a[0], num); }
                    else { need(a, 2, op, num); rd = reg(a[0], num); rs = reg(a[1], num); }
                    break;
                case "mult": case "multu": case "div": case "divu":
                    need(a, 2, op, num); rs = reg(a[0], num); rt = reg(a[1], num); break;
                case "mfhi": case "mflo": need(a, 1, op, num); rd = reg(a[0], num); break;
                default:
                    need(a, 3, op, num);
                    rd = reg(a[0], num); rs = reg(a[1], num); rt = reg(a[2], num);
            }
            return (rs << 21) | (rt << 16) | (rd << 11) | (sh << 6) | funct;
        }

        if (ITYPE.containsKey(op)) {
            int opcode = ITYPE.get(op);
            int rs = 0, rt = 0, imm = 0;
            switch (op) {
                case "beq": case "bne": {
                    need(a, 3, op, num);
                    rs = reg(a[0], num); rt = reg(a[1], num);
                    if (isNumber(a[2])) imm = parseInt(a[2], num);   // raw offset in words
                    else {
                        int target = label(a[2], num);
                        imm = (target - (l.address + 4)) / 4;
                    }
                    if (imm < -32768 || imm > 32767) throw new AsmError("line " + num + " branch to " + a[2] + " is too far away");
                    break;
                }
                case "lui":
                    need(a, 2, op, num); rt = reg(a[0], num); imm = immValue(a[1], num, false);
                    break;
                case "lw": case "sw": case "lb": case "lbu": case "lh": case "lhu": case "sb": case "sh": {
                    need(a, 2, op, num);
                    rt = reg(a[0], num);
                    String mem = a[1];
                    int open = mem.lastIndexOf('('), close = mem.lastIndexOf(')');
                    if (open < 0 || close < open) throw new AsmError("line " + num + " " + op + " needs the form offset($reg) but got " + mem);
                    String off = mem.substring(0, open).trim();
                    rs = reg(mem.substring(open + 1, close).trim(), num);
                    imm = off.isEmpty() ? 0 : immValue(off, num, true);
                    break;
                }
                case "andi": case "ori": case "xori":
                    need(a, 3, op, num); rt = reg(a[0], num); rs = reg(a[1], num); imm = immValue(a[2], num, false);
                    break;
                default: // addi addiu slti sltiu
                    need(a, 3, op, num); rt = reg(a[0], num); rs = reg(a[1], num); imm = immValue(a[2], num, true);
            }
            return (opcode << 26) | (rs << 21) | (rt << 16) | (imm & 0xffff);
        }
        throw new AsmError("line " + num + " unsupported instruction " + op);
    }

    // immediate that can be a number or %hi(label) or %lo(label)
    int immValue(String s, int num, boolean signed) throws AsmError {
        int v;
        if (s.startsWith("%hi(") && s.endsWith(")")) v = (labelOrNumber(s.substring(4, s.length() - 1), num) >> 16) & 0xffff;
        else if (s.startsWith("%lo(") && s.endsWith(")")) v = labelOrNumber(s.substring(4, s.length() - 1), num) & 0xffff;
        else v = parseInt(s, num);
        if (signed && (v < -32768 || v > 32767)) throw new AsmError("line " + num + " immediate " + s + " does not fit in 16 signed bits");
        if (!signed && (v < 0 || v > 65535)) throw new AsmError("line " + num + " immediate " + s + " does not fit in 16 unsigned bits");
        return v;
    }

    int labelOrNumber(String s, int num) throws AsmError {
        if (isNumber(s)) return parseInt(s, num);
        return label(s, num);
    }

    int label(String s, int num) throws AsmError {
        Integer v = labels.get(s);
        if (v == null) throw new AsmError("line " + num + " label " + s + " is not defined anywhere");
        return v;
    }

    int reg(String s, int num) throws AsmError {
        if (!s.startsWith("$")) throw new AsmError("line " + num + " expected a register like $t0 but got " + s);
        String n = s.substring(1);
        if (n.matches("\\d+")) {
            int r = Integer.parseInt(n);
            if (r > 31) throw new AsmError("line " + num + " there is no register " + s);
            return r;
        }
        for (int i = 0; i < 32; i++) if (REG_NAMES[i].equals(n)) return i;
        throw new AsmError("line " + num + " unknown register " + s);
    }

    // ------------------------------------------------------------- helpers
    static String stripComment(String s) {
        boolean inStr = false;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '"') inStr = !inStr;
            if (c == '#' && !inStr) return s.substring(0, i);
        }
        return s;
    }

    // "addi $t0, $t1, 5" becomes [addi, $t0, $t1, 5]
    static String[] splitInstr(String line) {
        String[] first = line.trim().split("\\s+", 2);
        String op = first[0].toLowerCase();
        if (first.length == 1) return new String[]{op};
        String[] args = first[1].split(",");
        String[] out = new String[args.length + 1];
        out[0] = op;
        for (int i = 0; i < args.length; i++) out[i + 1] = args[i].trim();
        return out;
    }

    static void need(String[] a, int n, String op, int num) throws AsmError {
        if (a.length != n) throw new AsmError("line " + num + " " + op + " needs " + n + " operands but got " + a.length);
    }

    static boolean isNumber(String s) {
        return s.matches("-?(0[xX][0-9a-fA-F]+|\\d+)");
    }

    static long parseLong(String s, int num) throws AsmError {
        if (!isNumber(s)) throw new AsmError("line " + num + " expected a number but got " + s);
        try {
            boolean neg = s.startsWith("-");
            String t = neg ? s.substring(1) : s;
            long v = t.toLowerCase().startsWith("0x") ? Long.parseLong(t.substring(2), 16) : Long.parseLong(t);
            return neg ? -v : v;
        } catch (NumberFormatException e) {
            throw new AsmError("line " + num + " number " + s + " is too big");
        }
    }

    static int parseInt(String s, int num) throws AsmError {
        long v = parseLong(s, num);
        if (v < Integer.MIN_VALUE || v > 0xffffffffL) throw new AsmError("line " + num + " number " + s + " does not fit in 32 bits");
        return (int) v;
    }

    static String unescape(String s, int num) throws AsmError {
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c != '\\') { b.append(c); continue; }
            if (++i >= s.length()) throw new AsmError("line " + num + " string ends with a lone backslash");
            switch (s.charAt(i)) {
                case 'n': b.append('\n'); break;
                case 't': b.append('\t'); break;
                case '0': b.append('\0'); break;
                case '\\': b.append('\\'); break;
                case '"': b.append('"'); break;
                default: throw new AsmError("line " + num + " unknown escape \\" + s.charAt(i));
            }
        }
        return b.toString();
    }

    // ------------------------------------------------------------- output
    // The header is five words. magic, text start, text word count,
    // data start, data byte count. Then the text words then the data bytes
    // in address order padded to a multiple of four.
    List<Integer> allWords() {
        List<Integer> out = new ArrayList<>();
        out.add(MAGIC); out.add(TEXT_START); out.add(words.size());
        out.add(DATA_START); out.add(data.size());
        out.addAll(words);
        byte[] d = data.toByteArray();
        for (int i = 0; i < d.length; i += 4) {
            int w = 0;
            for (int k = 0; k < 4; k++) {
                int b = i + k < d.length ? d[i + k] & 0xff : 0;
                w = (w << 8) | b;
            }
            out.add(w);
        }
        return out;
    }

    void writeAscii(String path) throws IOException {
        List<Integer> all = allWords();
        try (PrintWriter w = new PrintWriter(new FileWriter(path))) {
            for (int i = 0; i < all.size(); i++) {
                // blank lines separate the header the text and the data
                if (i == 5 || i == 5 + words.size()) w.println();
                String bits = Integer.toBinaryString(all.get(i));
                while (bits.length() < 32) bits = "0" + bits;
                w.println(bits);
            }
        }
    }

    void writeBin(String path) throws IOException {
        try (DataOutputStream w = new DataOutputStream(new FileOutputStream(path))) {
            for (int word : allWords()) w.writeInt(word);   // big endian so the opcode byte comes first
        }
    }
}
