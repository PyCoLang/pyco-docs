# PyCo Modul Rendszer - Tervezési Dokumentum

## Áttekintés

A PyCo modul rendszer lehetővé teszi külső kód használatát más `.pyco` fájlokból. A rendszer két működési módot támogat:

1. **Statikus import** (top-level): Compile-time linkelés, a kód befordul a binárisba
2. **Dinamikus import** (function-level): Runtime betöltés, scope-alapú élettartam

### Tervezési elvek

- **Egyszerűség**: Nincs relokációs tábla, marker-byte alapú relokáció
- **Hatékonyság**: Nulla overhead a modul méretben
- **Scope = Lifetime**: A modul élettartama = a betöltő scope élettartama
- **Automatikus takarítás**: Függvény return → modul memória felszabadul
- **Python-szerű szintaxis**: Ismerős, nincs új koncepció

## Import Szintaxis

### Alapok

```python
from module_name import name1, name2, name3
```

- **Kötelező felsorolás**: Minden használt nevet fel kell sorolni
- **Nincs wildcard**: `from X import *` NEM támogatott
- **Prefix nélküli használat**: Az importált nevek közvetlenül használhatók

### Példa

```python
from math import sin, cos
from gfx import Sprite, draw_line

def main():
    x = sin(0.5)           # Közvetlenül használható, nincs prefix!
    y = cos(0.5)
    draw_line(0, 0, x, y)
```

### Alias (`as`) támogatás

Névütközés esetén vagy rövidítéshez:

```python
from math import sin as math_sin
from audio import sin as audio_sin    # Más modul, azonos név

x = math_sin(0.5)
freq = audio_sin(440)

# Rövidítés:
from very_long_module import some_function as sf
sf()
```

### Névütközés = fordítási hiba

```python
from math import sin
from audio import sin     # HIBA: 'sin' already imported from 'math'!

# Megoldás - használj alias-t:
from math import sin
from audio import sin as audio_sin   # OK
```

## Két Import Mód

### Statikus Import (Top-level)

A fájl elején található import **compile-time** linkelődik:

```python
# Fájl eleje - STATIKUS import
from math import sin, cos
from gfx import Sprite

def main():
    x = sin(0.5)             # Direct call, nincs runtime overhead
    s: Sprite
    s()
```

**Jellemzők:**
- A modul kódja befordul a PRG-be
- Nincs runtime betöltés, nincs disk I/O
- A compiler ellenőrzi a típusokat és paramétereket
- Tree-shaking: csak a használt függvények kerülnek be

### Dinamikus Import (Function-level)

Függvényen belüli import **runtime** töltődik be:

```python
def game_screen():
    # DINAMIKUS import - runtime betöltés
    from my_game_utils import sin, cos, update_pos
    from sprites import PlayerSprite

    init()
    player: PlayerSprite
    player()

    while not game_over:
        player.update()
        x = sin(angle)

    # ← Függvény vége: modulok AUTOMATIKUSAN felszabadulnak!

def main():
    while True:
        choice = menu_screen()
        if choice == 1:
            game_screen()      # Modul betöltődik, majd felszabadul
        elif choice == 2:
            options_screen()   # Teljesen más modulok tölthetők
```

**Jellemzők:**
- A modul a stack-re töltődik
- Scope vége = automatikus memória felszabadítás
- Több modul használhatja ugyanazt a memóriát (egymás után)
- Végtelen méretű program lehetséges (részletekben töltve)

## Export Szabályok

### Python-szerű konvenció

```python
# Egyszerű szabály:
# _prefix = privát (NEM exportálva)
# Nincs prefix = publikus (exportálva)
```

### Saját kód exportálása

```python
# math.pyco

def sin(x: float) -> float:         # ✓ Exportálva (publikus)
    return _sin_impl(x)

def cos(x: float) -> float:         # ✓ Exportálva (publikus)
    return _cos_impl(x)

def _sin_impl(x: float) -> float:   # ✗ NEM exportálva (privát)
    ...

def _normalize(x: float) -> float:  # ✗ NEM exportálva (privát)
    ...

LOOKUP_TABLE: tuple[byte] = (...)   # ✓ Exportálva (publikus konstans)

_INTERNAL_BUFFER: array[byte, 64]   # ✗ NEM exportálva (privát adat)
```

