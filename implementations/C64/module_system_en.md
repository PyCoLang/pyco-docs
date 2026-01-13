# PyCo Module System - Design Document

## Overview

The PyCo module system enables the use of external code from other `.pyco` files. The system supports two operating modes:

1. **Static import** (top-level): Compile-time linking, code is compiled into the binary
2. **Dynamic import** (function-level): Runtime loading, scope-based lifetime

### Design Principles

- **Simplicity**: No relocation table, marker-byte based relocation
- **Efficiency**: Zero overhead in module size
- **Scope = Lifetime**: Module lifetime = enclosing scope lifetime
- **Automatic cleanup**: Function return → module memory is freed
- **Python-like syntax**: Familiar, no new concepts

## Import Syntax

### Basics

```python
from module_name import name1, name2, name3
```

- **Explicit listing required**: All used names must be listed
- **No wildcard**: `from X import *` is NOT supported
- **No prefix needed**: Imported names can be used directly

### Example

```python
from math import sin, cos
from gfx import Sprite, draw_line

def main():
    x = sin(0.5)           # Can be used directly, no prefix!
    y = cos(0.5)
    draw_line(0, 0, x, y)
```

### Alias (`as`) Support

For name collisions or shortening:

```python
from math import sin as math_sin
from audio import sin as audio_sin    # Different module, same name

x = math_sin(0.5)
freq = audio_sin(440)

# Shortening:
from very_long_module import some_function as sf
sf()
```

### Name Collision = Compile Error

```python
from math import sin
from audio import sin     # ERROR: 'sin' already imported from 'math'!

# Solution - use an alias:
from math import sin
from audio import sin as audio_sin   # OK
```

## Two Import Modes

### Static Import (Top-level)

Import at file beginning is **compile-time** linked:

```python
# File beginning - STATIC import
from math import sin, cos
from gfx import Sprite

def main():
    x = sin(0.5)             # Direct call, no runtime overhead
    s: Sprite
    s()
```

**Characteristics:**
- Module code is compiled into the PRG
- No runtime loading, no disk I/O
- Compiler checks types and parameters
- Tree-shaking: only used functions are included

### Dynamic Import (Function-level)

Import inside a function is **runtime** loaded:

```python
def game_screen():
    # DYNAMIC import - runtime loading
    from my_game_utils import sin, cos, update_pos
    from sprites import PlayerSprite

    init()
    player: PlayerSprite
    player()

    while not game_over:
        player.update()
        x = sin(angle)

    # ← Function end: modules AUTOMATICALLY freed!

def main():
    while True:
        choice = menu_screen()
        if choice == 1:
            game_screen()      # Module loads, then frees
        elif choice == 2:
            options_screen()   # Completely different modules can load
```

**Characteristics:**
- Module loads onto the stack
- Scope end = automatic memory release
- Multiple modules can use the same memory (sequentially)
- Unlimited program size possible (loaded in parts)

## Export Rules

### Python-style Convention

```python
# Simple rule:
# _prefix = private (NOT exported)
# No prefix = public (exported)
```

### Exporting Your Own Code

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

### Static Import and Export

Statically imported names are **automatically exported**, EXCEPT if they receive a `_` prefixed alias:

```python
# my_game_utils.pyco - custom "package" composition

# These will be PUBLIC (exported):
from math import sin, cos
from physics import update_pos
from gfx import draw_sprite

# This stays PRIVATE (not exported):
from internal import debug_helper as _debug

# Custom public function:
def rotate(x: int, y: int, angle: float) -> int:
    _debug("rotating...")      # Uses internally
    return int(x * cos(angle) - y * sin(angle))

# Custom private function:
def _internal_calc() -> int:
    ...
```

**Result - my_game_utils.pycom exports:**

| Name | Source | Exported? |
|------|--------|-----------|
| `sin` | math | ✓ Yes |
| `cos` | math | ✓ Yes |
| `update_pos` | physics | ✓ Yes |
| `draw_sprite` | gfx | ✓ Yes |
| `rotate` | own | ✓ Yes |
| `_debug` | internal (as _debug) | ✗ No |
| `_internal_calc` | own | ✗ No |

### Testing Private Import

