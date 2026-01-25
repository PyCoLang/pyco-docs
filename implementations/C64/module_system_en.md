# PyCo Module System - Design Document

## Overview

The PyCo module system enables the use of external code from other `.pyco` files. The system supports two operating modes, following Python syntax:

1. **Static import** (`from X import a, b`): Compile-time linking, code is compiled into the PRG
2. **Dynamic import** (`import X`): Module registration + explicit runtime loading

### Design Principles

- **Python syntax**: Familiar `from`/`import` keywords with different semantics
- **Simplicity**: No relocation table, marker-byte based relocation
- **Efficiency**: Zero overhead in module size
- **Programmer control**: Explicit `load_module()`, no automatic lifecycle management
- **Forward compatible**: Works for compiler running on C64 (everything pre-registered)

## Import Syntax

### Static Import: `from X import`

Listed elements are **compiled into the PRG**, directly usable:

```python
# File beginning - STATIC import
from math import sin, cos         # sin, cos code is compiled in
from gfx import Sprite, draw_line # Sprite class, draw_line func compiled in
from screen import row_offsets    # Global tuple is compiled in

def main():
    x = sin(0.5)                  # Direct call, no prefix!
    y = cos(0.5)
    s: Sprite
    s()
    draw_line(0, 0, x, y)
    offset: word = row_offsets[5] # Tuple access
```

**Characteristics:**

| Property           | Value                                              |
| ------------------ | -------------------------------------------------- |
| Compile-time       | Code compiles into PRG                             |
| Runtime overhead   | None (static linking)                              |
| Usage              | No prefix: `sin()`, `Sprite`, `tuple[]`            |
| Tree-shaking       | Only listed elements are compiled in               |
| Type checking      | Compile-time                                       |

### Dynamic Import: `import X`

The module is **registered**, but code is **NOT compiled in**:

```python
# DYNAMIC module registration
import math                       # Info Section read + BSS pointer allocation
import sprites                    # __mod_math: .word 0, __mod_sprites: .word 0

def game_session():
    load_module(math)             # Runtime load to stack
    load_module(sprites)

    while running:
        x = math.sin(0.5)         # With namespace! math.sin
        player: sprites.Sprite    # sprites.Sprite
        player()
        player.update()

    # Return → stack resets → modules "disappear"
    # BSS pointers remain - programmer's responsibility!

def game_loop():
    # If game_session() already loaded it, works
    x = math.sin(0.5)             # __mod_math + SIN_OFFSET
    # If not loaded → crash (pointer = 0 or garbage)
```

**Characteristics:**

| Property           | Value                                            |
| ------------------ | ------------------------------------------------ |
| Compile-time       | Only Info Section read (signatures)              |
| BSS allocation     | 2 byte pointer per module                        |
| Runtime            | Explicit `load_module()` call                    |
| Usage              | With namespace: `math.sin()`, `sprites.Sprite`   |
| Cleanup            | Programmer's responsibility (stack-based)        |

### Comparison

| Syntax                 | Compiled? | Usage           | Loading         |
| ---------------------- | --------- | --------------- | --------------- |
| `from X import a`      | ✓ Yes     | `a()`           | Automatic       |
| `import X`             | ✗ No      | `X.a()`         | `load_module()` |

## The `load_module()` Function

### Syntax

```python
load_module(module_name)
```

### Operation

1. **Save SSP**: Current SSP value = module_base (where module will be loaded)
2. **Advance SSP FIRST** (IRQ-safe!): SSP += code_size + 4 (compile-time known size + header)
3. **Disable IRQ + Enable ROM**: SEI, then `$01 = $37` (Kernal ROM on)
4. **Initialize Kernal I/O**: CLALL ($FFE7) + CLRCH ($FFCC)
5. **Set filename**: SETNAM ($FFBD) from Pascal string
6. **Open file**: SETLFS ($FFBA) device 8, **SA=0** (important!)
7. **Load**: LOAD ($FFD5) to module_base address
   - Kernal **skips first 2 bytes** (magic) with SA=0
   - Remainder (code_size + code_end + code) loads to module_base
8. **Relocation**: Instruction-by-instruction scan, JAM marker + JMP/JSR patching
9. **BSS pointer setup**: `__mod_X = load address + 4` (after header)
10. **Restore ROM + Enable IRQ**: `$01` restore, CLI

### Why IRQ-Safe? (2026-01)

In the previous implementation, SSP was incremented **after** the LOAD. This caused problems if an IRQ fired during loading:

```
During LOAD (WRONG - old):            When IRQ fires:

SSP → ┌────────────────┐              SSP → ┌────────────────┐
      │ MODULE LOADING │ ← LOAD             │ MODULE LOADING │
+4 →  ├────────────────┤              +4 →  ├────────────────┤
      │ (module data)  │                    │ IRQ local #1   │ ← OVERWRITTEN!
      └────────────────┘                    └────────────────┘
```

The new solution: SSP is advanced **BEFORE** the LOAD starts by the module's size. This way, the IRQ handler writes from SSP+4 (which is above the "reserved" area) and won't overwrite the module being loaded.

```
During LOAD (CORRECT - new):          When IRQ fires:

module_base → ┌────────────────┐      module_base → ┌────────────────┐
              │ MODULE LOADING │ ← LOAD             │ MODULE LOADING │ ← Safe!
              ├────────────────┤                    ├────────────────┤
SSP ────────► │ (empty - guard)│      SSP ────────► │ (empty - guard)│
        +4 →  ├────────────────┤              +4 →  ├────────────────┤
              │                │                    │ IRQ local #1   │ ← OK!
              └────────────────┘                    └────────────────┘
```

### Important: Module Recompilation Required!

