# PyCo Code Generator - Internal Implementation

This document contains the **internal implementation details** of the PyCo compiler's code generator component. It is intended for developers who want to modify or understand the compiler.

> **For users:** See the [Language Reference](../../language-reference/language_reference_en.md) for language features, and the [C64 Compiler Reference](c64_compiler_reference_en.md) for C64-specific details.

## 1. Overview

The code generator produces 6502 assembly code from the validated AST:

```
┌─────────┐    ┌──────────┐    ┌───────────┐    ┌────────────┐    ┌─────────┐
│ Parser  │ →  │ Include  │ →  │ Validator │ →  │ CodeGen    │ →  │ .asm    │
│         │    │ Resolver │    │           │    │            │    │ output  │
└─────────┘    └──────────┘    └───────────┘    └────────────┘    └─────────┘
```

### 1.1 Module structure

```
src/pyco/compiler/codegen/
├── __init__.py          # Public API: generate()
├── generator.py         # Main AST visitor, statements
├── expressions.py       # Expression code generation
├── emitter.py           # Assembly output builder
├── float_routines.py    # Float assembly helpers
└── fixed_routines.py    # f16/f32 assembly helpers
```

### 1.2 Generation phases

1. **Symbol Collection** - Gather constants, class layouts, function signatures
2. **Code Generation** - AST traversal, assembly generation, label management
3. **Output** - Insert runtime helpers, arrange segments

---

## 2. Memory and Zero Page