### Statikus import és export

A statikusan importált nevek **automatikusan exportálva** lesznek, KIVÉVE ha `_` prefixes alias-t kapnak:

```python
# my_game_utils.pyco - saját "csomag" összeállítása

# Ezek PUBLIKUSAK lesznek (exportálva):
from math import sin, cos
from physics import update_pos
from gfx import draw_sprite

# Ez PRIVÁT marad (nem exportálva):
from internal import debug_helper as _debug

# Saját publikus függvény:
def rotate(x: int, y: int, angle: float) -> int:
    _debug("rotating...")      # Belsőleg használja
    return int(x * cos(angle) - y * sin(angle))

# Saját privát függvény:
def _internal_calc() -> int:
    ...
```

**Eredmény - my_game_utils.pycom exportjai:**

| Név | Forrás | Exportálva? |
|-----|--------|-------------|
| `sin` | math | ✓ Igen |
| `cos` | math | ✓ Igen |
| `update_pos` | physics | ✓ Igen |
| `draw_sprite` | gfx | ✓ Igen |
| `rotate` | saját | ✓ Igen |
| `_debug` | internal (as _debug) | ✗ Nem |
| `_internal_calc` | saját | ✗ Nem |

### Privát import tesztelése

```python
# main.pyco
from my_game_utils import sin, cos, rotate    # ✓ OK
from my_game_utils import _debug              # ✗ HIBA: '_debug' is private
```

## Egyedi Modul Összeállítás

### Koncepció

Ha nagy lib-ekből csak néhány függvényre van szükség, készíthetsz saját modult:

```
┌─────────────────────────────────────────────────────────┐
│ NAGY LIB-EK:                                            │
│   math.pyco (20 függvény)                               │
│   gfx.pyco (30 függvény)                                │
│   physics.pyco (15 függvény)                            │
└────────────────────┬────────────────────────────────────┘
                     │ statikus import (válogatás)
                     ▼
┌─────────────────────────────────────────────────────────┐
│ SAJÁT MODUL (csak ami kell + saját kód):                │
│   my_game_utils.pyco:                                   │
│     from math import sin, cos      # 2 függvény        │
│     from gfx import draw_sprite    # 1 függvény        │
│     def rotate(): ...              # saját             │
│                                                         │
│   Fordítás: pycoc compile my_game_utils.pyco --module  │
│   Eredmény: MY_GAME_UTILS.PYCOM (kis méret!)           │
└────────────────────┬────────────────────────────────────┘
                     │ dinamikus import (runtime)
                     ▼
┌─────────────────────────────────────────────────────────┐
│ FŐ PROGRAM:                                             │
│   def game_screen():                                    │
│       from my_game_utils import sin, cos, rotate       │
│       ...                                               │
└─────────────────────────────────────────────────────────┘
```

### Előnyök

- **Tree-shaking**: Csak a használt függvények fordulnak be
- **Fejlesztői kontroll**: Te döntöd el, mi tartozik össze
- **Nincs új koncepció**: Modul = modul, csak összeállítod
- **Saját kód**: Keverve az importáltakkal

## Marker-Byte Relokáció

### A probléma

A 6502 abszolút címzést használ. Ha egy modult különböző címekre töltünk:

```asm
; Eredeti cím: $0000
start:
    JSR $0050        ; ← Ezt át kell írni!
    LDA $0100        ; ← Ezt is!
    STA $D400        ; ← Ezt NEM (HW regiszter)
```

### A megoldás: Marker-byte

A C64 memória térképe segít:

| Cím tartomány | Tartalom | Modul ugorhat ide? |
|---------------|----------|-------------------|
| `$0000-$00FF` | Zero Page | ❌ SOHA (adat) |
| `$0100-$01FF` | Hardware Stack | ❌ SOHA (adat) |
| `$0200-$02FF` | OS változók | ❌ SOHA |
| `$0300-$03FF` | Vektorok, buffer | ❌ SOHA |
| `$0400-$07FF` | Screen RAM (alapból) | ❌ SOHA (adat) |
| `$0800-$FFFF` | **Program terület** | ✓ IGEN |

**Következtetés:** Ha egy címben a high byte `$00-$07`, az **garantáltan modul-belső cím**, amit relokálni kell!

### Marker tartomány

```
High byte: $00-$07 = MARKER (relokálandó)
High byte: $08-$FF = FIX cím (HW regiszter, külső cím)

Offset számítás:
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
Összesen: 2048 byte (2KB) belső címzés
```

### Relokáció betöltéskor

```asm
; Modul betöltés $C000-ra
; base_page = $C0

relocate:
    LDY #0
.loop:
    LDA (module_ptr),Y      ; Byte olvasása

    ; Ha ez egy cím high byte pozíciója ÉS < $08:
    CMP #$08
    BCS .no_reloc           ; >= 8: fix cím, hagyni

    CLC
    ADC base_page           ; $00 + $C0 = $C0
                            ; $05 + $C0 = $C5
.no_reloc:
    STA (dest_ptr),Y
    INY
    ; ...
```

### Példa

```
Modul eredetileg $0000-ra fordítva:
────────────────────────────────────
$0000: JSR $0050     ; 20 50 00  → marker $00
$0003: LDA $0100     ; AD 00 01  → marker $01
$0006: STA $D400     ; 8D 00 D4  → fix (SID regiszter)
...
$0050: internal_func
$0100: singleton_data

Betöltés $C000-ra:
────────────────────────────────────
$C000: JSR $C050     ; 20 50 C0  ✓
$C003: LDA $C100     ; AD 00 C1  ✓
$C006: STA $D400     ; 8D 00 D4  ✓ (változatlan!)
```

### Előnyök

| Tulajdonság | Érték |
|-------------|-------|
| Relokációs tábla mérete | **0 byte!** |
| Extra modul overhead | **0 byte!** |
| Loader komplexitás | Nagyon egyszerű |
| Max modul belső méret | 2KB (bővíthető long jump-pal) |

## Modul Fájl Formátum (.PYCOM)

### Struktúra

```
┌─────────────────────────────────────────────────────────┐
│ HEADER (csak fordító olvassa - NEM töltődik be!)        │
├─────────────────────────────────────────────────────────┤
│ magic (5 byte): "PYCOM"                                 │
│ version (1 byte): 1                                     │
│ header_size (2 byte): header teljes mérete              │
│ code_size (2 byte): betöltendő kód+adat mérete          │
│ entry_count (1 byte): belépési pontok száma             │
│ symbol_count (2 byte): szimbólumok száma                │
├─────────────────────────────────────────────────────────┤
│ ENTRY TABLE (entry_count × 4 byte)                      │
│   [0] offset (2 byte) + name_idx (2 byte)               │
│   [1] offset (2 byte) + name_idx (2 byte)               │
│   ...                                                   │
├─────────────────────────────────────────────────────────┤
│ SYMBOL TABLE (fordítónak - típusinfo, paraméterek)      │
│   Minden exportált függvény/osztály:                    │
│   - name (null-terminated)                              │
│   - type (function/class/singleton)                     │
│   - signature (mangled, paraméter típusok)              │
│   - entry_index (melyik entry point)                    │
├─────────────────────────────────────────────────────────┤
│ (header vége - eddig olvassa a fordító)                 │
╞═════════════════════════════════════════════════════════╡
│ CODE + DATA (ez töltődik be futáskor!)                  │
├─────────────────────────────────────────────────────────┤
│ JUMP TABLE (entry_count × 3 byte)                       │
│   JMP entry_0_code      ; $4C xx xx                     │
│   JMP entry_1_code      ; $4C xx xx                     │
│   ...                                                   │
├─────────────────────────────────────────────────────────┤
│ CODE                                                    │
│   entry_0_code: ...                                     │
│   entry_1_code: ...                                     │
│   internal_functions: ...                               │
├─────────────────────────────────────────────────────────┤
│ SINGLETON DATA (ha van)                                 │
│   field1: .byte 0                                       │
│   field2: .word 0                                       │
│   ...                                                   │
└─────────────────────────────────────────────────────────┘
```