**If a dynamically imported module (`.pm` file) changes, the main program MUST be recompiled!**

This is because the module's `code_size` value is embedded at **compile-time** in the main program for IRQ-safe loading. If the module size changes (new function, modified code) but the main program still contains the old size:
- Smaller module → memory waste (not critical)
- **Larger module** → **overflow, crash!** (LOAD exceeds the reserved area)

**This is automatic for static imports** (module is compiled into the program).

### Critical Implementation Details

| Question                       | Solution                                                    |
| ------------------------------ | ----------------------------------------------------------- |
| Why SA=0?                      | SA=1 would load to file's first 2 bytes ($0000)!            |
| Why SEI?                       | ROM switch would make IRQ vector point wrong                |
| Where is module_base?          | In tmp2/tmp3, saved to hw stack (Kernal corrupts ZP!)       |
| What if LOAD error?            | A/X = 0 (null pointer), stack cleanup, rts                  |
| Why advance SSP first?         | IRQ-safe: IRQ handler won't overwrite loading module        |

### Stack Management (LIFO)

```
                    ┌─────────────────┐
                    │ sprites module  │ ← load_module(sprites) - 2nd
      SSP ────────► ├─────────────────┤
                    │ math module     │ ← load_module(math) - 1st
                    ├─────────────────┤
                    │ local variables │
                    ├─────────────────┤
                    │ stack frame     │
                    └─────────────────┘
```

**Important:** Modules "disappear" in LIFO order when function returns!

### No `unload_module()`

No explicit unload needed:

- When function returns, SSP resets
- Module memory is automatically freed
- **BUT:** The BSS pointer (`__mod_X`) remains!

**Programmer's responsibility:** If the pointer points to "garbage" address and you call the module → crash. This is fine - trust the programmer.

## Alias (`as`) Support

### For Static Import

```python
from math import sin as math_sin
from audio import sin as audio_sin    # Name collision resolution

x = math_sin(0.5)                     # Direct call
freq = audio_sin(440)
```

### For Dynamic Import

```python
import math as m                      # Shorter namespace
import very_long_module_name as vlm

load_module(m)
x = m.sin(0.5)                        # m.sin instead of math.sin
```

### Name Collision Handling

```python
from math import sin
from audio import sin     # ERROR: 'sin' already imported from 'math'!

# Solution - use alias:
from math import sin
from audio import sin as audio_sin   # OK
```

## Export Rules

### Python-style Convention

```python
# Simple rule:
# _prefix = private (NOT exported)
# No prefix = public (exported)
```

### Example Module

```python
# math.pyco

def sin(x: float) -> float:         # ✓ Exported (public)
    return _sin_impl(x)

def cos(x: float) -> float:         # ✓ Exported (public)
    return _cos_impl(x)

def _sin_impl(x: float) -> float:   # ✗ NOT exported (private)
    ...

def _normalize(x: float) -> float:  # ✗ NOT exported (private)
    ...

LOOKUP_TABLE: tuple[byte] = (...)   # ✓ Exported (public constant)

_INTERNAL_BUFFER: array[byte, 64]   # ✗ NOT exported (private data)
```

### Static Import and Re-export

Statically imported names are **automatically exported**, EXCEPT if they receive a `_` prefixed alias:

```python
# my_game_utils.pyco - custom "package" composition

# These will be PUBLIC (exported):
from math import sin, cos
from physics import update_pos

# This stays PRIVATE (not exported):
from internal import debug_helper as _debug

# Custom public function:
def rotate(x: int, y: int, angle: float) -> int:
    _debug("rotating...")
    return int(x * cos(angle) - y * sin(angle))
```

**Result - my_game_utils.pm exports:**

| Name           | Source                 | Exported? |
| -------------- | ---------------------- | --------- |
| `sin`          | math                   | ✓ Yes     |
| `cos`          | math                   | ✓ Yes     |
| `update_pos`   | physics                | ✓ Yes     |
| `rotate`       | own                    | ✓ Yes     |
| `_debug`       | internal (as _debug)   | ✗ No      |

## Custom Module Composition

### Concept

If you only need a few functions from large libraries, you can create your own module:

```
┌─────────────────────────────────────────────────────────────┐
│ LARGE LIBRARIES:                                            │
│   math.pyco (20 functions)                                  │
│   gfx.pyco (30 functions)                                   │
│   physics.pyco (15 functions)                               │
└────────────────────┬────────────────────────────────────────┘
                     │ static import (selection)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ CUSTOM MODULE (only what you need + your own code):         │
│   my_game_utils.pyco:                                       │
│     from math import sin, cos      # 2 functions           │
│     from gfx import draw_sprite    # 1 function            │
│     def rotate(): ...              # own                   │
│                                                             │
│   Compile: pycoc compile my_game_utils.pyco --module       │
│   Result: MY_GAME_UTILS.PM (small size!)                   │
└────────────────────┬────────────────────────────────────────┘
                     │ dynamic import (runtime)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ MAIN PROGRAM:                                               │
│   import my_game_utils                                      │
│                                                             │
│   def game_screen():                                        │
│       load_module(my_game_utils)                            │
│       my_game_utils.rotate(...)                             │
│       x = my_game_utils.sin(0.5)                            │
└─────────────────────────────────────────────────────────────┘
```

### Benefits

- **Tree-shaking**: Only used functions are compiled into the module
- **Developer control**: You decide what belongs together
- **Small size**: PRG only contains loader code, module is separate file

### Modules and `main()`

Modules can have a `main()` function - this can contain test or demo code:

```python
# mylib.pyco
def useful_function():
    pass

def another_function():
    pass

def main():
    # Test code - only runs when executed directly
    print("Testing mylib...\n")
    useful_function()
```

**Compilation modes:**

