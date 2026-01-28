# PyCo Language Reference

PyCo is a **Python-like language** for low-level programming that combines the strengths of several languages with its own innovative solutions.

## 1. Introduction

### What is PyCo?

**Inspiration:**
- **Python:** readable syntax, indentation-based blocks, classes
- **Pascal:** strict typing, pre-declared variables, Pascal-style strings
- **C:** low-level memory management, bit operations, machine-level approach

**Own solutions:**
- **Memory-mapped variables:** direct typed access to hardware registers (`var: byte[0xD020]`)
- **Alias type:** dynamic, typed references with runtime address assignment
- **Implicit self:** no need to write `self` parameter in methods

**Characteristics:**
- Fast and memory efficient
- Simple, easy to learn
- Platform-independent language, compilable with different backends
- Modular: only used functions are loaded

**Target platforms:** 8/16/32-bit systems, microcontrollers - the specific platform depends on the compiler backend, not the language.
The first reference implementation was made for the C64.

### Language Restrictions

| Restriction                           | Reason                                  |
| ------------------------------------- | --------------------------------------- |
| No global variables                   | Only UPPERCASE constants at module level |
| Variables at function start           | Pascal-style, simpler memory management |
| Single-threaded execution             | Simplicity, easier to learn             |
| No dynamic memory management          | But available from library              |
| Functions/classes only at module level | No nesting                             |
| Import and include only at module level | Simpler compilation                   |
| Definition order required             | Single-pass compilation, simpler compiler |

### Example Program

```python
# This is a comment
from sys import clear_screen

class Position:
    # All properties must be declared
    x: int = 0
    y: int = 0

class Hero(Position):
    score: int = 0

    def move_right(inc: int):      # self is NOT needed!
        self.score += inc          # But in the body it is

def main():
    # Variables must be declared at the beginning
    hero: Hero
    i: int

    hero()                         # Initialize the object
    print("Hello world\n")
```

---

## 2. Basics

### 2.1 Names and Identifiers

Names can only contain lowercase and uppercase letters, numbers, and underscores, but cannot start with a number. The language is case-sensitive.

**Reserved names:** Names with `__` (double underscore) prefix are reserved for the system. User code cannot define functions, methods, or variables with such names. Exceptions are documented special methods:
- `__init__` - constructor
- `__str__` - string representation

#### Recommended Naming Conventions

| Element  | Convention      | Example                      |
| -------- | --------------- | ---------------------------- |
| Class    | PascalCase      | `MyClass`, `PlayerSprite`    |
| Function | snake_case      | `my_function`, `get_score`   |
| Variable | snake_case      | `my_variable`, `player_x`    |
| Constant | SCREAMING_SNAKE | `MAX_ENEMIES`, `SCREEN_ADDR` |

### 2.2 Comments

Comments are notes written for the programmer that the compiler ignores. Their purpose is to explain and document code, or temporarily disable code sections.

#### Single-line Comments

Everything from the `#` character to the end of the line is considered a comment:

```python
def example():
    # This is a full line comment
    x: int = 42  # This is an end-of-line comment
```

#### Docstrings

PyCo supports **docstrings** using triple-quoted strings (`"""..."""`) for documenting functions, methods, and classes. Docstrings must be the first statement in the function/method/class body:

```python
def calculate_score(hits: byte, multiplier: byte) -> word:
    """
    Calculate the player's score based on hits and multiplier.
    Returns the calculated score as a word value.
    """
    result: word
    result = word(hits) * word(multiplier) * 10
    return result

class Player:
    """
    Represents a player in the game.
    Handles position, health, and score tracking.
    """
    x: byte = 0
    y: byte = 0
    health: byte = 100

    def take_damage(amount: byte):
        """Reduce player health by the specified amount."""
        if self.health > amount:
            self.health = self.health - amount
        else:
            self.health = 0
```

**Important:** Docstrings are ignored by the compiler - they generate no code and use no memory. They exist purely for documentation purposes.

> **Note:** Only triple double-quotes (`"""`) are supported, not single quotes (`'''`).

### 2.3 Blocks and Indentation

Statements ending with a colon (`:`) open a new block. The block content must be marked with **4 spaces** indentation:

```python
def example():
    x: int = 10

    if x > 0:
        print("positive\n")
        x = x - 1
```

The block continues as long as the indentation is maintained. Empty blocks are marked with the `pass` keyword:

```python
def later():
    pass
```

### 2.4 Multi-line Statements

Long statements can be broken into multiple lines with `\` character at the end of the line:

```python
def example():
    result: int

    result = very_long_function_name(param1, param2) \
        + another_function(param3)
```

**Rules:**
- Nothing can follow `\` (not even comments), only newline
- Line breaks inside strings are not allowed
- Adjacent string literals are automatically concatenated:

```python
def example():
    s: string = "first line\n" \
        "second line\n" \
        "third line"
```

This string concatenation happens at compile time, there is no runtime cost.

### 2.5 Include

File text insertion is done with the `include()` function. This is a preprocessor operation: the compiler reads the content of the specified file and inserts it at the call location.

```python
include("hardware")
include("constants")
```

**What to use it for:**
- Sharing constants between multiple files
- Hardware definitions (memory addresses, registers)
- Common configurations

**Example:**

```python
# hardware.pyco
VIC = 0xD000
BORDER = VIC + 0x20
BACKGROUND = VIC + 0x21
```

```python
# game.pyco
include("hardware")

def main():
    border: byte[BORDER]
    border = 0
```

> **IMPORTANT:** `include()` does not load a compiled module, it only textually copies the file content. It's for sharing constants and definitions.

### 2.6 Import

The `import` statement loads functions and classes from compiled modules. In PyCo, the location of the import determines the loading mode.

**Syntax:**

```python
from module_name import name1, name2, name3
from module_name import name as alias
```

**Basic rules:**

- **Explicit listing required**: All used names must be explicitly listed
- **No wildcard**: `from X import *` is NOT supported
- **No prefix needed**: Imported names can be used directly

#### Two Import Modes

The location of the import determines how the module is loaded:

| Import Location         | Mode    | When Loaded   | Lifetime         |
| ----------------------- | ------- | ------------- | ---------------- |
| File beginning (top-level) | Static  | Compile-time  | Program lifetime |
| Inside function         | Dynamic | Runtime       | Scope end        |

**Static import (top-level):**

```python
# At file beginning - STATICALLY compiled into the program
from math import sin, cos

def main():
    x: float = sin(0.5)    # Can be used directly
    y: float = cos(0.5)
```

Benefits of static import:
- No runtime loading
- Compiler checks types
- Tree-shaking: only used functions are included in the program

**Dynamic import (inside function):**

```python
def game_screen():
    # Inside function - DYNAMICALLY loaded at runtime
    from game_utils import update, draw
    from music import play

    play()
    while not game_over:
        update()
        draw()
    # ← Function end: module memory is FREED!
```

Benefits of dynamic import:
- Memory efficient: only what's needed is in memory
- Scope = Lifetime: automatic cleanup
- Unlimited program size through partial loading

> **Note:** Dynamic import is a platform-specific feature. It may not be available or practical on all platforms - for example, on microcontrollers without storage (disk, SD card), dynamic loading is not possible. In such cases, only static import can be used.

#### Alias (`as`) Support

Used for name collisions or shortening:

```python
from math import sin as math_sin
from audio import sin as audio_sin

x: float = math_sin(0.5)
freq: float = audio_sin(440.0)
```

**Name collision = compile error:**

```python
from math import sin
from audio import sin     # ERROR: 'sin' already imported from 'math'!

# Solution - use an alias:
from math import sin
from audio import sin as audio_sin   # OK
```

#### Export Rules

Modules follow Python-style export rules:

| Name Format                    | Exported?                |
| ------------------------------ | ------------------------ |
| `name`                         | ✓ Yes (public)           |
| `_name`                        | ✗ No (private)           |
| `from X import foo`            | ✓ Yes (re-export)        |
| `from X import foo as _foo`    | ✗ No (private alias)     |

```python
# math.pyco module
def sin(x: float) -> float:     # ✓ Exported (public)
    return _sin_impl(x)

def _sin_impl(x: float) -> float:   # ✗ NOT exported (private)
    ...
```

#### Global Tuple Import

Module global tuples can be imported, similar to functions and classes:

```python
# screen.pyco module - global tuple definition
row_offsets: tuple[word] = (0, 40, 80, 120, 160, 200, 240, 280, 320, 360)
sprite_masks: tuple[byte] = (0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01)
```

**Static tuple import:**

```python
from screen import row_offsets

def main():
    y: byte = 5
    offset: word = row_offsets[y]  # Direct access
    print(offset)  # 200
```

**Dynamic tuple import:**

```python
import screen

def main():
    load_module(screen)
    offset: word = screen.row_offsets[5]  # With namespace
    print(offset)  # 200
```

**Tuple export rules:**

| Tuple Name      | Exported? |
| --------------- | --------- |
| `row_offsets`   | ✓ Yes     |
| `_internal_buf` | ✗ No      |

Benefits of tuple import:
- **Tree-shaking**: Only used tuples are compiled in
- **Shareable data**: Lookup tables, sprite data, character sets
- **Ideal for education**: Built-in data that can be learned gradually

#### Custom Module Composition

You can compose your own module from multiple libraries:

```python
# my_game_utils.pyco - custom module
from math import sin, cos           # Statically included
from physics import update_pos
from gfx import draw_sprite

def rotate(x: int, y: int, angle: float) -> int:
    return int(x * cos(angle) - y * sin(angle))
```

In the main program, you can load it dynamically:

```python
def game_screen():
    from my_game_utils import sin, cos, rotate, draw_sprite
    # Everything in one module, one load
```

#### Namespace Import with `load_module()`

For explicit control over module loading, use the `import` statement with `load_module()`:

```python
import screen  # Register module (no code loaded yet!)

@lowercase
def main():
    load_module(screen)  # Load module from disk at runtime

    screen.Screen()                        # Initialize singleton
    screen.Screen.clear(' ', 0, 1)         # Call singleton method
    screen.print_at(10, 10, "Hello!", 1)   # Call module function
```

**How it works:**

| Statement | What happens |
|-----------|--------------|
| `import X` | Reads type info from `.pmi` file, allocates BSS pointer |
| `load_module(X)` | Loads `.pm` file from disk, relocates to SSP |
| `X.func()` | Calls function through module's jump table |
| `X.Class()` | Initializes singleton from module |
| `X.Class.method()` | Calls method on singleton |

**Alias support:**

```python
import screen as scr

def main():
    load_module(scr)
    scr.Screen()
    scr.Screen.clear(' ', 0, 1)
```

#### Dynamic Import Limitations

> **IMPORTANT:** Dynamic imports have restrictions compared to static imports!

| Feature | Static (`from X import`) | Dynamic (`import X`) |
|---------|--------------------------|----------------------|
| Module-level functions | ✅ Full support | ✅ Full support |
| Global tuples | ✅ Full support | ✅ Full support |
| Singleton classes | ✅ Auto-init defaults | ⚠️ Requires explicit `X.Class()` |
| Regular classes | ✅ Full support | ✅ Full support |
| Property defaults | ✅ Automatic | ⚠️ Only via `__init__` |

**Why these limitations?**

- Dynamic modules are loaded at **runtime**, not compile-time
- The compiler only has type information (`.pmi`), not default values
- Regular class instances need stack allocation which requires compile-time knowledge

**Best practice for dynamic modules:**

```python
# In your module - always use __init__ for singletons!
@singleton
class Config:
    value: byte

    def __init__():
        self.value = 42  # Set defaults here, not in declaration!
```

#### Include vs Import Comparison

| Keyword                | What it does                     | When to use                            |
| ---------------------- | -------------------------------- | -------------------------------------- |
| `include("name")`      | Textually inserts the file       | Sharing constants, definitions         |
| `from X import a, b`   | Loads from compiled module       | Using functions, classes               |

### 2.7 Constants

Constants are module-level values with UPPERCASE names. The compiler substitutes them at the point of use - there is no runtime memory allocation.

```python
BORDER = 0xD020
MAX_ENEMIES = 8
PLAYER_SPEED = 2
```

**Rules:**
- Must be defined at module level (outside functions)
- The name must be UPPERCASE_SNAKE_CASE
- Can only be a primitive literal or a value calculated from another constant
- The compiler substitutes them at compile time

**Constant expressions:**

```python
VIC = 0xD000
BORDER = VIC + 0x20          # OK - calculated from constant
BACKGROUND = VIC + 0x21
SPRITE_BASE = VIC + 0x00
```

**Usage:**

```python
BORDER = 0xD020
MAX_ENEMIES = 8

def main():
    border: byte[BORDER]                  # for memory-mapped variable
    enemies: array[Enemy, MAX_ENEMIES]    # for array size
    i: byte

    border = 0
    for i in range(0, MAX_ENEMIES):
        pass
```

> **IMPORTANT:** Global variables are NOT allowed in PyCo. Every module-level assignment must be UPPERCASE and is treated as a constant. If you try to create a lowercase global variable, the compiler will report an error.

### 2.8 Variables

Variables store values that change during program execution. In PyCo, variables are declared with **type annotation** and can only be used **inside functions or methods** (global variables are not allowed).

**Syntax:**

```python
name: type                # declaration without default value
name: type = default      # declaration with default value
```

**Examples:**

```python
def main():
    x: int                    # int variable, no default value
    y: int = 0                # int variable, 0 as default
    name: string[20] = "Player"
    scores: array[byte, 10]   # 10-element byte array
```

**Pascal-style declaration:**

In PyCo, variables must be declared at the **beginning** of the function, before executable statements:

```python
def calculate():
    # First: all variable declarations
    x: int = 0
    y: int = 0
    result: int

    # Then: executable code
    x = 10
    y = 20
    result = x + y