For C64 memory layout and Zero Page allocation details, see: [C64 Compiler Reference - 2. Memory Architecture](c64_compiler_reference_en.md#2-memory-architecture)

### 2.1 Type memory representation

#### Primitive types

| Type   | Size    | Representation                        |
| ------ | ------- | ------------------------------------- |
| bool   | 1 byte  | 0 = false, ≠0 = true                  |
| char   | 1 byte  | PETSCII code                          |
| byte   | 1 byte  | 0-255 unsigned                        |
| sbyte  | 1 byte  | -128 to 127 signed (two's complement) |
| word   | 2 bytes | Little-endian, 0-65535                |
| int    | 2 bytes | Little-endian, -32768 to 32767 signed |
| float  | 4 bytes | Microsoft Binary Format (MBF) 32-bit  |

#### String

Pascal-style string: first byte is length, followed by characters.

```
┌────────┬────────┬────────┬─────┬────────┐
│ length │ char 0 │ char 1 │ ... │ char N │
│ 1 byte │ 1 byte │ 1 byte │     │ 1 byte │
└────────┴────────┴────────┴─────┴────────┘
```

**Declaration and size:**

| Syntax                  | Allocated size  | Explanation                    |
| ----------------------- | --------------- | ------------------------------ |
| `s: string = "Hello"`   | 6 bytes         | From constant: 1 (len) + 5     |
| `s: string[80]`         | 81 bytes        | Explicit buffer size           |
| `s: string[80] = "Hi"`  | 81 bytes        | Buffer + initial value         |
| `s: string[40][0x0400]` | 0 bytes (mapped)| Memory-mapped at fixed address |

#### Array

Fixed-size, contiguous memory area. Index type is automatic:
- ≤256 elements: byte index (faster)
- >256 elements: word index

#### Class instance

Class instances store properties in declaration order:

```python
class Enemy:
    x: byte = 0
    y: byte = 0
    health: int = 100
```

In memory (5 bytes):
```
┌────────┬────────┬──────────────┐
│ x      │ y      │ health       │
│ 1 byte │ 1 byte │ 2 bytes (LE) │
│ off 0  │ off 1  │ off 2        │
└────────┴────────┴──────────────┘
```

---

## 3. Function calling convention

PyCo uses a **hybrid stack model**: primitive parameters on the 6502 hardware stack ($0100-$01FF), local variables on the software stack (SSP).

### 3.1 Stack architecture

```
Hardware Stack ($0100-$01FF):        Software Stack (SSP):
┌─────────────────────────────┐      ┌─────────────────────────────┐
│ [param N-1]                 │      │ Program (code + data + bss) │
│ [param N-2]                 │      ├─────────────────────────────┤ ← __program_end
│ ...                         │      │ [local 0]                   │ ← FP
│ [param 0]                   │      │ [local 1]                   │
│ [ret addr hi]               │      │ ...                         │
│ [ret addr lo]               │ ←SP  │ [local N]                   │ ← SSP
└─────────────────────────────┘      └─────────────────────────────┘
256 byte limit!                       Grows upward, no fixed limit
```

**Why hybrid?**
- HW Stack is faster (TSX + indexed) but limited to 256 bytes
- SSP is slower (16-bit pointer) but unlimited
- Primitive parameters fit in HW stack
- Local variables and large data go on SSP

**Initialization:**
```asm
.label __program_end = *
.label SSP = $0A
.label FP = $08

_pyco_init:
    // Disable BASIC ROM
    lda $01
    and #%11111110
    sta $01

    // Initialize Software Stack pointer
    lda #<__program_end
    sta SSP
    lda #>__program_end
    sta SSP+1

    jmp main
```

### 3.2 Calling sequence

**1. Caller:**
```asm
// Calling foo(10, 20)
    lda #20         // Parameters in REVERSE order (LIFO)
    pha             // param1 → HW stack
    lda #10
    pha             // param0 → HW stack
    jsr __F_foo
    // Return value: A (1 byte) or retval (2-4 bytes)
    pla             // Remove parameters
    pla
```

**2. Callee:**
```asm
__F_foo:
    // Prologue: save FP, allocate locals
    lda FP+1
    pha
    lda FP
    pha

    lda SSP          // FP = SSP
    sta FP
    lda SSP+1
    sta FP+1

    clc              // SSP += locals_size
    lda SSP
    adc #LOCALS_SIZE
    sta SSP
    bcc +
    inc SSP+1
+:
    // Parameter access: TSX + indexed
    tsx
    lda $0105,x      // param0 (offset = FP_saved(2) + ret_addr(2) + 1)
    lda $0106,x      // param1
    // ...

    // Local variable access: (FP),y
    ldy #0
    lda (FP),y       // local0
    ldy #1
    sta (FP),y       // local1
    // ...

    // Epilogue: free locals, restore FP
    sec
    lda SSP
    sbc #LOCALS_SIZE
    sta SSP
    bcs +
    dec SSP+1
+:
    pla
    sta FP
    pla
    sta FP+1
    rts
```

### 3.3 Parameter passing

| Category              | Parameter type            | Passing method        | Location            |
| --------------------- | ------------------------- | --------------------- | ------------------- |
| Primitive (1 byte)    | `byte`, `sbyte`, `char`   | By value (PHA)        | HW Stack            |
| Primitive (2 bytes)   | `word`, `int`             | By value (2×PHA)      | HW Stack            |
| Primitive (4 bytes)   | `float`                   | By value (4×PHA)      | HW Stack            |
| Composite (direct)    | `Enemy`, `array[byte,10]` | **COMPILE ERROR**     | -                   |
| Alias                 | `alias[Enemy]`            | Pointer (2 bytes)     | HW Stack            |

**Automatic address passing for alias parameters:**

```python
def process(e: alias[Enemy]):
    e.x = 50

def main():
    enemy: Enemy
    process(enemy)  # Compiler automatically: process(addr(enemy))
```

**HW Stack parameter access:**
```asm
// Leaf function (no FP save): offset = ret_addr(2) + 1
tsx
lda $0103,x      // param0

// Non-leaf function (FP saved): offset = FP(2) + ret_addr(2) + 1
tsx
lda $0105,x      // param0
```

### 3.4 Return value

| Category          | Return type    | Where is the value | Lifetime            |
| ----------------- | -------------- | ------------------ | ------------------- |
| Primitive (1 byte)| `byte`, `bool` | A register         | Immediately usable  |
| Primitive (2 byte)| `word`, `int`  | `retval` ($0F-$10) | Immediately usable  |
| Primitive (4 byte)| `float`        | `retval` ($0F-$12) | Immediately usable  |
| Alias             | `alias[Enemy]` | `retval` (pointer) | Until statement end!|

### 3.5 Caller Frame Allocation (methods)

For method calls, the **caller allocates the callee's full frame** (parameters + locals). This ensures that alias-returning calls (like `str()`) allocate AFTER the frame.

```asm
// Calling player.move(10, 5)
    // 1. Save caller's FP
    lda FP
    pha
    lda FP+1
    pha

    // 2. Save new frame base (FP still points to caller's frame during arg eval!)
    lda SSP
    pha
    lda SSP+1
    pha

    // 3. Allocate frame (params + locals)
    clc
    lda SSP
    adc #FRAME_SIZE
    sta SSP
    bcc +
    inc SSP+1
+:
    // 4. Write parameters to frame (peek frame base from HW stack)
    tsx
    lda $0102,x      // frame_base_lo
    sta tmp4
    lda $0101,x      // frame_base_hi
    sta tmp5
    lda #10          // param0
    ldy #0
    sta (tmp4),y
    lda #5           // param1
    iny
    sta (tmp4),y

    // 5. Set FP to new frame
    pla
    sta FP+1
    pla
    sta FP

    // 6. Load self pointer
    lda #<__B_player
    sta ZP_SELF
    lda #>__B_player
    sta ZP_SELF+1

    // 7. Method call
    jsr __C_Player_move

    // 8. Restore caller's FP + frame cleanup
    pla
    sta FP+1
    pla
    sta FP
    sec
    lda SSP
    sbc #FRAME_SIZE
    sta SSP
    bcs +
    dec SSP+1
+:
```

---

## 4. Methods and Self (ZP_SELF optimization)

### 4.1 Self as ZP-optimized pointer

The `self` pointer is loaded into **Zero Page cache ($16-$17 = ZP_SELF)** for fast property access.

```asm
// === CALL FROM MAIN: player.move(10, 5) ===
// 1. Load player address to ZP_SELF
lda #<__B_player
sta ZP_SELF
lda #>__B_player
sta ZP_SELF+1

// 2. Push explicit parameters
// ...

// 3. Method call
jsr __C_Player_move
// COST: ~12 cycles (ZP load)

// === OWN METHOD CALL: self.update() ===
// self is already in ZP_SELF!
jsr __C_Player_update
// COST: 0 extra cycles!
```

### 4.2 Property access from method

```python
self.health += 10
```

**Assembly (ZP-optimized):**
```asm
// self.health read and modify (offset 2, word)
ldy #2
lda (ZP_SELF),y      // health low - ZP indirect!
clc
adc #10
pha
iny
lda (ZP_SELF),y      // health high
adc #0
tax

// self.health write
ldy #2
pla
sta (ZP_SELF),y      // health low
iny
txa
sta (ZP_SELF),y      // health high
```

### 4.3 Calling another object's method (ZP save/restore)

```python
def process_bullet(self, bullet: Bullet):
    bullet.update()      # Nested call - different object!
    self.score += 10     # self must be restored
```

```asm
__C_Player_process_bullet:
    // === NESTED CALL - DIFFERENT OBJECT ===
    // 1. Save ZP_SELF to stack
    lda ZP_SELF
    pha
    lda ZP_SELF+1
    pha

    // 2. Load new self (bullet pointer)
    // ... bullet pointer load ...

    // 3. Method call
    jsr __C_Bullet_update

    // 4. Restore original ZP_SELF
    pla
    sta ZP_SELF+1
    pla
    sta ZP_SELF

    // === Now self is Player object again ===
    // self.score += 10
    ldy #SCORE_OFFSET
    lda (ZP_SELF),y
    // ...
```

### 4.4 Performance summary

| Case                       | ZP_SELF operation      | Cost          |
| -------------------------- | ---------------------- | ------------- |
| `player.move()`            | Load to ZP             | ~12 cycles    |
| `self.update()`            | **NONE**               | **0 cycles!** |
| `other.update()`           | Save + Load + Restore  | ~30 cycles    |
| Property access (`self.x`) | **NONE** (ZP in use!)  | ~7 cycles     |

---

## 5. Deferred Cleanup ("Poor Man's GC")

### 5.1 The problem

Returning composite types from functions is problematic:

```python
def create_enemy() -> alias[Enemy]:
    e: Enemy
    e()
    e.x = 50
    return e    # e is on the stack frame!

def main():
    enemy: Enemy = create_enemy()  # Where does it copy to?
```

After `return e`, the function's stack frame is freed, but the `e` pointer still points there → **dangling pointer**!

### 5.2 Solution: Deferred Cleanup

**Key idea:** Don't clean up immediately! Let the "garbage" remain on the stack until statement end.

```
Normal return:              Deferred cleanup:

[caller][called][SSP]       [caller][called][SSP]
         ↓                           ↓
[caller][SSP]               [caller][called_"garbage"][SSP] ← stays!
    (immediate cleanup)              ↓
                            At statement end:
                            [caller][SSP] ← NOW cleanup!
```

### 5.3 Rules

1. **Primitive type return** (`byte`, `int`, `bool`, etc.):
   - Normal stack cleanup at function end
   - Value in A register (1 byte) or retval (2-4 bytes)

2. **Alias return** (`alias[Enemy]`, `alias[array[byte,10]]`, etc.):
   - **DON'T** decrease SSP at function end!
   - Locals (including return value) remain on stack
   - `retval` pointer points to them

3. **Statement wrapper:**
   - Statement start: Save SSP to **hardware stack (PHA)**
   - Statement end: Restore SSP from **hardware stack (PLA)**
   - Alias lifetime is exactly until statement end!

### 5.4 Implementation

#### Function return generation

**File:** `src/pyco/compiler/codegen/generator.py` - `_gen_return()` method

```python
def _is_alias_return(self) -> bool:
    """Check if current function returns an alias type."""
    if self.current_function:
        func_sig = self.symbols.get_function(self.current_function)
        if func_sig and func_sig.return_type:
            return func_sig.return_type.startswith("alias[")
    return False
```

**Generated assembly for alias return:**

```asm
// [test_alias.pyco:9] return e
    // Alias return: get address of value
    clc
    lda FP
    adc #0           // e offset
    sta tmp0
    lda FP+1
    adc #0
    sta tmp1
    lda tmp0
    sta retval
    lda tmp1
    sta retval+1
    // Alias return: skip SSP cleanup, only restore FP
    pla
    sta FP
    pla
    sta FP+1
    rts
```

#### Statement wrapper

**File:** `src/pyco/compiler/codegen/generator.py` - `_generate_statement()` method

```python
def _needs_deferred_cleanup(self, node: ast.stmt) -> bool:
    """Check if statement needs SSP save/restore for deferred cleanup."""
    for child in ast.walk(node):
        if isinstance(child, ast.Call):
            # Check if function returns alias type
            # ...
    return False
```

**Generated assembly:**

```asm
    // Deferred cleanup: save SSP
    lda SSP
    pha
    lda SSP+1
    pha

// [test_alias.pyco:13] enemy: Enemy = create_enemy()
    jsr __F_create_enemy
    // Alias return: pointer in retval
    lda retval
    sta tmp0
    lda retval+1
    sta tmp1
    // Copy Enemy object
    // ...

    // Deferred cleanup: restore SSP
    pla
    sta SSP+1
    pla
    sta SSP
```

### 5.5 Nested calls

```python
process(create_enemy(), create_item())
```

```
State                                SSP         Hardware Stack
──────────────────────────────────────────────────────────────────
Statement start                      X           [SSP_hi][SSP_lo]
After create_enemy() call            X + frame   [SSP_hi][SSP_lo]
After create_item() call             X + frame2  [SSP_hi][SSP_lo]
After process() call                 X + ...     [SSP_hi][SSP_lo]
Statement end                        X           (restored!)
```

**Why hardware stack?** ZP registers are used by for loops, and nested calls would overwrite them. The hardware stack's LIFO nature naturally handles nested calls.

### 5.6 Trade-offs

**Advantages:**
- Simple implementation - no complex lifetime tracking
- No "return buffer" pre-allocation
- Universal solution - string, array, object all work the same
- Zero-copy possibility - if used immediately
- Hardware stack LIFO - naturally handles nested calls

**Disadvantages:**
- Stack waste (but only until statement end!)
- Deep chains consume lots of stack: `a(b(c(d(e()))))`
- Hardware stack limit: 256 bytes (~40-60 nested levels)
- +12 cycles overhead per statement requiring cleanup

---

## 6. Alias type implementation

`alias[T]` is a typed dynamic reference (2-byte pointer).

### 6.1 addr() function

```asm
// addr(enemy) - for stack variable
clc
lda FP
adc #ENEMY_OFFSET
sta tmp0
lda FP+1
adc #0
sta tmp1

// addr(enemy) - for BSS variable
lda #<__B_enemy
sta tmp0
lda #>__B_enemy
sta tmp1
```

### 6.2 alias() function

```asm
// alias(e, addr(enemy))
lda tmp0
ldy #0
sta (FP),y        // alias low byte
lda tmp1
iny
sta (FP),y        // alias high byte
```

### 6.3 Property access through alias

```asm
// e.x read (where e is alias[Enemy])
ldy #ALIAS_OFFSET
lda (FP),y        // Pointer low byte → tmp0
sta tmp0
iny
lda (FP),y        // Pointer high byte → tmp1
sta tmp1
ldy #OFFSET_X     // x property offset
lda (tmp0),y      // Indirect indexed load
```

### 6.4 Performance

| Operation              | Cycles (approx) | Note                      |
| ---------------------- | --------------- | ------------------------- |
| Memory-mapped access   | 4-6             | Direct address, fastest   |
| Alias access           | 12-16           | Pointer load + indirect   |
| Local variable access  | 8-10            | Frame pointer + indirect  |

---

## 7. Runtime Helpers

### 7.1 Selective Runtime Linking

The PyCo compiler only includes runtime helpers that the program **actually uses**.

**Implementation:**

```python
# In generator.py
class CodeGenerator:
    used_helpers: set[str] = set()

    def use_helper(self, name: str):
        self.used_helpers.add(name)

    def emit_runtime_helpers(self):
        for helper in self.used_helpers:
            self.emitter.emit(RUNTIME_CODE[helper])
```

**Examples:**

| Program uses           | Included helpers  |
| ---------------------- | ----------------- |
| `print("Hello")`       | `__R_print_str`   |
| `print(x)` where x:int | `__R_print_int`   |
| `a * b` where int      | `__R_mul16`       |
| `str(x)` where x:byte  | `__R_str_byte`    |
| nothing special        | **NONE**          |

### 7.2 Helper list

| Routine          | Function                      | When needed       |
| ---------------- | ----------------------------- | ----------------- |
| `__R_mul8`       | 8-bit multiplication          | `byte * byte`     |
| `__R_mul16`      | 16-bit multiplication         | `int * int`       |
| `__R_div8`       | 8-bit division                | `byte / byte`     |
| `__R_div16`      | 16-bit division               | `int / int`       |
| `__R_print_byte` | Print byte as decimal         | `print(byte_var)` |
| `__R_print_int`  | Print int as decimal          | `print(int_var)`  |
| `__R_print_str`  | Print string (Pascal format)  | `print(str_var)`  |
| `__R_strcpy`     | String copy                   | `s1 = s2`         |
| `__R_memcpy`     | Memory copy                   | array/object copy |
| `__R_str_byte`   | Byte → string conversion      | `str(byte_var)`   |
| `__R_str_int`    | Int → string conversion       | `str(int_var)`    |
| `__R_str_bool`   | Bool → string conversion      | `str(bool_var)`   |
| `__R_str_float`  | Float → string conversion     | `str(float_var)`  |

---

## 8. str() and __str__ implementation

### 8.1 Compilation logic

1. **Primitive types** → `__R_str_*` runtime helper call
2. **Objects with `__str__` method** → `__C_ClassName___str__` call
3. **Objects without `__str__`** → constant string: `"<ClassName>"`

### 8.2 Generated code example

```python
class Player:
    name: string[20] = "Hero"
    score: int = 0

    def __str__() -> string:
        result: string[40]
        sprint(result, self.name, ": ", self.score)
        return result
```

```asm
// str(player) call → __C_Player___str__
    // 1. Load self pointer to ZP_SELF
    lda #<__B_player
    sta ZP_SELF
    lda #>__B_player
    sta ZP_SELF+1

    // 2. Method call
    jsr __C_Player___str__

    // 3. retval now contains string pointer
```

**Class without `__str__`:**

```asm
// str(enemy) → constant string
    lda #<__S_Enemy_typename
    sta retval
    lda #>__S_Enemy_typename
    sta retval+1

// Data segment:
__S_Enemy_typename:
    .byte 7
    .text "<Enemy>"
```

---

## 9. Optimization possibilities

### 9.1 Implemented optimizations

See: [C64 Compiler Reference - Optimizations](c64_compiler_reference_en.md)

### 9.2 Planned decorators (not implemented)

```python
@fastcall                    # ZP parameters - nested calls FORBIDDEN
def critical_inner_loop(x: byte, y: byte):
    ...

@inline                      # Inline function at call site
def tiny_helper() -> byte:
    ...
```

---

## 10. Complete compilation example

### Input (test.pyco)

```python
BORDER = 0xD020

class Counter:
    value: byte = 0

    def increment():
        self.value += 1

def main():
    border: byte[BORDER] = 0
    c: Counter
    c()
    i: byte

    for i in range(0, 10):
        c.increment()

    border = c.value
```

### Output (test.asm)

```asm
// Generated by PyCo Compiler
// Target: C64 / 6502

// === CONSTANTS ===
.const BORDER = $D020

// === ZERO PAGE ===
.label tmp0 = $02
.label FP = $08
.label SSP = $0A
.label retval = $0F
.label ZP_SELF = $16

// === BASIC UPSTART ===
BasicUpstart2(__F_main)

// === CODE SEGMENT ===

__C_Counter___init__:
    // self pointer already in ZP_SELF
    lda #0
    ldy #0
    sta (ZP_SELF),y   // value = 0
    rts

__C_Counter_increment:
    // self pointer already in ZP_SELF
    ldy #0
    lda (ZP_SELF),y   // self.value
    clc
    adc #1
    sta (ZP_SELF),y
    rts

__F_main:
    // Runtime init
    lda #<__program_end
    sta SSP
    lda #>__program_end
    sta SSP+1

    // border = 0
    lda #0
    sta BORDER

    // c: Counter - stack allocation
    // c() - constructor
    clc
    lda FP
    adc #0            // c offset
    sta ZP_SELF
    lda FP+1
    adc #0
    sta ZP_SELF+1
    jsr __C_Counter___init__

    // for i in range(0, 10):
    lda #0
    ldy #1            // i offset
    sta (FP),y
!loop:
    ldy #1
    lda (FP),y
    cmp #10
    bcs !end+

    // c.increment() - self already in ZP_SELF!
    jsr __C_Counter_increment

    // i++
    ldy #1
    lda (FP),y
    clc
    adc #1
    sta (FP),y
    jmp !loop-
!end:

    // border = c.value
    ldy #0
    lda (ZP_SELF),y   // c.value
    sta BORDER

    rts

__program_end:
```