| Command | Result | `main()` |
|---------|--------|----------|
| `pycoc compile mylib.pyco` | mylib.prg | ✓ Included, runs |
| `pycoc compile mylib.pyco --module` | mylib.pm | ✗ Excluded (tree-shaking) |

With `--module` flag, `main()` is automatically excluded from the .pm file because nobody imports/calls it. This doesn't require a separate file structure - it's simply how tree-shaking works.

**Usage:**
- **During development:** Compile as PRG, test with `main()`
- **In production:** Compile as .pm, import from other programs

## Marker-Byte Relocation

### The Problem

The 6502 uses absolute addressing. If we load a module to different addresses:

```asm
; Original address: $0000
start:
    JSR $0050        ; ← This needs to be rewritten!
    LDA $0100        ; ← This too!
    STA $D400        ; ← This NOT (HW register)
```

### The Solution: Marker-byte

The C64 memory map helps:

| Address Range   | Content                | Can module jump here? |
| --------------- | ---------------------- | --------------------- |
| `$0000-$00FF`   | Zero Page              | ❌ NEVER (data)        |
| `$0100-$01FF`   | Hardware Stack         | ❌ NEVER (data)        |
| `$0200-$02FF`   | OS variables           | ❌ NEVER               |
| `$0300-$03FF`   | Vectors, buffer        | ❌ NEVER               |
| `$0400-$07FF`   | Screen RAM (default)   | ❌ NEVER (data)        |
| `$0800-$FFFF`   | **Program area**       | ✓ YES                 |

**IMPORTANT:** A high byte of `$00-$07` is **NOT guaranteed** to be a module-internal address!

The C64 memory map shows that the `$0000-$07FF` range is system area (Zero Page,
Stack, Screen RAM). However, module internal addresses also start from `$0000`!
This means a module-internal offset of `$0400` and the C64 Screen RAM (`$0400`)
are **indistinguishable** in the binary.

**Solution:** Use explicit marker opcodes for addresses that need relocation:
- **JMP/JSR** - detected by high byte `$00-$07` (these are definitely internal)
- **Immediate high byte** - marked by JAM marker (`$02`)
- **ABS,X/ABS,Y DATA access** - marked by special marker opcodes (`$12`, `$32`)

### Marker Range

```
High byte detection (only for JMP/JSR/JMP(ind)!):
────────────────────────────────────────────────────────────
High byte: $00-$07 = Internal address (needs relocation)
High byte: $08-$FF = Fixed external address (HW register, etc.)

Offset calculation:
  offset = high_byte * 256 + low_byte

$00xx = offset    0 -  255
$01xx = offset  256 -  511
$02xx = offset  512 -  767
$03xx = offset  768 - 1023
$04xx = offset 1024 - 1279
$05xx = offset 1280 - 1535
$06xx = offset 1536 - 1791
$07xx = offset 1792 - 2047
────────────────────────────
Total: 2048 bytes (2KB) internal addressing
```

### Marker Opcodes

We use 6502 illegal opcodes as markers because:
1. They don't occur in normal code
2. If accidentally executed (without relocation), the CPU halts (JAM)
3. The relocator replaces them with the actual opcode

| Marker | Original opcode | Instruction type | Usage |
|--------|-----------------|------------------|-------|
| `$02`  | `$A9`           | LDA #            | Immediate high byte for pointer loading |
| `$12`  | `$BD`           | LDA ABS,X        | DATA section read with X index |
| `$22`  | `$AD`           | LDA ABS          | Direct DATA section read |
| `$32`  | `$B9`           | LDA ABS,Y        | DATA section read with Y index |
| `$42`  | `$4C`           | JMP ABS          | Internal jump (for >2KB modules) |
| `$52`  | `$20`           | JSR ABS          | Internal call (for >2KB modules) |

**Why are separate markers needed for ABS,X/ABS,Y?**

In modules, tuple/constant data resides in the DATA section. For constant index
access, the compiler generates direct ABS,X/ABS,Y addressing for efficiency:

```asm
; tuple[5] access - direct ABS addressing
lda tuple_data+10    ; Efficient, but address needs relocation!
```

The problem: if this address is e.g. `$0400`, it matches the C64 Screen RAM address!
High byte detection cannot distinguish them. The marker explicitly indicates
that this is a module-internal DATA address.

```asm
; Code generated in module:
.byte $12            ; Marker (was: $BD = LDA ABS,X)
.word $0400          ; DATA offset (happens to equal Screen RAM address!)

; After relocation:
lda $C400,x          ; $BD + relocated address
```

**Why are JMP/JSR markers needed for modules larger than 2KB?**

The standard relocation logic detects JMP/JSR by checking if the high byte is `$00-$07`
(internal module address). This works for modules up to 2KB. However, for larger modules:

```asm
; Module internal code at offset $0800 (2048 bytes):
JSR $0850            ; High byte = $08 → NOT detected as internal!
JMP $1234            ; High byte = $12 → NOT relocated!
```

The loader would treat these as external addresses (hardware registers, etc.) and
NOT relocate them → **CRASH!**

**Solution:** For modules that may exceed 2KB, the compiler uses explicit markers:

```asm
; Instead of:
JSR $0850            ; 20 50 08 → won't be relocated!

; The compiler generates:
.byte $52            ; Marker (illegal opcode)
.word $0850          ; Address

; After relocation ($C000 base):
JSR $C850            ; 20 50 C8 → correctly relocated!
```

This allows modules up to **40KB** (the entire C64 address space below I/O) to work correctly.

### Relocation at Load Time

The relocator advances **instruction-by-instruction** (not byte-by-byte), performing
these types of relocation:

1. **JAM marker ($02)** - immediate high byte values (pointer loading)
2. **ABS marker ($12/$22/$32)** - direct DATA section access (LDA ABS,X / LDA ABS / LDA ABS,Y)
3. **JMP marker ($42)** - internal JMP instructions (for >2KB modules)
4. **JSR marker ($52)** - internal JSR instructions (for >2KB modules)
5. **JMP/JSR/JMP(ind)** - 16-bit absolute addresses (by high byte `$00-$07`, for <2KB modules)

#### Instruction-based Scan

```asm
; For each instruction:
; 1. Read opcode
; 2. Does it need relocation?
; 3. Skip by instruction length

relocate:
    LDY #4              ; Skip 6-byte header (Y starts at code)
.loop:
    LDA (module_ptr),Y  ; Read opcode

    ; === Marker opcodes (explicit marking) ===
    CMP #$02            ; JAM marker? (immediate high byte)
    BEQ .do_jam
    CMP #$12            ; ABS,X marker? (LDA data,X)
    BEQ .do_abs_marker
    CMP #$22            ; ABS marker? (LDA data)
    BEQ .do_abs_marker
    CMP #$32            ; ABS,Y marker? (LDA data,Y)
    BEQ .do_abs_marker
    CMP #$42            ; JMP marker? (for >2KB modules)
    BEQ .do_jmp_marker
    CMP #$52            ; JSR marker? (for >2KB modules)
    BEQ .do_jsr_marker

    ; === JMP/JSR (high byte detection, for <2KB modules) ===
    CMP #$20            ; JSR?
    BEQ .do_jmp
    CMP #$4C            ; JMP?
    BEQ .do_jmp
    CMP #$6C            ; JMP indirect?
    BEQ .do_jmp

    ; ... skip instruction by length ...
```

#### JMP/JSR Relocation (full 16-bit)

```asm
.do_abs:
    INY                     ; Low byte position
    INY                     ; High byte position
    LDA (module_ptr),Y      ; Read high byte
    CMP #$08                ; Internal address? (< $08)
    BCS .skip               ; External: don't relocate

    ; FULL 16-bit relocation (carry matters!)
    DEY                     ; Back to low byte
    LDA (module_ptr),Y
    CLC
    ADC base_lo             ; Low byte + base_lo
    STA (module_ptr),Y
    INY                     ; To high byte
    LDA (module_ptr),Y
    ADC base_hi             ; High byte + base_hi + CARRY!
    STA (module_ptr),Y
```

#### JAM Marker Relocation

The compiler marks immediate high bytes with JAM markers:

```asm
; Compiled code (in module):
    LDA #<label         ; $A9 LL   (low byte)
    STA tmp0            ; $85 $02
    .byte $02           ; JAM marker (illegal opcode)
    .byte >label        ; HH (high byte)
    STA tmp1            ; $85 $03

; After relocation ($C000 base):
    LDA #<label+$C000   ; $A9 LL'  (low byte relocated)
    STA tmp0
    LDA #>label+$C000   ; $A9 HH'  (JAM → LDA #, high relocated)
    STA tmp1
```

**CRITICAL:** For JAM marker relocation, BOTH bytes (low AND high) must be
relocated, and the carry must be propagated! If `LL + base_lo > 255`, the high
byte also increases!

```asm
.do_jam:
    INY                     ; High byte position (byte after JAM)
    LDA (module_ptr),Y
    CMP #$08                ; Real JAM marker?
    BCS .skip               ; >= $08: not a marker, skip

    ; Relocate low byte (at Y-4 position!)
    DEY
    DEY
    DEY
    DEY                     ; LDA # operand position
    LDA (module_ptr),Y
    CLC
    ADC base_lo
    STA (module_ptr),Y

    ; Convert JAM → LDA #
    INY
    INY
    INY                     ; JAM opcode position
    LDA #$A9                ; LDA # opcode
    STA (module_ptr),Y

    ; Relocate high byte with carry!
    INY
    LDA (module_ptr),Y
    ADC base_hi             ; + carry from low byte!
    STA (module_ptr),Y
```

#### ABS,X/ABS,Y Marker Relocation

For direct DATA section access, the compiler uses marker opcodes:
- `$12` marks `LDA abs,X` (`$BD`) instructions
- `$22` marks `LDA abs` (`$AD`) instructions
- `$32` marks `LDA abs,Y` (`$B9`) instructions

```asm
; Compiled code (in module) - constant index tuple access:
    .byte $12           ; Marker (original: $BD = LDA ABS,X)
    .word $0400         ; DATA offset (coincidental match with Screen RAM!)

; After relocation ($C000 base):
    LDA $C400,X         ; $BD $00 $C4 - correctly relocated address!
```

The relocator simply swaps the marker opcode back and relocates the address:

```asm
.do_abs_marker:
    ; A = marker opcode ($12, $22, or $32)
    TAX                     ; Save in X

    ; Marker → original opcode swap
    CPX #$12
    BNE .not_12
    LDA #$BD                ; LDA ABS,X
    JMP .patch_opcode
.not_12:
    CPX #$22
    BNE .not_22
    LDA #$AD                ; LDA ABS
    JMP .patch_opcode
.not_22:
    LDA #$B9                ; LDA ABS,Y

.patch_opcode:
    STA (module_ptr),Y      ; Write opcode back

    ; Relocate 16-bit address (at Y+1, Y+2)
    INY                     ; Low byte
    LDA (module_ptr),Y
    CLC
    ADC base_lo
    STA (module_ptr),Y
    INY                     ; High byte
    LDA (module_ptr),Y
    ADC base_hi             ; + carry!
    STA (module_ptr),Y

    INY                     ; Move to next instruction
    JMP .loop
```

#### JMP/JSR Marker Relocation (for >2KB modules)