```

This rule helps the compiler allocate memory in advance and makes the code more transparent.

**Default value rules:**

Default values can only be **compile-time known constant values**:

| Allowed                             | Not allowed                   |
| ----------------------------------- | ----------------------------- |
| Literals: `42`, `"text"`, `True`    | Function call: `get_value()`  |
| UPPERCASE constants: `MAX_ENEMIES`  | Variable: `other_var`         |
| Constant expressions: `10 + 5`      | Runtime expression: `x + 1`   |
|                                     | Parameter: `param`            |

**Incorrect example:**

```python
def bad_example(n: byte):
    x: int = get_initial_value()  # ERROR: function call
    y: int = n                    # ERROR: parameter not constant
    z: int = x + 1                # ERROR: variable not constant
```

> **Note:** For details about types, see [3. Types](#3-types). For memory-mapped variables (variables at fixed memory addresses), see [4. Memory-mapped Programming](#4-memory-mapped-programming).

### 2.9 Definition Order

PyCo uses **single-pass name resolution**. This means a name (type, function, method) can only be referenced if it's already defined in the source code.

#### Why is this important?

| Advantage                | Explanation                                                             |
| ------------------------ | ----------------------------------------------------------------------- |
| Simpler compilation      | The compiler can process the code in a single pass                      |
| No "mirror in mirror"    | Self-referencing classes automatically excluded (avoiding infinite loop) |
| Clear dependencies       | Always visible what depends on what                                     |

#### Classes

A class can only reference **already defined** classes as property types:

```python
class Node:
    value: int = 0
    next: alias[Node]    # OK: self-reference with alias (Node already known)

class Tree:
    root: alias[Node]    # OK: Node is already defined above
```

**INCORRECT code:**
```python
class Tree:
    root: alias[Node]    # ERROR: Node is not yet defined!

class Node:
    value: int = 0
```

**Error message:**
```
example.pyco:2: Error: Property 'root': Type 'Node' is not yet defined.
    Classes can only reference previously defined classes.
    Move the 'Node' class definition before this line.
```

#### Self-reference

If a class references itself, **alias is required**:

```python
class Node:
    value: int = 0
    next: Node           # ERROR: would be infinite memory!
```

**Error message:**
```
example.pyco:3: Error: Property 'next': Type 'Node' is the current class.
    Use 'alias[Node]' for self-references.
```

With `alias`, PyCo only stores a 2-byte pointer to the next Node, not the Node itself.

#### Inheritance

The parent class must also be defined:

```python
class Parent:
    x: int = 0

class Child(Parent):     # OK: Parent is already defined
    y: int = 0
```

**INCORRECT code:**
```python
class Child(Parent):     # ERROR: Parent is not yet defined!
    y: int = 0

class Parent:
    x: int = 0
```

#### Functions and Methods

See: [8.5 Forward Declaration (@forward)](#85-forward-declaration-forward).

---

## 3. Types

> **"Memory is truth, type is just glasses."**
>
> In PyCo, types don't work magically - they simply tell how to interpret raw bytes in memory. The same 4 bytes can be `float`, `array[word, 2]` or `array[byte, 4]` - it depends on which "glasses" we look through.

### 3.1 Primitive Types

Primitive (or elementary) types are the basic building blocks - they store a single, indivisible value. Composite types (arrays, classes) are built from these.

| Type  | Size   | Range         | Description          |
| ----- | ------ | ------------- | -------------------- |
| bool  | 1 byte | True/False    | 0 = False, else True |
| char  | 1 byte | 0..255        | Single character     |
| byte  | 1 byte | 0..255        | Unsigned 8 bit       |
| sbyte | 1 byte | -128..127     | Signed 8 bit         |
| word  | 2 byte | 0..65535      | Unsigned 16 bit      |
| int   | 2 byte | -32768..32767 | Signed 16 bit        |

#### Bool

`bool` occupies 1 byte:
- `0` = False
- anything else = True

```python
def example():
    b: bool
    x: int = 256          # 0x0100 - low byte is 0!

    b = x                 # low byte (0x00) is stored
    if b:                 # False, because b = 0
        print("no\n")     # doesn't run

    if x:                 # True, because x != 0 (checked as int)
        print("yes\n")    # runs
```

> **WARNING:** On assignment (`b = x`) only the low byte is copied! If the full value matters, use `bool()` conversion: `b = bool(x)`. In conditions, however, the full value is always checked.

#### Char

`char` occupies 1 byte, stores a single character. Technically the same as `byte`, but interpreted as a character.

A character literal is a **single-character string** in double quotes:

```python
def example():
    c: char = "A"         # character literal (exactly 1 character!)
    b: byte = 65          # same, but as number

    c = b                 # OK - freely convertible
    b = c                 # OK

    if c == b:            # True - same value
        print("same\n")
    if c == 65:           # True - char comparable with number
        print("65\n")
    if b == "A":          # True - byte comparable with character
        print("A\n")
```

**Encoding:** Platform-dependent. PETSCII on Commodore, ASCII on other platforms.

**Why is the `char` type useful?**

`char` and `byte` are the same in memory, but behave differently in different contexts:

```python
def example():
    c: char = "A"
    b: byte = 65
    s: string[20] = "Hello"

    # 1. print() handles them differently
    print(c)              # "A" - appears as character
    print(b)              # "65" - appears as number

    # 2. char can be appended to string
    s = s + c             # "HelloA"
    s = "Hi" + "!"        # "Hi!"
```

**When to use:**
- `char` - when storing a character, want to display it as character, or append to string
- `byte` - when storing a number and want to display it as number
- `bool` - when handling logical values

### 3.2 Floating-point Type (float)

`float` is a 32-bit floating-point type (MBF format).

| Type  | Size   | Range    | Precision |
| ----- | ------ | -------- | --------- |
| float | 4 byte | ±10^38   | ~7 digits |

```python
def example():
    x: float = 3.14159
    y: float = 2.0

    x = x * y             # slow operation!
```

> **WARNING:** Float operations are slow on old hardware! The float library is only loaded if the program uses float type.

#### Mixing Float and Integer

The float type is an **exception** to the automatic type widening rule! If float and integer types are mixed in an operation, the integer is automatically converted to float:

```python
def example():
    f: float = 10.5
    i: int = 3
    result: float

    # Implicit conversion - integer automatically becomes float
    result = f + i            # 10.5 + 3.0 = 13.5
    result = f * i            # 10.5 * 3.0 = 31.5

    # Implicit conversion on assignment too
    f = 42                    # f = 42.0 (no need for float(42))
    f = i                     # f = 3.0
```

> **IMPORTANT:** If **both** operands are integer type, division **remains integer division**!

```python
def example():
    a: int = 7
    b: int = 2
    result: float

    # WRONG: integer division! 7 / 2 = 3 (not 3.5!)
    result = a / b            # result = 3.0, not 3.5!

    # CORRECT: at least one operand must be converted to float
    result = float(a) / b     # 7.0 / 2 = 3.5
```

### 3.3 Fixed-point Types (f16, f32)

Fixed-point types sit between floating-point (`float`) and integer (`int`) types: they store fractional numbers but are much faster than float.

| Type | Size   | Format | Range                 | Precision |
| ---- | ------ | ------ | --------------------- | --------- |
| f16  | 2 byte | 8.8    | -128.0 .. +127.996    | 1/256     |
| f32  | 4 byte | 16.16  | -32768.0 .. +32767.99 | 1/65536   |

**When to use?**
- Sprite positions with subpixel precision (smooth movement)
- Physics simulations (velocity, acceleration)
- Any fractional number where speed matters more than large range

#### f16 (8.8 format)

```python
def example():
    x: f16 = f16(10)       # explicit conversion required!
    y: f16 = f16(3)
    z: f16

    z = x + y              # addition as fast as int!
    z = x * y              # multiplication: faster than float
```

#### f32 (16.16 format)

```python
def example():
    pi: f32 = f32(3.14159)  # float literal converts at compile-time!
    radius: f32 = f32(100)
    area: f32

    area = pi * radius * radius
```

> **IMPORTANT:** For correct conversion of numeric values, use the `f16()` and `f32()` functions!

```python
def main():
    # Explicit conversion - the number TRANSFORMS to f16 format
    x: f16 = f16(5)         # → 0x0500 (5.0 as f16)
    y: f16 = f16(1.5)       # → 0x0180 (1.5 as f16, compile-time!)

    # Implicit assignment - bytes COPY as they are
    z: f16 = 5              # → 0x0005 (~0.02 as f16!)
    w: f16 = 0x0500         # → 0x0500 (5.0 - if you know what you're doing)
```

> **WARNING:** With implicit assignment (`z: f16 = 5`) the number's bytes copy without change! 5 won't become 5.0 as f16, but ~0.02. If you want real number conversion, use the `f16()` function!

**When to use explicit conversion?**
- When you want to put a number **as a value** into f16: `f16(5)` → 5.0
- With float literals: `f16(1.5)` → converts at compile-time, no runtime overhead

**When to use implicit assignment?**
- When loading **raw bytes** (e.g., from file, memory)
- When you know exactly what you're doing at the memory level

#### Overflow Behavior

For fixed-point types **wraparound** occurs:

| Type  | Overflow example         |
| ----- | ------------------------ |
| `f16` | `f16(200)` → -56.0 (200-256) |
| `f32` | `f32(40000)` → -25536.0  |

#### Speed Comparison (cycles, ~1 MHz)

| Operation | int  | f16  | f32   | float |
| --------- | ---- | ---- | ----- | ----- |
| Add/Sub   | ~10  | ~10  | ~20   | ~200  |
| Multiply  | ~100 | ~150 | ~500  | ~500  |
| Divide    | ~200 | ~300 | ~1000 | ~1000 |

f16 **addition/subtraction is as fast as int** - only multiplication/division is slower.

### 3.4 String (Pascal-style)

The string is Pascal-style: the first byte contains the length, followed by the characters.

```
[length][character1][character2]...[characterN]
```

Maximum 255 characters long (the length is stored in 1 byte).

#### Declaration and Capacity

For strings, we must distinguish between **capacity** and **length**:

| Concept      | What it means                         | How we know              |
| ------------ | ------------------------------------- | ------------------------ |
| **Capacity** | Maximum how many characters fit       | Specified in declaration |
| **Length**   | Currently how many characters are in  | The first byte stores it |

```
string[10] = "Hello"

Memory:  [5][H][e][l][l][o][?][?][?][?][?]
          ↑                 ↑
        length=5         capacity=10 (5 more slots available)
```

```python
# Syntax
name: string = "constant"           # capacity from constant (5 characters)
name: string[capacity]              # explicit capacity (empty string)
name: string[capacity] = "initial"  # explicit capacity, pre-filled
```

> **Note:** In memory, capacity+1 bytes are allocated (the first byte is the length).

**Rules:**

| Case                     | Capacity required | Explanation                                   |
| ------------------------ | ----------------- | --------------------------------------------- |
| Constant initialization  | Optional          | Capacity can be calculated from constant      |
| No initialization        | **Required**      | Otherwise we don't know how much space to allocate |

```python
def example():
    # From constant - capacity automatic (5 characters fit)
    greeting: string = "Hello"           # 6 bytes (1 length + 5 char)

    # Explicit capacity - for dynamic content
    buffer: string[80]                   # 81 bytes, 0-80 characters can fit
    line: string[40]                     # 41 bytes, 0-40 characters can fit

    # Explicit capacity + constant - pre-filled but expandable
    msg: string[100] = "Score: "         # 101 bytes, now 7 char, max 100

    length: byte
    length = len(greeting)               # 5 - current length, O(1)
```

**Why Pascal-style:**
- Fast length query (O(1), no need to traverse the string)
- Safer (the length is always known)

#### Escape Sequences

| Escape | Meaning                         |
| ------ | ------------------------------- |
| `\n`   | Newline (PETSCII RETURN)        |
| `\\`   | Backslash                       |
| `\"`   | Quote                           |
| `\0`   | Null character                  |
| `\xHH` | Character by hexadecimal code   |

```python
def example():
    s: string = "First line\nSecond line"
    path: string = "C:\\folder\\file"
    special: string = "\x41\x42\x43"    # "ABC"
```

#### String Operations

| Operation | Description       | Example                  |
| --------- | ----------------- | ------------------------ |
| `len(s)`  | Get length        | `len("hello")` → 5       |
| `+`       | Concatenation     | `"ab" + "cd"` → `"abcd"` |
| `*`       | Repetition        | `"ab" * 3` → `"ababab"`  |

**String repetition and const():**

```python
# Calculated at runtime
SEPARATOR = "-" * 40

# Evaluated at compile time (embedded in data segment)
SEPARATOR = const("-" * 40)    # 40 dashes stored
```

`const()` is a preprocessor directive for compile-time evaluation.

#### Modifying Strings

Unlike Python, PyCo strings are **mutable**:

```python
def example():
    s: string = "hello"
    c: char

    c = s[0]             # "h" - reading
    s[0] = "H"           # "Hello" - writing
    s[4] = "!"           # "Hell!" - modification
```

**Negative indexing (Python-style):**

```python
def example():
    s: string = "hello"
    c: char

    c = s[-1]            # "o" - last character
    c = s[-2]            # "l" - second to last
```

> **Note:** For negative constant index, the compiler chooses type based on size:
> - `-1..-128` → 8-bit `sbyte` indexing (faster)
> - `-129..-255` → 16-bit `int` indexing (slower, but necessary)
>
> For positive constant index (`s[0]`, `s[5]`) always fast 8-bit indexing is used.

> **WARNING:** There is no index checking! Indexing beyond bounds causes undefined behavior. Correct size handling is the programmer's responsibility.

### 3.5 Arrays (array)

Fixed-size, **one-dimensional** sequence of elements of the same type.

```python
array[element_type, size]
```

```python
def example():
    scores: array[int, 10]
    x: int
    i: int

    # Zeroing with for loop
    for i in range(10):
        scores[i] = 0

    scores[0] = 100     # first element
    x = scores[9]       # last element
```

