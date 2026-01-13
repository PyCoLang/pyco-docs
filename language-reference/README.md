# PyCo Quick Reference

> Full documentation: [language_reference_en.md](language_reference_en.md)

## Types

| Type   | Size   | Range               | Description           |
| ------ | ------ | ------------------- | --------------------- |
| bool   | 1 byte | True/False          | 0 = False, else True  |
| char   | 1 byte | 0..255              | Single character      |
| byte   | 1 byte | 0..255              | Unsigned 8-bit        |
| sbyte  | 1 byte | -128..127           | Signed 8-bit          |
| word   | 2 byte | 0..65535            | Unsigned 16-bit       |
| int    | 2 byte | -32768..32767       | Signed 16-bit         |
| float  | 4 byte | ±10^38              | 32-bit MBF float      |
| f16    | 2 byte | -128.0..+127.996    | Fixed-point 8.8       |
| f32    | 4 byte | -32768.0..+32767.99 | Fixed-point 16.16     |

### Composite Types

```python
string[capacity]              # Pascal-style string (max 255 chars)
array[element_type, size]     # Fixed-size array
tuple[element_type]           # Read-only data (data segment)
alias[type]                   # Typed reference (pointer)
irq_safe[type[addr]]          # Atomic access (IRQ protection)
```

## Include and Import

### Include (constants/definitions)

```python
include("hardware")           # Textually inserts file content
```

### Import (compiled modules)

```python
from module_name import name1, name2      # Import specific names
from module_name import name as alias     # Import with alias
```

**Two import modes:**

| Location      | Mode    | Loaded      | Memory                    |
| ------------- | ------- | ----------- | ------------------------- |
| Top-level     | Static  | Compile-time| Part of program           |
| Inside function| Dynamic | Runtime     | Freed when scope ends     |

```python
# Static import (top-level)
from math import sin, cos

def game_screen():
    # Dynamic import (inside function)
    from music import play
    play()
    # ← module freed here!
```

## Syntax Basics

### Constants (module level only)

```python
BORDER = 0xD020
MAX_ENEMIES = 8
VIC = 0xD000
SPRITE_BASE = VIC + 0x100
```

### Variables (function start only)

```python
def example():
    x: int = 0                      # With default
    name: string[20] = "Player"     # String with capacity
    scores: array[byte, 10]         # Array (no default)
    buffer: array[byte, 100] = [0]  # Array filled with zeros
    data: array[byte, 5] = (1,2,3)  # Array with tuple init
```

### Memory-mapped Variables

```python
border: byte[0xD020]                    # Single value at address
screen: array[byte, 1000][0x0400]       # Array at address
counter: irq_safe[word[0x0080]]         # Atomic multi-byte access
```

## Tuples (read-only data)

```python
# Constant data - stored in data segment
colors: tuple[byte] = (0, 2, 5, 7, 10, 14)
x: byte = colors[2]              # Reading OK

# Pointer variable - can be reassigned
ptr: tuple[byte]                 # Uninitialized (pointer)
ptr = colors                     # Assign to data
print(len(ptr))                  # 6

# Copy tuple to array
buffer: array[byte, 10]
buffer = colors                  # Fast memcpy
buffer[0] = 99                   # Now modifiable
```

## Operators

| Arithmetic      | Comparison        | Logical      | Bitwise          |
| --------------- | ----------------- | ------------ | ---------------- |
| `+` `-` `*` `/` | `==` `!=`         | `and` `or`   | `&` `\|` `^` `~` |
| `%` `**`        | `<` `>` `<=` `>=` | `not`        | `<<` `>>`        |

Assignment: `=` `+=` `-=` `*=` `/=` `%=` `&=` `|=` `^=` `<<=` `>>=`

## Control Structures

```python
# Conditionals
if condition:
    pass
elif condition2:
    pass
else:
    pass

# While loop
while condition:
    break       # Exit loop
    continue    # Next iteration

# For loop
for i in range(10):           # 0..9
for i in range(5, 10):        # 5..9
for i in range(0, 10, 2):     # 0, 2, 4, 6, 8
for i in range(10, 0, -1):    # 10, 9, 8, ..., 1
for _ in range(10):           # Throwaway counter (optimized)
```

## Functions

```python
def add(a: int, b: int) -> int:
    return a + b

def no_return(x: byte):
    pass  # No return type = no return statement

# Forward declaration (for mutual recursion)
@forward
def func_a(n: int) -> int: ...

def func_b(n: int) -> int:
    return func_a(n - 1)

def func_a(n: int) -> int:
    return func_b(n - 1)
```