For modules larger than 2KB, internal JMP/JSR instructions are marked:
- `$42` marks `JMP abs` (`$4C`) instructions
- `$52` marks `JSR abs` (`$20`) instructions

```asm
.do_jmp_marker:
    LDA #$4C                ; JMP absolute opcode
    JMP .do_jsr_common

.do_jsr_marker:
    LDA #$20                ; JSR absolute opcode

.do_jsr_common:
    STA (module_ptr),Y      ; Replace marker with actual opcode

    ; Relocate 16-bit address (at Y+1, Y+2)
    INY                     ; Low byte
    LDA (module_ptr),Y
    CLC
    ADC base_lo
    STA (module_ptr),Y
    INY                     ; High byte
    LDA (module_ptr),Y
    ADC base_hi             ; + carry!
    STA (module_ptr),Y

    INY                     ; Move to next instruction
    JMP .loop
```

**Note:** The marker system ensures that ALL internal addresses are correctly
relocated, regardless of module size. The old high-byte detection (`$00-$07`)
is kept for backward compatibility with modules compiled before this feature.

**Why isn't high byte detection enough for ABS,X/ABS,Y?**

```asm
; Problem: both instructions have $04 high byte:
LDA $0400,X         ; Screen RAM access - DON'T relocate!
LDA tuple_data,Y    ; where tuple_data = $0400 offset - RELOCATE!

; Indistinguishable in binary:
; $BD $00 $04  vs  $B9 $00 $04
```

The marker explicitly identifies module-internal addresses:
```asm
STA $0400,X         ; $9D $00 $04 - external, unchanged
.byte $12, $00, $04 ; internal DATA - needs relocation!
```

### Example

```
Module originally compiled for $0000:
────────────────────────────────────
$0000: JSR $0050     ; 20 50 00  → needs relocation (JMP/JSR)
$0003: STA $0400,X   ; 9D 00 04  → NO relocation (Screen RAM!)
$0006: STA $D400     ; 8D 00 D4  → NO relocation (SID register)
$0009: LDA #<$0200   ; A9 00     → needs relocation (JAM pattern)
$000B: STA tmp0      ; 85 02
$000D: .byte $02     ; 02        → JAM marker
$000E: .byte >$0200  ; 02        → high byte
$000F: STA tmp1      ; 85 03
$0011: .byte $12     ; 12        → ABS,X marker (tuple access)
$0012: .word $0400   ; 00 04     → DATA offset (happens to match Screen RAM!)
$0015: STA tmp0      ; 85 02

Loaded to $C000:
────────────────────────────────────
$C000: JSR $C050     ; 20 50 C0  ✓ (JMP/JSR relocated)
$C003: STA $0400,X   ; 9D 00 04  ✓ (unchanged - external address!)
$C006: STA $D400     ; 8D 00 D4  ✓ (unchanged - HW register)
$C009: LDA #$00      ; A9 00     ✓ (low byte relocated)
$C00B: STA tmp0      ; 85 02     ✓
$C00D: LDA #$C2      ; A9 C2     ✓ (JAM → LDA #, high relocated)
$C00F: STA tmp1      ; 85 03     ✓
$C011: LDA $C400,X   ; BD 00 C4  ✓ (marker → LDA, address relocated!)
$C014: STA tmp0      ; 85 02     ✓
```

**Key observation:** The `$0400` address appears twice:
1. `STA $0400,X` - Screen RAM access → **NOT** relocated (no marker)
2. `$12 $00 $04` - DATA section access → **RELOCATED** (marker indicates it!)

### Benefits

| Property                | Value                            |
| ----------------------- | -------------------------------- |
| Relocation table size   | **0 bytes!**                     |
| Extra module overhead   | **0 bytes!**                     |
| Loader complexity       | Very simple                      |
| Max module internal size| 2KB (extendable with long jump)  |

## Module File Formats (.PM and .PMI)

The PyCo module system uses **two separate files**:

| File  | Content           | Location         | Read by          |
| ----- | ----------------- | ---------------- | ---------------- |
| `.pm` | Executable code   | C64 floppy       | Runtime loader   |
| `.pmi`| Type information  | Developer machine| Compiler         |

### Why Two Files?

1. **Smaller distribution size**: The `.pmi` (type info) NEVER goes to the C64 floppy
2. **Faster runtime**: The loader doesn't parse metadata, just loads code
3. **Portability**: The `.pmi` format works for both PC and C64-native compiler
4. **Protection**: Type information isn't distributed with the released program

### .PM File Format (Runtime Code)

```
┌─────────────────────────────────────────────────────────────┐
│ .PM FILE - This is loaded onto the C64!                     │
├─────────────────────────────────────────────────────────────┤
│ HEADER (6 bytes)                                            │
│   magic (2 bytes): "PM" ASCII ($50 $4D)               │
│   code_size (2 bytes): size to load (little-endian)         │
│   code_end (2 bytes): code end, relocation boundary         │
├─────────────────────────────────────────────────────────────┤
│ JUMP TABLE (entry_count × 3 bytes)                          │
│   JMP entry_0_code      ; $4C xx xx                         │
│   JMP entry_1_code      ; $4C xx xx                         │
│   ...                                                       │
├─────────────────────────────────────────────────────────────┤
│ CODE                                                        │
│   entry_0_code: ...                                         │
│   entry_1_code: ...                                         │
│   internal_functions: ...                                   │
│   ← code_end boundary (relocation stops here!)              │
├─────────────────────────────────────────────────────────────┤
│ DATA (string literals, tuple data, etc.)                    │
├─────────────────────────────────────────────────────────────┤
│ SINGLETON DATA (if any)                                     │
│   field1: .byte 0                                           │
│   field2: .word 0                                           │
└─────────────────────────────────────────────────────────────┘
```