Array element values after declaration are not guaranteed (memory garbage). Indexing starts from 0.

**Index type automatic selection:**

| Element count | Index type | Explanation               |
| ------------- | ---------- | ------------------------- |
| ≤ 256         | byte       | Faster indexing           |
| > 256         | word       | Support for larger arrays |

**Fill initialization (single-value fill):**

```python
def example():
    zeros: array[byte, 100] = [0]       # 100 bytes zeroed
    ones: array[byte, 50] = [1]         # 50 bytes with 1s
    pattern: array[byte, 256] = [0xaa]  # 256 bytes with 0xAA
```

**Rules:**
- Only one element in square brackets: `[value]`
- The value must be a byte literal (0-255)
- The entire memory area is filled byte by byte

**Tuple initialization (specifying multiple values):**

```python
def example():
    scores: array[byte, 5] = (10, 20, 30, 40, 50)  # 5 values specified
    partial: array[byte, 10] = (1, 2, 3)           # only 3 values, rest uninitialized
    words: array[word, 3] = (1000, 2000, 3000)     # word values
```

**Rules:**
- In parentheses, separated by commas: `(value1, value2, ...)`
- Every value must be a constant literal (not a variable!)
- You can specify fewer elements than the array size - no checking!
- Values are copied from the data segment at runtime

**Class-type arrays (flattened byte values):**

For arrays of class types, the tuple contains flattened property values as bytes:

```python
class Position:
    x: byte = 0
    y: byte = 0

class Snake:
    # 3 Position objects, each with x and y properties
    # Tuple contains: x0, y0, x1, y1, x2, y2 (6 bytes total)
    body: array[Position, 3] = (18, 12, 19, 12, 20, 12)

def main():
    snake: Snake
    snake()                 # Initialize
    print(snake.body[0].x)  # 18
    print(snake.body[0].y)  # 12
    print(snake.body[1].x)  # 19
```

**Rules for class-type array tuples:**
- Each tuple value is a **byte** (0-255), not a class instance
- Values are listed in property order: first all properties of element 0, then element 1, etc.
- Total tuple values = number of elements × class size in bytes
- This provides direct memory layout control, useful for sprite data, game objects, etc.

**Comparison:**

| Syntax                     | Meaning                        | When to use?                   |
| -------------------------- | ------------------------------ | ------------------------------ |
| `[0]`                      | Fill with single value         | Zeroing, initialization        |
| `(1, 2, 3)`                | Specify concrete values        | Lookup tables, sprite data     |

> **WARNING:** There is no index checking! Indexing beyond bounds causes undefined behavior.

**Multi-dimensional arrays:** The language only supports one-dimensional arrays. For multi-dimensional data structures, a wrapper class can be used:

```python
class Matrix:
    data: array[int, 50]  # 5 rows × 10 columns
    cols: int = 10

    def get(x: int, y: int) -> int:
        return data[y * cols + x]

    def set(x: int, y: int, value: int):
        data[y * cols + x] = value
```

#### Character Arrays and String Assignment

For `char` element arrays (`array[char, N]`) you can also assign a string value. In this case, the string copies **without the length byte** - this is particularly useful for screen memory handling:

```python
SCREEN = 0x0400

def example():
    # First row of screen (40 characters)
    row: array[char, 40][SCREEN]

    row = "Hello!"         # "Hello!" directly to screen, without length
```

> **WARNING:** The compiler doesn't check if the string fits in the array! If the string is longer than the array size, overflow characters will overwrite the next bytes in memory.

**Reverse direction: character array → string**

Character arrays can also be assigned to strings. In this case, copying continues until:
- A `\0` (null) character is found, OR
- It reaches the `min(array size, string capacity)` limit

```python
def example():
    chars: array[char, 40]
    s: string[50]

    # ... filling chars ...
    s = chars              # copies until \0 or min(40, 50) = 40 characters
```

This way both worlds are supported: null-terminated (C-style) and fixed-length character arrays alike.

**Comparison:**

| Direction                | Behavior                                              |
| ------------------------ | ----------------------------------------------------- |
| `string` → `array[char]` | Copies characters without length byte                 |
| `array[char]` → `string` | Copies until `\0` or `min(N, M)`, sets the length     |

> **Note:** For local variables, both buffer sizes are known at compile time, so the `min(N, M)` limit applies automatically. For function parameters (if size is unknown), copying continues until `\0` character or maximum 255 bytes.

### 3.6 Tuple (read-only data and pointer variables)

Tuples provide efficient access to fixed data sequences. PyCo supports **two tuple variants**:

1. **Initialized tuple** - Read-only constant data in data segment
2. **Tuple pointer variable** - Mutable pointer that can reference different tuples

```python
tuple[element_type]
```

#### Initialized Tuple (constant data)

When a tuple variable is initialized with a tuple literal, it becomes a **read-only constant**:

```python
def example():
    # Initialized tuple - read-only, stored in data segment
    colors: tuple[byte] = (0, 2, 5, 7, 10, 14)

    # Indexing works
    x: byte = colors[2]    # x = 5

    # Writing is FORBIDDEN - compile error!
    # colors[0] = 99       # ERROR: initialized tuple is read-only
    # colors = other       # ERROR: cannot reassign initialized tuple
```

#### Tuple Pointer Variable

When a tuple variable is declared **without initialization**, it becomes a **pointer variable** that can be assigned later:

```python
def example():
    data1: tuple[byte] = (10, 20, 30)   # Initialized (constant)
    data2: tuple[byte] = (40, 50, 60)   # Initialized (constant)

    # Tuple pointer variable (uninitialized)
    ptr: tuple[byte]

    # Initially empty (len = 0)
    print(len(ptr))    # Output: 0

    # Can be assigned
    ptr = data1
    print(ptr[0])      # Output: 10
    print(len(ptr))    # Output: 3

    # Can be reassigned
    ptr = data2
    print(ptr[0])      # Output: 40
```

This is useful for:
- Selecting between different data sets at runtime
- Passing tuples as function parameters
- Class properties that reference tuple data

**Difference from array:**

| Property           | `array[T, N]`                    | `tuple[T]`                     |
| ------------------ | -------------------------------- | ------------------------------ |
| Size specification | Required: `array[byte, 10]`      | Automatic from literal         |
| Storage            | Stack (copied at runtime)        | Data segment (no copying)      |
| Modifiable?        | Yes                              | No                             |
| Initialization     | `[v]` fill or `(v1,v2)` tuple    | Only `(v1, v2, ...)` tuple     |
| Speed              | Slower (memory copying)          | Faster (direct access)         |
| As parameter       | `alias[array[T, N]]`             | `tuple[T]`                     |

**When to use tuple?**

- Constant data (sprite patterns, font data, lookup tables)
- Large data blocks that don't change at runtime
- Speed-critical cases (no runtime copying)

**When to use array?**

- Modifiable data
- Buffers, variable content

**Tuple as class property:**

Tuples can be used as class properties with the same two-variant behavior:

```python
class Level:
    # Initialized tuple property - shared by ALL instances (constant)
    default_colors: tuple[byte] = (0, 2, 5, 7, 10, 14)

    # Tuple pointer property - each instance can have different data
    current_data: tuple[byte]

def main():
    level: Level

    # All Level instances share the same default_colors (fast!)
    x: byte = level.default_colors[0]

    # Each instance can point to different data
    level.current_data = level.default_colors
```

> **Note:** Initialized tuple properties (`= (...)`) are stored once in the data segment and shared by all instances. Tuple pointer properties require 2 bytes per instance.

**Tuple constant at module level:**

Tuple literals can be defined as UPPERCASE constants at module level, and the preprocessor substitutes them at the point of use. This allows storing sprite data in separate files:

```python
# sprites.pyinc - in separate file
SPRITE_ENEMY = (0xFF, 0xAA, 0x55, 0x00, ...)
SPRITE_PLAYER = (0x3C, 0x7E, 0xFF, ...)
```

```python
# main.pyco
include("sprites")

def main():
    # The constant is substituted - as if written here
    enemy_data: tuple[byte] = SPRITE_ENEMY
    player_data: tuple[byte] = SPRITE_PLAYER
```

```python
# Sprite pattern - never changes
SPRITE_DATA: tuple[byte] = (
    0x00, 0x7E, 0x00,
    0x03, 0xFF, 0xC0,
    0x07, 0xFF, 0xE0,
    # ... 21 rows × 3 bytes
)

def main():
    # Fast access, no copying
    first_row: byte = SPRITE_DATA[0]
```

**Tuple size:** The tuple contains a 2-byte size prefix (word), so the `len()` function works on it at runtime too:

```python
def print_all(data: tuple[byte]):
    i: word

    for i in range(len(data)):  # len() gives the tuple size
        print(data[i])
```

**Filling array from tuple:**

An array's value can be copied from a tuple. This is **raw memory copy** (memcpy) from the data segment to the stack - no type checking!

```python
def main():
    # Constant data in data segment
    default_values: tuple[byte] = (10, 20, 30, 40, 50)

    # Modifiable array on stack
    buffer: array[byte, 10]

    # Copy from tuple to array
    buffer = default_values

    # Now modifiable!
    buffer[0] = 99
```

**Type-independent copy:** Since this is raw memcpy, you can also copy different type tuples to a byte array to access the data at byte level:

```python
def main():
    # Word data
    words: tuple[word] = (0x1234, 0x5678)

    # Byte-accessible copy
    bytes: array[byte, 10]
    bytes = words

    # Little-endian: bytes[0] = $34, bytes[1] = $12, bytes[2] = $78, bytes[3] = $56
    print(bytes[0])  # 52 ($34)
    print(bytes[1])  # 18 ($12)
```

This is useful when you have a constant data set (e.g., default values) that you want to modify at runtime, or when you want byte-level access to larger types.

---

## 4. Memory-mapped Programming

Memory-mapped variables are variables bound to fixed memory addresses. We use them for direct access to hardware registers and memory.

### 4.1 Memory-mapped Variables

```python
name: type[address]
```

```python
border: byte[0xD020]        # VIC border color register
bg: byte[0xD021]            # VIC background color
sprite0_x: byte[0xD000]     # Sprite 0 X coordinate
```

**Usage:**

```python
def example():
    border: byte[0xD020]
    bg: byte[0xD021]
    x: byte

    border = 0              # STA $D020
    x = bg                  # LDA $D021
```

**Advantage:** Faster because the compiler generates direct memory operations, no function call (peek/poke).

### 4.2 Memory-mapped Arrays

```python
name: array[type, size][address]
```

```python
def example():
    screen: array[byte, 1000][0x0400]   # Screen memory
    colors: array[byte, 1000][0xD800]   # Color memory
    i: byte = 0
    x: byte = 65

    screen[0] = 1           # writes to $0400
    screen[i] = x           # writes to $0400 + i address
```

#### Memory-mapped Character Arrays

The `array[char, N]` type is particularly useful for screen memory handling because it can also receive a string value - in this case, it copies **without** the Pascal length byte:

```python
SCREEN = 0x0400
COLOR = 0xD800

def example():
    screen: array[char, 1000][SCREEN]
    color: array[byte, 1000][COLOR]

    screen = "Hello!"          # writes directly to screen (without length!)
    color[0] = 1               # first character white
```

> **Note:** This is just a simplified example. PETSCII/ASCII character codes don't always match screen codes - for some characters (e.g., uppercase letters) additional conversion is needed for correct display.

### 4.3 Memory-mapped Strings

Pascal-style string buffer mapped to fixed memory address:

```python
BUFFER_ADDR = 0xC000

def example():
    # External buffer (e.g., for communication)
    buffer: string[80][BUFFER_ADDR]    # 81 bytes from $C000 address

    buffer = "Hello!"          # length byte + characters
    print(buffer)              # works with print
```

> **WARNING:** The Pascal-style string's first byte is the length! NOT recommended for screen memory, because the length byte also appears as a character. For screen handling use `array[char, N]` type!

> **Note:** For memory-mapped strings, capacity specification is required for syntax clarity - otherwise the compiler couldn't distinguish the address from capacity.

### 4.4 Memory-mapped Classes (hardware wrappers)

When **all** properties of a class are memory-mapped (pointing to fixed addresses), the class becomes a "mapped-only" class. This is particularly useful for creating hardware wrappers:

```python
class VIC:
    border: byte[0xD020]
    bg0: byte[0xD021]
    bg1: byte[0xD022]
    bg2: byte[0xD023]
    sprite_enable: byte[0xD015]

    def flash_border(color: byte):
        self.border = color

    def reset():
        self.border = 14
        self.bg0 = 6
```

**Usage:**

```python
def main():
    vic: VIC

    vic.border = 0           # direct: STA $D020
    vic.flash_border(1)      # method call also works
```

**Advantages of mapped-only classes:**

| Aspect                | Normal class              | Mapped-only class        |
| --------------------- | ------------------------- | ------------------------ |
| Memory usage          | `total_size` bytes/instance | 0 bytes (no allocation) |
| Method call speed     | Normal                    | ~2-3x faster             |

**Important rules:**

1. **Detection**: A class is mapped-only if it has at least one property AND `total_size == 0` (including inherited properties)
2. **Inheritance**: If the parent class has normal (non-mapped) properties, the descendant is NOT mapped-only
3. **Multiple instances**: You can create multiple "instances", but they all point to the same memory

```python
class SpriteRegs:
    x: byte[0xD000]
    y: byte[0xD001]

def main():
    s1: SpriteRegs
    s2: SpriteRegs

    s1.x = 100     # $D000 = 100
    s2.x = 200     # $D000 = 200 (overwrites s1!)
    # s1.x and s2.x are THE SAME memory address!
```

> **Tip:** Mapped-only classes are ideal for typed access to hardware registers. With methods, you can implement complex hardware operations in a clear way.

### 4.5 IRQ-safe Variables (irq_safe)