```python
# main.pyco
from my_game_utils import sin, cos, rotate    # ✓ OK
from my_game_utils import _debug              # ✗ ERROR: '_debug' is private
```

## Custom Module Composition

### Concept

If you only need a few functions from large libraries, you can create your own module:

```
┌─────────────────────────────────────────────────────────┐
│ LARGE LIBRARIES:                                        │
│   math.pyco (20 functions)                              │
│   gfx.pyco (30 functions)                               │
│   physics.pyco (15 functions)                           │
└────────────────────┬────────────────────────────────────┘
                     │ static import (selection)
                     ▼
┌─────────────────────────────────────────────────────────┐
│ CUSTOM MODULE (only what you need + your own code):     │
│   my_game_utils.pyco:                                   │
│     from math import sin, cos      # 2 functions       │
│     from gfx import draw_sprite    # 1 function        │
│     def rotate(): ...              # own               │
│                                                         │
│   Compile: pycoc compile my_game_utils.pyco --module   │
│   Result: MY_GAME_UTILS.PYCOM (small size!)            │
└────────────────────┬────────────────────────────────────┘
                     │ dynamic import (runtime)
                     ▼
┌─────────────────────────────────────────────────────────┐
│ MAIN PROGRAM:                                           │
│   def game_screen():                                    │
│       from my_game_utils import sin, cos, rotate       │
│       ...                                               │
└─────────────────────────────────────────────────────────┘
```

### Benefits

- **Tree-shaking**: Only used functions are compiled in
- **Developer control**: You decide what belongs together
- **No new concept**: Module = module, just composed
- **Own code**: Mixed with imported ones

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

| Address Range | Content | Can module jump here? |
|---------------|---------|----------------------|
| `$0000-$00FF` | Zero Page | ❌ NEVER (data) |
| `$0100-$01FF` | Hardware Stack | ❌ NEVER (data) |
| `$0200-$02FF` | OS variables | ❌ NEVER |
| `$0300-$03FF` | Vectors, buffer | ❌ NEVER |
| `$0400-$07FF` | Screen RAM (default) | ❌ NEVER (data) |
| `$0800-$FFFF` | **Program area** | ✓ YES |

**Conclusion:** If an address has high byte `$00-$07`, it's **guaranteed to be a module-internal address** that needs relocation!

### Marker Range

```
High byte: $00-$07 = MARKER (needs relocation)
High byte: $08-$FF = FIXED address (HW register, external address)

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

### Relocation at Load Time

```asm
; Module loading to $C000
; base_page = $C0

relocate:
    LDY #0
.loop:
    LDA (module_ptr),Y      ; Read byte

    ; If this is an address high byte position AND < $08:
    CMP #$08
    BCS .no_reloc           ; >= 8: fixed address, leave it

    CLC
    ADC base_page           ; $00 + $C0 = $C0
                            ; $05 + $C0 = $C5
.no_reloc:
    STA (dest_ptr),Y
    INY
    ; ...
```

### Example

```
Module originally compiled for $0000:
────────────────────────────────────
$0000: JSR $0050     ; 20 50 00  → marker $00
$0003: LDA $0100     ; AD 00 01  → marker $01
$0006: STA $D400     ; 8D 00 D4  → fixed (SID register)
...
$0050: internal_func
$0100: singleton_data