### Header és Code szétválasztása

**Fontos:** A header tartalmazza a típusinformációkat, de ez **NEM töltődik be** a C64-re!

1. **Fordításkor**: A compiler megnyitja a `.pycom` fájlt, olvassa a header-t:
   - Ellenőrzi: létezik-e az importált név?
   - Ellenőrzi: publikus-e? (nincs `_` prefix)
   - Ellenőrzi: paraméter típusok stimmelnek?
   - Megjegyzi: entry point index

2. **Futáskor**: Csak a CODE+DATA rész töltődik be:
   - A header kimarad (seek a code_offset-re)
   - Relokáció a marker-byte alapján
   - Jump table használható

### Name Mangling

A szimbólum táblában a függvények mangled névvel szerepelnek:

```
sin(angle: float) -> float
  → _F_sin_f_f    (Function, param: float, return: float)

set_volume(ch: byte, vol: byte)
  → _F_set_volume_bb  (params: byte, byte)

Player.update(self)
  → _M_Player_update  (Method of Player)
```

Ez lehetővé teszi a típusellenőrzést fordításkor.

## Betöltési Mechanizmus

### Statikus Import (compile-time)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Fordító látja: from math import sin                  │
│                          ↓                              │
│ 2. Megnyitja: math.pycom                                │
│    - Olvassa a header-t                                 │
│    - Ellenőrzi: van 'sin' szimbólum? ✓                  │
│    - Ellenőrzi: publikus? ✓ (nincs _ prefix)            │
│    - Ellenőrzi: paraméterek OK? ✓                       │
│    - Megjegyzi: sin = entry index 0                     │
│                          ↓                              │
│ 3. Beolvassa a CODE+DATA részt                          │
│    - Beilleszti a PRG-be                                │
│    - Compile-time relokáció (ismert fix cím)            │
│                          ↓                              │
│ 4. Hívás: JSR sin_relocated_address                     │
└─────────────────────────────────────────────────────────┘
```

### Dinamikus Import (runtime)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Kód: from my_utils import sin, rotate                │
│                          ↓                              │
│ 2. Generált kód futáskor:                               │
│    __R_module_load("MY_UTILS.PYCOM")                    │
│    - OPEN 8,8,8,"MY_UTILS.PYCOM,S,R"                    │
│    - Seek code_offset-re (header átugrása)              │
│    - READ code_size byte → stack tetejére               │
│    - Relokáció (marker-byte scan)                       │
│    - CLOSE                                              │
│    - SSP += code_size (stack pointer előre)             │
│                          ↓                              │
│ 3. module_base = régi SSP érték                         │
│    sin = module_base + 0  (entry 0)                     │
│    rotate = module_base + 3  (entry 1)                  │
│                          ↓                              │
│ 4. Hívások: JSR (module_base + offset)                  │
│                          ↓                              │
│ 5. Scope vége: SSP visszaáll → modul "eltűnik"          │
└─────────────────────────────────────────────────────────┘
```

## Scope-Alapú Memória Kezelés

### A PyCo memória modell egységessége

| Koncepció | Tárolás | Felszabadulás |
|-----------|---------|---------------|
| Lokális változó | Stack | Statement/scope vége |
| Osztály instance | Stack | Scope vége |
| Dinamikus modul | Stack | Import scope vége |
| Singleton (modulban) | Modul része | Modul scope vége |

**Minden ugyanúgy működik!** A stack pointer visszaállítása mindent "takarít".

### Példa: Játék screen-ek

