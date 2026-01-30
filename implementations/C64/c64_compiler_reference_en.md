# C64 Compiler Reference

This document is the technical reference for the PyCo C64 (6502) compiler implementation.

## 1. Introduction

### What is this document?

This reference documents the **platform-specific operation** of the PyCo C64 compiler. This document should be read together with the [Language Reference](../../language-reference/language_reference_en.md):

| Document                  | Content                                                     |
| ------------------------- | ----------------------------------------------------------- |
| **Language Reference**    | PyCo syntax, types, language constructs (platform-independent) |
| **C64 Compiler Reference** | C64-specific implementation, memory management, optimizations |

### C64 Compiler Features

The PyCo C64 compiler generates 6502 assembly code for the Commodore 64. Main features:

- **Kick Assembler** or **built-in assembler** output
- **Kernal-free mode** by default (+16KB RAM)
- **Zero Page optimized** temp registers
- **Software stack** for local variables
- **Dead Code Elimination** - only used code goes into the binary

### Compilation Process

```
source.pyco → Parser → Preprocessor → SemanticAnalyzer → CodeGen → output.asm
                                              ↓
                                        SymbolTable
```

The generated `.asm` file uses Kick Assembler syntax, or can be assembled directly to `.prg` binary using the built-in assembler.

---

## 2. Memory Architecture

### 2.1 C64 Memory Map

PyCo **disables both ROMs** by default (+16KB RAM):

```
┌──────────────────────────────────────────────────────────────┐
│ Address Range  │ Size   │ Description                        │
├──────────────────────────────────────────────────────────────┤
│ $0000 - $00FF  │ 256 B  │ Zero Page (system + PyCo ZP)       │
│ $0100 - $01FF  │ 256 B  │ Hardware Stack (6502)              │
│ $0200 - $03FF  │ 512 B  │ System area (see note)             │
│ $0400 - $07FF  │ 1 KB   │ Screen memory (default)            │
│ $0801 - $BFFF  │ ~46 KB │ PyCo program area                  │
│                │        │ (BASIC ROM disabled)               │
│ $C000 - $CFFF  │ 4 KB   │ Free RAM                           │
│ $D000 - $D3FF  │ 1 KB   │ VIC-II registers                   │
│ $D400 - $D7FF  │ 1 KB   │ SID registers                      │
│ $D800 - $DBFF  │ 1 KB   │ Color memory                       │
│ $DC00 - $DCFF  │ 256 B  │ CIA1 (keyboard, joystick)          │
│ $DD00 - $DDFF  │ 256 B  │ CIA2 (serial port, VIC bank)       │
│ $E000 - $FFFF  │ 8 KB   │ RAM (Kernal ROM disabled!)         │
└──────────────────────────────────────────────────────────────┘
```

**Note on $0200-$03FF area:**
- **PRG mode:** Free for use
- **Cartridge mode (`@cartridge`):** $0200-$025F (~60 bytes) is **RESERVED** for the bank dispatcher! The $0277-$028D area is also reserved for Kernal-compatible variables (keyboard buffer, color, key repeat).

