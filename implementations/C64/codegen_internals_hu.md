# PyCo Kódgenerátor - Belső Implementáció

Ez a dokumentum a PyCo fordító kódgenerátor komponensének **belső implementációs részleteit** tartalmazza. Fejlesztőknek szól, akik a fordítót módosítani vagy megérteni szeretnék.

> **Felhasználóknak:** A nyelvi funkciókat lásd a [Nyelvi referenciában](../../language-reference/language_reference_hu.md), a C64-specifikus részleteket pedig a [C64 Compiler Reference-ben](c64_compiler_reference_hu.md).

## 1. Áttekintés

A kódgenerátor a validált AST-ből 6502 assembly kódot állít elő:

```
┌─────────┐    ┌──────────┐    ┌───────────┐    ┌────────────┐    ┌─────────┐
│ Parser  │ →  │ Include  │ →  │ Validator │ →  │ CodeGen    │ →  │ .asm    │
│         │    │ Resolver │    │           │    │            │    │ output  │
└─────────┘    └──────────┘    └───────────┘    └────────────┘    └─────────┘
```

### 1.1 Modul struktúra

```
src/pyco/compiler/codegen/
├── __init__.py          # Public API: generate()
├── generator.py         # Fő AST visitor, statement-ek
├── expressions.py       # Kifejezések kódgenerálása
├── emitter.py           # Assembly kimenet builder
├── size_estimator.py    # Branch távolság becslés
├── float_routines.py    # Float assembly helperek
└── fixed_routines.py    # f16/f32 assembly helperek
```

### 1.2 Generálás fázisai

1. **Symbol Collection** - Konstansok, osztály layoutok, függvény signatúrák összegyűjtése
2. **Code Generation** - AST bejárás, assembly generálás, label management
3. **Output** - Runtime helperek beillesztése, szegmensek rendezése

---

## 2. Memória és Zero Page