**Header fields:**

| Offset | Size | Name       | Description                                         |
| ------ | ---- | ---------- | --------------------------------------------------- |
| 0-1    | 2    | magic      | `$1C $0E` - file identifier ("P1C0 Extension")      |
| 2-3    | 2    | code_size  | Number of bytes to load (excluding header)          |
| 4-5    | 2    | code_end   | Where code ends and data begins                     |

**Why `code_end`?**

The relocator scans instruction-by-instruction. In the data section, bytes may
accidentally look like opcodes (e.g., `$4C` in the middle of a string). If the
relocator treated this as "JMP", incorrect relocation would occur. `code_end`
tells it where to stop.

**Why magic?**

Kernal LOAD (`$FFD5`) with secondary address 0 loads and **skips the first 2
bytes** (PRG header). We use this space for the magic number. The compiler
validates the file at compile-time, no runtime overhead.

**Size**: 6 bytes header + executable code, minimal metadata overhead!

### .PMI File Format (Module Info)

The `.pmi` file uses a compact binary format readable by a C64-native compiler.

```
┌─────────────────────────────────────────────────────────────┐
│ .PMI FILE - Only the compiler reads this!                   │
├─────────────────────────────────────────────────────────────┤
│ HEADER                                                      │
│   magic (3 bytes): "PMI"                                    │
│   version (1 byte): 1                                       │
│   module_name_len (1 byte)                                  │
│   module_name (N bytes)                                     │
│   export_count (1 byte)                                     │
├─────────────────────────────────────────────────────────────┤
│ EXPORT ENTRIES (export_count entries)                       │
│   name_len (1 byte)                                         │
│   name (N bytes)                                            │
│   export_type (1 byte): 0=func, 1=class, 2=singleton, 3=tuple│
│   jump_index (1 byte): position in jump table               │
│     (NOT present for tuples!)                               │
│   [type-specific data...]                                   │
├─────────────────────────────────────────────────────────────┤
│ FUNCTION ENTRY (if export_type = 0)                         │
│   param_count (1 byte)                                      │
│   param_types (N bytes, encoded types)                      │
│   return_type (1 byte, encoded type)                        │
├─────────────────────────────────────────────────────────────┤
│ CLASS ENTRY (if export_type = 1)                            │
│   instance_size (2 bytes, word)                             │
│   property_count (1 byte)                                   │
│   PROPERTY ENTRIES (property_count entries):                │
│     name_len (1 byte)                                       │
│     name (N bytes)                                          │
│     type (N bytes, encoded type)                            │
│     offset (2 bytes, word)                                  │
│     size (1 byte)                                           │
│     flags (1 byte): bit0=has_address                        │
│     address (2 bytes, only if has_address)                  │
│   method_count (1 byte)                                     │
│   METHOD ENTRIES (method_count entries):                    │
│     name_len (1 byte)                                       │
│     name (N bytes)                                          │
│     jump_index (1 byte)                                     │
│     param_count (1 byte)                                    │
│     param_types (N bytes)                                   │
│     return_type (1 byte)                                    │
├─────────────────────────────────────────────────────────────┤
│ SINGLETON ENTRY (if export_type = 2)                        │
│   (Same structure as CLASS ENTRY)                           │
├─────────────────────────────────────────────────────────────┤
│ GLOBAL_TUPLE ENTRY (if export_type = 3)                     │
│   element_type (1 byte, encoded type: byte, word, etc.)     │
│   element_count (2 bytes, little-endian)                    │
│   offset (2 bytes, little-endian) - offset from module start│
└─────────────────────────────────────────────────────────────┘
```

### Type Encoding in .PMI

Types are encoded as 1 or more bytes:

#### Simple Types ($00-$1F) - 1 byte

| Code  | Type   | Size  |
| ----- | ------ | ----- |
| $00   | void   | 0     |
| $01   | byte   | 1     |
| $02   | sbyte  | 1     |
| $03   | word   | 2     |
| $04   | int    | 2     |
| $05   | float  | 4     |
| $06   | f16    | 2     |
| $07   | f32    | 4     |
| $08   | bool   | 1     |
| $09   | char   | 1     |
| $0A   | string | 2 (ptr) |

#### Composite Types ($20-$3F) - variable length

| Code  | Type        | Format                                |
| ----- | ----------- | ------------------------------------- |
| $20   | array[T,N]  | +1 byte elem_type +2 bytes size       |
| $21   | tuple[T]    | +1 byte elem_type                     |

#### Reference Types ($40-$5F) - variable length

| Code  | Type      | Format                                |
| ----- | --------- | ------------------------------------- |
| $40   | alias[T]  | +N bytes target_type (recursive)      |

#### Class References ($80-$FF)

| Code      | Type            | Meaning               |
| --------- | --------------- | --------------------- |
| $80-$BF   | internal class  | index = code & $3F    |
| $C0-$FF   | imported class  | index = code & $3F    |

#### Type Encoding Reference

| PyCo Type                  | Encoding (hex)    |
| -------------------------- | ----------------- |
| `void`                     | `00`              |
| `byte`                     | `01`              |
| `sbyte`                    | `02`              |
| `word`                     | `03`              |
| `int`                      | `04`              |
| `float`                    | `05`              |
| `f16`                      | `06`              |
| `f32`                      | `07`              |
| `bool`                     | `08`              |
| `char`                     | `09`              |
| `string`                   | `0A`              |
| `alias[byte]`              | `40 01`           |
| `alias[word]`              | `40 03`           |
| `alias[char]`              | `40 09`           |
| `alias[string]`            | `40 0A`           |
| `tuple[byte]`              | `21 01`           |
| `tuple[word]`              | `21 03`           |
| `tuple[char]`              | `21 09`           |
| `array[byte, 64]`          | `20 01 40 00`     |
| `array[char, 256]`         | `20 09 00 01`     |
| `alias[array[byte, 1000]]` | `40 20 01 E8 03`  |
| `Screen` (internal, idx 0) | `80`              |

