# PyCo EasyFlash Cartridge Reference

**Version:** 1.0
**Date:** 2026-01-26

## Overview

EasyFlash cartridge support for PyCo:
- Native C64 cartridge output (.crt files)
- Programs running directly from ROM
- **Module-based bank system** - reusing existing `import` syntax
- Flash read/write via the `easyflash` library module

**Target platforms:**
- Physical EasyFlash 1/1CR/3 cartridges
- Ultimate 64 / Ultimate II+L (EasyFlash emulation)
- VICE emulator

---

## EasyFlash Hardware

### Specifications

| Component   | Details                                          |
|-------------|--------------------------------------------------|
| Flash ROM   | 1 MB (2x512KB chips)                             |
| SRAM        | 256 bytes ($DF00-$DFFF) - **writable!**          |
| Banks       | 64 banks x 8KB ROML                              |
| Registers   | $DE00 (bank select), $DE02 (control)             |

### Cartridge Modes

| Mode    | ROML        | ROMH         | $01 works? | Kernal off? |
|---------|-------------|--------------|------------|-------------|
| Ultimax | $8000-$9FFF | $E000-$FFFF  | X NO       | N/A         |
| 16KB    | $8000-$9FFF | $A000-$BFFF  | X NO       | X NO        |
| **8KB** | $8000-$9FFF | -            | **V YES**  | **V YES**   |

**8KB mode advantages:** Only ROML is cartridge-controlled. The rest of memory ($A000-$FFFF) is under $01 control -> Kernal can be disabled!

### Control Register ($DE02)

| Value | Bits      | Meaning                              |
|-------|-----------|--------------------------------------|
| $04   | %000100   | Cartridge ROM off                    |
| $05   | %000101   | Ultimax mode (ROML@$8000, ROMH@$E000)|
| $06   | %000110   | 8KB mode (ROML@$8000)                |
| $07   | %000111   | 16KB mode (ROML@$8000, ROMH@$A000)   |
| $8x   | %1xxxxxx  | LED on (OR with mode)                |

---

## Memory Map

### 8KB Cartridge Mode + Kernal OFF

```
$0000-$00FF  Zero Page (RAM) - PyCo runtime
$0100-$01FF  Hardware Stack (RAM)
$0200-$025F  Bank dispatcher (~60 bytes) - RESERVED!
$0260-$02FF  Free RAM
$0300-$07FF  Free RAM (includes cassette buffer)
$0800+       SSP default start address
$8000-$9FFF  ROML - Current bank (8KB Flash ROM)
$A000-$BFFF  Free RAM (8KB) - can use for data!
$C000-$CFFF  Free RAM (4KB)
$D000-$DFFF  I/O + EasyFlash registers
  $DE00      Bank register (write-only, 0-63)
  $DE02      Control register (write-only)
  $DF00-$DF33  SMC Helper (52 bytes)
  $DF34-$DF3F  EasyFlash module SRAM variables
  $DF40-$DF7F  Read trampoline routine
  $DF80-$DFFF  EAPI area (flash programming)
$E000-$FFFF  Free RAM (8KB) - IRQ vectors here!
```

**Total free RAM: ~50KB!** (vs. ~34KB in 16KB mode)

### IMPORTANT: Reserved Addresses

| Address     | Used By          | Notes                                   |
|-------------|------------------|-----------------------------------------|
| $0200-$025F | Bank dispatcher  | For multi-bank module calls             |
| $0277-$028D | Kernal variables | Keyboard buffer, color, key repeat      |
| $DF00-$DF33 | SMC Helper       | Fill/copy operations from SRAM          |
| $DF34-$DF3F | EasyFlash module | Shadow registers, EAPI arguments        |
| $DF40-$DF7F | Read trampoline  | Safe bank-switching read                |
| $DF80-$DFFF | EAPI             | Flash programming routines              |

---

## @cartridge Decorator

### Syntax

```python
@cartridge              # mode=8, stack=0x0800 (defaults)
@cartridge()            # same
@cartridge(8)           # mode=8, stack=0x0800
@cartridge(16)          # mode=16, stack=0x0800
@cartridge(8, 0x0300)   # mode=8, stack=0x0300
def main():
    pass
```

### Parameters

| Parameter     | Type | Default | Description               |
|---------------|------|---------|---------------------------|
| `mode`        | int  | 8       | 8KB or 16KB mode          |
| `stack_start` | int  | 0x0800  | SSP start address         |

### Decorator Compatibility

| Decorator    | Compatible? | Notes                                 |
|--------------|-------------|---------------------------------------|
| `@cartridge` | Required    | Marks program as cartridge            |
| `@lowercase` | V Yes       | Works normally                        |
| `@noreturn`  | V Yes       | Implicit (cartridge never returns)    |
| `@irq`       | V Yes       | **Full raster IRQ support!**          |
| `@irq_raw`   | V Yes       | Minimal overhead IRQ                  |
| `@irq_hook`  | V Yes       | Works (but Kernal is disabled)        |
| `@kernal`    | X No        | Kernal is disabled                    |

---

## Startup Sequence