The `irq_safe` is a wrapper type that provides **atomic access** to memory-mapped variables. This is critical for variables that are used by both the main program and IRQ handlers.

#### The Problem

Reading and writing multi-byte types (word, int) requires **multiple machine instructions**. If an interrupt (IRQ) occurs midway through the operation, a "torn read/write" happens - the IRQ handler sees a partially updated, inconsistent value.

```python
# DANGEROUS - IRQ can interrupt!
SHARED_ADDR = 0x0080  # Platform-dependent address

@singleton
class State:
    counter: word[SHARED_ADDR]    # 2 bytes = 2 instructions

def main():
    State.counter = 12345
    # ↑ If IRQ interrupts between the two byte writes,
    #   the IRQ handler may read a corrupted value!
```

#### Solution: irq_safe wrapper

The `irq_safe` wrapper automatically disables IRQ during the operation:

```python
irq_safe[type[address]]
```

```python
SHARED_ADDR = 0x0080

@singleton
class State:
    counter: irq_safe[word[SHARED_ADDR]]    # Atomic access

def main():
    State.counter = 12345    # Protected: IRQ cannot interrupt
```

#### How It Works

The compiler generates protection code for `irq_safe` variable access:

1. **Saves** the current interrupt flag state
2. **Disables** IRQ
3. **Performs** the read or write operation
4. **Restores** the original interrupt flag state

> **Why not simple SEI/CLI?** If the user already disabled IRQ (`__sei__()`), CLI would accidentally re-enable it. Restoring the original state preserves the user's intent.

#### Usage in IRQ Handlers

Inside IRQ handlers (`@irq`, `@irq_raw`), the protection is **automatically skipped** because:

1. The CPU automatically disables IRQ when entering the handler
2. Additional protection would be unnecessary overhead

```python
SHARED_ADDR = 0x0080

@singleton
class Game:
    score: irq_safe[word[SHARED_ADDR]]

@irq
def timer_irq():
    # No protection generated here - already in IRQ context
    if Game.score > 0:
        Game.score = Game.score - 1

def main():
    # Protection is generated here
    print(Game.score)    # Atomic read
```

#### Supported Types

The `irq_safe` wrapper can be used with the following memory-mapped types:

| Type   | Description                                  |
| ------ | -------------------------------------------- |
| byte   | 1 byte (protection for consistency)          |
| sbyte  | 1 byte signed                                |
| word   | 2 bytes - **critical**, requires 2 instructions |
| int    | 2 bytes signed - **critical**                |

> **Note:** For the `byte` type, protection is technically not necessary (single instruction), but the compiler still generates it for consistency and future-proofing.

#### When to Use?

| Situation                                         | Use irq_safe?         |
| ------------------------------------------------- | --------------------- |
| Variable used only in main program                | Not required          |
| Variable used only in IRQ handler                 | Not required          |
| Variable used in both places (read/write)         | **Yes!**              |
| Multi-byte type (word, int) with shared access    | **Absolutely!**       |

#### Example: Shared Counter

```python
# Platform-specific addresses (see compiler reference)
COUNTER_ADDR = 0x0080

@singleton
class SharedState:
    counter: irq_safe[word[COUNTER_ADDR]]
    flag: irq_safe[byte[COUNTER_ADDR + 2]]

@irq
def timer_handler():
    # IRQ context - no protection needed
    SharedState.counter = SharedState.counter + 1

def main():
    SharedState.counter = 0
    SharedState.flag = 1

    # ... program logic ...

    # Safe read - atomic
    if SharedState.counter > 1000:
        SharedState.flag = 0
```

> **Platform-specific details:** Specific memory addresses, IRQ vector setup, and generated assembly code depend on the target platform. See the compiler reference for your platform (e.g., C64, Plus/4, etc.).

---

## 5. Alias and References

An `alias` is a **typed reference** that can point to a memory address set at runtime. It behaves as if it were the original variable - providing transparent access.

```python
alias[type]
```

You can decide at runtime which memory area it points to.

> **For C programmers:** Alias is similar to C language pointers, but there are some important differences:
> - No dereferencing syntax (`*ptr`) - the alias is automatically "transparent", directly usable
> - No null pointer - the alias must always point to a valid address
> - Type-safe - `alias[byte]` only treats the pointed memory as byte

### 5.1 Alias vs Memory-mapped Comparison

| Property         | Memory-mapped            | Alias                       |
| ---------------- | ------------------------ | --------------------------- |
| Address given    | At compile time (fixed)  | At runtime (dynamic)        |
| Syntax           | `var: byte[0xD020]`      | `var: alias[byte]`          |
| Address modifiable? | No                    | Yes, with `alias()` function |
| Usage            | Hardware registers       | Dynamic data structures     |
| Overhead         | 0 (direct address)       | 2 bytes (pointer storage)   |

### 5.2 Alias Declaration and Setting

```python
def example():
    # Original variables
    enemy: Enemy
    score: int = 100
    buffer: array[byte, 100]

    # Alias declarations
    e: alias[Enemy]
    s: alias[int]
    b: alias[byte]

    # Setting alias with alias() function
    alias(e, addr(enemy))        # e now points to enemy
    alias(s, addr(score))        # s now points to score
    alias(b, addr(buffer))       # b points to first element of buffer

    # Can also point to fixed address
    alias(s, 0xC000)             # s points to $C000 address

    # Pointer arithmetic is also possible!
    alias(b, addr(buffer) + 10)  # b points to 10th element
```

### 5.3 The addr() Function

The `addr()` function returns the memory address of a variable, property, or array element:

```python
def example():
    enemy: Enemy
    ptr: word

    ptr = addr(enemy)            # enemy's memory address
    print(ptr)                   # e.g., 2048
```

**addr() with object properties:**

You can get the address of an object's property, including chained access:

```python
class Position:
    x: byte = 0
    y: byte = 0

class Enemy:
    pos: Position
    hp: byte = 0

    def __init__():
        self.pos()

def example():
    enemy: Enemy
    ptr: alias[byte]

    enemy()
    enemy.pos.x = 50

    alias(ptr, addr(enemy.pos.x))  # Address of enemy.pos.x
    print(ptr)                      # 50

    # Works with any depth of chaining
    # addr(obj.a.b.c) is valid
```

**addr() with array elements:**

```python
def example():
    arr: array[byte, 10] = [0]
    ptr: alias[byte]

    arr[5] = 42
    alias(ptr, addr(arr[5]))       # Address of arr[5]
    print(ptr)                      # 42
```

**Pointer arithmetic:**

This is useful for pointer arithmetic:

```python
def example():
    enemies: array[Enemy, 10]
    e: alias[Enemy]
    i: byte

    # Accessing i-th enemy with pointer arithmetic
    i = 3
    alias(e, addr(enemies) + i * size(Enemy))
    e.x = 100                    # enemies[3].x = 100
```

**addr() with alias variable:**

When calling `addr()` with an alias variable, it returns **the address pointed to by the alias** - not the storage address of the alias variable itself:

```python
def example():
    x: byte = 42              # x is on the stack
    a: alias[byte]            # a is also on stack (2 byte pointer)
    ptr: word

    alias(a, 0xD020)          # a now points to 0xD020

    ptr = addr(x)             # → x's actual memory address on stack
    ptr = addr(a)             # → 0xD020 (the address the alias points to!)
```

This behavior is consistent with the transparent semantics of alias: every operation through an alias refers to the pointed-to object.

**addr() with function name:**

The `addr()` function can also retrieve the address of a function. This is useful for IRQ vector setup:

```python
@irq
def raster_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF               # Acknowledge IRQ

def main():
    irq_vector: word[0x0314]     # Kernal IRQ vector

    __sei__()                    # Disable interrupts
    irq_vector = addr(raster_handler)  # Set IRQ handler
    __cli__()                    # Enable interrupts
```

**Recommended: `__set_irq__()` intrinsic:**

The preferred way to set up IRQ handlers is the `__set_irq__()` intrinsic, which automatically handles SEI/CLI and selects the correct vector based on the decorator:

```python
@irq_hook
def frame_counter():
    count: byte[0x02F0]
    count = count + 1

def main():
    __set_irq__(frame_counter)   # Automatically sets $0314/$0315 for @irq_hook
```

| Decorator   | Vector set by `__set_irq__()` |
| ----------- | ----------------------------- |
| `@irq`      | $FFFE/$FFFF (hardware)        |
| `@irq_raw`  | $FFFE/$FFFF (hardware)        |
| `@irq_hook` | $0314/$0315 (Kernal software) |