A C64 memória layout és Zero Page kiosztás részleteit lásd: [C64 Compiler Reference - 2. Memória architektúra](c64_compiler_reference_hu.md#2-memória-architektúra)

### 2.1 Típusok memória reprezentációja

#### Primitív típusok

| Típus  | Méret   | Reprezentáció                         |
| ------ | ------- | ------------------------------------- |
| bool   | 1 byte  | 0 = false, ≠0 = true                  |
| char   | 1 byte  | PETSCII kód                           |
| byte   | 1 byte  | 0-255 unsigned                        |
| sbyte  | 1 byte  | -128 to 127 signed (two's complement) |
| word   | 2 bytes | Little-endian, 0-65535                |
| int    | 2 bytes | Little-endian, -32768 to 32767 signed |
| float  | 4 bytes | Microsoft Binary Format (MBF) 32-bit  |

#### String

Pascal-típusú string: első byte a hossz, utána a karakterek.

```
┌────────┬────────┬────────┬─────┬────────┐
│ length │ char 0 │ char 1 │ ... │ char N │
│ 1 byte │ 1 byte │ 1 byte │     │ 1 byte │
└────────┴────────┴────────┴─────┴────────┘
```

**Deklaráció és méret:**

| Szintaxis               | Lefoglalt méret | Magyarázat                       |
| ----------------------- | --------------- | -------------------------------- |
| `s: string = "Hello"`   | 6 byte          | Konstansból: 1 (hossz) + 5 (kar) |
| `s: string[80]`         | 81 byte         | Explicit buffer méret            |
| `s: string[80] = "Hi"`  | 81 byte         | Buffer + kezdőérték              |
| `s: string[40][0x0400]` | 0 byte (mapped) | Memory-mapped, fix címen         |

#### Array

Fix méretű, folytonos memóriaterület. Az index típusa automatikus:
- ≤256 elem: byte index (gyorsabb)
- >256 elem: word index

#### Osztály instance

Az osztály példány a property-k sorrendjében tárolja az adatokat:

```python
class Enemy:
    x: byte = 0
    y: byte = 0
    health: int = 100
```

Memóriában (5 byte):
```
┌────────┬────────┬──────────────┐
│ x      │ y      │ health       │
│ 1 byte │ 1 byte │ 2 bytes (LE) │
│ off 0  │ off 1  │ off 2        │
└────────┴────────┴──────────────┘
```

---

## 3. Függvényhívási konvenció

### 3.1 Software Stack

A 6502 hardver stackje csak 256 byte. Ezért **software stack**-et használunk a lokális változókhoz.

**Nincs fix méretkorlát!** A stack a program végétől indul és felfelé nő:

```
$0801         ┌─────────────────────────────┐
              │ Program (code + data + bss) │
$xxxx         └─────────────────────────────┘ ← __program_end
              ┌─────────────────────────────┐
              │ STACK                       │
              │ (felfelé nő, ameddig kell)  │
$CFFF         └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘
```

**Inicializálás:**
```asm
.label __program_end = *
.label SSP = $0A

_pyco_init:
    // BASIC ROM kikapcsolása
    lda $01
    and #%11111110
    sta $01

    // Stack pointer inicializálása
    lda #<__program_end
    sta SSP
    lda #>__program_end
    sta SSP+1

    jmp main
```

### 3.2 Hívási sorrend

1. **Caller** (hívó):
   - Stack frame növelése a paramétereknek
   - Paraméterek a stack-re
   - `jsr function_name`
   - Visszatérési érték: `retval` ($0F-$12)

2. **Callee** (hívott):
   - Stack frame növelése a lokális változóknak
   - Függvény törzs végrehajtása
   - Frame cleanup (params + locals)
   - `rts`

**Generált kód struktúra:**
```asm
function_name:
    // Prologue: FP mentése, locals allokálása
    lda FP
    pha
    lda FP+1
    pha

    clc
    lda SSP
    sta FP
    adc #LOCAL_SIZE
    sta SSP
    bcc +
    inc SSP+1
+:
    // ... function body ...

    // Epilogue: locals felszabadítása, FP visszaállítása
    sec
    lda SSP
    sbc #LOCAL_SIZE
    sta SSP
    bcs +
    dec SSP+1
+:
    pla
    sta FP+1
    pla
    sta FP
    rts
```

### 3.3 Paraméter átadás

| Kategória             | Paraméter típus           | Átadás módja          | Hely        |
| --------------------- | ------------------------- | --------------------- | ----------- |
| Primitív (1-2B)       | `byte`, `int`, stb.       | Érték szerint         | Stack frame |
| Összetett (közvetlen) | `Enemy`, `array[byte,10]` | **FORDÍTÁSI HIBA**    | -           |
| Alias                 | `alias[Enemy]`            | Pointer (2 byte)      | Stack frame |

**Automatikus cím átadás alias paramétereknél:**

```python
def process(e: alias[Enemy]):
    e.x = 50

def main():
    enemy: Enemy
    process(enemy)  # Fordító: process(addr(enemy))
```

### 3.4 Visszatérési érték

| Kategória         | Visszatérési típus | Hol van az érték      | Élettartam          |
| ----------------- | ------------------ | --------------------- | ------------------- |
| Primitív (1 byte) | `byte`, `bool`     | A regiszter           | Azonnal használható |
| Primitív (2 byte) | `word`, `int`      | `retval` ($0F-$10)    | Azonnal használható |
| Primitív (4 byte) | `float`            | `retval` ($0F-$12)    | Azonnal használható |
| Alias             | `alias[Enemy]`     | `retval` (pointer)    | Statement végéig!   |

---

## 4. Metódusok és Self (ZP_SELF optimalizáció)

### 4.1 Self mint ZP-optimalizált pointer

A `self` pointer **Zero Page cache-be ($16-$17 = ZP_SELF)** töltődik a gyors property hozzáféréshez.

```asm
// === MAIN-BŐL HÍVÁS: player.move(10, 5) ===
// 1. Load player címe ZP_SELF-be
lda #<__B_player
sta ZP_SELF
lda #>__B_player
sta ZP_SELF+1

// 2. Explicit paraméterek push
// ...

// 3. Metódus hívás
jsr __C_Player_move
// KÖLTSÉG: ~12 ciklus (ZP load)

// === SAJÁT METÓDUS HÍVÁS: self.update() ===
// self már ZP_SELF-ben van!
jsr __C_Player_update
// KÖLTSÉG: 0 extra ciklus!
```

### 4.2 Property elérés metódusból

```python
self.health += 10
```

**Assembly (ZP-optimalizált):**
```asm
// self.health olvasás és módosítás (offset 2, word)
ldy #2
lda (ZP_SELF),y      // health low - ZP indirect!
clc
adc #10
pha
iny
lda (ZP_SELF),y      // health high
adc #0
tax

// self.health írás
ldy #2
pla
sta (ZP_SELF),y      // health low
iny
txa
sta (ZP_SELF),y      // health high
```

### 4.3 Másik objektum hívása (ZP save/restore)

```python
def process_bullet(self, bullet: Bullet):
    bullet.update()      # Nested call - másik objektum!
    self.score += 10     # self-et vissza kell állítani
```

```asm
__C_Player_process_bullet:
    // === NESTED CALL - MÁSIK OBJEKTUM ===
    // 1. ZP_SELF mentése stackre
    lda ZP_SELF
    pha
    lda ZP_SELF+1
    pha

    // 2. Új self betöltése (bullet pointer)
    // ... bullet pointer load ...

    // 3. Metódus hívás
    jsr __C_Bullet_update

    // 4. Eredeti ZP_SELF visszaállítása
    pla
    sta ZP_SELF+1
    pla
    sta ZP_SELF

    // === Most self ismét a Player objektum ===
    // self.score += 10
    ldy #SCORE_OFFSET
    lda (ZP_SELF),y
    // ...
```

### 4.4 Teljesítmény összefoglaló

| Eset                       | ZP_SELF művelet        | Költség       |
| -------------------------- | ---------------------- | ------------- |
| `player.move()`            | Load to ZP             | ~12 ciklus    |
| `self.update()`            | **NINCS**              | **0 ciklus!** |
| `other.update()`           | Save + Load + Restore  | ~30 ciklus    |
| Property access (`self.x`) | **NINCS** (ZP van!)    | ~7 ciklus     |

---

## 5. Deferred Cleanup ("Szegényember GC")

### 5.1 A probléma

Összetett típusok visszatérése függvényből problémás:

```python
def create_enemy() -> alias[Enemy]:
    e: Enemy
    e()
    e.x = 50
    return e    # e a stack frame-en van!

def main():
    enemy: Enemy = create_enemy()  # Hova másolódik?
```

A `return e` után a függvény stack frame-je felszabadul, de az `e` pointer még oda mutat → **dangling pointer**!

### 5.2 Megoldás: Deferred Cleanup

**Alapötlet:** Ne takarítsunk azonnal! A "garbage" maradjon a stack-en a statement végéig.

```
Normál return:              Deferred cleanup:

[caller][called][SSP]       [caller][called][SSP]
         ↓                           ↓
[caller][SSP]               [caller][called_"garbage"][SSP] ← marad!
    (azonnal takarít)                ↓
                            Statement végén:
                            [caller][SSP] ← MOST takarít!
```

### 5.3 Szabályok

1. **Primitív típus return** (`byte`, `int`, `bool`, stb.):
   - Normál stack cleanup a függvény végén
   - Érték A regiszterben (1 byte) vagy retval-ban (2-4 byte)

2. **Alias return** (`alias[Enemy]`, `alias[array[byte,10]]`, stb.):
   - **NE** csökkentsd az SSP-t a függvény végén!
   - A lokálisok (beleértve a return értéket) ottmaradnak
   - `retval` pointer mutat rájuk

3. **Statement wrapper:**
   - Statement elején: SSP mentése **hardware stack-re (PHA)**
   - Statement végén: SSP visszaállítása **hardware stack-ről (PLA)**
   - Az alias élettartama pontosan a statement végéig tart!

### 5.4 Implementáció

#### Függvény return generálás

**Fájl:** `src/pyco/compiler/codegen/generator.py` - `_gen_return()` metódus

```python
def _is_alias_return(self) -> bool:
    """Check if current function returns an alias type."""
    if self.current_function:
        func_sig = self.symbols.get_function(self.current_function)
        if func_sig and func_sig.return_type:
            return func_sig.return_type.startswith("alias[")
    return False
```

**Generált assembly alias return esetén:**

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

**Fájl:** `src/pyco/compiler/codegen/generator.py` - `_generate_statement()` metódus

```python
def _needs_deferred_cleanup(self, node: ast.stmt) -> bool:
    """Check if statement needs SSP save/restore for deferred cleanup."""
    for child in ast.walk(node):
        if isinstance(child, ast.Call):
            # Check if function returns alias type
            # ...
    return False
```

**Generált assembly:**

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

### 5.5 Nested hívások

```python
process(create_enemy(), create_item())
```

```
Állapot                              SSP         Hardware Stack
──────────────────────────────────────────────────────────────────
Statement eleje                      X           [SSP_hi][SSP_lo]
create_enemy() hívás után            X + frame   [SSP_hi][SSP_lo]
create_item() hívás után             X + frame2  [SSP_hi][SSP_lo]
process() hívás után                 X + ...     [SSP_hi][SSP_lo]
Statement vége                       X           (visszaállítva!)
```

**Miért hardware stack?** A ZP regisztereket a for loop használja, és nested hívások felülírnák. A hardware stack LIFO természetesen kezeli a beágyazott hívásokat.

### 5.6 Trade-offs

**Előnyök:**
- Egyszerű implementáció - nincs bonyolult lifetime tracking
- Nincs "return buffer" pre-allokáció
- Univerzális megoldás - string, array, object mind ugyanígy működik
- Zero-copy lehetőség - ha azonnal használjuk
- Hardware stack LIFO - természetesen kezeli nested hívásokat

**Hátrányok:**
- Stack pazarlás (de csak statement végéig!)
- Mély láncok sok stack-et esznek: `a(b(c(d(e()))))`
- Hardware stack limit: 256 byte (~40-60 nested szint)
- +12 ciklus overhead statement-enként ami cleanup-ot igényel

---

## 6. Alias típus implementáció

Az `alias[T]` egy típusos dinamikus referencia (2 byte pointer).

### 6.1 addr() függvény

```asm
// addr(enemy) - stack változó esetén
clc
lda FP
adc #ENEMY_OFFSET
sta tmp0
lda FP+1
adc #0
sta tmp1

// addr(enemy) - BSS változó esetén
lda #<__B_enemy
sta tmp0
lda #>__B_enemy
sta tmp1
```

### 6.2 alias() függvény

```asm
// alias(e, addr(enemy))
lda tmp0
ldy #0
sta (FP),y        // alias low byte
lda tmp1
iny
sta (FP),y        // alias high byte
```

### 6.3 Property elérés alias-on keresztül

```asm
// e.x olvasása (ahol e egy alias[Enemy])
ldy #ALIAS_OFFSET
lda (FP),y        // Pointer low byte → tmp0
sta tmp0
iny
lda (FP),y        // Pointer high byte → tmp1
sta tmp1
ldy #OFFSET_X     // x property offset
lda (tmp0),y      // Indirect indexed load
```

### 6.4 Teljesítmény

| Művelet                | Ciklus (kb.) | Megjegyzés                 |
| ---------------------- | ------------ | -------------------------- |
| Memory-mapped elérés   | 4-6          | Közvetlen cím, leggyorsabb |
| Alias elérés           | 12-16        | Pointer load + indirect    |
| Lokális változó elérés | 8-10         | Frame pointer + indirect   |

---

## 7. Runtime Helpers

### 7.1 Szelektív Runtime Linking

A PyCo fordító **csak azokat a runtime helpereket** illeszti be, amelyeket a program ténylegesen használ.

**Implementáció:**

```python
# generator.py-ban
class CodeGenerator:
    used_helpers: set[str] = set()

    def use_helper(self, name: str):
        self.used_helpers.add(name)

    def emit_runtime_helpers(self):
        for helper in self.used_helpers:
            self.emitter.emit(RUNTIME_CODE[helper])
```

**Példák:**

| Program használ        | Beillesztett helperek |
| ---------------------- | --------------------- |
| `print("Hello")`       | `__R_print_str`       |
| `print(x)` ahol x: int | `__R_print_int`       |
| `a * b` ahol int       | `__R_mul16`           |
| `str(x)` ahol x: byte  | `__R_str_byte`        |
| semmi special          | **SEMMI**             |

### 7.2 Helper lista

| Rutin            | Funkció                       | Mikor kell        |
| ---------------- | ----------------------------- | ----------------- |
| `__R_mul8`       | 8-bit szorzás                 | `byte * byte`     |
| `__R_mul16`      | 16-bit szorzás                | `int * int`       |
| `__R_div8`       | 8-bit osztás                  | `byte / byte`     |
| `__R_div16`      | 16-bit osztás                 | `int / int`       |
| `__R_print_byte` | Byte kiírás decimálisan       | `print(byte_var)` |
| `__R_print_int`  | Int kiírás decimálisan        | `print(int_var)`  |
| `__R_print_str`  | String kiírás (Pascal format) | `print(str_var)`  |
| `__R_strcpy`     | String másolás                | `s1 = s2`         |
| `__R_memcpy`     | Memória másolás               | array/object copy |
| `__R_str_byte`   | Byte → string konverzió       | `str(byte_var)`   |
| `__R_str_int`    | Int → string konverzió        | `str(int_var)`    |
| `__R_str_bool`   | Bool → string konverzió       | `str(bool_var)`   |
| `__R_str_float`  | Float → string konverzió      | `str(float_var)`  |

---

## 8. str() és __str__ implementáció

### 8.1 Fordítási logika

1. **Primitív típusok** → `__R_str_*` runtime helper hívás
2. **Objektumok `__str__` metódussal** → `__C_ClassName___str__` hívás
3. **Objektumok `__str__` nélkül** → konstans string: `"<ClassName>"`

### 8.2 Generált kód példa

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
// str(player) hívás → __C_Player___str__
    // 1. self pointer ZP_SELF-be töltése
    lda #<__B_player
    sta ZP_SELF
    lda #>__B_player
    sta ZP_SELF+1

    // 2. Metódus hívás
    jsr __C_Player___str__

    // 3. retval most a string pointert tartalmazza
```

**`__str__` nélküli osztály:**

```asm
// str(enemy) → konstans string
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

## 9. Optimalizációs lehetőségek

### 9.1 Implementált optimalizációk

Lásd: [C64 Compiler Reference - Optimalizációk](c64_compiler_reference_hu.md)

### 9.2 Tervezett dekorátorok (nem implementált)

```python
@fastcall                    # ZP paraméterek - nested hívás TILOS
def critical_inner_loop(x: byte, y: byte):
    ...

@inline                      # Függvény beillesztése hívás helyett
def tiny_helper() -> byte:
    ...
```

---

## 10. Teljes fordítási példa

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
    // self pointer már ZP_SELF-ben van
    lda #0
    ldy #0
    sta (ZP_SELF),y   // value = 0
    rts

__C_Counter_increment:
    // self pointer már ZP_SELF-ben van
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

    // c: Counter - stack allokáció
    // c() - konstruktor
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

    // c.increment() - self már ZP_SELF-ben!
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
