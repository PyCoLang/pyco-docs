# Kick Assembler Reference Documentation

This document serves as a quick reference for Kick Assembler syntax and features, specifically tailored for the PyCo project's code generation needs.

## 1. Basic Directives

### Memory & Positioning

#### `.pc` / `*`
Sets the program counter (memory position).
```asm
* = $0801 "Basic Upstart"
.pc = $1000 "Main Program"
```

#### `BasicUpstart2`
Generates a BASIC loader line (SYS ...) to start the program.
```asm
BasicUpstart2(start)
* = $1000
start: rts
```

#### `.align`
Aligns the memory position to the next multiple of the given value.
```asm
.align $100  // Align to next page boundary
```

#### `.pseudopc`
Compiles code as if it was at a different address (for relocation).
```asm
.pseudopc $2000 {
    label: jmp label  // Compiles as jmp $2000
}
```

### Data Definition

#### `.byte` / `.by`
Defines 8-bit values.
```asm
.byte $00, $ff, 128, %10101010
.byte "A", "B", "C"
```

#### `.word` / `.wo`
Defines 16-bit values (little-endian).
```asm
.word $1000, label, label+$20
```

#### `.dword` / `.dw`
Defines 32-bit values (little-endian).
```asm
.dword $12345678
```

#### `.text` / `.te`
Defines string data using the current encoding.
```asm
.text "Hello World"
```

#### `.fill`
Fills memory with a value or pattern.
```asm
.fill 10, 0          // 10 bytes of 0
.fill 256, i         // 0, 1, 2, ... 255
.fill 4, [$10, $20]  // $10, $20, $10, $20
```

#### `.fillword`
Fills memory with 16-bit words.
```asm
.fillword 5, $1000   // 5 words of $1000
```

### Import

#### `.import` (Deprecated for source) / `#import`
Includes another source file.
```asm
#import "macros.asm"
#importif DEBUG "debug.asm"
#importonce
```

#### `.import binary` / `.import c64` / `.import text`
Imports binary data.
```asm
.import binary "data.bin"
.import c64 "music.prg"      // Skips first 2 bytes (load address)
.import text "scroll.txt"
```

## 2. Label System

### Global Labels
Standard labels ending with a colon.
```asm
start:  lda #0
        jmp start
```

### Local Labels
Labels visible only within the current scope (file, block, macro).
```asm
!loop:  dex
        bne !loop-  // Jump to previous !loop

        ldy #10
!loop:  dey
        bne !loop-
```
Note: `!label` is a multi-label. `+` refers to next, `-` to previous.

### Anonymous Labels
Simple jump targets without names.
```asm
        jmp !+
        nop
!:      jmp !-
```

### Scopes
Scopes are created by `{ ... }`, `.namespace`, macros, and functions.
```asm
.label global = 1
{
    .label local = 2
    lda #global  // 1
    lda #local   // 2
}
```
Accessing parent scope: `@label`.

### File-level Namespaces
Wraps the entire file in a namespace.
```asm
.filenamespace MyLibrary
label: nop // Becomes MyLibrary.label
```

### Explicit Label Definition
Labels can be defined explicitly as variables using `.label`.
```asm
.label border = $d020
.label bg = $d021
lda #0
sta border
```

## 3. Macros and Functions

### Macros
Blocks of code that can be instantiated.
```asm
.macro SetColor(color) {
    lda #color
    sta $d020
}

SetColor($01)
```

### Functions
Script functions that return values (compile-time).
```asm
.function area(w, h) {
    .return w * h
}

lda #area(10, 20)
```

### Local Variables in Macros
Variables defined with `.var` inside macros are local.
```asm
.macro Loop(count) {
    .var i = 0
    ldx #count
    loop: dex
          bne loop
}
```

## 4. Pseudo Commands

Higher-level instructions defined by the user or libraries.

### Definition
```asm
.pseudocommand mov src:tar {
    lda src
    sta tar
}
```

### Usage
Arguments are separated by colons.
```asm
mov #10 : $d020
mov $1000 : $1001
```

### Argument Types
Inside pseudo commands, arguments are objects with `getType()` and `getValue()`.
Types: `AT_IMMEDIATE`, `AT_ABSOLUTE`, `AT_ABSOLUTEX`, etc.

## 5. Expressions and Operators

