#!/bin/sh
# Runs every test for the assembler and disassembler.
# Run from the assembler-project folder with   sh tests/run_tests.sh
# If Mars.jar is in the folder it is also used to cross check the machine code and run the programs.
cd "$(dirname "$0")/.." || exit 1
javac Assembler.java Disassembler.java || exit 1
mkdir -p tests/out
T=tests/out
pass=0; fail=0
ok()   { echo "PASS $1"; pass=$((pass+1)); }
bad()  { echo "FAIL $1"; fail=$((fail+1)); }

echo "== 1 assemble fizzbuzz.asm"
java Assembler fizzbuzz.asm $T/fizzbuzz && ok "assembled fizzbuzz.asm" || bad "assembled fizzbuzz.asm"
cmp -s $T/fizzbuzz.mhc-bin fizzbuzz.mhc-bin && ok "fizzbuzz.mhc-bin matches the file in the repo" || bad "fizzbuzz.mhc-bin matches the file in the repo"
cmp -s $T/fizzbuzz.mhc-ascii fizzbuzz.mhc-ascii && ok "fizzbuzz.mhc-ascii matches the file in the repo" || bad "fizzbuzz.mhc-ascii matches the file in the repo"

echo "== 2 the ascii file is the bin file written as text"
python3 - "$T" <<'PY' && ok "ascii words equal bin words" || bad "ascii words equal bin words"
import sys,struct
t=sys.argv[1]
b=open(t+'/fizzbuzz.mhc-bin','rb').read()
w=['%032d'%int(bin(x)[2:]) for x in struct.unpack('>%dI'%(len(b)//4),b)]
a=[l for l in open(t+'/fizzbuzz.mhc-ascii').read().split('\n') if l]
sys.exit(0 if a==w else 1)
PY

echo "== 3 disassemble both formats"
java Disassembler $T/fizzbuzz.mhc-bin $T/from_bin.asm && ok "disassembled the bin file" || bad "disassembled the bin file"
java Disassembler $T/fizzbuzz.mhc-ascii $T/from_ascii.asm && ok "disassembled the ascii file" || bad "disassembled the ascii file"
tail -n +2 $T/from_bin.asm > $T/a.tmp; tail -n +2 $T/from_ascii.asm > $T/b.tmp
cmp -s $T/a.tmp $T/b.tmp && ok "both formats give the same program" || bad "both formats give the same program"
tail -n +2 fizzbuzz_rebuilt.asm > $T/c.tmp
cmp -s $T/a.tmp $T/c.tmp && ok "matches fizzbuzz_rebuilt.asm in the repo" || bad "matches fizzbuzz_rebuilt.asm in the repo"

echo "== 4 reassemble the rebuilt program and compare bytes"
java Assembler $T/from_bin.asm $T/again >/dev/null && ok "rebuilt program assembles" || bad "rebuilt program assembles"
cmp -s $T/again.mhc-bin fizzbuzz.mhc-bin && ok "rebuilt bin bytes identical to the original" || bad "rebuilt bin bytes identical to the original"
cmp -s $T/again.mhc-ascii fizzbuzz.mhc-ascii && ok "rebuilt ascii identical to the original" || bad "rebuilt ascii identical to the original"

echo "== 5 part 1 instructions"
java Assembler tests/part1.asm $T/part1 >/dev/null && ok "part1.asm assembles" || bad "part1.asm assembles"
sed -n '7,10p' $T/part1.mhc-ascii > $T/part1_words.txt
printf '00100000000010000000000000000011\n00100000000010010000000000000101\n00000001000010010101000000100000\n00000001001010000101100000100010\n' > $T/part1_expected.txt
cmp -s $T/part1_words.txt $T/part1_expected.txt && ok "part 1 words match my hand assembly" || bad "part 1 words match my hand assembly"

echo "== 6 bad assembly input gives an error"
for f in bad_instruction bad_register bad_label bad_immediate bad_operands bad_data; do
  if java Assembler tests/$f.asm $T/$f >$T/$f.log 2>&1; then bad "$f.asm should have failed"; else ok "$f.asm rejected. $(cat $T/$f.log)"; fi
done

echo "== 7 bad machine code input gives an error"
for f in cutoff.mhc-bin wrong_count.mhc-bin short_line.mhc-ascii bad_char.mhc-ascii not_mhc.mhc-ascii unknown_opcode.mhc-ascii; do
  if java Disassembler tests/$f $T/$f.asm >$T/$f.log 2>&1; then bad "$f should have failed"; else ok "$f rejected. $(cat $T/$f.log)"; fi
done

if [ -f Mars.jar ]; then
  echo "== 8 cross check with MARS"
  java -jar Mars.jar nc a dump .text HexText $T/mars_text.hex fizzbuzz.asm >/dev/null 2>&1
  python3 - "$T" <<'PY' && ok "text words equal the MARS dump" || bad "text words equal the MARS dump"
import sys,struct
t=sys.argv[1]
b=open(t+'/fizzbuzz.mhc-bin','rb').read()
w=struct.unpack('>%dI'%(len(b)//4),b)
mine=['%08x'%x for x in w[5:5+w[2]]]
mars=open(t+'/mars_text.hex').read().split()
sys.exit(0 if mine==mars else 1)
PY
  java -jar Mars.jar nc fizzbuzz.asm 2>/dev/null | grep -v '^Picked' > $T/orig.out
  java -jar Mars.jar nc $T/from_bin.asm 2>/dev/null | grep -v '^Picked' > $T/rebuilt.out
  cmp -s $T/orig.out $T/rebuilt.out && ok "original and rebuilt print the same thing in MARS" || bad "original and rebuilt print the same thing in MARS"
  python3 -c "
import sys
exp=[('FizzBuzz' if i%15==0 else 'Fizz' if i%3==0 else 'Buzz' if i%5==0 else str(i)) for i in range(1,101)]
got=[l for l in open('$T/rebuilt.out').read().split('\n') if l]
sys.exit(0 if got==exp else 1)" && ok "rebuilt output is the correct FizzBuzz 1 to 100" || bad "rebuilt output is the correct FizzBuzz 1 to 100"
else
  echo "== 8 skipped. put Mars.jar in this folder to cross check with MARS"
fi

echo
echo "$pass passed $fail failed"
[ $fail -eq 0 ]
