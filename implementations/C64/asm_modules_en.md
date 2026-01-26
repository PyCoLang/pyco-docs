# Writing Assembly Modules in PyCo

**Version:** 1.0.0
**Date:** 2026-01-25

This document describes best practices for writing PyCo modules that contain inline assembly code, with focus on module relocation compatibility.

## Table of Contents

1. [Overview](#overview)
2. [Module Relocation System](#module-relocation-system)
3. [Automatic Relocation](#automatic-relocation)
4. [Embedding Driver Code](#embedding-driver-code)
5. [Best Practices](#best-practices)
6. [Patterns to Avoid](#patterns-to-avoid)
7. [Example: RLE Decompressor](#example-rle-decompressor)

## Overview

PyCo modules (`.pm` files) are relocatable binary code that can be embedded in programs or loaded dynamically at runtime. When writing modules with inline assembly, you must understand how relocation works to ensure your code functions correctly at any load address.

## Module Relocation System

When a module is embedded or loaded, its code must be relocated from the base address `$0000` to the actual load address. The PyCo module system uses **marker-based relocation**:

| Marker | Opcode | Purpose |
|--------|--------|---------|
| `$02` (JAM) | `$A9` (LDA #) | Immediate high byte relocation |
| `$12` (JAM) | `$BD` (LDA abs,X) | DATA access with X index |
| `$22` (JAM) | `$AD` (LDA abs) | Direct DATA access |
| `$32` (JAM) | `$B9` (LDA abs,Y) | DATA access with Y index |
| `$42` (JAM) | `$4C` (JMP abs) | Internal jump (for large modules) |
| `$52` (JAM) | `$20` (JSR abs) | Internal call (for large modules) |

## Automatic Relocation

The following patterns are **automatically relocated** by the module loader:

### 1. Internal JSR/JMP Calls

```asm
jsr _my_subroutine    // Automatically relocated
jmp _loop_start       // Automatically relocated
```

When the assembler generates `JSR $00xx` or `JMP $00xx` (addresses in range `$0000-$07FF`), these are automatically detected and relocated.

### 2. Absolute Addressing with Labels

```asm
lda my_data_table,x   // LDA abs,X - relocated
sta my_buffer,y       // STA abs,Y - relocated
lda my_variable       // LDA abs - relocated
```

The module loader checks the high byte of absolute addresses. If it's in the range `$00-$07`, the address is relocated by adding the module base address.

## Embedding Driver Code

When writing inline assembly modules, a common pattern is having "driver code" (subroutines) that are called from multiple functions. The challenge is that Dead Code Elimination (DCE) may remove functions that aren't directly called.

### The Problem

```python
# WRONG: DCE will remove _driver() because it's not called directly!
@naked
def _driver():
    __asm__("""
_my_subroutine:
    // ... subroutine code ...
    rts
    """)

def my_function():
    __asm__("""
    jsr _my_subroutine  // ERROR: Undefined symbol!
    """)
```

The `_driver()` function starts with `_`, making it private. Since it's not called directly from any PyCo code, DCE removes it. The labels defined inside (`_my_subroutine`) are also removed, causing the assembler error.

### The Solution: Embed Driver in Exported Function

Embed the driver code at the beginning of an exported function, using a `JMP` to skip over it:

```python
def my_function(param: byte) -> byte:
    __asm__("""
    // Jump over driver code
    jmp _my_function_entry

// ============================================================
// DRIVER CODE (embedded here to prevent DCE)
// ============================================================
_my_subroutine:
    // ... subroutine implementation ...
    rts

_helper_routine:
    // ... helper code ...
    rts

// ============================================================
// END OF DRIVER CODE
// ============================================================

_my_function_entry:
    // Actual function code starts here
    ldy #0
    lda (FP),y      // Load parameter
    jsr _my_subroutine
    // ... rest of function ...
    """)
```

This ensures:
1. The driver code is included (it's part of an exported function)
2. The JMP instruction skips over the driver on normal calls
3. All labels are available to other functions in the module

## Best Practices

### 1. Use Local Labels for Short Jumps

The `!:` / `!+` / `!-` syntax is preferred for short jumps within a subroutine:

```asm
_my_loop:
    dex
    bne !+          // Skip next instruction if X != 0
    ldy #0          // Reset Y when X reaches 0
!:  dey
    bne _my_loop    // Continue outer loop
```

### 2. Keep Driver Variables in Code Segment

Variables used by driver code should be stored in the code segment (not BSS) to ensure they're relocated with the module:

```asm
_my_counter:
    .byte 0         // In code segment, relocated with module

_my_buffer:
    .fill 16, 0     // 16-byte buffer in code segment
```

### 3. Use Zero Page Temp Registers

For temporary storage, use the standard PyCo zero page registers:

| Register | Purpose |
|----------|---------|
| `tmp0-tmp5` | General temporaries (main code) |
| `irq_tmp0-irq_tmp5` | IRQ-safe temporaries |

```asm
// Using tmp registers (always at fixed addresses)
sta tmp0
lda tmp2
// These work regardless of module load address
```

### 4. Document Register Usage

Always document which registers and temporaries your driver code uses:

```asm
// ============================================================
// MY_ROUTINE - Does something useful
// ============================================================
// Input:
//   tmp0-tmp1: Source pointer
//   tmp2-tmp3: Destination pointer
//   A: Value to process
// Output:
//   A: Result
// Clobbers: A, X, Y, tmp0-tmp5
// ============================================================
_my_routine:
    // ... implementation ...
```

## Patterns to Avoid

### 1. LDA #>label (Immediate High Byte)

**AVOID** using immediate high byte addressing with labels:

```asm
// DANGEROUS: Requires JAM marker, may not work as expected
lda #>my_data_table
sta ptr_high
lda #<my_data_table
sta ptr_low
```

This pattern requires the compiler to generate JAM markers (`$02`) for relocation. While supported, it's error-prone and should be avoided when possible.

**BETTER**: Use calculated addresses at runtime:

```asm
// Get address of data table (if it's a parameter or global tuple)
lda data_table_addr
sta ptr_low
lda data_table_addr+1
sta ptr_high
```

### 2. Self-Modifying Code with Absolute Addresses

If using SMC, ensure modified addresses are properly handled:

```asm
// RISKY: The $1234 address won't be relocated!
    lda #$00
    sta $1234   // Fixed address, not module-internal
```

For module-internal SMC, the addresses will be relocated, but it's still a fragile pattern.

### 3. Hardcoded Module-Internal Addresses

Never hardcode addresses that should be module-relative:

```asm
// WRONG: $0050 won't be relocated
jsr $0050

// RIGHT: Use a label
jsr _my_subroutine
```

## Example: RLE Decompressor

The `compress` module demonstrates proper inline assembly module design:

```python
def rle_decompress_addr(src_addr: word, dest_addr: word, compressed_size: word):
    """Decompress RLE data from raw addresses."""
    __asm__("""
    // Jump to actual function code (skip over driver)
    jmp _rle_decompress_addr_entry

// ============================================================
// RLE DECOMPRESSION ROUTINE (embedded driver)
// ============================================================
// Input:
//   tmp2-tmp3: source pointer (compressed data)
//   tmp0-tmp1: destination pointer
//   tmp4-tmp5: INPUT size (compressed bytes to read)
//
// Uses: A, X, Y, tmp0-tmp5
// ============================================================

_rle_decompress:
    ldy #0              // Y = source index within page
    ldx #0              // X = dest index (always 0 for indirect)

_rle_loop:
    lda tmp4
    ora tmp5
    beq _rle_done       // input size == 0, done

    lda (tmp2),y
    pha
    jsr _rle_dec_input
    jsr _rle_inc_src
    pla

    cmp #$FF
    beq _rle_marker

_rle_store_byte:
    sta (tmp0,x)
    inc tmp0
    bne _rle_loop
    inc tmp1
    jmp _rle_loop

// ... more driver code ...

_rle_done:
    rts

// Temporary variables in code segment
_rle_count:
    .byte 0
_rle_value:
    .byte 0

// ============================================================
// END OF DRIVER CODE
// ============================================================

_rle_decompress_addr_entry:
    // Load parameters and call driver
    ldy #0
    lda (FP),y
    sta tmp2
    // ... load other params ...
    jsr _rle_decompress
    """)
```

Key points from this example:

1. **Driver embedded in first exported function** - Prevents DCE
2. **JMP to skip driver** - Normal calls jump over the driver code
3. **Uses tmp0-tmp5** - Standard ZP temporaries
4. **Variables in code segment** - `_rle_count`, `_rle_value`
5. **Well-documented** - Input/output/clobbers documented
6. **Only internal JSR** - Uses `jsr _rle_decompress` (no `LDA #>` patterns)

## Summary

When writing assembly modules:

| Do | Don't |
|----|-------|
| Embed driver in exported function | Put driver in separate `@naked` private function |
| Use `tmp0-tmp5` for temporaries | Create BSS variables for temps |
| Use labels for all addresses | Hardcode module-internal addresses |
| Document register usage | Leave undocumented code |
| Test with both static and dynamic import | Assume one import method works for all |