```python
def menu_screen():
    from menu_gfx import draw_menu, handle_input

    draw_menu()
    choice = handle_input()
    return choice
    # ← menu_gfx modul FELSZABADUL

def game_screen():
    from game_utils import init, update
    from music import play_ingame

    init()
    play_ingame()
    while not game_over:
        update()
    # ← game_utils és music modul FELSZABADUL

def main():
    while True:
        choice = menu_screen()     # Menu memóriában
                                   # ← Menu felszabadul
        if choice == 1:
            game_screen()          # Game memóriában (teljes RAM!)
                                   # ← Game felszabadul
```

**Minden screen a teljes memóriát használhatja!** Nincs fragmentáció.

## Hibaüzenetek

### Fordítási idejű hibák

```
main.pyco:3: Error: Unknown module 'maht'. Did you mean 'math'?
main.pyco:5: Error: Module 'math' has no export 'sn'. Did you mean 'sin'?
main.pyco:7: Error: Cannot import '_helper' from 'math': name is private
main.pyco:10: Error: 'sin' already imported from 'math'
main.pyco:15: Error: Type mismatch: sin expects float, got byte
```

### Futásidejű hibák

```
Runtime Error: Module 'MUSIC.PYCOM' not found on disk
Runtime Error: Out of memory loading module (need 1234 bytes, have 500)
Runtime Error: Module format error (invalid magic)
```

## Implementációs Fázisok

### Fázis 1: Modul Generálás
- [ ] `.pycom` header formátum generálása
- [ ] Symbol table (csak publikus nevek, `_` prefix szűrése)
- [ ] Re-export kezelés (statikus import → export, kivéve `as _name`)
- [ ] Code+data szekció $0000 base-zel
- [ ] Jump table generálás
- [ ] `pycoc compile --module` kapcsoló

### Fázis 2: Statikus Import
- [ ] Header olvasás fordításkor
- [ ] Publikus név ellenőrzés
- [ ] Típus és paraméter ellenőrzés
- [ ] `as` alias támogatás
- [ ] Névütközés detektálás
- [ ] Code beillesztés és compile-time relokáció
- [ ] Tree-shaking (csak használt entry point-ok)

### Fázis 3: Dinamikus Import Alapok
- [ ] Function-level import felismerése
- [ ] Runtime loader assembly rutin
- [ ] Marker-byte relokáció implementálása
- [ ] Stack-re töltés és scope kezelés

### Fázis 4: Runtime Loader
- [ ] Disk I/O (OPEN, READ, CLOSE)
- [ ] Header átugrása (seek)
- [ ] Relokáció scan
- [ ] Entry point cím számítás

### Fázis 5: Optimalizálások
- [ ] Modul cache (ha ugyanaz többször kell)
- [ ] Loader kód optimalizálás

## Összefoglalás

### Import szabályok

| Szintaxis | Jelentés |
|-----------|----------|
| `from X import a, b` | a és b közvetlenül használható |
| `from X import a as my_a` | my_a néven használható |
| `a()` | Hívás prefix nélkül |
| Névütközés | Fordítási hiba → `as` kell |

### Export szabályok

| Név formátum | Exportálva? |
|--------------|-------------|
| `name` | ✓ Igen (publikus) |
| `_name` | ✗ Nem (privát) |
| `from X import foo` | ✓ Igen (re-export) |
| `from X import foo as _foo` | ✗ Nem (privát alias) |

### Két import mód

| Tulajdonság | Statikus Import | Dinamikus Import |
|-------------|-----------------|------------------|
| Pozíció | Top-level | Function-level |
| Időpont | Compile-time | Runtime |
| Tárolás | PRG-ben | Stack-en |
| Élettartam | Program futása | Scope vége |
| Disk I/O | Nincs (befordul) | Van (betöltés) |
| Relokáció | Compile-time | Runtime (marker-byte) |

### Marker-byte rendszer

| High byte | Jelentés |
|-----------|----------|
| `$00-$07` | Marker (relokálandó, modul-belső cím) |
| `$08-$FF` | Fix cím (HW regiszter, külső memória) |

---

*Verzió: 2.1 - 2026-01-13*
*Változások: Prefix-mentes használat, `as` alias, Python-szerű export szabályok*