1. **Reset** -> Ultimax mode active
2. CPU reads reset vector from $FFFC/$FFFD (in ROMH @ $E000)
3. Kernal checks for "CBM80" signature at $8004
4. If found -> `JMP ($8000)` executes cartridge code
5. **Switch to 8KB mode** ($DE02 = $06) + **SHADOW_CTRL init** ($DF35 = $06)
6. **Copy SMC Helper** from ROMH to SRAM ($DF00)
7. **Kernal init** ($FDA3, $FD50, $FD15, $FF5B)
8. Initialize SSP/FP
9. JMP main

---

## Bank Switching and Return

### The Problem

If the program runs from ROM (e.g., $8100) and switches banks:

```
$8100: JSR set_bank    ; return address ($8103) -> pushed to stack
       ...
       ; set_bank executes: STA $DE00
       ; IMMEDIATELY the other bank's content is visible at $8000-$9FFF
       ; Return address ($8103) now points to GARBAGE!
       ; RTS -> CRASH!
```

### Solution 1: SRAM Trampoline (easyflash module)

The `easyflash.read_byte()` function uses a routine running from SRAM ($DF50):

```
1. Routine in SRAM ($DF50) - ALWAYS visible, regardless of active bank
2. Switch to target bank
3. Read byte
4. Restore bank 0
5. RTS -> safe, because bank 0 is active again
```

### Solution 2: Bank Dispatcher (multi-bank modules)

Modules defined in TOML use the RAM-based dispatcher ($0200):

```
Caller (bank 0):
  1. tmp0/tmp1 = target address in other bank
  2. A = target bank number
  3. JSR $0200

Dispatcher ($0200, in RAM):
  4. PHA -> save target bank
  5. LDA current_bank
  6. PHA -> CALLER BANK SAVED TO STACK
  7. PLA -> target bank back
  8. STA $DE00 -> switch bank
  9. JSR (tmp0) -> execute target code

Return:
  10. PLA -> caller bank from stack
  11. STA $DE00 -> original bank restored
  12. RTS -> safe return
```

**The dispatcher runs from RAM, so bank switching doesn't affect it!**

---

## Multi-Bank Module System

### TOML Configuration

```toml
[cartridge]
name = "MY GAME"
type = "easyflash"
stack_address = 0x0800    # Optional

[cartridge.main]
source = "main.pyco"
bank = 0

[[cartridge.modules]]
name = "common"
source = "common.pyco"
bank = 2

[[cartridge.modules]]
name = "editor"
source = "editor.pyco"
bank = 3
size = 16  # 16KB module (ROML + ROMH)
```

### Usage

```python
# main.pyco - UNCHANGED SYNTAX!
import common        # TOML specifies: bank 2
import editor        # TOML specifies: bank 3

@cartridge(8, 0x0800)
def main():
    common.init()           # Automatic bank switching!
    common.draw_menu("Help")

    if key == 'e':
        editor.run()        # Switch to editor bank
```

### CLI Commands

```bash
# Build CRT from TOML
pycoc crt game.toml -o build/game.crt

# Force recompile
pycoc crt game.toml --force
```

### Validations

- Bank number: 0-63 (0 reserved for main)
- Bank size: 8 or 16 KB
- No duplicate bank numbers
- No duplicate module names

---

## SRAM Usage

### Layout

| Address     | Size     | Contents                              |
|-------------|----------|---------------------------------------|
| $DF00-$DF33 | 52 bytes | SMC Helper (fill/copy operations)     |
| $DF34       | 1 byte   | SHADOW_BANK (current bank)            |
| $DF35       | 1 byte   | SHADOW_CTRL (mode + LED status)       |
| $DF36       | 1 byte   | SHADOW_INIT (EAPI initialized?)       |
| $DF37-$DF3D | 7 bytes  | EAPI arguments                        |
| $DF40-$DF7F | 64 bytes | Read trampoline routine               |
| $DF80-$DFFF | 128 bytes| EAPI runtime code                     |

### Why SRAM?

SRAM ($DF00-$DFFF) is **ALWAYS visible**, regardless of:
- Which bank is active ($DE00)
- Which mode is active ($DE02)
- The $01 register value

This enables:
- Running code during bank switching
- Flash programming (EAPI)
- Shadow registers (reading write-only registers)

---

## CRT File Format

### Structure

```
Header (64 bytes):
  - "C64 CARTRIDGE   " signature
  - EasyFlash type ($0020)
  - Cartridge name

Bank 0 ROML CHIP (8KB @ $8000):
  - JMP __romh_boot (to $FE00)
  - NOP
  - CBM80 signature
  - Phase 3 code (__phase3)
  - Main program code

Bank 0 ROMH CHIP (8KB @ $E000):
  - Boot code @ $FE00
  - SMC Helper data
  - Reset vector @ $FFFC -> $8000

Bank N ROML CHIPs (per module):
  - Jump table @ $8000
  - Module code
  - (16KB mode: ROMH @ $A000 also)
```

---

## Flash Programming

The `easyflash` library module provides flash read/write capabilities.

See: [c64_library_en.md - easyflash module](../c64_library_en.md#easyflash---easyflash-cartridge)

---

## References

- [EasyFlash Programmer's Guide](http://skoe.de/easyflash/files/devdocs/EasyFlash-ProgRef.pdf)
- [CRT File Format (VICE Manual)](https://vice-emu.sourceforge.io/vice_15.html)
- [Ultimate Documentation](https://1541u-documentation.readthedocs.io/)
- [C64 Wiki - EasyFlash](https://www.c64-wiki.com/wiki/EasyFlash)