### Arithmetic & Logic
Standard operators: `+`, `-`, `*`, `/`, `%` (mod), `&`, `|`, `^`, `<<`, `>>`.
Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`.
Boolean: `&&`, `||`, `!`.

### Built-in Functions
- `lo(val)`, `hi(val)`: Low and high byte.
- `min(a,b)`, `max(a,b)`
- `mod(a,b)`
- `sin(r)`, `cos(r)`, `tan(r)`
- `sqrt(x)`, `pow(x,y)`
- `random()`
- `toRadians(deg)`, `toDegrees(rad)`
- `floor(x)`, `ceil(x)`, `round(x)`

### Label Arithmetic
Labels are values and can be used in expressions.
```asm
lda table + 5
jmp * + 3
```

## 6. String and Encoding

### Encoding Selection
```asm
.encoding "screencode_upper" // Default C64 uppercase
.encoding "petscii_mixed"    // Upper/Lower case
.encoding "ascii"
```

### String Literals
Strings can be used in `.text` or script variables.
```asm
.text "HELLO"
.var msg = "Hello" + " World"
```

### Escape Sequences
Standard escapes like `\n`, `\r`, `\"`, `\$` (hex).

## 7. Data Structures

### Lists
Mutable list of values.
```asm
.var list = List()
.eval list.add(1, 2, 3)
.print list.get(0)
```

### Hashtables
Key-value pairs.
```asm
.var map = Hashtable()
.eval map.put("color", $d020)
lda map.get("color")
```

### Structs
```asm
.struct Point { x, y }
```

### Usage
```asm
.var p = Point(10, 20)
lda #p.x
ldy #p.y
```

### Enums
```asm
.enum { OFF, ON }
lda #ON
```

## 8. Memory Organization (Segments)

### Definition
Segments allow defining memory layout independent of code order.
```asm
.segmentdef Code [start=$0801]
.segmentdef Data [startAfter="Code"]
.segmentdef BSS  [startAfter="Data", virtual]
```

### Usage
Switching between segments.
```asm
.segment Code
start: jmp init

.segment Data
val: .byte 0

.segment Code
init: lda val
```

### File Output
Directing segments to files.
```asm
.file [name="game.prg", segments="Code,Data"]
```

## 9. Conditional Compilation

### If / Else
```asm
.if (SIDE_BORDER) {
    dec $d016
} .else {
    inc $d016
}
```

### Loops
Compile-time loops for code generation.
```asm
.for (var i=0; i<10; i++) {
    nop
}
```

### While Loops
```asm
.var i = 0
.while (i < 10) {
    nop
    .eval i++
}
```

### Variables
Mutable script variables.
```asm
.var x = 10
.eval x = x + 1
```

### Constants
Immutable constants.
```asm
.const BORDER = $d020
```

## 10. 6502 Specifics

### Illegal Opcodes
Enabled by default. Can be disabled or switched to DTV/65c02.
```asm
.cpu _6502            // Standard + Illegals (Default)
.cpu _6502NoIllegals  // Standard only
.cpu _65c02           // CMOS 6502
```

### Addressing Modes
Standard syntax.
- Immediate: `#$00`
- Zero Page: `$00`
- Absolute: `$0000`
- Indexed: `$0000,x`, `$0000,y`
- Indirect: `($0000)`
- Indirect Indexed: `($00),y`
- Indexed Indirect: `($00,x)`

Forcing addressing mode:
```asm
lda.z $10   // Force Zero Page
lda.a $10   // Force Absolute
```

## 11. Debugging

### Console Output
Print messages during assembly.
```asm
.print "Generating tables..."
.printnow "Immediate output"
.var x = 10
.print "Value of x is " + x
```

### Assertions
Verify values at compile time.
```asm
.assert "Table size check", table.size(), 256
.errorif * > $1000, "Program too large!"
```

## 12. Advanced Output & Integration

### Disk Images (D64)
Create a D64 disk image directly.
```asm
.disk [filename="game.d64", name="MY GAME", id="23"] {
    [name="MAIN", type="prg", segments="Code"],
    [name="DATA", type="seq", segments="Data"]
}
```

### Command Line Variables
Access variables passed via `-define name=value` or `:name=value`.
```asm
// java -jar kickass.jar source.asm :BUILD_ID=123
.var id = cmdLineVars.get("BUILD_ID").asNumber()
```