### Compile and Load Process

**1. Compiling a module:**
```bash
pycoc compile math.pyco --module
```
Result:
- `math.pm` → Binary code (goes to C64 floppy)
- `math.pmi` → Type info (STAYS on developer machine)

**2. Import processing (at compile time):**
- Compiler opens the `.pmi` file
- Checks: does the imported name exist?
- Checks: is it public? (no `_` prefix)
- Checks: do parameter types match?
- Notes: entry point offsets

**3. Runtime loading:**
- Loader opens the `.pm` file
- Reads `code_size` (2 bytes)
- Loads code → SSP (stack top)
- Relocation based on marker-byte/JAM
- **No .pmi reading at runtime!**

## Loading Mechanism

### Static Import (compile-time)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Compiler sees: from math import sin                      │
│                          ↓                                  │
│ 2. Opens: math.pm                                           │
│    - Reads Info Section (metadata)                          │
│    - Checks: is there a 'sin' symbol? ✓                     │
│    - Checks: is it public? ✓ (no _ prefix)                  │
│    - Checks: parameters OK? ✓                               │
│                          ↓                                  │
│ 3. Reads Code Section                                       │
│    - Inserts into PRG                                       │
│    - Compile-time relocation (known fixed address)          │
│                          ↓                                  │
│ 4. Call: JSR sin_relocated_address                          │
└─────────────────────────────────────────────────────────────┘
```

### Dynamic Import (runtime)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Compiler sees: import math                               │
│                          ↓                                  │
│ 2. Opens: math.pm                                           │
│    - Reads Info Section (metadata, signatures)              │
│    - Allocates space in BSS: __mod_math: .word 0            │
│    - Notes entry offsets (sin = 0, cos = 3, ...)            │
│    - Code is NOT compiled in!                               │
│                          ↓                                  │
│ 3. Runtime: load_module(math) call                          │
│    - OPEN 8,8,8,"MATH.PM,S,R"                               │
│    - READ 2 bytes → code_size                               │
│    - READ code_size bytes → SSP (stack top)                 │
│    - Relocation (marker-byte scan)                          │
│    - __mod_math = SSP (BSS pointer setup)                   │
│    - SSP += code_size                                       │
│    - CLOSE                                                  │
│                          ↓                                  │
│ 4. Call: math.sin(0.5)                                      │
│    - Generated code: JSR (__mod_math + SIN_OFFSET)          │
│                          ↓                                  │
│ 5. Function return → SSP resets → module "disappears"       │
│    - __mod_math pointer REMAINS (programmer's responsibility!)│
└─────────────────────────────────────────────────────────────┘
```

## Dynamic Import Limitations

Dynamic imports have restrictions compared to static imports due to the runtime nature of module loading.

### Feature Comparison

| Feature                  | Static (`from X import`) | Dynamic (`import X`)             |
|--------------------------|--------------------------|----------------------------------|
| Module-level functions   | ✅ Full support          | ✅ Full support                  |
| Singleton classes        | ✅ Auto-init defaults    | ⚠️ Requires explicit `X.Class()` |
| Regular classes          | ✅ Full support          | ✅ Full support                  |
| Property default values  | ✅ Automatic             | ⚠️ Only via `__init__`           |

### Singleton vs Regular Class Usage

**Singleton classes** (stored in BSS):
```python
import config

def main():
    load_module(config)
    config.Config()                    # Required initialization!
    print(config.Config.value)         # Direct property access
```

**Regular classes** (allocated on stack):
```python
import counter

def main():
    c: counter.Counter                 # Stack allocation (size from PMI)
    load_module(counter)
    c()                                # __init__ call
    c.increment()                      # Method call
    print(c.get_value())
```

### Property Default Values

For dynamic imports, property default values are set in the `__init__` method because:
- The compiler only reads `.pmi` files which contain type information
- Property default values are in the module code, not the `.pmi`
- Therefore, defaults are loaded at runtime when `__init__` is called

**Important:** For regular classes, calling `__init__` (`obj()`) is required to set default values!

### Best Practice

Always use explicit `__init__` methods in classes intended for dynamic import:

```python
# In your module (e.g., config.pyco)
@singleton
class Config:
    value: byte
    timeout: word

    def __init__():
        # Set ALL defaults here!
        self.value = 42
        self.timeout = 1000
```

```python
# In caller
import config

def main():
    load_module(config)
    config.Config()          # REQUIRED - calls __init__, sets defaults
    print(config.Config.value)  # Now correctly shows 42
```

### BSS Memory Layout for Dynamic Singletons

```
__program_end
    │
    ├── __SI_LocalSingleton (local singleton data)
    │
    ├── __mod_screen (2 bytes - module pointer)
    │
    └── __DSI_screen_Screen (singleton instance data)
          │
          └── __singletons_end = SSP start
```

## Global Tuple Export/Import

### Tuple Export

Modules can export their global tuples if their names don't have a `_` prefix:

```python
# screen.pyco - module
SCREEN_RAM = 0x0400

# Exported global tuple (public)
row_offsets: tuple[word] = (
    0, 40, 80, 120, 160, 200, 240, 280, 320, 360,
    400, 440, 480, 520, 560, 600, 640, 680, 720, 760,
    800, 840, 880, 920, 960
)

# Private tuple (NOT exported)
_internal_buffer: tuple[byte] = (0, 1, 2, 3)

def main():
    pass
```