### Decorators

| Decorator        | Effect                                             |
| ---------------- | -------------------------------------------------- |
| `@forward`       | Forward declaration for mutual recursion           |
| `@lowercase`     | Lowercase character mode (main only, C64)          |
| `@kernal`        | Keep Kernal ROM enabled (main only, C64)           |
| `@noreturn`      | Skip cleanup - program never exits                 |
| `@irq`           | IRQ handler (chains to system IRQ)                 |
| `@irq_raw`       | Raw IRQ handler (direct RTI)                       |
| `@irq_hook`      | Lightweight Kernal IRQ hook                        |
| `@naked`         | IRQ-callable function (no overhead)                |
| `@mapped(addr)`  | Call code at fixed address                         |

```python
@mapped(0x1000)
def music_init(song: byte): ...

@irq
def raster_handler():
    pass
```

## Classes

```python
class Position:
    x: int = 0
    y: int = 0

class Player(Position):           # Single inheritance
    score: int = 0

    def __init__(start_x: int):   # No self in params!
        self.x = start_x          # self required in body

    def move(dx: int):
        self.x += dx

    def __str__() -> string:      # String representation
        result: string[20]
        sprint(result, self.x)
        return result

# Usage
def main():
    p: Player = Player()          # No-arg constructor inline
    enemy: Player                 # Declaration
    enemy = Player(100)           # Parameterized constructor separate
```

### Singletons and Method Override

```python
@singleton
class Game:
    score: int = 0

# Usage: Game.score += 100  (no instance needed)

class Dog(Animal):
    def speak():
        print("Woof! ")
        super.speak()             # Call parent method
```

## Alias (References)

```python
def example():
    enemy: Enemy = Enemy()
    e: alias[Enemy]

    alias(e, addr(enemy))         # Point to enemy
    e.x = 100                     # Modifies enemy.x

# Pass composite types as alias (required!)
def process(e: alias[Enemy]):
    e.x = 50

def main():
    enemy: Enemy = Enemy()
    process(enemy)                # Auto-converted to alias
```

## Built-in Functions

| Function               | Description                                               |
| ---------------------- | --------------------------------------------------------- |
| `print(a, b, ...)`     | Output (no auto newline/space!)                           |
| `printsep(sep, ...)`   | Output with separator                                     |
| `sprint(buf, ...)`     | Write to string buffer                                    |
| `str(value)`           | Convert to string                                         |
| `len(s)`               | String/array/tuple length                                 |
| `size(x)`              | Memory size in bytes                                      |
| `getkey()`             | Non-blocking key read (0 if none)                         |
| `waitkey()`            | Blocking key read                                         |
| `abs(x)`               | Absolute value                                            |
| `min(a, b)`            | Smaller value                                             |
| `max(a, b)`            | Larger value                                              |
| `addr(x)`              | Memory address of variable, property, element, or function|
| `alias(ref, address)`  | Set alias to point to address                             |
| `memfill(dest, value)` | Fill memory with byte value                               |
| `blkcpy(dest, src, n)` | Copy n bytes from src to dest                             |

## Type Conversions

```python
result = word(a) + word(b)    # Prevent overflow
i = int(f)                    # Truncate float
flag = bool(value)            # Full value check
x = f16(5)                    # Fixed-point 8.8
y = f32(3.14)                 # Fixed-point 16.16
```

## Key Differences from Python

| Python                       | PyCo                              |
| ---------------------------- | --------------------------------- |
| `x = 10`                     | `x: int = 10` (type required)     |
| Variables anywhere           | Variables at function start       |
| `def method(self, x):`       | `def method(x: int):` (no self)   |
| `obj2 = obj1` (same ref)     | `obj2 = obj1` (copy!)             |
| `print("Hi")` → `Hi\n`       | `print("Hi")` → `Hi` (no newline) |
| `print(a, b)` → `a b`        | `print(a, b)` → `ab` (no space)   |
| `import X`                   | `from X import a, b`              |
| Dynamic lists/dicts          | Fixed arrays only                 |
| Garbage collection           | Stack-based (automatic)           |

## Example Program

```python
from sys import clear_screen

SCREEN = 0x0400
MAX_SCORE = 1000

class Player:
    x: int = 0
    score: int = 0

    def add_score(points: int) -> bool:
        self.score += points
        return self.score >= MAX_SCORE

def main():
    p: Player = Player()
    i: byte

    clear_screen()
    for i in range(10):
        if p.add_score(100):
            print("Winner!\n")
            break
```