> **Note:** For more details about IRQ handling, see the [Interrupt Handling](#13-interrupt-handling-c64) section.

### 5.4 Using Alias - Transparent Access

The alias behaves **as if it were the original variable**:

```python
def example():
    enemy: Enemy
    e: alias[Enemy]

    enemy.x = 10
    alias(e, addr(enemy))

    # Reading and writing - transparent!
    e.x = 50                     # = enemy.x = 50
    e.y = 100                    # = enemy.y = 100
    print(e.x)                   # = print(enemy.x)
    e.move(5, 5)                 # = enemy.move(5, 5)
```

**For primitive types:**

```python
def example():
    score: int = 100
    s: alias[int]

    alias(s, addr(score))

    s = 200                      # = score = 200
    s += 50                      # = score += 50
    print(s)                     # = print(score) → 250
```

### 5.5 Alias as Parameter

> **RULE:** Composite types (object, array, string) can **only be passed as alias** to a function!

```python
# CORRECT - alias parameter
def process_enemy(e: alias[Enemy]):
    e.x = 50                     # Modifies the original!
    e.health -= 10

def sum_array(arr: alias[array[byte, 10]]) -> word:
    total: word = 0
    i: byte
    for i in range(len(arr)):
        total += arr[i]
    return total

# INCORRECT - composite type directly
# def bad_function(e: Enemy):      # COMPILE ERROR!
```

**Automatic alias conversion:**

If a function expects an `alias[T]` type parameter, the compiler automatically passes the variable as alias. The user simply passes the variable - the compiler does the conversion:

```python
def main():
    enemy: Enemy
    buffer: array[byte, 10]

    process_enemy(enemy)         # Compiler automatically passes as alias
    sum_array(buffer)            # Compiler automatically passes as alias
```

**Passing alias variable:**

If you already have an alias variable, you can also pass it to a function. The compiler passes the stored pointer value:

```python
def main():
    enemy: Enemy
    enemy()                      # Initialize the enemy
    e_alias: alias[Enemy]

    alias(e_alias, addr(enemy))  # e_alias → enemy's address
    process_enemy(e_alias)       # Passes the CONTENT of e_alias (enemy's address)

    # Both calls result in the same:
    process_enemy(enemy)         # Directly
    process_enemy(e_alias)       # Through alias variable
```

**Alias for primitives (pass-by-reference):**

Primitive types (byte, word, int, etc.) are passed by value by default. If you want to modify the original value, use `alias[T]`:

```python
def increment(x: alias[byte]):
    x = x + 1                    # Modifies the ORIGINAL variable!

def main():
    val: byte = 10
    increment(val)               # Automatic alias conversion
    print(val)                   # → 11
```

> **Note:** `alias[alias[T]]` (nested alias) is **not allowed**! A pointer pointing to a pointer would be unnecessary complexity. Use simple `alias[T]`.

**Passing string literals:**

String and screen code literals can be passed directly to `alias[string]` parameters. The compiler passes the address of the literal stored in the data segment:

```python
def print_text(s: alias[string]):
    # ... use s ...

print_text("hello")      # PETSCII string literal
print_text(s"hello")     # Screen code literal
```

> **Warning:** String literals are **mutable** in PyCo! If a function modifies the string through the alias, the literal itself changes in memory. This affects all subsequent uses of that literal:
>
> ```python
> def modify(s: alias[string]):
>     s[0] = 'X'
>
> print("hello")    # Prints: "hello"
> modify("hello")   # Modifies the literal!
> print("hello")    # Prints: "Xello" - same literal, now modified!
> ```
>
> This behavior can be useful for template strings (e.g., score displays) but requires awareness.

### 5.6 Alias as Return Value

> **RULE:** Returning composite types is **only possible as alias**!

```python
def create_enemy() -> alias[Enemy]:
    e: Enemy
    e()                          # Initialize
    e.x = 100
    e.y = 50
    return e                     # e is returned as alias

def main():
    enemy: Enemy
    enemy = create_enemy()       # The alias is COPIED to enemy
```

> ⚠️ **WARNING:** The alias return value is **only valid until the end of that statement!**

**Why?** When a function returns, its stack frame is freed. The alias points to the function's local variable, which was on the stack. At the end of the statement, this memory area is already "free" - the next function call or variable declaration can overwrite it!

**Safe usage - immediate copy:**

```python
def main():
    result: Enemy

    result = create_enemy()      # ✅ OK - immediately copied to result
    # The create_enemy stack frame is freed, BUT the data is already in result
```

**Dangerous usage - saving alias:**

```python
def main():
    enemy_ptr: alias[Enemy]

    alias(enemy_ptr, addr(create_enemy()))  # ⚠️ DANGEROUS!
    # In the next line enemy_ptr may already point to "garbage" data!

    do_something()               # This call may overwrite the stack
    print(enemy_ptr.x)           # ← Reading memory garbage!
```

**The rule is simple:** If you get an alias back, **immediately copy** it to a proper variable, or use it in the same line.

### 5.7 Type Categories Summary

| Category      | Types                                     | As parameter      | As return value  |
| ------------- | ----------------------------------------- | ----------------- | ---------------- |
| **Primitive** | byte, sbyte, word, int, bool, char, float | By value          | Value            |
| **Composite** | array, string, classes                    | Automatic alias   | `alias[T]` type  |

### 5.8 Practical Example: Reusable List Handler

```python
class ByteList:
    data: alias[byte]            # Can point to any byte array
    capacity: byte
    count: byte = 0

    def init(data_ptr: word, cap: byte):
        alias(data, data_ptr)
        capacity = cap
        count = 0

    def add(value: byte) -> bool:
        if count >= capacity:
            return False
        data[count] = value
        count += 1
        return True

    def get(index: byte) -> byte:
        return data[index]

def main():
    # Declarations at function start
    bullets: array[byte, 50]
    scores: array[byte, 10]
    bullet_list: ByteList
    score_list: ByteList

    # Initialization and usage
    bullet_list.init(addr(bullets), len(bullets))
    bullet_list.add(42)

    score_list.init(addr(scores), len(scores))
    score_list.add(100)
```

> **WARNING:** Alias doesn't check if it points to a valid address! Using an uninitialized alias causes undefined behavior.

---

## 6. Operators and Expressions

### 6.1 Arithmetic Operators

| Operator | Description    | Example |
| -------- | -------------- | ------- |
| `+`      | Addition       | `a + b` |
| `-`      | Subtraction    | `a - b` |
| `*`      | Multiplication | `a * b` |
| `/`      | Division       | `a / b` |
| `%`      | Modulo         | `a % b` |

> **IMPORTANT:** The operation type depends on the **operand types**, not the result variable! `byte + byte` is always an 8-bit operation, even if stored in a `word` variable. See: [Type Conversions](#10-type-conversions-and-type-handling)

### 6.2 Comparison Operators

| Operator | Description           | Example  |
| -------- | --------------------- | -------- |
| `==`     | Equal                 | `a == b` |
| `!=`     | Not equal             | `a != b` |
| `<`      | Less than             | `a < b`  |
| `>`      | Greater than          | `a > b`  |
| `<=`     | Less than or equal    | `a <= b` |
| `>=`     | Greater than or equal | `a >= b` |

### 6.3 Logical Operators

| Operator | Description | Example   |
| -------- | ----------- | --------- |
| `and`    | Logical AND | `a and b` |
| `or`     | Logical OR  | `a or b`  |
| `not`    | Logical NOT | `not a`   |

### 6.4 Bitwise Operators

| Operator | Description    | Example  |
| -------- | -------------- | -------- |
| `&`      | Bitwise AND    | `a & b`  |
| `\|`     | Bitwise OR     | `a \| b` |
| `^`      | Bitwise XOR    | `a ^ b`  |
| `~`      | Bitwise NOT    | `~a`     |
| `<<`     | Left shift     | `a << 2` |
| `>>`     | Right shift    | `a >> 2` |

```python
def example():
    x: byte = 0b11001010

    x = x & 0x0F          # lower 4 bits: 0b00001010
    x = x | 0x80          # set highest bit
    x = x ^ 0xFF          # invert all bits
    x = x << 1            # left shift (multiply by 2)
    x = x >> 1            # right shift (divide by 2)
```

### 6.5 Assignment Operators

| Operator | Equivalent   |
| -------- | ------------ |
| `=`      | `a = b`      |
| `+=`     | `a = a + b`  |
| `-=`     | `a = a - b`  |
| `*=`     | `a = a * b`  |
| `/=`     | `a = a / b`  |
| `%=`     | `a = a % b`  |
| `&=`     | `a = a & b`  |
| `\|=`    | `a = a \| b` |
| `^=`     | `a = a ^ b`  |
| `<<=`    | `a = a << b` |
| `>>=`    | `a = a >> b` |

**Optimization:** The `+= 1` and `-= 1` operations can generate optimized machine code (platform-dependent). For example on C64:

| Variable type      | `+= 1` code                    | Speed      |
| ------------------ | ------------------------------ | ---------- |
| Memory-mapped byte | `inc $addr` (1 instruction)    | ~6 cycles  |
| Stack byte         | `lda/clc/adc/sta` (5 instructions) | ~15 cycles |

### 6.6 Operator Precedence

Precedence follows Python. Higher precedence = evaluated first.

| Level | Operators                        | Description               |
| ----- | -------------------------------- | ------------------------- |
| 1     | `()`                             | Parentheses               |
| 2     | `**`                             | Exponentiation            |
| 3     | `~`, `+x`, `-x`                  | Unary operators           |
| 4     | `*`, `/`, `%`                    | Multiply, divide, modulo  |
| 5     | `+`, `-`                         | Addition, subtraction     |
| 6     | `<<`, `>>`                       | Bit shift                 |
| 7     | `&`                              | Bitwise AND               |
| 8     | `^`                              | Bitwise XOR               |
| 9     | `\|`                             | Bitwise OR                |
| 10    | `==`, `!=`, `<`, `>`, `<=`, `>=` | Comparison                |
| 11    | `not`                            | Logical NOT               |
| 12    | `and`                            | Logical AND               |
| 13    | `or`                             | Logical OR                |
| 14    | `=`, `+=`, `-=`, etc.            | Assignment                |

> **Tip:** If unsure, use parentheses!

---

## 7. Control Structures

### 7.1 Conditionals

#### if

```python
if condition:
    statements
```

#### if-else

```python
if condition:
    statements
else:
    statements
```

#### if-elif-else

```python
if condition1:
    statements
elif condition2:
    statements
elif condition3:
    statements
else:
    statements
```

There can be any number of `elif` branches. The `else` branch is optional.

```python
def example():
    score: int = 85

    if score >= 90:
        print("Excellent\n")
    elif score >= 70:
        print("Good\n")
    elif score >= 50:
        print("Pass\n")
    else:
        print("Fail\n")
```

### 7.2 Loops

#### while

Pre-test loop - repeats while the condition is true:

```python
def example():
    i: byte = 0

    while i < 10:
        print(i)
        i = i + 1
```

**Infinite loop optimization:** The `while True:` and `while 1:` loops are optimized by the compiler - unnecessary condition checking is skipped, generating more efficient code. You can exit the loop with a `break` statement:

```python
def example():
    i: byte = 0

    while True:
        print(i)
        i += 1
        if i >= 10:  # Post-test loop
            break
```

#### for

Counter loop over a range:

```python
for variable in range(end):
    statements

for variable in range(start, end):
    statements

for variable in range(start, end, step):
    statements
```

| Form                        | Description                                  |
| --------------------------- | -------------------------------------------- |
| `range(end)`                | Iterates from 0 to end-1 (step: 1)           |
| `range(start, end)`         | Iterates from start to end-1 (step: 1)       |
| `range(start, end, step)`   | Iterates from start to end-1 with custom step |

```python
def example():
    i: byte

    # Simple form: 0 to 9
    for i in range(10):
        print(i)           # 0, 1, 2, ... 9

    # With start value: 5 to 9
    for i in range(5, 10):
        print(i)           # 5, 6, 7, 8, 9

    # With step: even numbers
    for i in range(0, 10, 2):
        print(i)           # 0, 2, 4, 6, 8

    # Iterating backwards
    for i in range(10, 0, -1):
        print(i)           # 10, 9, 8, ... 1
```

**Rules:**
- `range()` does not include the end value (half-open interval)
- `step` cannot be 0
- For backwards iteration, negative step is needed, and `start > end`

> **IMPORTANT:** The loop variable must be declared in advance! In PyCo, variables live at function level.

##### Throwaway Loop Variable

When you don't need the loop counter value, use `_` as the loop variable:

```python
def example():
    for _ in range(10):
        print("hello")     # prints 10 times, counter not used
```

This has several advantages:
- **No declaration needed** - `_` doesn't require a variable declaration
- **Optimized code** - uses the 6502 hardware stack for ~25% faster loop overhead
- **Clearer intent** - signals that the counter value is irrelevant

| Form                      | Counter Type | Description                          |
| ------------------------- | ------------ | ------------------------------------ |
| `for _ in range(n)`       | byte         | When `n ≤ 255`                       |
| `for _ in range(n)`       | word         | When `n > 255`                       |
| `for _ in range(var)`     | from `var`   | Determined by variable type          |

**Restrictions:**
- **Only `range(n)` form is supported** - use a named variable for `range(start, end)` or `range(start, end, step)`
- `_` cannot be used inside the loop body - compile-time error
- `_` cannot be declared as a variable name
- `_` cannot appear in any expression

```python
# INCORRECT - using _ in body
for _ in range(10):
    x = _              # COMPILE ERROR!

# INCORRECT - declaring _
_: byte = 0            # COMPILE ERROR!

# INCORRECT - range with start/end (use named variable instead)
for _ in range(5, 10):    # COMPILE ERROR!
    pass
```

#### break and continue

`break` exits the loop:

```python
def example():
    done: bool

    while True:
        if done:
            break
```

`continue` jumps to the next iteration of the loop:

```python
def example():
    i: byte

    for i in range(0, 10):
        if i == 5:
            continue       # skips 5
        print(i)
```

---

## 8. Functions

### 8.1 Defining Functions

```python
def name(parameters) -> type:
    variable declarations
    body
    return value
```

**Parameter types must be specified:**

```python
def add(a: int, b: int) -> int:
    return a + b

def greet(name: string, times: byte):
    i: byte
    for i in range(0, times):
        print(name)
```

If there's no return value, don't specify a return type, and the `return` keyword cannot be used.

> **IMPORTANT:** You cannot define another function inside a function (nested functions are not allowed) - all functions must be defined at module level (the "outermost" level of the file).

### 8.2 Parameters and Return Value

**Primitive types are passed by value** (copy):

```python
def modify_int(x: int):
    x = 100      # local copy is modified

def main():
    n: int = 10
    modify_int(n)
    # n is still 10 - the original didn't change
```

**Composite types are passed by reference** - see [Alias as Parameter](#55-alias-as-parameter).

### 8.3 The main() Entry Point

Every PyCo program **must** contain a `main()` function. This is the program's entry point - execution starts here. Without a `main()` function, the compiler reports an error.

```python
def main():
    print("Hello World!\n")
```

**Libraries and main():**
Libraries can also have a `main()` function - it can contain test or demo code:

```python
# mylib.pyco
def useful_function():
    pass

def main():
    # Test code - only runs when executed directly
    print("Testing mylib...\n")
    useful_function()
```

- **Direct execution:** `main()` runs
- **On import:** `main()` is not loaded

### 8.4 Decorators

Functions can be modified with decorators that affect platform- and compiler-specific behavior. Currently available decorators apply to the `main()` function.

```python
@decorator_name
def main():
    pass
```

Decorators depend on the target platform. For example, the C64 backend supports the following decorators:

| Decorator        | Effect                                                 |
| ---------------- | ------------------------------------------------------ |
| `@lowercase`     | Lowercase character set mode (main fn. only, C64)      |
| `@kernal`        | Keep Kernal ROM enabled (main fn. only, C64)           |
| `@noreturn`      | Skip cleanup - program never exits (main only)         |
| `@origin(addr)`  | Custom program start address, no BASIC loader (main)   |
| `@irq`           | Mark function as IRQ handler (chains to system IRQ)    |
| `@irq_raw`       | Mark function as raw IRQ handler (direct rti)          |
| `@irq_hook`      | Lightweight Kernal IRQ hook (no prologue, rts return)  |
| `@naked`         | IRQ-callable function without runtime overhead         |
| `@forward`       | Forward declaration for mutual recursion               |
| `@mapped(addr)`  | Call pre-compiled code at fixed address                |

> **Note:** For platform-specific decorator details, see the target platform compiler reference (e.g., `c64_compiler_reference.md`).

### 8.5 Forward Declaration (@forward)

The definition order rule also applies to functions - a function can only call already defined functions. For mutual recursion (two functions calling each other), this would cause a problem. The solution: **forward declaration**.

#### Syntax

```python
@forward
def function_name(parameters) -> return_type: ...
```

The `...` (Ellipsis) indicates this is only a declaration, not an implementation. This form, known from Python, clearly shows: "something is missing here".

#### Example: Mutual Recursion

```python
@forward
def is_even(n: int) -> bool: ...    # Forward declaration

def is_odd(n: int) -> bool:
    result: bool

    if n == 0:
        return False
    result = is_even(n - 1)         # OK: is_even declared with forward
    return result

def is_even(n: int) -> bool:        # Full implementation
    result: bool

    if n == 0:
        return True
    result = is_odd(n - 1)          # OK: is_odd already defined
    return result
```

#### Rules

| Rule                   | Description                                                  |
| ---------------------- | ------------------------------------------------------------ |
| Stub body              | Forward declaration body can only be `...` (Ellipsis)        |
| Implementation required | Every `@forward` function MUST have a full implementation    |
| Signature match        | Implementation signature must match exactly                   |
| Same file              | Forward and implementation must be in the same module        |

#### Error Messages

**Calling undefined function:**
```
example.pyco:5: Error: Function 'helper' is not yet defined.
    Functions can only call previously defined functions.
    Hint: Add a forward declaration:
    @forward
    def helper(...) -> ...: ...
```

**Forward without implementation:**
```
example.pyco:2: Error: Forward declaration for 'calculate' has no implementation.
    Every @forward function must have a full implementation below.
```

**Different signature:**
```
example.pyco:10: Error: Function 'process' signature doesn't match its forward declaration.
    Forward: def process(x: int) -> bool
    Actual:  def process(x: int, y: int) -> bool
```

#### Methods

`@forward` also works for methods:

```python
class Calculator:
    @forward
    def multiply(a: int, b: int) -> int: ...

    def square(n: int) -> int:
        return self.multiply(n, n)    # OK: multiply declared with forward

    def multiply(a: int, b: int) -> int:
        result: int = 0
        # ... implementation
        return result
```

#### When is @forward needed?

| Situation                              | @forward needed? |
| -------------------------------------- | ---------------- |
| Recursive function (calls itself)      | No               |
| Mutual recursion (A↔B)                 | Yes              |
| Calling later defined function         | Yes              |
| Calling earlier defined function       | No               |

### 8.6 External Functions (@mapped)

The `@mapped` decorator allows calling pre-compiled code at a fixed memory address without using inline assembly. This is useful for integrating external routines (music players, graphics libraries, etc.) that are loaded at known addresses.

#### Syntax

```python
@mapped(address)
def function_name(parameters) -> return_type: ...
```

The function body must be `...` (Ellipsis) since the actual code exists elsewhere in memory.

#### Example: Music Player Integration

```python
PLAYER_INIT = 0x1000   # Address where player init routine is loaded
PLAYER_PLAY = 0x1003   # Address where player play routine is loaded

@mapped(PLAYER_INIT)
def music_init(song: byte): ...

@mapped(PLAYER_PLAY)
def music_play(): ...

def main():
    music_init(0)        # Initialize first song
    while True:
        music_play()     # Call player each frame
        wait_frame()
```

#### Class Methods

`@mapped` also works with class methods for logical grouping:

```python
class MusicPlayer:
    @mapped(0x1000)
    def init(song: byte): ...

    @mapped(0x1003)
    def play(): ...

def main():
    MusicPlayer.init(0)
    MusicPlayer.play()
```

> **Note:** Mapped class methods have no `self` parameter - they behave like static methods.

#### Calling Convention

The compiler uses a register-based calling convention for mapped functions:

| Parameter position | Register |
| ------------------ | -------- |
| 1st parameter      | A        |
| 2nd parameter      | X        |
| 3rd parameter      | Y        |

Return values are passed in A (for `byte`) or A+X (for `word`, with low byte in A).

> **Important:** Only up to 3 byte-sized parameters are supported. For more complex parameter passing, use global variables or inline assembly.

#### Rules

| Rule                  | Description                                                    |
| --------------------- | -------------------------------------------------------------- |
| Stub body             | Function body must be `...` (Ellipsis)                         |
| Address range         | Address must be in valid memory range (platform-dependent)     |
| No @irq combination   | Cannot combine with `@irq`, `@irq_raw`, or `@irq_hook`         |
| Integer address       | Address must be an integer constant (not a variable)           |

### 8.7 IRQ-Callable Functions (@naked)

The `@naked` decorator marks a function as safe to call from interrupt handlers without the standard IRQ call overhead. When a normal function is called from an IRQ handler, the compiler must save and restore the main program's runtime state (stack frame, temporary registers). For functions that are specifically designed for IRQ use (like music player tick routines), this overhead is unnecessary.

#### Syntax

```python
@naked
def function_name(parameters) -> return_type:
    # Function body (typically inline assembly)
```

#### Example: Music Player Integration

```python
@naked
def music_tick():
    """Play one tick of music. Designed to be called from IRQ."""
    __asm__("""
    jsr _mp_play
    """)

@irq
def irq_handler(vic: byte):
    if vic & 0x01:
        music_tick()   # No IRQ call overhead - just a simple JSR!
```

#### How It Works

When calling a function from an IRQ handler, the compiler normally emits:

| Without @naked (normal function)        | With @naked                    |
| --------------------------------------- | ------------------------------ |
| Save tmp0-tmp5 to hardware stack        | —                              |
| Save FP/SSP to hardware stack           | —                              |
| Adjust SSP past IRQ locals              | —                              |
| JSR to function                         | JSR to function                |
| Restore FP/SSP from hardware stack      | —                              |
| Restore tmp0-tmp5 from hardware stack   | —                              |

The overhead savings are significant - approximately 100-120 cycles per call.

#### Programmer's Responsibility

The `@naked` decorator does not restrict what you can put in the function - it simply tells the compiler to skip the IRQ overhead. **It is the programmer's responsibility** to ensure:

1. The function does not corrupt registers that the main program expects to be preserved
2. If the function uses temporary registers (tmp0-tmp5), FP, or SSP, it saves and restores them itself
3. The function is actually safe to call from interrupt context

#### Register-Based Parameter Passing

The `@naked` decorator uses the same register-based calling convention as `@mapped` functions. Parameters are passed directly in CPU registers instead of the stack, eliminating frame setup overhead.

```python
@naked
def music_disable_channel(ch: byte):
    """Disable music on a channel. ch arrives in first register."""
    __asm__("""
    // ch parameter is in first register (platform-specific)
    // Process it directly without stack access
    ...
    rts
    """)

# Caller side - parameter goes directly to register
music_disable_channel(2)
```

**Parameter limits:**
- Maximum 3 register slots available (platform-dependent)
- Byte parameters use 1 slot each
- Word parameters use 2 slots
- See platform compiler reference for exact register assignments

> **ABI Note:** The exact register assignment for parameters depends on the target platform. For example, on 6502-based systems, the first byte parameter goes to A, second to X, third to Y. See your platform's compiler reference for details.

#### Rules

| Rule                     | Description                                                    |
| ------------------------ | -------------------------------------------------------------- |
| Top-level only           | Cannot be used on class methods                                |
| No @irq combination      | Cannot combine with `@irq`, `@irq_raw`, or `@irq_hook`         |
| Normal context OK        | Can also be called from normal (non-IRQ) context               |
| Register-based params    | Parameters passed in registers (max 3 slots, ABI-dependent)    |

> **Note:** For platform-specific details (cycle counts, register usage, ABI), see the target platform compiler reference.

---

## 9. Classes

Classes group related data (properties) and operations on them (methods) into a single unit. This makes code more transparent and helps logical grouping of data.

PyCo supports a **simplified version** of object-oriented programming (OOP) - only features that provide real advantage for low-level programming:

| Supported           | Not supported                      |
| ------------------- | ---------------------------------- |
| Properties          | Multiple inheritance               |
| Methods             | Interfaces, abstract classes       |
| Single inheritance  | Polymorphism, virtual methods      |
| Constructor         | Destructor, garbage collection     |

This approach helps code organization without causing runtime overhead.

### 9.1 Defining a Class

```python
class name:
    property declarations
    methods
```

or with inheritance:

```python
class name(parent_class):
    property declarations
    methods
```

> **IMPORTANT:** Nested classes are not allowed! All classes must be defined at module level (not inside another class or function).

### 9.2 Properties

All properties must be declared in advance, with [type](#3-types) and optional default value. The same rules apply to default values as for [variables](#28-variables):

```python
class Position:
    x: int = 0
    y: int = 0

class Hero(Position):
    score: int = 0
    name: string[20] = "Player"
```

**Memory-mapped properties:**

A property can also be mapped to a fixed memory address, similar to [memory-mapped variables](#41-memory-mapped-variables):

```python
class VIC:
    border: byte[0xD020]    # Fixed address: $D020
    bg: byte[0xD021]        # Fixed address: $D021
```

If **all** properties of a class are memory-mapped, the class becomes "mapped-only", and the compiler can apply extra optimizations (direct addressing). See: [4.4 Memory-mapped Classes](#44-memory-mapped-classes-hardware-wrappers)

### 9.3 Initializer (__init__)

The `__init__` method is called during object initialization. Unlike Python, PyCo objects are stored **inline on the stack** (like C structs), not as heap-allocated references. This means:

- **Declaration** (`pos: Position`) only allocates memory - does NOT initialize!
- **Initialization** (`pos()` or `pos(args)`) sets default values and runs `__init__`

```python
class Enemy:
    x: int = 0
    y: int = 0
    health: byte = 100

    def __init__(start_x: int, start_y: int):
        self.x = start_x
        self.y = start_y
```

**Initialization order when calling `pos()`:**
1. Class-level default values are set (e.g., `health = 100`)
2. `__init__` method runs (if exists and if called with arguments)

**Important:** The initializer call `pos()` is **NOT an expression** - it cannot appear on the right side of an assignment or as a function argument. It's a statement that operates on an already-declared object.

### 9.4 Methods

Methods are actually functions that can reference the class properties.

> **IMPORTANT:** `self` should **NOT** be in the method parameter list (unlike Python)! In the method body, however, `self` is used to access properties. This simplification is possible because PyCo is not a dynamic language - `self` always points to the current object, nothing else can be substituted.

```python
class Hero:
    x: int = 0
    score: int = 0

    def move(dx: int, dy: int):      # self is NOT in parameter list!
        self.x += dx                 # But in the body it's needed!
        self.y += dy

    def add_score(points: int) -> int:
        self.score += points
        return self.score
```

### 9.5 Inheritance

Inheritance allows a class to take over the properties and methods of another class. The child class (descendant) inherits all properties and methods of the parent class (ancestor), and can also define new ones.

PyCo has **single inheritance** - a class can only have one parent:

```python
class Position:
    x: int = 0
    y: int = 0

class Player(Position):    # Player inherits Position
    score: int = 100

    def move_right(inc: int):
        self.x += inc      # x inherited from Position
```

**Property inheritance:**

The child class receives all properties of the parent, and can also define its own new properties:

```python
class Position:
    x: int = 0
    y: int = 0

class Player(Position):
    score: int = 0         # Own property

def main():
    p: Player
    p()                    # Initialize
    p.x = 10               # Inherited property
    p.score = 100          # Own property
```

**Property shadowing:**

If a child class declares a property with the same name as a parent property, it creates a **new, separate property** (shadowing). The parent's property remains in memory (for parent methods to use), but the child cannot access it by name:

```python
class Parent:
    x: byte = 10

    def get_x() -> byte:
        return self.x      # Always uses Parent's x (offset 0)

class Child(Parent):
    x: byte = 20           # NEW property - shadows parent's x

    def get_child_x() -> byte:
        return self.x      # Uses Child's x (different offset)

def main():
    c: Child
    c()
    print(c.x)             # 20 - Child's x
    print(c.get_child_x()) # 20 - Child's x
    print(c.get_x())       # 10 - Parent method sees Parent's x!
```

Key points about property shadowing:
- Child can use a **different type** for the shadowed property
- Both properties are initialized with their default values
- Parent methods always access the parent's version
- To access a parent property from child, use a getter method in the parent class

**Method inheritance:**

The child class also inherits the parent's methods:

```python
class Animal:
    def describe():
        print("I am an animal\n")

class Dog(Animal):
    def speak():
        print("Woof!\n")

def main():
    d: Dog
    d()                    # Initialize
    d.describe()           # Inherited method - "I am an animal"
    d.speak()              # Own method - "Woof!"
```

**Method override:**

The child class can override the parent's methods with the same name:

```python
class Animal:
    def speak():
        print("...\n")

class Dog(Animal):
    def speak():           # Overrides Animal.speak()
        print("Woof!\n")

def main():
    a: Animal
    d: Dog
    a()                    # Initialize
    d()                    # Initialize

    a.speak()              # "..."
    d.speak()              # "Woof!"
```

**Calling parent method (super):**

If we override a method but want to call the parent's original implementation too, we can use the `super` keyword:

```python
class Animal:
    def speak():
        print("*sound*\n")

class Dog(Animal):
    def speak():
        print("Woof! ")
        super.speak()          # Calls Animal.speak()

def main():
    d: Dog
    d()                        # Initialize
    d.speak()                  # "Woof! *sound*"
```

A typical use case for `super` is **initializer chaining**, where the child initializer calls the parent initializer:

```python
class Position:
    x: int = 0
    y: int = 0

    def __init__(px: int, py: int):
        self.x = px
        self.y = py

class Player(Position):
    score: int = 0

    def __init__(px: int, py: int, initial_score: int):
        super.__init__(px, py)     # Call parent initializer
        self.score = initial_score

def main():
    p: Player
    p(10, 20, 100)                     # Initialize with arguments
    print(p.x, " ", p.y, " ", p.score)  # "10 20 100"
```

**Important rules:**
- `super` can only be used inside methods
- `super` is only valid in classes that have a parent class
- `super.method()` calls the parent (or ancestor) class method directly
- `super.property` is NOT supported - only for method calls

> **Note:** PyCo has no polymorphism - method calls are decided at compile time based on the variable type, not at runtime based on the object's actual type. This results in simpler and faster code.

### 9.6 Declaration and Initialization

In PyCo, objects are stored **inline on the stack** (like C structs), not as heap-allocated references. This is fundamentally different from Python and has important implications.

> **Note:** If larger or dynamic-sized memory area is needed, you can designate and manage any memory area with [memory-mapped programming](#4-memory-mapped-programming).
>
> **Why not heap?** C64 BASIC string handling uses heap, and because of this, "garbage collection" runs periodically, which can freeze the machine for seconds while compacting memory. PyCo's stack-based solution completely avoids this.

#### Declaration vs Initialization

| Class type | Syntax | What happens |
|------------|--------|--------------|
| **No `__init__`** | `pos: Position` | Memory allocated + **automatically initialized** |
| **Has `__init__`** | `enemy: Enemy` | Memory allocated - object is UNDEFINED |
| **Explicit init** | `enemy()` or `enemy(100, 50)` | Default values set + `__init__` called |

**Key rule:** The presence of `__init__` determines whether explicit initialization is needed:

```python
class Position:        # No __init__ - will be AUTO-INITIALIZED
    x: byte = 0
    y: byte = 0

class Enemy:           # Has __init__ - requires EXPLICIT initialization
    x: byte = 0
    health: byte = 100

    def __init__(start_x: byte):
        self.x = start_x

def example():
    pos: Position       # Auto-initialized! x=0, y=0 immediately usable
    print(pos.x)        # OK - prints 0

    enemy: Enemy        # NOT initialized (Enemy has __init__)
    enemy(50)           # Explicit initialization required
```

#### Initialization Order

When you call `pos()`:

1. **Default values** from class definition are applied
2. **`__init__` method** runs (if exists)

```python
class Enemy:
    x: int = 0          # Default value
    y: int = 0          # Default value
    health: byte = 100  # Default value

    def __init__(start_x: int, start_y: int):
        self.x = start_x
        self.y = start_y

def main():
    e: Enemy            # Step 1: Memory allocated (undefined values)
    e(50, 75)           # Step 2: defaults applied (x=0, y=0, health=100)
                        # Step 3: __init__ runs (x=50, y=75, health stays 100)
```

#### Re-initialization

Objects can be re-initialized at any time by calling the initializer again:

```python
class Counter:
    value: int = 0

def main():
    c: Counter
    c()                 # First initialization: value = 0
    c.value = 100

    # ... use c ...

    c()                 # Re-initialize: value resets to 0
```

If `__init__` has parameters, they must be provided when re-initializing:

```python
def main():
    pos: Position
    pos(10, 20)         # First initialization

    # ... use pos ...

    pos(0, 0)           # Re-initialize with new values
```

#### Automatic Initialization (Classes Without `__init__`)

Classes without `__init__` are **automatically initialized** when declared. This reduces boilerplate for simple data classes:

```python
class Point:
    x: byte = 10
    y: byte = 20
    # No __init__ - auto-initialized

def main():
    p: Point            # Automatically initialized! x=10, y=20
    print(p.x, p.y)     # OK - prints "10 20"

    p.x = 50            # Modify values
    p()                 # Re-initialize: resets to x=10, y=20
```

This also works recursively for **nested class properties**:

```python
class Position:
    x: byte = 0
    y: byte = 0
    # No __init__

class Entity:
    pos: Position       # Will be auto-initialized (Position has no __init__)
    id: byte = 1
    # No __init__

def main():
    e: Entity           # Auto-initialized, including nested pos!
    print(e.pos.x)      # OK - prints 0
```

**Mixed scenario:** If the container class has `__init__` but nested properties don't:

```python
class Point:           # No __init__ - auto-initialized
    x: byte = 0
    y: byte = 0

class Game:            # Has __init__ - explicit call needed
    pos: Point         # Will be auto-initialized when Game() is called
    score: word = 0

    def __init__():
        # pos is already initialized at this point!
        self.score = 100

def main():
    g: Game            # NOT initialized (Game has __init__)
    g()                # Initialize - pos auto-inits, then __init__ runs
```

> **Tip:** If you're unsure, you can always call the initializer explicitly - it's safe to initialize twice (just redundant).

#### Important: Initializer is NOT an Expression

The initializer call `pos()` is a **statement**, not an expression. It cannot be used:

```python
# ❌ FORBIDDEN - initializer is not an expression
x = pos()               # ERROR - no return value!
foo(enemy())            # ERROR - cannot use as argument!
return hero()           # ERROR - cannot return!

# ✅ CORRECT - separate declaration and initialization
pos: Position
pos()
```

This design makes it clear that `pos()` **operates on** an existing object rather than **creating** one.

#### Complete Example

```python
class Hero:
    x: int = 0
    y: int = 0
    score: int = 0

    def __init__(start_x: int, start_y: int):
        self.x = start_x
        self.y = start_y

    def move(dx: int, dy: int):
        self.x += dx
        self.y += dy

def main():
    hero: Hero          # Declaration
    points: int

    hero(10, 5)         # Initialization
    hero.move(5, 3)     # Method call
    points = hero.score
```

### 9.7 Singleton Classes

The `@singleton` decorator creates a class with exactly **one instance** that exists for the entire program lifetime. This is ideal for hardware wrappers (VIC, SID, Screen) and global state objects.

```python
@singleton
class Screen:
    border: byte[0xD020]
    bg: byte[0xD021]

    def set_colors(b: byte, c: byte):
        self.border = b
        self.bg = c

    def clear():
        # ... screen clearing logic ...
```

#### Usage

Singleton classes can be accessed in two ways:

**1. Direct class call (recommended for hardware wrappers):**
```python
def main():
    Screen.set_colors(1, 0)   # Direct call via class name
    Screen.clear()
```

**2. Local alias (like regular classes):**
```python
def main():
    scr: Screen               # Creates an alias to the singleton
    scr.set_colors(1, 0)      # Access via alias
```

Both methods access the **same instance** - changes made via one are visible through the other.

#### Behavior

| Aspect                | Singleton behavior                                    |
| --------------------- | ----------------------------------------------------- |
| Instance count        | Exactly one, created before `main()`                  |
| Constructor call      | `Singleton()` sets defaults, then calls `__init__`    |
| Auto-init             | If no `__init__`: defaults applied at program start   |
| Memory location       | After `__program_end` (mapped-only: no extra memory)  |
| Local declaration     | `scr: Screen` creates an alias, not a new instance    |

**Important:** The constructor call (`Singleton()`) behaves identically for singletons and normal classes:
1. Property defaults are set
2. `__init__` is called (if exists)

The only difference is that singletons don't need a variable declaration.

#### When to use `@singleton`

✅ **Good use cases:**
- Hardware wrappers (VIC, SID, CIA registers)
- Global game state (score, level, lives)
- Resource managers (sprite pool, sound effects)

❌ **Not suitable for:**
- Classes where you need multiple instances
- Data containers that should be passed around

#### Mapped-only Singletons

If **all properties** of a singleton are memory-mapped, no additional memory is allocated:

```python
@singleton
class VIC:
    border: byte[0xD020]      # All properties are mapped
    bg: byte[0xD021]
    # No stack/BSS memory used - just method access to fixed addresses
```

---

## 10. Type Conversions and Type Handling

### 10.1 Implicit vs Explicit Conversion

PyCo is a hardware-level language, so there is **no automatic type promotion** (implicit widening in operations). Correct type usage is the programmer's responsibility.

**On assignment** implicit conversion works:

```python
def example():
    b: byte = 200
    w: word

    w = b                # OK: byte → word automatic
```

**In operations** however, it does NOT:

```python
def example():
    a: byte = 200
    b: byte = 100
    result: word

    # WRONG: 8-bit operation! 200+100=44 (overflow)
    result = a + b

    # CORRECT: explicit conversion
    result = word(a) + word(b)   # 16-bit operation = 300
```

### 10.2 Type Conversion Functions

| Function   | Result | When to use                                 |
| ---------- | ------ | ------------------------------------------- |
| `byte(x)`  | byte   | Extract lower 8 bits                        |
| `sbyte(x)` | sbyte  | Signed interpretation of byte               |
| `word(x)`  | word   | For 16-bit operation against overflow       |
| `int(x)`   | int    | For signed arithmetic, truncate float       |
| `char(x)`  | char   | Display byte as character                   |
| `bool(x)`  | bool   | Check full value into bool variable         |
| `float(x)` | float  | For floating-point operations               |
| `f16(x)`   | f16    | Fixed-point conversion (8.8)                |
| `f32(x)`   | f32    | Fixed-point conversion (16.16)              |

#### word() - Widening Against Overflow

```python
def example():
    a: byte = 200
    b: byte = 100
    result: word

    # WRONG - 8-bit operation, overflows!
    result = a + b              # 200 + 100 = 44 (wraparound)

    # CORRECT - 16-bit operation
    result = word(a) + word(b)  # 200 + 100 = 300
```

#### sbyte() - Signed Interpretation

```python
def example():
    delta: byte = 254           # Let's say, joystick: -2 signed
    position: int = 100

    # Signed interpretation in operation
    position = position + sbyte(delta)   # 100 + (-2) = 98
```

#### int() - Truncating Float

```python
def example():
    f: float = 5.7
    i: int = int(f)          # 5 (doesn't round, truncates!)

    f = -10.9
    i = int(f)               # -10
```

#### bool() - Full Value Check

```python
def example():
    value: int = 256         # Low byte = 0!
    flag: bool

    # Direct assignment only takes low byte
    flag = value             # flag = False! (because low byte = 0)

    # bool() conversion considers FULL value
    flag = bool(value)       # flag = True! (because 256 != 0)
```

### 10.3 Type Mixing in Operations

| Operation      | Result type | Note                            |
| -------------- | ----------- | ------------------------------- |
| `byte + byte`  | `byte`      | 8-bit operation, may overflow!  |
| `word + word`  | `word`      | 16-bit operation                |
| `int + int`    | `int`       | 16-bit signed operation         |
| `int OP float` | `float`     | Integer auto-converts           |
| `float OP int` | `float`     | Integer auto-converts           |

> **IMPORTANT:** Float is the only exception where automatic conversion occurs in operations!

### 10.4 Overflow Behavior

On overflow, **wraparound** occurs:

| Type    | Range         | Overflow example     |
| ------- | ------------- | -------------------- |
| `byte`  | 0..255        | 255 + 1 → 0          |
| `sbyte` | -128..127     | 127 + 1 → -128       |
| `word`  | 0..65535      | 65535 + 1 → 0        |
| `int`   | -32768..32767 | 32767 + 1 → -32768   |

**No runtime checking** - overflow follows natural wrap-around behavior.

### 10.5 Common Mistakes and Solutions

#### 1. Byte Overflow in Operation

```python
# ❌ WRONG
result: word = a + b          # (a, b: byte) - 8-bit operation!

# ✅ CORRECT
result: word = word(a) + word(b)
```

#### 2. Bool Assignment from Large Number

```python
# ❌ WRONG
flag: bool = value            # (value: int = 256) - flag = False!

# ✅ CORRECT
flag: bool = bool(value)      # flag = True
```

#### 3. Integer Division

```python
# ❌ WRONG
result: float = a / b         # (a, b: int) - integer division!

# ✅ CORRECT
result: float = float(a) / float(b)
```

#### 4. Forgotten Explicit f16/f32 Conversion

```python
# ❌ WRONG
x: f16 = 5                    # COMPILE ERROR

# ✅ CORRECT
x: f16 = f16(5)
```

### Type Conversion Flowchart

```
                    Narrowing (data loss!)
              ◄────────────────────────────────

    byte ───► sbyte ───► word ───► int ───► float

              ────────────────────────────────►
                    Widening (safe)

                          │
                    f16 ──┴── f32
                   (explicit conversion required!)
```

---

## 11. Memory and Assignment

### 11.1 Primitive vs Composite Types

| Category  | Types                                     | Storage           |
| --------- | ----------------------------------------- | ----------------- |
| Primitive | byte, sbyte, word, int, float, bool, char | Value directly    |
| Composite | string, array, class instances            | Memory area       |

### 11.2 Assignment Semantics

**For primitive types** the value is copied:

```python
def example():
    a: int = 10
    b: int

    b = a        # b is a COPY, value 10
    b = 20       # a is still 10
```

**For composite types** (objects, arrays) a copy is also made:

```python
def example():
    pos1: Position
    pos2: Position
    pos1()               # Initialize pos1

    pos1.x = 10
    pos2 = pos1          # pos2 is a COPY!
    pos2.x = 100

    # pos1.x = 10 (unchanged)
    # pos2.x = 100
```

> **IMPORTANT - Difference from Python!**
>
> In Python and other dynamic languages, objects are **references** (pointers) to a heap-dynamically allocated memory area. So there `pos2 = pos1` means both variables point to the **same** object:
>
> ```python
> # Python behavior (NOT how PyCo works!)
> pos2 = pos1      # pos2 points to same object
> pos2.x = 100     # pos1.x also becomes 100!
> ```
>
> In PyCo, objects occupy space **directly on the stack**, not pointers - similar to C language `struct` type. So assignment makes a **complete copy** - the two objects are completely independent. If you need reference-like behavior, use [alias](#5-alias-and-references).

### 11.3 Parameter Passing

Behavior of parameters passed to functions differs between primitive and composite types.

**Primitive types - pass by value:**

A **copy** is made of primitive type parameters. Modification inside the function doesn't affect the original:

```python
def add_ten(x: int):
    x = x + 10       # Only local copy is modified

def main():
    n: int = 5

    add_ten(n)
    # n is still 5 - didn't change!
```

**Composite types - required alias:**

Composite types (objects, arrays, strings) can **only be passed as alias**. This is not optional, but a language requirement - the compiler reports an error if you try to use a composite type as parameter without alias.

```python
def modify_enemy(e: alias[Enemy]):    # alias REQUIRED!
    e.x = 100        # ORIGINAL object is modified!

def main():
    enemy: Enemy
    enemy()              # Initialize
    enemy.x = 10

    modify_enemy(enemy)  # Automatically passed as alias
    # enemy.x = 100 - changed!
```

**Why is alias required?** Copying a large object (e.g., 100-byte structure) would be slow and memory-wasting. Alias only passes 2 bytes (an address), and works directly with the original object.

**Summary table:**

| Type      | Passing            | Original modified? | Alias required? |
| --------- | ------------------ | ------------------ | --------------- |
| Primitive | By value           | No                 | No              |
| Composite | Reference (alias)  | Yes                | **Yes!**        |

> **Note:** You don't need to create an alias variable in advance for the call. If a function expects `alias[Enemy]` parameter, you can simply pass the `enemy` variable directly - the compiler automatically handles it as alias.
>
> If you already have an alias variable, you can pass that too - in this case the parameter will point to the object referenced by the alias, not to the alias variable itself.

### 11.4 Stack Frame

When a function is called, the system allocates a memory area for it on the **stack**. This is called a **stack frame**. The function's local variables and parameters are stored here.

Every function call creates a new frame, and when the function returns, it's automatically freed. This is why memory management is "free" - no manual allocation and deallocation needed. This also enables recursion: each call has its own frame with its own variables.

> **Note:** The exact structure of the stack frame is platform-dependent. For details of the C64 implementation, see the [C64 compiler reference](c64_compiler_reference_en.md#stack-frame-structure).

---

## 12. Built-in Functions

PyCo **does not support variable number of arguments** (variadic arguments) in user functions - every function has a fixed number of parameters. However, some built-in functions are special: the compiler knows them and accepts any number of arguments.

### print

Output values to the screen.

```python
print(value)                      # print one value
print(value1, value2, ...)        # print multiple values sequentially
```

**Important differences from Python:**

| Python                      | PyCo                                  |
| --------------------------- | ------------------------------------- |
| `print("Hi")` → `Hi\n`      | `print("Hi")` → `Hi` (no newline!)    |
| `print(a, b)` → `a b\n`     | `print(a, b)` → `ab` (no space!)      |
| `print(a, sep="-", end="")` | Not supported                         |

PyCo does not support **keyword arguments** (`sep=`, `end=`), so Python's `print` behavior cannot be exactly replicated. Instead, **explicit formatting** is the solution:

```python
def example():
    x: int = 10
    name: string = "Player"

    print("Hello\n")              # Explicit newline at the end
    print(x)                      # "10" - without newline
    print(name, " ", x, "\n")     # "Player 10\n" - explicit space
    print(x, "-", y, "-", z)      # "10-20-30" - explicit separator
```

> **Tip:** Using explicit `\n` and spaces makes the code more transparent - immediately visible what will appear.

> **Note:** `print` is a special built-in function. The compiler knows the parameter types at compile time and generates the appropriate output code for each. This is not possible in user functions.

### printsep

Output values with custom separator. Does **not** add newline at the end.

```python
printsep(separator, value1, value2, ...)
```

```python
def example():
    x: int = 10
    y: int = 20

    printsep(", ", x, y, "\n")    # "10, 20, \n"
    printsep("", x, y)            # "1020"
```

### sprint

Write values to a string buffer. Works the same as `print()`, just writes to buffer instead of screen.

```python
sprint(buffer, value1, value2, ...)
```

```python
def example():
    result: string[40]
    score: int = 100

    sprint(result, score)               # result = "100"
    sprint(result, "Score: ", score)    # result = "Score: 100"
```

> **WARNING:** The target buffer must be of sufficient size. There's no overflow checking!

### str

Convert value to string.

```python
str(value) -> string
```

**For objects:** If there's a `__str__` method, it calls that. If not, returns `<ClassName>` format.

```python
class Player:
    name: string[20] = "Hero"
    score: int = 0

    def __str__() -> string:
        result: string[40]
        sprint(result, self.name, ": ", self.score)
        return result

def example():
    p: Player
    p()                  # Initialize
    s: string[40]

    s = str(p)           # "Hero: 0"
```

### len

Get length.

```python
len(s) -> byte           # string length
len(arr) -> byte/word    # array element count
```

**For string** O(1) operation (Pascal-string length byte).

**For array** returns element count. Return type:
- ≤ 256 elements: `byte`
- > 256 elements: `word`

### size

Memory size in bytes.

```python
size(value) -> word
```

| Type   | Returned value                     |
| ------ | ---------------------------------- |
| string | declared size + 1 (length + char.) |
| array  | element count × element size       |
| class  | total size of all properties       |

### getkey

Read keyboard (non-blocking). Returns immediately.

```python
getkey() -> char    # 0 if no key pressed
```

### waitkey

Read keyboard (blocking). Waits for keypress.

```python
waitkey() -> char
```

| Function    | Behavior           | Typical use           |
| ----------- | ------------------ | --------------------- |
| `getkey()`  | Returns immediately | Game control          |
| `waitkey()` | Waits for keypress | "Press any key", menu |

### abs

Absolute value.

```python
abs(value) -> byte/word
```

| Input   | Output | Reason                               |
| ------- | ------ | ------------------------------------ |
| `sbyte` | `byte` | `abs(-128) = 128` doesn't fit sbyte  |
| `int`   | `word` | `abs(-32768) = 32768` doesn't fit int |

### min, max

Smaller/larger of two values.

```python
min(a, b) -> type of a and b
max(a, b) -> type of a and b
```

### blkcpy

Block (rectangle) memory copy. Copies a rectangular region from one array to another.

**7-parameter syntax (common stride):**

```python
blkcpy(src_arr, src_offset, dst_arr, dst_offset, width, height, stride)
```

**8-parameter syntax (separate strides):**

```python
blkcpy(src_arr, src_offset, src_stride, dst_arr, dst_offset, dst_stride, width, height)
```

**Parameters:**

| Parameter    | Type  | Description                               |
| ------------ | ----- | ----------------------------------------- |
| `src_arr`    | array | Source array                              |
| `src_offset` | word  | Starting offset in source (bytes)         |
| `src_stride` | byte  | Source row width (8-param only)           |
| `dst_arr`    | array | Destination array                         |
| `dst_offset` | word  | Starting offset in destination (bytes)    |
| `dst_stride` | byte  | Destination row width (8-param only)      |
| `width`      | byte  | Rectangle width (bytes, max 255)          |
| `height`     | byte  | Rectangle height (rows, max 255)          |
| `stride`     | byte  | Common row width (7-param only)           |

**Use cases:**

```python
screen: array[byte, 1000][0x0400]
buffer: array[byte, 1000][0x8000]
tile: array[byte, 16][0xC000]  # 4x4 tile

# Scroll left by 1 character
blkcpy(screen, 1, screen, 0, 39, 25, 40)

# Scroll up by 1 row
blkcpy(screen, 40, screen, 0, 40, 24, 40)

# Double buffer - copy 20x10 region
blkcpy(buffer, 5*40+10, screen, 5*40+10, 20, 10, 40)

# Tile blit - 4x4 tile with different strides
blkcpy(tile, 0, 4, screen, 5*40+10, 40, 4, 4)
```

**Automatic direction detection:**

For overlapping regions (same array), the compiler automatically selects the correct copy direction:

| Case                              | Direction | Determined at  |
| --------------------------------- | --------- | -------------- |
| Different arrays                  | Forward   | Compile-time   |
| Same array, both offsets constant | Correct   | Compile-time   |
| Same array, variable offset       | Correct   | Runtime        |

### memfill

Fast memory fill. Fills an array with a specified value.

**2-parameter syntax (fill entire array):**

```python
memfill(array, value)
```

**3-parameter syntax (fill first N elements):**

```python
memfill(array, value, count)
```

**Parameters:**

| Parameter | Type        | Description                                        |
| --------- | ----------- | -------------------------------------------------- |
| `array`   | array       | Array to fill (variable or class property)         |
| `value`   | element type| Value to fill with (must match array element type) |
| `count`   | word        | Number of elements to fill (optional)              |

**Key behavior:**
- **2-parameter version:** Fills the ENTIRE array - size is taken from type declaration
- **3-parameter version:** Fills only the first `count` elements

**Examples:**

```python
screen: array[byte, 1000][0x0400]
colorram: array[byte, 1000][0xD800]

# Fill entire screen with spaces (1000 bytes)
memfill(screen, 32)

# Fill entire color RAM with white (1000 bytes)
memfill(colorram, 1)

# Fill only first 40 bytes (one row)
memfill(screen, 0, 40)
```

**Class property support:**

```python
class Display:
    buffer: array[byte, 40][0x0400]

    def clear():
        # Works with self.property - fills entire array
        memfill(self.buffer, 32)
```

**Supported element types:**

| Type    | Size    | Notes                       |
| ------- | ------- | --------------------------- |
| `byte`  | 1 byte  | Direct value (0-255)        |
| `word`  | 2 bytes | Little-endian fill          |
| `int`   | 2 bytes | Same as word                |
| `float` | 4 bytes | MBF32 format fill           |

---

## 13. Special Features

### 13.1 Inline Assembly (__asm__)

> **Note:** Inline assembly is an **optional feature** - compilers are not required to implement it. If a compiler supports it, it must use the unified syntax described here. For example, in a native compiler where there's no intermediate assembly code generation, it may be difficult or impossible to implement.

`__asm__` allows inserting raw assembly code.

```python
__asm__("""
    lda #$00
    sta $d020
""")
```

**When to use:**
- Time-critical loops
- Hardware-specific operations (VIC tricks, SID)
- Special CPU instructions (SEI, CLI, BRK, NOP)

> **Note:** Dedicated decorators will be available in the future for interrupt routines, so inline assembly won't be needed for those.

**Rules:**

| Rule                        | Explanation                                |
| --------------------------- | ------------------------------------------ |
| Only usable in functions    | As a statement, at any point in the code   |
| No variable substitution    | Raw assembly code                          |
| Register preservation       | Programmer's responsibility (A, X, Y, status) |
| No syntax checking          | The PyCo compiler doesn't validate assembly |

**Examples:**

```python
def flash_border():
    __asm__("""
        inc $d020
    """)

def critical_section():
    __asm__("""
        sei
    """)
    # Critical operations...
    __asm__("""
        cli
    """)

def wait_rasterline():
    __asm__("""
    .wait:
        lda $d012
        cmp #$80
        bne .wait
    """)
```

> **Tip:** Before using `__asm__`, try to solve the task in PyCo. Inline assembly should be a last resort.

---

## Appendix

### A. Type Conversion Table

| Source | byte  | sbyte | word  | int   | float | f16   | f32   |
| ------ | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| byte   | =     | cast  | ext   | ext   | conv  | f16() | f32() |
| sbyte  | cast  | =     | ext   | ext   | conv  | f16() | f32() |
| word   | trunc | trunc | =     | cast  | conv  | f16() | f32() |
| int    | trunc | trunc | cast  | =     | conv  | f16() | f32() |
| float  | int() | int() | int() | int() | =     | f16() | f32() |
| f16    | -     | -     | -     | -     | auto  | =     | f32() |
| f32    | -     | -     | -     | -     | auto  | f16() | =     |

Legend:
- `=` : same type
- `ext` : extension (safe)
- `trunc` : truncation (data loss!)
- `cast` : reinterpretation
- `conv` : conversion
- `auto` : automatic
- `f16()/f32()` : explicit required

### B. Cheatsheet for Python Developers

This summary contains the most important differences between Python and PyCo.

#### Types and Declarations

| Python                | PyCo                            | Note                                  |
| --------------------- | ------------------------------- | ------------------------------------- |
| `x = 10`              | `x: int = 10`                   | Type annotation **required**          |
| Variable anywhere     | Variables at function **start** | Pascal-style                          |
| `x = get_value()`     | ❌ Not allowed in declaration    | Only constant default value           |
| `global x`            | `X = 10` (UPPERCASE)            | No global variable, only constant     |
| `list`, `dict`, `set` | `array[type, size]`             | Fixed size, static                    |
| `[1, 2, 3]`           | `= (1, 2, 3)`                   | Tuple syntax for array                |
| `tuple` (dynamic)     | `tuple[type]`                   | Fixed, read-only, data segment        |
| `str` (dynamic)       | `string[size]`                  | Fixed size (Pascal-style)             |

#### Classes and Objects

| Python                            | PyCo                        | Note                                    |
| --------------------------------- | --------------------------- | --------------------------------------- |
| `obj = Class()`                   | `obj: Class` then `obj()`   | Declaration and initialization separate |
| `def method(self, x):`            | `def method(x: int):`       | `self` **not needed** in parameter list |
| `obj2 = obj1` → both same         | `obj2 = obj1` → **copy**    | Stack-based, not reference              |
| Multiple inheritance              | Single inheritance          | `class Child(Parent):`                  |
| `isinstance()`, polymorphism      | ❌ None                      | No dynamic type handling                |
| Garbage collection                | ❌ None                      | Stack automatically freed               |

#### Functions

| Python          | PyCo                      | Note                            |
| --------------- | ------------------------- | ------------------------------- |
| `def f(*args):` | ❌ No variadic             | Fixed parameter count           |
| `def f(x=10):`  | ❌ No default value        | All parameters must be given    |
| `f(name="x")`   | ❌ No keyword arg          | Only positional                 |
| `return obj`    | `return obj` → `alias[T]` | Composite type only as alias    |
| `lambda x: x+1` | ❌ No lambda               | Only `def`                      |

#### Print and I/O

| Python                 | PyCo                 | Note                                 |
| ---------------------- | -------------------- | ------------------------------------ |
| `print("Hi")` → `Hi\n` | `print("Hi")` → `Hi` | **No** automatic newline             |
| `print(a, b)` → `a b`  | `print(a, b)` → `ab` | **No** automatic space               |
| `print(x, sep="-")`    | `printsep("-", x, y)` or `print(x, "-", y)` | Dedicated function or explicit |
| `s = f"x={x}"`         | `sprint(s, "x=", x)` | `sprint(buffer, ...)` writes to buffer |

#### Control Structures

| Python                  | PyCo                    | Note                               |
| ----------------------- | ----------------------- | ---------------------------------- |
| `for i in range(10):`   | `for i in range(10):`   | ✅ Same                             |
| `for _ in range(10):`   | `for _ in range(10):`   | ✅ Same - optimized with HW stack   |
| `for item in list:`     | ❌ No foreach            | Only index-based iteration         |
| `try/except`            | ❌ No exception handling | Error handling is programmer's job |
| `with`                  | ❌ No context manager    |                                    |

#### Unsupported Python Features

- ❌ `list`, `dict`, `set` (dynamic collections)
- ❌ List comprehension (`[x*2 for x in items]`)
- ❌ Generator, `yield`
- ❌ Decorator (except built-in: `@lowercase`, `@kernal`, `@noreturn`, `@origin`, `@irq`, `@irq_raw`, `@irq_hook`, `@naked`, `@forward`, `@mapped`, `@relocate`)
- ❌ `async`/`await`
- ❌ `import` (partially supported)
- ❌ Multi-line string (`"""..."""`)
- ❌ f-string (`f"Hello {name}"`)
- ❌ `None` (use `0` or empty string)
- ❌ `__slots__`, `@property`, `@classmethod`, `@staticmethod`

#### Quick Reference

```python
# Python                          # PyCo

class Enemy:                      class Enemy:
    def __init__(self, hp):           hp: int = 100
        self.hp = hp                  def __init__(hp_val: int):
                                          self.hp = hp_val

def greet(name="World"):          def greet(name: alias[string]):
    print(f"Hello {name}!")           print("Hello ", name, "!\n")

def main():                       def main():
    x = 10                            x: int = 10
    name = "hello"                    name: string = "hello"
    items = [0] * 100                 items: array[byte, 100] = [0]
    data = [1, 2, 3]                  data: array[byte, 3] = (1, 2, 3)
    e = Enemy(50)                     e: Enemy           # Declaration
                                      e(50)              # Initialization
```
