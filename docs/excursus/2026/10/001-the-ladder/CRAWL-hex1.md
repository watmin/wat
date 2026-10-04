# CRAWL — hex1: what stage0-posix's hex1 does, and what ours must decide

2026-10-04. Read from source: stage0-posix-amd64 `hex1_AMD64.hex0` (315 lines, about 500 bytes of code), fetched from
`raw.githubusercontent.com/oriansj/stage0-posix-amd64/master/hex1_AMD64.hex0` into `/var/tmp/hex1-crawl/`. Every
claim below cites a line of that file. Bash is the sequencer for hex1: it issues `hex0 hex1.hex0 hex1`, and the gate
checks the result (the builder's ruling, recorded in WEIGH-hex0).

## What hex1 adds to hex0

**One new form: a single-character label, and a 32-bit relative reference to it.**
- `:c` defines label `c` at the current output offset (IP). `c` is ONE byte, any byte value.
  - `Get_table_target` reads a single character, multiplies it by 8, and indexes a 256-entry table (lines 277-281).
  - `StoreLabel` writes the IP into the table (283-286).
- `%c` emits a 4-byte little-endian displacement: `target − (IP after the 4 bytes)`.
  - `StorePointer` does `add r13, 4`, then `sub rax, r13`, and writes 4 bytes (288-296).
  - That is exactly x86's `rel32` (relative to the next instruction, when the field ends the instruction).
- Nothing else is added: no 8-bit or 16-bit references, and no absolute addresses. Those are hex2's.

**Two passes over the input.**
- Pass 1 records every label's IP: hex digits advance IP by 1 per byte, and `%c` advances it by 4 (lines 92-135).
- `lseek(IN, 0, SEEK_SET)` rewinds the input (80-83), and pass 2 emits the bytes and the displacements (171-196).
- So IN must be seekable. A pipe or FIFO cannot be hex1's input.

**What stage0 does not do** (each of these is a gap in our hex0's sense of total):
- An undefined label reads a zero table entry and silently emits `0 − IP`. A duplicate `:c` silently takes the last
  value. There is no refusal for either.
- No syscall result is checked: open, read, write and lseek are all unchecked. It always exits 0 (`Done`, line
  233-236).
- A comment ends at CR **or** LF (`ascii_comment`, 213-218). Our hex0 ends a comment at LF or EOF only.
- OUT is opened `O_WRONLY|O_CREAT|O_TRUNC` with mode 0700 (67-68). Ours is 0755, truncated after the checks.
- `:c` is recognised only at the top of each pass's loop, so a `:` or `%` inside a comment is skipped as comment.

## What our hex1 must decide (recommendations, for the builder to rule where marked)

1. **The inherited contract.**
   - Recommend: hex1 accepts exactly hex0's language (comments end at LF or EOF; hex digits paired; whitespace is
     space, tab, CR or LF), plus `:c` and `%c`.
   - It keeps hex0's statuses 0–7 with the same meanings, and the same OUT handling: O_NONBLOCK, same-file 7,
     not-regular 3, fchmod then ftruncate.
   - Each new failure gets a NEW status number, never an overloaded old one.
2. **New refusals** (totality). Each has its own status:
   - a reference to a label never defined;
   - a label defined twice;
   - a displacement that does not fit 32 bits signed;
   - IN not seekable (lseek fails).
   - Stage0 accepts all four silently.
3. **The label alphabet.**
   - Recommend: one byte, restricted to printable ASCII that is not a hex digit, not whitespace, not `#`, `;`, `:` or
     `%`. Anything else after `:` or `%` is refused.
   - Stage0 allows any byte, including a newline, which makes `:` followed by a line end a label named LF.
   - **Builder ruling wanted:** one character, as stage0 has it, or longer names now. Longer names cost a
     string table in hand-written hex. stage0 waits for hex2 to get long names.
4. **What IP counts.** IP is the output offset from 0. The ELF header is written in hex1's own source, so labels count
   from the file's first byte. A displacement between two code labels is therefore correct whatever the load
   address. Recommend: state that in the README.
5. **The width of a reference.** Only `%` (rel32), as stage0 has it. Short jumps stay hand-computed raw hex until
   hex2. Recommend: no 8-bit form in hex1, because one width keeps the seed-to-hex1 step small.
6. **How it is built and checked.**
   - The sequencer (bash) runs `hex0 ladder/1-hex1/x86_64-linux/hex1.hex0 out/hex1`.
   - The gate's rows run `out/hex1` on hex1's fixtures, observe and judge, reusing round 7's runner and judges.
   - The fixpoint shape for hex1: hex1 assembles its own source, written in hex1's language, to the same bytes that
     hex0 built from the hex0-language form.
   - **Open:** does hex1 carry one source written in hex0's language (built by hex0), plus a second, label-using form
     proven equal? stage0 has only the hex0-language source.
7. **Size.** Stage0's code is about 500 bytes. Ours adds refusals, so expect roughly 700–900 bytes.
