import java.io.*;
import java.nio.file.*;
import java.util.*;

/*
 * Disassembler.java
 * Reads a .mhc-ascii or .mhc-bin file made by Assembler.java and writes a
 * MIPS assembly file that assembles back to the same bytes.
 *
 * Run with
 *   javac Disassembler.java
 *   java Disassembler fizzbuzz.mhc-bin            writes fizzbuzz.mhc-bin.asm
 *   java Disassembler fizzbuzz.mhc-ascii out.asm  writes out.asm
 *
 * The file type is found from the contents not the name. A binary file
 * starts with the bytes M H C 1. A text file starts with that same word
 * written as 32 zero and one characters.
 */
public class Disassembler {

    static final int MAGIC = 0x4D484331;

    static final String[] REG_NAMES = {
        "zero","at","v0","v1","a0","a1","a2","a3",
        "t0","t1","t2","t3","t4","t5","t6","t7",
        "s0","s1","s2","s3","s4","s5","s6","s7",
        "t8","t9","k0","k1","gp","sp","fp","ra" };

    static final Map<Integer,String> FUNCT = new HashMap<>();
    static final Map<Integer,String> OPCODE = new HashMap<>();
    static {
        FUNCT.put(0x20,"add");  FUNCT.put(0x21,"addu"); FUNCT.put(0x22,"sub");  FUNCT.put(0x23,"subu");
        FUNCT.put(0x24,"and");  FUNCT.put(0x25,"or");   FUNCT.put(0x26,"xor");  FUNCT.put(0x27,"nor");
        FUNCT.put(0x2a,"slt");  FUNCT.put(0x2b,"sltu");
        FUNCT.put(0x00,"sll");  FUNCT.put(0x02,"srl");  FUNCT.put(0x03,"sra");
        FUNCT.put(0x08,"jr");   FUNCT.put(0x09,"jalr");
        FUNCT.put(0x18,"mult"); FUNCT.put(0x19,"multu"); FUNCT.put(0x1a,"div"); FUNCT.put(0x1b,"divu");
        FUNCT.put(0x10,"mfhi"); FUNCT.put(0x12,"mflo");
        FUNCT.put(0x0c,"syscall"); FUNCT.put(0x0d,"break");

        OPCODE.put(0x08,"addi"); OPCODE.put(0x09,"addiu"); OPCODE.put(0x0a,"slti"); OPCODE.put(0x0b,"sltiu");
        OPCODE.put(0x0c,"andi"); OPCODE.put(0x0d,"ori");   OPCODE.put(0x0e,"xori"); OPCODE.put(0x0f,"lui");
        OPCODE.put(0x23,"lw");   OPCODE.put(0x2b,"sw");    OPCODE.put(0x20,"lb");   OPCODE.put(0x24,"lbu");
        OPCODE.put(0x21,"lh");   OPCODE.put(0x25,"lhu");   OPCODE.put(0x28,"sb");   OPCODE.put(0x29,"sh");
        OPCODE.put(0x04,"beq");  OPCODE.put(0x05,"bne");
        OPCODE.put(0x02,"j");    OPCODE.put(0x03,"jal");
    }