With the `@kernal` decorator, the Kernal ROM remains active (see [4.2 @kernal](#42-kernal)).

### 2.2 Zero Page Allocation

The Zero Page ($00-$FF) is the 6502 processor's fastest memory region. PyCo allocates it as follows:

#### Temp Registers

| Address   | Name       | Usage                                  |
| --------- | ---------- | -------------------------------------- |
| $02-$07   | tmp0-5     | General temp registers                 |
| $13-$15   | tmp6-8     | Extended temp (division, string, f32)  |
| $1A-$1F   | irq_tmp0-5 | IRQ handler temp registers             |

**tmp0-tmp5 ($02-$07)** - Basic operations:
- Byte/word arithmetic (+, -, *, &, |, ^, <<, >>)
- Comparisons (<, >, ==, !=, <=, >=)
- Array indexing, pointer dereferencing
- Variable access

**tmp6-tmp8 ($13-$15)** - Extended operations:
- Division (`/`) and modulo (`%`)
- String concatenation and multiplication
- f16/f32 arithmetic
- Large array offset calculation

#### Stack and Function Call Registers

| Address   | Name    | Usage                              |
| --------- | ------- | ---------------------------------- |
| $08-$09   | FP      | Frame Pointer - stack frame base   |
| $0A-$0B   | SSP     | Software Stack Pointer - stack top |
| $0F-$12   | retval  | Function return value (4 bytes)    |
| $16-$17   | ZP_SELF | `self` pointer for method calls    |

#### Print (sprint) Registers

| Address   | Name    | Usage                              |
| --------- | ------- | ---------------------------------- |
| $0C-$0D   | spbuf   | Sprint buffer pointer              |
| $0E       | sppos   | Current position in buffer         |
| $0F-$10   | spsave  | Saved CHROUT vector (overlaps!)    |
| $11       | sptmp   | Sprint temp (overlaps!)            |

> **Note:** `spsave` and `retval` overlap, but are never active simultaneously.

#### Float Registers

The float registers match the addresses used by the C64 BASIC ROM. This enables compatibility, but also means that BASIC ROM float routines cannot be used directly (PyCo uses 32-bit MBF format, while BASIC uses 40-bit MBF).

| Address   | Name      | Usage                                |
| --------- | --------- | ------------------------------------ |
| $57-$5D   | RESULT... | Multiplication/memory workspace      |
| $61-$66   | FAC       | Float Accumulator (exponent+mantissa)|
| $69-$6E   | ARG       | Float Argument (second operand)      |

> **Tip:** If your program doesn't use the `float` type, the $57-$6E area (24 bytes) is free for memory-mapped variables. This is significant extra Zero Page space for games and demos!

#### Leaf Function Local Variables

| Address   | Name    | Usage                                 |
| --------- | ------- | ------------------------------------- |
| $22-$29   | LEAF_ZP | Leaf function local variables (8 bytes) |

"Leaf" functions (that don't call other functions) store local variables in Zero Page. Requirements:

1. Leaf function (doesn't call other functions)
2. No parameters
3. Local variables size ≤ 8 bytes
4. Not IRQ handler, not `@naked`, not `@mapped`

**Savings:**

| Approach   | Prologue  | Access            | Epilogue  |
| ---------- | --------- | ----------------- | --------- |
| SSP/FP     | ~25 bytes | `ldy #N; (FP),y`  | ~15 bytes |
| LEAF_ZP    | 0 bytes   | `lda $xx`         | 0 bytes   |

#### Kernal-Compatible System Variables

Kernal-free mode uses the same addresses for seamless exit:

| Address     | Kernal name | Usage                           |
| ----------- | ----------- | ------------------------------- |
| $A0-$A2     | TIME        | Jiffy clock (1/60 sec)          |
| $C5         | LSTX        | Last key matrix code            |
| $C6         | NDX         | Keyboard buffer count           |
| $D1-$D2     | PNT         | Screen line pointer             |
| $D3         | PNTR        | Cursor column (0-39)            |
| $D6         | TBLX        | Cursor row (0-24)               |
| $0277-$0280 | KEYD        | Keyboard buffer (10 bytes)      |
| $028C       | KOUNT       | Key repeat delay                |
| $028D       | SHFLAG      | Shift/Ctrl/C= flags             |

#### User-Available Areas

| Address   | Size     | Description                                         |
| --------- | -------- | --------------------------------------------------- |
| $2A-$56   | 45 bytes | Area not used by PyCo                               |
| $FB-$FE   | 4 bytes  | Also free per Commodore documentation               |

> **Note:** The $FB-$FE area is marked as "Free for user programs" in the Commodore Programmer's Reference Guide. These 4 bytes are particularly useful for memory-mapped variables or fast ZP pointers.

### 2.3 Stack Architecture

On the C64, PyCo uses two stacks for different purposes:

- **Hardware stack** ($0100-$01FF): Parameters + return addresses
- **Software stack** (SSP): Local variables

```
Hardware stack ($0100-$01FF):        Software stack (SSP):

        ↑ SP (6502)                         ↑ SSP
┌─────────────────────────┐          ┌─────────────────────────┐
│    Parameter 0 (lo)     │ SP+5     │                         │
│    Parameter 0 (hi)     │ SP+6     │    Local variables      │
│    Parameter 1          │ SP+7     │    (in declaration      │
│    ...                  │          │     order)              │
├─────────────────────────┤          │                         │
│    Return address lo    │ SP+3     └─────────────────────────┘ ← FP
│    Return address hi    │ SP+4
├─────────────────────────┤
│    Saved FP (lo)        │ SP+1
│    Saved FP (hi)        │ SP+2
└─────────────────────────┘ ← SP
```

#### Frame Pointer (FP)

The **Frame Pointer (FP)** is the base address for local variables on the software stack. The callee sets it up: `FP = SSP`, then `SSP += locals_size`.

---

## 3. Generated Code

### 3.1 Name Mangling

In the generated assembly, PyCo names receive prefixes:

| Prefix | Meaning                   | Example                     |
| ------ | ------------------------- | --------------------------- |
| `__F_` | Function                  | `__F_calculate_score`       |
| `__C_` | Class method              | `__C_Player_move`           |
| `__B_` | BSS variable              | `__B_game_state`            |
| `__R_` | Runtime helper            | `__R_mul16`                 |

### 3.2 Calling Convention

#### Standard Calling Convention (HW Stack)

PyCo uses the **hardware stack** for parameter passing, which is ~3x faster than the software stack.

**Caller side:**
```asm
; foo(a, b) call - a=5, b=10
lda #10
pha              ; b parameter → HW stack
lda #5
pha              ; a parameter → HW stack
jsr __F_foo
pla              ; caller cleanup
pla
```

**Callee side:**
```asm
__F_foo:
    ; Access parameters via TSX + indexed addressing
    tsx
    lda $0103,x      ; a parameter (SP+3)
    sta tmp0
    lda $0104,x      ; b parameter (SP+4)
    ; ...
    rts
```

**Stack layout in callee:**
```
SP+1: saved FP (lo)
SP+2: saved FP (hi)
SP+3: return address (lo)
SP+4: return address (hi)
SP+5: first parameter (offset 0)
SP+6: second parameter (offset 1)
...
```

**Return value:** `retval` ($0F-$12, max 4 bytes)

#### Register-based ABI (`@naked` and `@mapped` only)

| Parameters           | Registers      |
| -------------------- | -------------- |
| `(byte)`             | A              |
| `(byte, byte)`       | A, X           |
| `(byte, byte, byte)` | A, X, Y        |
| `(word)`             | X (lo), Y (hi) |

### 3.3 Type Sizes

| Type    | Size    | Range                        |
| ------- | ------- | ---------------------------- |
| bool    | 1 byte  | 0, 1                         |
| char    | 1 byte  | PETSCII character            |
| byte    | 1 byte  | 0 - 255                      |
| sbyte   | 1 byte  | -128 - 127                   |
| word    | 2 bytes | 0 - 65535                    |
| int     | 2 bytes | -32768 - 32767               |
| f16     | 2 bytes | Fixed point (8.8)            |
| f32     | 4 bytes | Fixed point (16.16)          |
| float   | 4 bytes | 32-bit MBF floating point    |

---

## 4. C64 Decorators

Decorators modify function behavior. The C64 compiler provides special decorators.

### 4.1 @lowercase

Switches the screen to lowercase/uppercase character mode.

```python
@lowercase
def main():
    print("Hello World!")  # Displays in lowercase
```

The C64 starts in uppercase/graphics mode by default. The `@lowercase` decorator switches to lowercase/uppercase mode.

#### Screen Code String Literals (`s"..."`)

The C64 VIC chip works directly with **screen codes**, not PETSCII. The `s"..."` syntax enables defining strings converted to screen codes at compile time:

```python
SCREEN = 0x0400

def example():
    row: array[char, 40][SCREEN]

    row = "Hello!"         # PETSCII encoding (Kernal-compatible)
    row = s"Hello!"        # Screen code encoding (direct VIC display)
```

**Screen code vs PETSCII:**

| Syntax    | Encoding    | Usage                                      |
| --------- | ----------- | ------------------------------------------ |
| `"..."`   | PETSCII     | `print()`, file operations, Kernal routines|
| `s"..."`  | Screen code | Direct screen RAM writes                   |

**Character conversion based on `@lowercase` decorator:**

| Character  | Uppercase mode (default) | Mixed mode (`@lowercase`) |
| ---------- | ------------------------ | ------------------------- |
| `'A'-'Z'`  | 1-26 ($01-$1A)           | 65-90 ($41-$5A)           |
| `'a'-'z'`  | 1-26 (= uppercase)       | 1-26 ($01-$1A)            |
| `'@'`      | 0 ($00)                  | 0 ($00)                   |
| Space, 0-9 | Unchanged                | Unchanged                 |

```python
@lowercase
def main():
    screen: array[char, 40][SCREEN]
    screen = s"Hello World"  # H=72, e=5, l=12, ..., W=87, o=15, ...
```

> **Important:** Use `array[char, N]` type (not `array[byte, N]`), because `char` arrays use special copy logic that skips the Pascal string length byte.

### 4.2 @kernal

Enables Kernal ROM (legacy mode). By default, PyCo **disables the Kernal ROM** (+8KB RAM).

```python
@kernal
def main():
    # Kernal ROM active - $FFD2, $FFE4 etc. available
    pass
```

**Differences:**

| Function              | Default (Kernal OFF)         | @kernal (Kernal ON)  |
| --------------------- | ---------------------------- | -------------------- |
| ROM setting           | $01 = $35 (both ROMs off)    | $01 = $36 (BASIC off)|
| print()               | Custom screen routine        | $FFD2 CHROUT         |
| getkey() / waitkey()  | Custom keyboard routine      | $FFE4 GETIN          |
| @irq handler          | Chains to system IRQ         | Direct `rti`         |
| Extra RAM             | +8KB ($E000-$FFFF)           | None                 |

**When to use:**
- Direct Kernal routine calls (e.g., floppy I/O)
- When file size is critical (smaller PRG)

**When NOT to use:**
- If you need more RAM → +8KB ($E000-$FFFF)
- Raster effects → stable timing without ROM

**File size vs RAM trade-off:**

| Mode               | print/getkey source       | PRG size | Free RAM       |
| ------------------ | ------------------------- | -------- | -------------- |
| `@kernal`          | Kernal ROM ($FFD2, $FFE4) | Smaller  | ROM remains    |
| Default            | Built-in PyCo code        | Larger   | Net more RAM   |

By default, PyCo compiles its own screen and keyboard handling code into the program. The $E000-$FFFF area (8KB) becomes available as RAM, and while the built-in routines take some space, they are more compact and faster than Kernal routines.

### 4.3 @noreturn

The program never returns to BASIC. Exit cleanup code is omitted.

```python
@noreturn
def main():
    while True:
        pass  # Infinite loop
```

**Generated code:**
- Normal program: cleanup + `rts`
- @noreturn program: `jmp *` (infinite loop)

**Savings:** ~50-100 bytes

### 4.4 @relocate(address)

Relocates a function to the specified memory address at runtime.

```python
@relocate(0xC000)
def helper_function():
    # This code will be at $C000 at runtime
    pass
```

**Operation:**

1. Decorated functions are placed at program end in `.pseudopc` block
2. At startup, a table-driven copier moves them to target address
3. SSP points to freed physical location → more stack space!

```
After compilation:                    At runtime (before main):

$0801 ┌────────────────────┐         $0801 ┌────────────────────┐
      │ Main program code  │               │ Main program code  │
$xxxx ├────────────────────┤         $xxxx ├────────────────────┤
      │ Relocated functions│               │ (freed)            │ ← SSP
      │ [physical location]│               │                    │
$yyyy └────────────────────┘         $yyyy └────────────────────┘

                                     $C000 ┌────────────────────┐
                                           │ Relocated functions│
                                     $C0xx └────────────────────┘
```

**Dynamic region allocation:**

Functions with the same target address are placed consecutively:

```python
@relocate(0xC000)
def helper1():      # → from $C000
    print("*")

@relocate(0xC000)   # Continues, doesn't overwrite!
def helper2():      # → after helper1
    print("#")
```

**Typical use cases:**

| Target area   | When to use                                   |
| ------------- | --------------------------------------------- |
| `$C000-$CFFF` | VIC Bank 3 free area (4KB), most common       |
| `$A000-$BFFF` | BASIC ROM area (if disabled)                  |
| `$E000-$FFFF` | Kernal ROM area (if disabled)                 |

> **Note:** The `$0400-$07FF` area (default screen RAM) can theoretically be used if VIC bank != 0, but garbage will appear on screen during the copy. It's better to use the `$C000-$CFFF` area instead.

**Important notes:**

| Rule                             | Description                 |
| -------------------------------- | --------------------------- |
| No overlap checking              | Programmer's responsibility |
| Combinable with other decorators | `@relocate` + `@irq` works  |

### 4.5 @charset_rom(address)

Copies the C64 character ROM (2KB) to the specified RAM address at startup.

```python
@charset_rom(0xC800)  # 2KB ROM charset → $C800-$CFFF
@lowercase
def main():
    # Charset is already ready!
    pass
```

**Operation:**

1. Startup code disables IRQ with SEI
2. Switches CPU port for character ROM access
3. Copies 2KB ROM charset to target address
4. Re-enables I/O and IRQ with CLI
5. Then relocations run (if any)

**Combination with `relocate[tuple[byte], address]`:**

`@charset_rom` copies ROM FIRST, `relocate` tuples THEN overwrite custom characters:

```python
# Custom character 60 - overwrites ROM!
char_60: relocate[tuple[byte], 0xC9E0] = (0x00, 0x3F, 0x7F, 0x7F, ...)

@charset_rom(0xC800)
@lowercase
def main():
    # ROM charset copied to $C800, char 60 patched
    pass
```

### 4.6 @origin(address)

Sets a custom program start address without BASIC loader.

```python
@origin(0x1000)
def main():
    # Program starts at $1000
    pass
```

**Operation:**

- Program starts at the specified address (not $0801)
- **No BASIC loader** - `BasicUpstart2` macro is omitted
- PRG file's first 2 bytes contain the specified address (little-endian)

**Loading and running:**

```
LOAD "FILE",8,1
SYS 4096
```

The `,1` parameter is required in the `LOAD` command to load at the address stored in the file (not $0801).

**Use cases:**

1. **Cartridge development** - Program at $8000 as cartridge ROM
2. **Debugger/monitor** - Program in upper memory ($C000+)
3. **Multi-part programs** - Overlays at different addresses
4. **Disable autostart** - Program shouldn't auto-run with RUN

**Combination with other decorators:**

```python
@origin(0xC000)
@noreturn
@lowercase
def main():
    # Program at $C000, never returns to BASIC
    pass
```

**Combination with @relocate:**

```python
@relocate(0xE000)
def irq_handler():
    pass

@origin(0xC000)
def main():
    # Main program at $C000
    # IRQ handler relocated to $E000
    __set_irq__(irq_handler)
```

Relocation works the same: source code at program end, copied to target at startup.

**Address range:** $0000-$FFFF (full 64KB)

> **Note:** `@origin` can only be used on the `main()` function!

### 4.7 @cartridge(mode, stack_start)

Generate EasyFlash cartridge output (.crt file). The program runs directly from ROM.

```python
@cartridge              # mode=8, stack=0x0800 (defaults)
@cartridge()            # same
@cartridge(8)           # 8KB mode
@cartridge(16)          # 16KB mode
@cartridge(8, 0x0300)   # 8KB mode, stack at $0300
def main():
    pass
```

**Parameters:**

| Parameter     | Value     | Description                       |
|---------------|-----------|-----------------------------------|
| `mode`        | 8 or 16   | EasyFlash mode (8KB or 16KB ROM)  |
| `stack_start` | address   | SSP start address (default: $0800)|

**Memory map (8KB mode, Kernal enabled):**

```
$0000-$00FF  Zero Page (RAM) - PyCo runtime
$0100-$01FF  Hardware Stack (RAM)
$0200-$07FF  Free RAM (bank dispatcher here in multi-bank mode)
$0800+       SSP default start address
$8000-$9FFF  ROML - Cartridge ROM (8KB)
$A000-$BFFF  Free RAM (8KB) - in 8KB mode!
$C000-$CFFF  Free RAM (4KB)
$D000-$DFFF  I/O + EasyFlash registers
  $DE00      Bank register (0-63)
  $DE02      Mode register ($06=8KB, $07=16KB)
  $DF00-$DF7F  SRAM - SMC helper copied here
$E000-$FFFF  Kernal ROM (enabled)
```

**Generated files:**

| File type | Description                           |
|-----------|---------------------------------------|
| `.crt`    | EasyFlash cartridge (VICE, Ultimate)  |
| `.prg`    | NOT generated in cartridge mode!      |

**Decorator compatibility:**

| Decorator    | Works? | Notes                               |
|--------------|--------|-------------------------------------|
| `@lowercase` | ✓      | Works normally                      |
| `@noreturn`  | ✓      | Implicit (cartridge never returns)  |
| `@irq`       | ✓      | Full raster IRQ support             |
| `@irq_raw`   | ✓      | Minimal overhead IRQ                |
| `@kernal`    | ✗      | Kernal is enabled by default        |

**SMC Helper in SRAM:**

Large (≥64 byte) fill and copy operations use an SMC (Self-Modifying Code) helper. In cartridge mode, this helper is copied to SRAM ($DF00, 52 bytes) by the boot code, since ROM cannot be modified.

> **Details:** See `docs/implementations/C64/native/cartridge_plan_en.md`

### 4.8 IRQ Decorators

Four decorators are available for IRQ handling. Detailed description: [5. IRQ Handling](#5-irq-handling).

| Decorator       | IRQ vector              | Usage                          |
| --------------- | ----------------------- | ------------------------------ |
| `@irq`          | $FFFE/$FFFF (hardware)  | General IRQ handler            |
| `@irq_raw`      | $FFFE/$FFFF (hardware)  | Bare metal, no chaining        |
| `@irq_hook`     | $0314/$0315 (Kernal)    | Fastest, Kernal hook           |
| `@irq_helper`   | N/A                     | Helper function for IRQ calls  |

### 4.9 @naked

For functions written entirely in assembly. The compiler generates only a label, nothing else - no prologue, epilogue, or any PyCo overhead.

```python
@naked
def sid_play():
    __asm__("""
    jsr $1003       // External music player routine
    rts
    """)

def main():
    sid_play()      // Simple JSR _sid_play call
```

**When to use:**
- Wrapper functions for external libraries (e.g., music players)
- Routines written entirely in assembly
- When PyCo calling convention is not needed

**Register-based parameters:**

Naked functions receive parameters in registers:

| Parameters           | Registers      |
| -------------------- | -------------- |
| `(byte)`             | A              |
| `(byte, byte)`       | A, X           |
| `(byte, byte, byte)` | A, X, Y        |
| `(word)`             | X (lo), Y (hi) |

**Rules:**
- Function must handle register preservation itself
- Cannot combine with `@irq` decorator
- **Module export:** `@naked` functions can be exported from modules, the PMI contains the `is_naked` flag

> **Note:** For efficient calling from IRQ handlers, see the `@irq_helper` decorator (section 5.4).

---

## 5. IRQ Handling

### 5.1 Overview

The C64 has two IRQ vectors:

| Vector        | Address     | Trigger                           |
| ------------- | ----------- | --------------------------------- |
| Hardware IRQ  | $FFFE/$FFFF | VIC-II raster, CIA timer          |
| Kernal hook   | $0314/$0315 | Software hook called by Kernal    |

### 5.2 @irq vs @irq_raw vs @irq_hook vs @irq_helper

| Property          | @irq                    | @irq_raw              | @irq_hook             | @irq_helper           |
| ----------------- | ----------------------- | --------------------- | --------------------- | --------------------- |
| IRQ vector        | $FFFE/$FFFF             | $FFFE/$FFFF           | $0314/$0315           | N/A                   |
| Prologue/epilogue | A/X/Y save + `rti`      | A/X/Y save + `rti`    | None + `jmp $ea31`    | Just `rts`            |
| System IRQ chain  | Yes (in default mode)   | Never                 | N/A (Kernal handles)  | N/A                   |
| Temp registers    | irq_tmp0-5              | irq_tmp0-5            | irq_tmp0-5            | irq_tmp0-5            |

**@irq:** Full IRQ handler. In default mode, chains to system IRQ (keyboard works).

**@irq_raw:** Full IRQ handler, but never chains. Full control, but keyboard doesn't work automatically.

**@irq_hook:** Lightweight hook for Kernal software IRQ vector. Kernal already saved A/X/Y, so no prologue. Handler ends with `JMP $EA31`.

> **Important:** `@irq_hook` is only suitable for CIA system timer tasks (music playback, frame counter, etc.). For raster or other VIC interrupts, use `@irq` or `@irq_raw`, because the Kernal IRQ handler doesn't acknowledge VIC interrupts and doesn't filter interrupt sources.

**@irq_helper:** Helper function for calling from IRQ handler. Uses `irq_tmp0-5` registers. **Module export:** `@irq_helper` functions can be exported from modules, the PMI contains the `is_irq_helper` flag.

```python
# General IRQ - keyboard works
@irq
def raster_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF

# Bare metal IRQ - full control
@irq_raw
def timing_critical_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF

# Kernal hook - smallest own overhead
@irq_hook
def frame_counter():
    frame_count: byte[0x02F0]
    frame_count = frame_count + 1
```

### 5.3 IRQ Parameters

IRQ handlers can receive special parameters:

| Parameter | Register | Description                | Reading        |
| --------- | -------- | -------------------------- | -------------- |
| `vic`     | $D019    | VIC-II interrupt flag      | Direct         |
| `cia1`    | $DC0D    | CIA1 interrupt control     | **Lazy cache** |
| `cia2`    | $DD0D    | CIA2 interrupt control     | Direct         |

> **Special:** Parameter order is arbitrary, and any can be omitted. `(cia1: byte, vic: byte)` works the same as `(vic: byte, cia1: byte)`, and `(vic: byte)` alone is valid if you only use VIC.

**Important differences:**
- **VIC ($D019):** Reading does NOT clear the value → can read multiple times
- **CIA1 ($DC0D):** Reading CLEARS the value → lazy cache required
- **CIA2 ($DD0D):** Reading CLEARS the value → user's responsibility

```python
@irq
def raster_handler(vic: byte, cia1: byte):
    if vic & 0x01:
        vic = 0x01  # Acknowledge - writes directly to $D019
        # raster logic...

    if cia1 & 0x01:
        # CIA1 Timer A interrupt
        pass
```

**Writing parameters:** goes directly to hardware register:

```python
@irq
def handler(vic: byte, cia1: byte):
    if vic & 0x01:
        vic = 0x01      # → sta $D019
    if cia1 & 0x01:
        cia1 = 0x7f     # → sta $DC0D
```

**Lazy reading optimization (CIA1):**

The `cia1` parameter uses lazy reading, saving ~7 cycles in raster IRQs:

1. Prologue initializes a cache (`irq_cia1_cache = $80`)
2. CIA1 register is ONLY read if your code uses it
3. In epilogue (if reached), CIA1 is always read for acknowledgment

**Early return in raster IRQs:**

If you use `return` mid-handler (e.g., for fast raster effects), the epilogue doesn't run. If CIA1 also triggered meanwhile, the IRQ **fires again immediately** after RTI (CIA1 /IRQ line stays LOW). This isn't a problem - you can handle CIA1 in the next invocation if needed.

### 5.4 Temp Registers

IRQ can interrupt the main program at any time. Therefore, IRQ handler uses **separate ZP area**:

| Normal context     | IRQ context   | Usage                  |
| ------------------ | ------------- | ---------------------- |
| $02-$07 (tmp0-5)   | $1A-$1F       | Basic operations       |
| $13-$15 (tmp6-8)   | (none)        | Avoid in IRQ!          |

**Important:** tmp6-8 are not automatically substituted in IRQ! These are needed for division, f16/f32 and string operations - which are **forbidden** in IRQ handlers.

### 5.5 Local Variables in IRQ

IRQ handler uses the software stack but **does NOT modify** SSP and FP. It uses `(SSP) + 4 + offset` address directly.

```
IRQ entry:                           During IRQ:
┌─────────────┐                      ┌─────────────┐
│  (free)     │                      │ IRQ local   │ ← (SSP) + 4 + offset
├─────────────┤ ← SSP                │  variables  │
│  main prog  │                      ├─────────────┤ ← (SSP) + 4
│  variables  │                      │  (4 byte    │
└─────────────┘                      │   guard)    │
                                     ├─────────────┤ ← SSP (unchanged!)
                                     │  main prog  │
                                     └─────────────┘
```

**Why +4 byte guard zone?** The main program writes max 4 bytes at once (float parameter), without modifying SSP. The +4 offset guarantees we don't overwrite.

### 5.6 FORBIDDEN Operations in IRQ

The compiler checks at compile time:

| Operation                     | Error message                    | Why forbidden?               |
| ----------------------------- | -------------------------------- | ---------------------------- |
| `float`, `f16`, `f32` types   | "Float type not allowed in @irq" | FAC/ARG not saved            |
| `print()`                     | "print() not allowed in @irq"    | spbuf/spsave not saved       |

**ALLOWED in IRQ:**
- `byte`, `word`, `int`, `char`, `bool` types
- Comparisons, conditions, loops
- Memory-mapped variables
- Array/subscript access
- `__sei__()`, `__cli__()`, `__inc__()`, `__dec__()`, `__asm__()`
- Function calls (normal functions too!) and `@naked`/`@irq_helper` calls

**Calling normal functions from IRQ:**

IRQ handlers can call normal functions! The compiler automatically generates the necessary wrapper code:

```python
def calculate_score(base: word, multiplier: byte) -> word:
    return base * multiplier

@irq
def raster_handler(vic: byte):
    if vic & 0x01:
        vic = 0x01
        new_score: word = calculate_score(100, 5)  # Normal call - works!
```

**The compiler automatically:**
1. Saves main program's `tmp0-tmp5`, `FP`, `SSP` values to hardware stack
2. Sets up `SSP` and `FP` for the called function
3. Restores original values after the call

**Overhead:** ~100-120 cycles per call (due to save/restore).

**Advantage:** Normal functions can be called **from both IRQ and main program** - the same code is reusable in both contexts.

**Optimization:** If minimal overhead is needed and the function will **only be called from IRQ**, use `@irq_helper` decorator. It uses `irq_tmp0-5` registers, so it canNOT be called from main program!

### 5.7 irq_safe Wrapper Type

The `irq_safe` wrapper type provides **atomic access** to variables used by both main program and IRQ handler.

```python
@singleton
class Game:
    score: irq_safe[word[0x00FB]]    # Atomic access
```

**Problem (without irq_safe):**

```
; Normal word write - DANGEROUS!
    lda #$39
    sta $FB          ; ← IRQ can interrupt here
    lda #$30         ;   IRQ reads wrong value!
    sta $FC
```

**Solution (with irq_safe):**

```
; irq_safe word write - SAFE
    php              ; Save I flag
    sei              ; Disable IRQ
    lda #$39
    sta $FB
    lda #$30
    sta $FC
    plp              ; Restore I flag
```

**Why PHP/PLP and not SEI/CLI?**

`PLP` restores the **original** I flag state. If user called `__sei__()` earlier, CLI would re-enable IRQ against their intention.

**IRQ context detection:**

In IRQ handlers, protection is **automatically skipped** (6502 CPU automatically sets I=1).

**Overhead:**

| Operation         | Extra cycles |
| ----------------- | ------------ |
| irq_safe read     | +9 cycles    |
| irq_safe write    | +9 cycles    |
| In IRQ            | +0 cycles    |

### 5.8 IRQ Handler Setup

**`__set_irq__()` intrinsic (recommended):**

```python
@irq_hook
def frame_counter():
    frame_count: byte[0x02F0]
    frame_count = frame_count + 1

def main():
    __set_irq__(frame_counter)  # Automatically detects decorator
```

| Decorator   | Vector set            |
| ----------- | --------------------- |
| `@irq`      | $FFFE/$FFFF (hardware)|
| `@irq_raw`  | $FFFE/$FFFF (hardware)|
| `@irq_hook` | $0314/$0315 (Kernal)  |

**Manual setup:**

```python
def main():
    irq_vector: word[0x0314]
    __sei__()
    irq_vector = addr(raster_handler)
    __cli__()
```

### 5.9 Protected SSP Update

If the program has an `@irq` handler, the code generator uses **protected SSP update** for page boundary crossing:

```asm
; Protected SSP update (php/plp preserves user's __sei__ state)
clc
lda SSP
adc #<frame_size
bcc .no_carry       ; No carry → safe
php                 ; Page crossing → protect!
sei
sta SSP
inc SSP+1
plp                 ; Restore ORIGINAL I flag
jmp .done
.no_carry:
sta SSP
.done:
```

**Overhead:**
- No page crossing: **0 extra cycles**
- Page crossing: **+12 cycles**

---

## 6. Intrinsic Functions

### 6.1 Interrupt Handling

**`__sei__()` - Disable interrupts:**

```python
__sei__()  # Interrupts disabled
```

Generates the 6502 `SEI` instruction.

**`__cli__()` - Enable interrupts:**

```python
__cli__()  # Interrupts enabled
```

Generates the 6502 `CLI` instruction.

> **Important:** `__sei__()` and `__cli__()` should always be used in pairs!

### 6.2 Timing

**`__nop__()` - No operation:**

```python
__nop__()     # 1 NOP = 2 cycles
__nop__(5)    # 5 NOPs = 10 cycles
```

Typical use: precise timing for raster effects.

### 6.3 Raster IRQ Helper Functions

**`__enable_raster_irq__(line)` - Enable raster IRQ:**

```python
IRQ_LINE = 100

def main():
    __set_irq__(raster_handler)
    __enable_raster_irq__(IRQ_LINE)
```

Automatically handles SEI/CLI and $D011 bit 7 (9th raster bit).

**`__disable_raster_irq__()` - Disable raster IRQ:**

```python
def cleanup():
    __disable_raster_irq__()
```

**`__set_raster__(line)` - Set raster line:**

```python
@irq
def split_screen(vic: byte, cia1: byte):
    vic = 0x01
    current: word = __get_raster__()

    if current < 100:
        __set_raster__(SECOND_LINE)
    else:
        __set_raster__(FIRST_LINE)
```

In IRQ context, **no** SEI/CLI overhead.

**`__get_raster__()` - Get current raster line:**

```python
current: word = __get_raster__()  # 0-311
```

**Summary:**

| Function                | Returns | IRQ protection                   |
| ----------------------- | ------- | -------------------------------- |
| `__enable_raster_irq__` | void    | PHP/SEI...PLP (always)           |
| `__disable_raster_irq__`| void    | PHP/SEI...PLP (always)           |
| `__set_raster__`        | void    | PHP/SEI...PLP (only outside IRQ) |
| `__get_raster__`        | word    | None (read only)                 |

### 6.4 Other Intrinsics

**`__inc__(var)` / `__dec__(var)` - Internal use:**

> **Note:** You don't need to use these directly! The compiler automatically converts `counter += 1` and `counter -= 1` expressions to INC/DEC instructions. Simply use the `+=` / `-=` operators - optimization is automatic.
>
> **Important:** The `c = c + 1` form is NOT automatically converted, only `c += 1`!

---

## 7. Automatic Optimizations

### 7.1 Array Copy

`arr1 = arr2` type array assignment generates inline memcpy.

**Addressing modes:**

| Type               | Method       | Cycles/byte |
| ------------------ | ------------ | ----------- |
| Indirect           | `(ptr),Y`    | ~17-19      |
| Hybrid             | Mixed        | ~15-16      |
| Absolute (SMC)     | `$addr,Y`    | ~13-15      |

```python
def main():
    screen: array[byte, 1000][0x0400]  # Mapped
    backup: array[byte, 1000][0xC000]  # Mapped

    backup = screen  # SMC optimized: ~13-15 cy/byte
```

The compiler automatically chooses the fastest method:
- Both mapped → full SMC (fastest)
- One mapped → hybrid
- Neither mapped → indirect

### 7.2 Block Copy (blkcpy)

The `blkcpy()` intrinsic implements fast block memory copy.

**Syntax:**

```python
# 7 parameters (shared stride):
blkcpy(src_arr, src_offset, dst_arr, dst_offset, width, height, stride)

# 8 parameters (separate strides):
blkcpy(src_arr, src_offset, src_stride, dst_arr, dst_offset, dst_stride, width, height)
```

**Usage examples:**

```python
screen: array[byte, 1000][0x0400]

# Scroll left
blkcpy(screen, 1, screen, 0, 39, 25, 40)

# Scroll up
blkcpy(screen, 40, screen, 0, 40, 24, 40)

# Tile blit (8x8 tile → screen)
blkcpy(tile, 0, 8, screen, 12*40+16, 40, 8, 8)
```

**Automatic direction detection:**

For overlapping copies, the compiler automatically determines correct direction:
- **Forward** (dst ≤ src): 0 to width-1
- **Backward** (dst > src): width-1 to 0

**Performance:**

| Array types            | Cycles/byte |
| ---------------------- | ----------- |
| Both mapped            | ~13         |
| One mapped             | ~17         |
| Both stack             | ~21         |

### 7.3 Arithmetic Optimizations

#### Strength Reduction (O1)

Operations with power-of-2 constants are converted to bit shifts:

| Operation | Optimized code   | Savings       |
| --------- | ---------------- | ------------- |
| `a * 2`   | `asl`            | ~80 → 2 cy    |
| `a * 4`   | `asl` `asl`      | ~80 → 4 cy    |
| `a / 2`   | `lsr`            | ~80 → 2 cy    |
| `a % 16`  | `and #15`        | ~100 → 2 cy   |

#### Constant Multiplication Decomposition (O2)

Multiplication by small constants decomposes to shift+add/sub:

| Constant | Decomposition      | Cycles |
| -------- | ------------------ | ------ |
| 3        | `(a << 1) + a`     | ~12    |
| 5        | `(a << 2) + a`     | ~14    |
| 7        | `(a << 3) - a`     | ~16    |
| 9        | `(a << 3) + a`     | ~16    |
| 10       | `(a << 3) + (a<<1)`| ~20    |

**Performance comparison:**

| Operation | Runtime helper | O1 (shift) | O2 (decomp) |
| --------- | -------------- | ---------- | ----------- |
| `a * 2`   | ~80 cy         | ~2 cy      | -           |
| `a * 3`   | ~80 cy         | -          | ~12 cy      |
| `a * 5`   | ~80 cy         | -          | ~14 cy      |

---

## 8. Type Implementation

### 8.1 Float Format

PyCo uses **32-bit MBF** (Microsoft Binary Format) floating point numbers:

| Byte | Content                            |
| ---- | ---------------------------------- |
| 0    | Exponent (biased by 128)           |
| 1-3  | Mantissa (24 bit, implicit 1)      |
| 3    | bit 7 = sign                       |

**Representable range:**

| Value         | Decimal approximation |
| ------------- | --------------------- |
| Max positive  | ~1.7×10³⁸             |
| Max negative  | ~-1.7×10³⁸            |

### 8.2 Float Overflow

On overflow, **signed saturation** occurs:

| Operation         | Condition         | Result          |
| ----------------- | ----------------- | --------------- |
| Addition/multiply | Positive overflow | Max positive    |
| Addition/multiply | Negative overflow | Max negative    |
| Division by zero  | Positive dividend | Max positive    |
| Division by zero  | Negative dividend | Max negative    |

> **Note:** This differs from Commodore BASIC (`?OVERFLOW ERROR`). PyCo uses the saturation approach common in DSP/SIMD processors.

---

## 9. Build System

### 9.1 D64 Disk Images

PyCo supports packaging multi-file projects into D64 disk images with TOML configuration.

**Project structure:**

```
project/
├── game.pyco       # Main program
├── game.toml       # Project configuration
├── build/
│   ├── game.prg
│   ├── game.d64
│   └── ...
└── includes/
```

### 9.2 TOML Configuration

```toml
[project]
name = "MyGame"
version = "1.0"

[disk]
label = "MYGAME"      # Disk name (max 16 characters)
id = "01"             # Disk ID (2 characters)

[[disk.files]]
source = "build/game.prg"
name = "MYGAME"

[[disk.files]]
source = "build/title_bitmap_rle.prg"
name = "TITLEBIT"

[run]
autostart = true
warp = true
```

**Disk ID:** The 2-character ID is important for 1541 drive BAM caching. On disk change, ID change signals the drive to re-read.

### 9.3 CLI Usage

```bash
# Compile
pycoc compile game.pyco              # → build/game.prg

# Create D64
pycoc d64 game.toml                  # → build/game.d64

# Run in VICE
pycoc run game.pyco
pycoc run game.toml
```

**Typical workflow:**

```bash
pycoc compile game.pyco   # 1. Compile
pycoc image title.koa ... # 2. Convert images
pycoc music song.fur ...  # 3. Convert music
pycoc d64 game.toml       # 4. Build D64
```

### 9.4 PRG File Format

```
┌──────────────┬─────────────────────┐
│ Byte 0-1     │ Byte 2 - end        │
│ Load address │ Raw data            │
│ (little-end) │                     │
└──────────────┴─────────────────────┘
```

The C64 `LOAD "FILE",8,1` command loads data to the address stored in the PRG.

### 9.5 Binary Converters

```bash
# Image → PRG
pycoc image title.koa --binary -C rle -O build/

# Music → PRG
pycoc music song.fur --binary -L 0xA000 -O build/
```

---

## Examples

### Memory-Mapped Variables

```python
BORDER = 0xD020
BGCOLOR = 0xD021

def main():
    border: byte[BORDER]
    bgcolor: byte[BGCOLOR]

    border = 0       # black border
    bgcolor = 6      # blue background
```

### Screen Memory

```python
SCREEN = 0x0400
COLOR = 0xD800

def main():
    screen: array[byte, 1000][SCREEN]
    color: array[byte, 1000][COLOR]

    screen[0] = 1    # 'A' character
    color[0] = 1     # white color
```

### Colorful Border

```python
@lowercase
def main():
    border: byte[0xD020]
    i: byte

    while True:
        for i in range(16):
            border = i
```

### Raster Scroll

```python
scroll_x: byte[0x02F0] = 0

@irq
def raster_handler():
    vic_ctrl2: byte[0xD016]
    vic_irq: byte[0xD019]

    vic_ctrl2 = (vic_ctrl2 & 0xF8) | scroll_x
    vic_irq = 0xFF
```