Loaded to $C000:
────────────────────────────────────
$C000: JSR $C050     ; 20 50 C0  ✓
$C003: LDA $C100     ; AD 00 C1  ✓
$C006: STA $D400     ; 8D 00 D4  ✓ (unchanged!)
```

### Benefits

| Property | Value |
|----------|-------|
| Relocation table size | **0 bytes!** |
| Extra module overhead | **0 bytes!** |
| Loader complexity | Very simple |
| Max module internal size | 2KB (extendable with long jump) |

## Module File Format (.PYCOM)

### Structure

```
┌─────────────────────────────────────────────────────────┐
│ HEADER (compiler reads only - NOT loaded!)              │
├─────────────────────────────────────────────────────────┤
│ magic (5 bytes): "PYCOM"                                │
│ version (1 byte): 1                                     │
│ header_size (2 bytes): total header size                │
│ code_size (2 bytes): code+data size to load             │
│ entry_count (1 byte): number of entry points            │
│ symbol_count (2 bytes): number of symbols               │
├─────────────────────────────────────────────────────────┤
│ ENTRY TABLE (entry_count × 4 bytes)                     │
│   [0] offset (2 bytes) + name_idx (2 bytes)             │
│   [1] offset (2 bytes) + name_idx (2 bytes)             │
│   ...                                                   │
├─────────────────────────────────────────────────────────┤
│ SYMBOL TABLE (for compiler - type info, parameters)     │
│   For each exported function/class:                     │
│   - name (null-terminated)                              │
│   - type (function/class/singleton)                     │
│   - signature (mangled, parameter types)                │
│   - entry_index (which entry point)                     │
├─────────────────────────────────────────────────────────┤
│ (header end - compiler reads up to here)                │
╞═════════════════════════════════════════════════════════╡
│ CODE + DATA (this is loaded at runtime!)                │
├─────────────────────────────────────────────────────────┤
│ JUMP TABLE (entry_count × 3 bytes)                      │
│   JMP entry_0_code      ; $4C xx xx                     │
│   JMP entry_1_code      ; $4C xx xx                     │
│   ...                                                   │
├─────────────────────────────────────────────────────────┤
│ CODE                                                    │
│   entry_0_code: ...                                     │
│   entry_1_code: ...                                     │
│   internal_functions: ...                               │
├─────────────────────────────────────────────────────────┤
│ SINGLETON DATA (if any)                                 │
│   field1: .byte 0                                       │
│   field2: .word 0                                       │
│   ...                                                   │
└─────────────────────────────────────────────────────────┘
```

### Header and Code Separation

**Important:** The header contains type information, but it is **NOT loaded** to the C64!

1. **At compile time**: The compiler opens the `.pycom` file, reads the header:
   - Checks: does the imported name exist?
   - Checks: is it public? (no `_` prefix)
   - Checks: do parameter types match?
   - Notes: entry point index

2. **At runtime**: Only the CODE+DATA section is loaded:
   - Header is skipped (seek to code_offset)
   - Relocation based on marker-bytes
   - Jump table can be used

### Name Mangling

Functions appear in the symbol table with mangled names:

```
sin(angle: float) -> float
  → _F_sin_f_f    (Function, param: float, return: float)

set_volume(ch: byte, vol: byte)
  → _F_set_volume_bb  (params: byte, byte)

Player.update(self)
  → _M_Player_update  (Method of Player)
```

This enables type checking at compile time.

## Loading Mechanism

### Static Import (compile-time)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Compiler sees: from math import sin                  │
│                          ↓                              │
│ 2. Opens: math.pycom                                    │
│    - Reads the header                                   │
│    - Checks: is there a 'sin' symbol? ✓                 │
│    - Checks: is it public? ✓ (no _ prefix)              │
│    - Checks: parameters OK? ✓                           │
│    - Notes: sin = entry index 0                         │
│                          ↓                              │
│ 3. Reads CODE+DATA section                              │
│    - Inserts into PRG                                   │
│    - Compile-time relocation (known fixed address)      │
│                          ↓                              │
│ 4. Call: JSR sin_relocated_address                      │
└─────────────────────────────────────────────────────────┘
```

### Dynamic Import (runtime)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Code: from my_utils import sin, rotate               │
│                          ↓                              │
│ 2. Generated code at runtime:                           │
│    __R_module_load("MY_UTILS.PYCOM")                    │
│    - OPEN 8,8,8,"MY_UTILS.PYCOM,S,R"                    │
│    - Seek to code_offset (skip header)                  │
│    - READ code_size bytes → top of stack                │
│    - Relocation (marker-byte scan)                      │
│    - CLOSE                                              │
│    - SSP += code_size (stack pointer forward)           │
│                          ↓                              │
│ 3. module_base = old SSP value                          │
│    sin = module_base + 0  (entry 0)                     │
│    rotate = module_base + 3  (entry 1)                  │
│                          ↓                              │
│ 4. Calls: JSR (module_base + offset)                    │
│                          ↓                              │
│ 5. Scope end: SSP resets → module "disappears"          │
└─────────────────────────────────────────────────────────┘
```

## Scope-Based Memory Management

### PyCo Memory Model Consistency

| Concept | Storage | Release |
|---------|---------|---------|
| Local variable | Stack | Statement/scope end |
| Class instance | Stack | Scope end |
| Dynamic module | Stack | Import scope end |
| Singleton (in module) | Part of module | Module scope end |

**Everything works the same way!** Stack pointer reset "cleans" everything.

### Example: Game Screens

```python
def menu_screen():
    from menu_gfx import draw_menu, handle_input

    draw_menu()
    choice = handle_input()
    return choice
    # ← menu_gfx module FREED