### Static Tuple Import

```python
# main.pyco - consumer program
from screen import row_offsets

@lowercase
def main():
    y: byte = 5
    offset: word
    offset = row_offsets[y]  # 200
    print(offset)
```

**Generated code:**
```asm
; The tuple is compiled in with the module code
; Access: __MOD_screen + tuple_offset + index*elem_size
lda __MOD_screen+762+10   ; row_offsets[5] low byte (5*2=10)
sta tmp0
lda __MOD_screen+762+11   ; row_offsets[5] high byte
sta tmp1
```

### PMI Tuple Entry

In the `.pmi` file, a tuple export is 6 bytes:

| Offset | Size | Field         | Description                           |
| ------ | ---- | ------------- | ------------------------------------- |
| 0      | 1    | export_type   | 3 (GLOBAL_TUPLE)                      |
| 1      | 1    | element_type  | Element type code (e.g., $03 = word)  |
| 2-3    | 2    | element_count | Number of elements (little-endian)    |
| 4-5    | 2    | offset        | Offset from module start (bytes)      |

**Note:** Tuple exports have NO `jump_index` because tuples are data, not code.

### Tuple vs Function Difference

| Property    | Function/Class          | Tuple                       |
| ----------- | ----------------------- | --------------------------- |
| PMI entry   | jump_index + signature  | elem_type + count + offset  |
| Access      | JSR (via jump table)    | LDA (direct address)        |
| Relocation  | Jump table relocated    | Base + offset calculation   |

### Dynamic Tuple Import

```python
# main.pyco - dynamic import
import screen

@lowercase
def main():
    load_module(screen)
    offset: word = screen.row_offsets[5]  # Runtime access
    print(offset)  # 200
```

**Generated code:**
```asm
; Read module BSS pointer at runtime
clc
lda __mod_screen       ; BSS pointer (module base)
adc #<762              ; + tuple offset
sta tmp0
lda __mod_screen+1
adc #>762
sta tmp1
; Indirect addressing with index
ldy #10                ; index * elem_size (5 * 2)
lda (tmp0),y           ; low byte
sta tmp2
iny
lda (tmp0),y           ; high byte
```

**Important:** Dynamic tuple access only works AFTER the `load_module()` call!

## Usage Examples

### Example 1: Simple Game

```python
# Static - always needed
from utils import clear_screen, wait_key

# Dynamic - swappable per screen
import menu_module
import game_module
import highscore_module

def main():
    while True:
        # Menu screen
        load_module(menu_module)
        choice = menu_module.show_menu()
        # Return → menu_module freed

        if choice == 1:
            # Game screen - full RAM available!
            load_module(game_module)
            score = game_module.play()
            # Return → game_module freed

            # Highscore screen
            load_module(highscore_module)
            highscore_module.check_and_save(score)
            # Return → highscore_module freed
```

### Example 2: Shared Module Across Functions

```python
import math

def game_session():
    load_module(math)         # Load

    while running:
        game_loop()           # math.sin() works
        update_physics()      # math.cos() works

    # Return → math freed

def game_loop():
    # No load_module needed - game_session() already loaded it
    x = math.sin(angle)       # Works!

def update_physics():
    # This can use it too
    force = math.cos(angle) * gravity
```

**Important:** It's the programmer's responsibility that `game_loop()` and `update_physics()` are only called from `game_session()`!

### Example 3: Nested Modules (LIFO)

```python
import math
import sprites

def render_frame():
    load_module(math)         # Stack: [math]
    load_module(sprites)      # Stack: [math, sprites]

    for obj in objects:
        x = math.sin(obj.angle)
        sprites.draw(obj.sprite, x, obj.y)

    # Return → Stack: [] (LIFO: sprites, then math freed)
```

## Error Messages

### Compile-time Errors

```
main.pyco:3: Error: Unknown module 'maht'. Did you mean 'math'?
main.pyco:5: Error: Module 'math' has no export 'sn'. Did you mean 'sin'?
main.pyco:7: Error: Cannot import '_helper' from 'math': name is private
main.pyco:10: Error: 'sin' already imported from 'math'
main.pyco:15: Error: Type mismatch: math.sin expects float, got byte
```

### Runtime Errors

```
Runtime Error: Module 'MUSIC.PM' not found on disk
Runtime Error: Out of memory loading module (need 1234 bytes, have 500)
Runtime Error: Module format error (invalid magic)
```

## Summary

### Two Import Modes

| Syntax               | Compile-time            | Runtime               | Usage             |
| -------------------- | ----------------------- | --------------------- | ----------------- |
| `from X import a, b` | Code compiles in        | -                     | `a()`, `b()`      |
| `import X`           | Info Section + BSS ptr  | `load_module(X)`      | `X.a()`, `X.b()`  |

### Export Rules

| Name Format                    | Exported? |
| ------------------------------ | --------- |
| `name`                         | ✓ Yes     |
| `_name`                        | ✗ No      |
| `from X import foo`            | ✓ Yes     |
| `from X import foo as _foo`    | ✗ No      |

### Marker-byte System

| High Byte   | Meaning                               |
| ----------- | ------------------------------------- |
| `$00-$07`   | Marker (needs relocation, module-internal address) |
| `$08-$FF`   | Fixed address (HW register, external memory) |

### Programmer's Responsibility

- After `load_module()`, the module is usable
- After function return, stack resets, module "disappears"
- The BSS pointer (`__mod_X`) remains - **may point to garbage!**
- If you call without loading → **crash** (and that's OK)

---

*Version: 3.7 - 2026-01-20*
*Changes: JMP/JSR markers ($42/$52) for modules larger than 2KB, LDA ABS marker ($22)*