    static class DisError extends Exception {
        DisError(String msg) { super(msg); }
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("usage  java Disassembler program.mhc-bin|program.mhc-ascii [output.asm]");
            System.exit(2);
        }
        String in = args[0];
        String out = args.length > 1 ? args[1] : in + ".asm";
        try {
            int[] words = readWords(in);
            String asm = disassemble(words, in);
            Files.write(Paths.get(out), asm.getBytes("US-ASCII"));
            System.out.println("wrote " + out);
        } catch (DisError e) {
            System.err.println("error " + e.getMessage());
            System.exit(1);
        } catch (IOException e) {
            System.err.println("error could not read or write a file. " + e.getMessage());
            System.exit(1);
        }
    }

    // ------------------------------------------------------------ reading
    // Returns every 32 bit word in the file in order. Works for both formats.
    static int[] readWords(String path) throws IOException, DisError {
        byte[] raw = Files.readAllBytes(Paths.get(path));
        if (raw.length == 0) throw new DisError(path + " is empty");

        // binary file. the first four bytes spell MHC1
        if (raw.length >= 4 && raw[0] == 'M' && raw[1] == 'H' && raw[2] == 'C' && raw[3] == '1') {
            if (raw.length % 4 != 0)
                throw new DisError(path + " has " + raw.length + " bytes which is not a multiple of 4. The file is cut off or damaged");
            int[] w = new int[raw.length / 4];
            for (int i = 0; i < w.length; i++)
                w[i] = ((raw[4*i] & 0xff) << 24) | ((raw[4*i+1] & 0xff) << 16) | ((raw[4*i+2] & 0xff) << 8) | (raw[4*i+3] & 0xff);
            return w;
        }

        // text file. one word per line as 32 zero or one characters
        List<Integer> list = new ArrayList<>();
        String[] lines = new String(raw, "US-ASCII").split("\r?\n");
        for (int i = 0; i < lines.length; i++) {
            String s = lines[i].trim();
            if (s.isEmpty() || s.startsWith("#")) continue;
            if (s.length() != 32)
                throw new DisError(path + " line " + (i + 1) + " has " + s.length() + " characters. Every line must have exactly 32 zeros and ones");
            if (!s.matches("[01]{32}"))
                throw new DisError(path + " line " + (i + 1) + " has a character that is not 0 or 1");
            list.add((int) Long.parseLong(s, 2));
        }
        if (list.isEmpty()) throw new DisError(path + " has no binary lines in it");
        int[] w = new int[list.size()];
        for (int i = 0; i < w.length; i++) w[i] = list.get(i);
        if (w[0] != MAGIC)
            throw new DisError(path + " does not start with the MHC1 header word so it is not a file from Assembler.java");
        return w;
    }

    // ------------------------------------------------------------ decoding
    static String disassemble(int[] w, String path) throws DisError {
        if (w.length < 5) throw new DisError(path + " is too short to hold the five word header");
        if (w[0] != MAGIC) throw new DisError(path + " does not start with the MHC1 header word");
        int textStart = w[1], textCount = w[2], dataStart = w[3], dataBytes = w[4];
        int dataWords = (dataBytes + 3) / 4;
        if (textCount < 0 || dataBytes < 0 || 5 + textCount + dataWords != w.length)
            throw new DisError(path + " header says " + textCount + " text words and " + dataBytes
                + " data bytes but the file holds " + (w.length - 5) + " words after the header");

        int[] text = Arrays.copyOfRange(w, 5, 5 + textCount);

        // first pass. find every branch and jump target so it can get a label
        Map<Integer,String> labels = new TreeMap<>();
        labels.put(textStart, "main");
        for (int i = 0; i < textCount; i++) {
            int ins = text[i], pc = textStart + 4 * i;
            int op = ins >>> 26;
            if (op == 4 || op == 5) {
                int off = (short) (ins & 0xffff);
                labels.putIfAbsent(pc + 4 + off * 4, null);
            } else if (op == 2 || op == 3) {
                labels.putIfAbsent((pc & 0xF0000000) | ((ins & 0x03ffffff) << 2), null);
            }
        }
        int n = 1;
        for (Map.Entry<Integer,String> e : labels.entrySet())
            if (e.getValue() == null) e.setValue("L" + (n++));

        StringBuilder out = new StringBuilder();
        out.append("# Rebuilt by Disassembler.java from ").append(Paths.get(path).getFileName()).append("\n");
        out.append("# text starts at ").append(hex(textStart)).append(" with ").append(textCount).append(" instructions\n");
        out.append("# data starts at ").append(hex(dataStart)).append(" with ").append(dataBytes).append(" bytes\n\n");

        if (dataBytes > 0) {
            out.append(".data\n");
            int base = 5 + textCount;
            for (int i = 0; i < dataBytes; i++) {
                int b = (w[base + i / 4] >>> (24 - 8 * (i % 4))) & 0xff;
                if (i % 8 == 0) out.append(i == 0 ? ".byte " : "\n.byte ");
                else out.append(", ");
                out.append(b);
            }
            out.append("\n\n");
        }

        out.append(".text\n");
        for (int i = 0; i < textCount; i++) {
            int pc = textStart + 4 * i;
            if (labels.containsKey(pc)) out.append(labels.get(pc)).append(":\n");
            out.append(decode(text[i], pc, labels)).append("\n");
        }
        return out.toString();
    }

    static String decode(int ins, int pc, Map<Integer,String> labels) throws DisError {
        int op = ins >>> 26;
        int rs = (ins >>> 21) & 31, rt = (ins >>> 16) & 31, rd = (ins >>> 11) & 31;
        int sh = (ins >>> 6) & 31, funct = ins & 63;
        int imm = (short) (ins & 0xffff);     // sign extended
        int uimm = ins & 0xffff;

        if (op == 0) {
            String name = FUNCT.get(funct);
            if (name == null) throw new DisError("unsupported R type funct " + hex6(funct) + " in word " + hex(ins) + " at " + hex(pc));
            switch (name) {
                case "syscall": case "break": return name;
                case "sll": case "srl": case "sra": return name + " " + r(rd) + ", " + r(rt) + ", " + sh;
                case "jr": return name + " " + r(rs);
                case "jalr": return name + " " + r(rd) + ", " + r(rs);
                case "mult": case "multu": case "div": case "divu": return name + " " + r(rs) + ", " + r(rt);
                case "mfhi": case "mflo": return name + " " + r(rd);
                default: return name + " " + r(rd) + ", " + r(rs) + ", " + r(rt);
            }
        }
        String name = OPCODE.get(op);
        if (name == null) throw new DisError("unsupported opcode " + hex6(op) + " in word " + hex(ins) + " at " + hex(pc));
        switch (name) {
            case "j": case "jal": {
                int target = (pc & 0xF0000000) | ((ins & 0x03ffffff) << 2);
                return name + " " + labels.get(target);
            }
            case "beq": case "bne":
                return name + " " + r(rs) + ", " + r(rt) + ", " + labels.get(pc + 4 + imm * 4);
            case "lui": return name + " " + r(rt) + ", " + uimm;
            case "andi": case "ori": case "xori": return name + " " + r(rt) + ", " + r(rs) + ", " + uimm;
            case "lw": case "sw": case "lb": case "lbu": case "lh": case "lhu": case "sb": case "sh":
                return name + " " + r(rt) + ", " + imm + "(" + r(rs) + ")";
            default: return name + " " + r(rt) + ", " + r(rs) + ", " + imm;
        }
    }

    static String r(int n) { return "$" + REG_NAMES[n]; }
    static String hex(int v) { return String.format("0x%08x", v); }
    static String hex6(int v) { return String.format("0x%02x", v); }
}