def game_screen():
    from game_utils import init, update
    from music import play_ingame

    init()
    play_ingame()
    while not game_over:
        update()
    # ← game_utils and music module FREED

def main():
    while True:
        choice = menu_screen()     # Menu in memory
                                   # ← Menu freed
        if choice == 1:
            game_screen()          # Game in memory (full RAM!)
                                   # ← Game freed
```

**Every screen can use the full memory!** No fragmentation.

## Error Messages

### Compile-time Errors

```
main.pyco:3: Error: Unknown module 'maht'. Did you mean 'math'?
main.pyco:5: Error: Module 'math' has no export 'sn'. Did you mean 'sin'?
main.pyco:7: Error: Cannot import '_helper' from 'math': name is private
main.pyco:10: Error: 'sin' already imported from 'math'
main.pyco:15: Error: Type mismatch: sin expects float, got byte
```

### Runtime Errors

```
Runtime Error: Module 'MUSIC.PYCOM' not found on disk
Runtime Error: Out of memory loading module (need 1234 bytes, have 500)
Runtime Error: Module format error (invalid magic)
```

## Implementation Phases

### Phase 1: Module Generation
- [ ] `.pycom` header format generation
- [ ] Symbol table (public names only, `_` prefix filtering)
- [ ] Re-export handling (static import → export, except `as _name`)
- [ ] Code+data section with $0000 base
- [ ] Jump table generation
- [ ] `pycoc compile --module` flag

### Phase 2: Static Import
- [ ] Header reading at compile time
- [ ] Public name verification
- [ ] Type and parameter checking
- [ ] `as` alias support
- [ ] Name collision detection
- [ ] Code insertion and compile-time relocation
- [ ] Tree-shaking (only used entry points)

### Phase 3: Dynamic Import Basics
- [ ] Function-level import recognition
- [ ] Runtime loader assembly routine
- [ ] Marker-byte relocation implementation
- [ ] Stack loading and scope handling

### Phase 4: Runtime Loader
- [ ] Disk I/O (OPEN, READ, CLOSE)
- [ ] Header skipping (seek)
- [ ] Relocation scan
- [ ] Entry point address calculation

### Phase 5: Optimizations
- [ ] Module cache (if same module needed again)
- [ ] Loader code optimization

## Summary

### Import Rules

| Syntax | Meaning |
|--------|---------|
| `from X import a, b` | a and b can be used directly |
| `from X import a as my_a` | can be used as my_a |
| `a()` | Call without prefix |
| Name collision | Compile error → `as` required |

### Export Rules

| Name Format | Exported? |
|-------------|-----------|
| `name` | ✓ Yes (public) |
| `_name` | ✗ No (private) |
| `from X import foo` | ✓ Yes (re-export) |
| `from X import foo as _foo` | ✗ No (private alias) |

### Two Import Modes

| Property | Static Import | Dynamic Import |
|----------|---------------|----------------|
| Position | Top-level | Function-level |
| Timing | Compile-time | Runtime |
| Storage | In PRG | On stack |
| Lifetime | Program runtime | Scope end |
| Disk I/O | None (compiled in) | Yes (loading) |
| Relocation | Compile-time | Runtime (marker-byte) |

### Marker-byte System

| High Byte | Meaning |
|-----------|---------|
| `$00-$07` | Marker (needs relocation, module-internal address) |
| `$08-$FF` | Fixed address (HW register, external memory) |

---

*Version: 2.1 - 2026-01-13*
*Changes: Prefix-free usage, `as` alias, Python-style export rules*
