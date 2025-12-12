# PyCo Modul Rendszer - Tervezési Dokumentum

## Áttekintés

A PyCo modul rendszer lehetővé teszi külső függvények és osztályok használatát más `.pyco` fájlokból. A rendszer **függvény-szintű betöltést** támogat - csak a ténylegesen használt függvények kerülnek a memóriába.

### Fő jellemzők

- **Explicit import**: Fel kell sorolni a használt függvényeket
- **Prefix kötelező**: `modul.függvény()` formátum
- **Szelektív betöltés**: Csak a szükséges függvények és adatok töltődnek be
- **Tranzitív függőségek**: Automatikusan kezeli a függvények közötti hívásokat

## Szintaxis

### Import utasítás

```python
from modul import függvény1, függvény2, osztály1
```

**Szabályok:**
- Import **csak a fájl elején** lehet (notebook módban: init cell)
- **Explicit felsorolás** kötelező - nincs `import *`
- A használatkor **prefix kötelező**: `modul.függvény()`

### Példa

```python
# Fájl eleje - importok
from math import sin, cos
from gfx import Sprite, draw_line

# Konstansok
PLAYER_SPEED = 5

# Függvények - itt már minden elérhető
def update_position(angle: float) -> float:
    # Prefix kötelező!
    return math.sin(angle) * PLAYER_SPEED

def main():
    x: float = math.cos(0.5)
    player: gfx.Sprite = gfx.Sprite(0, 100, 100)
```

### Hibás használat

```python
# HIBA - prefix hiányzik
x = sin(3.14)           # ✗ Helyes: math.sin(3.14)

# HIBA - import függvényben
def bad():
    from math import tan   # ✗ Import csak fájl elején!

# HIBA - nincs felsorolva
from math import sin
x = math.cos(1.0)       # ✗ cos nincs importálva!
```

## Modul Formátum (.LIB)

A modulok `.LIB` kiterjesztésű fájlok, SEQ típusban (nincs load address - bárhova tölthető).

### Fájlstruktúra

```
┌────────────────────────────────────────────────────┐
│ HEADER                                             │
├────────────────────────────────────────────────────┤
│ Magic (2 byte): "PL" ($50 $4C = PyCo Library)     │
│ Version (1 byte): 1                                │
│ Function count (1 byte)                            │
│ Data segment count (1 byte)                        │
│ String table offset (2 byte)                       │
├────────────────────────────────────────────────────┤
│ FUNCTION INDEX (N × 12 byte)                       │
├────────────────────────────────────────────────────┤
│ Per function:                                      │
│   name_offset (2 byte)     → string table          │
│   code_offset (2 byte)     → code section          │
│   code_size (2 byte)                               │
│   uses_funcs (1 byte)      → bitmask, belső fv-ek  │
│   uses_data (1 byte)       → bitmask, adat szegm.  │
│   ext_dep_idx (1 byte)     → external dep. tábla   │
│   ext_dep_count (1 byte)                           │
│   reloc_offset (2 byte)    → relocation table      │
├────────────────────────────────────────────────────┤
│ DATA SEGMENT INDEX (M × 6 byte)                    │
├────────────────────────────────────────────────────┤
│ Per segment:                                       │
│   name_offset (2 byte)                             │
│   data_offset (2 byte)     → data section          │
│   data_size (2 byte)                               │
├────────────────────────────────────────────────────┤
│ EXTERNAL DEPENDENCY TABLE                          │
├────────────────────────────────────────────────────┤
│   module_name_offset (2 byte)                      │
│   function_name_offset (2 byte)                    │
│   ... (minden külső függőséghez)                   │
├────────────────────────────────────────────────────┤
│ CODE SECTION                                       │
├────────────────────────────────────────────────────┤
│   [function 0 code]                                │
│   [function 1 code]                                │
│   ...                                              │
├────────────────────────────────────────────────────┤
│ DATA SECTION                                       │
├────────────────────────────────────────────────────┤
│   [data segment 0]                                 │
│   [data segment 1]                                 │
│   ...                                              │
├────────────────────────────────────────────────────┤
│ RELOCATION TABLE                                   │
├────────────────────────────────────────────────────┤
│ Per function:                                      │
│   reloc_count (1 byte)                             │
│   offsets (2 byte each) - hol kell patchelni      │
├────────────────────────────────────────────────────┤
│ STRING TABLE                                       │
├────────────────────────────────────────────────────┤
│   null-terminated strings                          │
└────────────────────────────────────────────────────┘
```

### Korlátok

- Max 8 függvény per modul (bitmask = 1 byte)
- Max 8 adat szegmens per modul
- Max 255 külső függőség
- Fájlnév max 16 karakter (CBM DOS limit): `MODULNEV.LIB`

## Függőségi Gráf

Minden függvényhez tároljuk:
1. **Belső függvények**: Melyik másik függvényt hívja ugyanebből a modulból
2. **Adat szegmensek**: Melyik adat szegmenseket használja
3. **Külső függőségek**: Melyik másik modul melyik függvényét hívja

### Példa

```python
# math.pyco → MATH.LIB

def sin(angle: float) -> float:
    # Használ: cos (belső), _normalize (belső), TRIG_TABLE (adat)
    normalized: float = _normalize(angle)
    return _sin_impl(normalized)

def cos(angle: float) -> float:
    # Használ: _normalize (belső), TRIG_TABLE (adat)
    normalized: float = _normalize(angle)
    return _cos_impl(normalized)

def _normalize(angle: float) -> float:
    # Használ: TRIG_TABLE (adat)
    ...

def atan2(y: float, x: float) -> float:
    # Használ: külső util.sqrt!
    ...
```

**Generált függőségi gráf:**

```
sin:
  uses_funcs: [cos, _normalize]  → bitmask: 0b00000110
  uses_data: [TRIG_TABLE]        → bitmask: 0b00000001
  uses_external: []

cos:
  uses_funcs: [_normalize]       → bitmask: 0b00000100
  uses_data: [TRIG_TABLE]        → bitmask: 0b00000001
  uses_external: []

_normalize:
  uses_funcs: []                 → bitmask: 0b00000000
  uses_data: [TRIG_TABLE]        → bitmask: 0b00000001
  uses_external: []

atan2:
  uses_funcs: []
  uses_data: []
  uses_external: [(util, sqrt)]  → extra modul kell!
```

## Betöltési Mechanizmus

### 1. Index beolvasása

```
OPEN "MATH.LIB",8 → SEQ read
READ header + function index + data index
CLOSE
```

Az index kicsi (pár száz byte), memóriában marad.

### 2. Tranzitív lezárás számítása

```
Input: wanted = {sin}

Iteráció 1:
  sin → uses_funcs = {cos, _normalize}
  wanted = {cos, _normalize}
  needed = {sin, cos, _normalize}

Iteráció 2:
  cos → uses_funcs = {_normalize}
  _normalize → uses_funcs = {}
  needed = {sin, cos, _normalize}  (nem változott)

Adat szegmensek:
  sin.uses_data ∪ cos.uses_data ∪ _normalize.uses_data
  = {TRIG_TABLE}

Külső függőségek:
  (egyik sem használ külsőt)
  = {}

Output:
  load_funcs = {sin, cos, _normalize}
  load_data = {TRIG_TABLE}
  load_external = {}
```

### 3. Szelektív olvasás

```
OPEN "MATH.LIB",8

position = 0
for each chunk in file:
    if chunk in load_funcs or chunk in load_data:
        READ chunk → _load_ptr
        új_cím[chunk] = _load_ptr
        _load_ptr += chunk.size
    else:
        SKIP chunk.size bytes

CLOSE
```

### 4. Relokáció

A betöltött függvényekben az eredeti címeket át kell írni az új címekre:

```
for each func in load_funcs:
    for each reloc in func.relocations:
        cím = új_cím[func] + reloc.offset
        eredeti = PEEK(cím) + PEEK(cím+1)*256
        cél_chunk = find_chunk(eredeti)
        új_érték = új_cím[cél_chunk] + (eredeti - eredeti_cím[cél_chunk])
        POKE cím, új_érték & 0xFF
        POKE cím+1, új_érték >> 8
```

### 5. Külső függőségek rekurzív betöltése

```
for each (module, func) in load_external:
    if module not in loaded_modules:
        load_module(module, {func})
    else:
        ensure_function_loaded(module, func)
```

## Memória Layout

```
$0801: BASIC loader (ha PRG)
$080D: Fő program
        ├── import handler kód
        ├── user kód
        └── user adat
$xxxx: _program_end
        │
        ▼ (modulok ide töltődnek, felfelé)
┌─────────────────────────────────┐
│ MATH.LIB részlet:               │
│   sin (80 byte)                 │
│   cos (60 byte)                 │
│   _normalize (40 byte)          │
│   TRIG_TABLE (128 byte)         │
├─────────────────────────────────┤
│ GFX.LIB részlet:                │
│   Sprite (200 byte)             │
│   draw_line (150 byte)          │
│   LINE_BUFFER (40 byte)         │
└─────────────────────────────────┘
$yyyy: _modules_end = SSP (stack kezdete)
        │
        ▼ (stack felfelé nő)
```

## Loaded Modules Registry

A már betöltött modulok és függvények nyilvántartása:

```
_loaded_registry:
    module_count: 2

    [0] module: "MATH"
        loaded_funcs: 0b00000111  (sin, cos, _normalize)
        loaded_data:  0b00000001  (TRIG_TABLE)
        base_addr: $2000
        func_addrs: [sin=$2000, cos=$2050, _norm=$2090]
        data_addrs: [TRIG=$20B8]

    [1] module: "GFX"
        loaded_funcs: 0b00000011
        loaded_data:  0b00000001
        base_addr: $2200
        ...
```

Ha később kell még egy függvény ugyanabból a modulból:
1. Ellenőrizzük a registry-t
2. Ha már betöltve → használjuk a meglévő címet
3. Ha nincs → újra megnyitjuk a .LIB-et és betöltjük a hiányzó részt

## Cross-Compiler Módok

### 1. Library generálás

```bash
pycoc compile math.pyco --lib
# Eredmény: MATH.LIB
```

A compiler:
1. Elemzi a forráskódot
2. Felépíti a függőségi gráfot
3. Generálja a kódot + relokációs táblát
4. Kiírja a .LIB formátumot

### 2. Static linking (all-in-one PRG)

```bash
pycoc compile main.pyco
# Eredmény: MAIN.PRG (minden benne van)
```

A compiler:
1. Beolvassa az importokat
2. Megkeresi a .LIB fájlokat
3. Kiszámolja a tranzitív lezárást
4. Csak a szükséges függvényeket rakja a PRG-be
5. Relokáció compile-time történik

### 3. Dynamic linking

```bash
pycoc compile main.pyco --dynamic
# Eredmény: MAIN.PRG + MATH.LIB + GFX.LIB (külön)
```

A MAIN.PRG tartalmazza:
- Import listát
- Loader kódot
- User kódot

Futáskor tölti be a modulokat.

## Notebook Mód

### Init Cell

```
┌─ INIT CELL ─────────────────────────────────┐
│ # Importok és include-ok CSAK ITT!          │
│ from math import sin, cos                   │
│ from gfx import Sprite                      │
│ include("c64.pyco")                         │
└─────────────────────────────────────────────┘
```

- Automatikusan lefut notebook megnyitáskor
- Modulok betöltődnek
- Utána a cellák már használhatják

### Működés

1. **Notebook megnyit** → Init cell fut → modulok betöltődnek
2. **Cella szerkesztés** → Csak a cella fordul újra (gyors!)
3. **Futtatás** → main() hívódik

## Hibaüzenetek

```
main.pyco:3: Error: Unknown module 'maht'. Did you mean 'math'?
main.pyco:5: Error: Module 'math' has no function 'sn'. Did you mean 'sin'?
main.pyco:10: Error: Function 'cos' not imported. Add: from math import cos
main.pyco:15: Error: Missing module prefix. Use 'math.sin()' instead of 'sin()'
main.pyco:20: Error: Import only allowed at file beginning

runtime: Error: Module 'MATH.LIB' not found
runtime: Error: Out of memory loading module
runtime: Error: Circular dependency detected: A → B → A
```

## Implementációs Fázisok

### Fázis 1: Semantic Validation (részben kész)
- [x] `import` szintaxis felismerése
- [ ] Modul keresés (`-M` kapcsoló)
- [ ] Export lista validálása .LIB-ből
- [ ] Prefix kötelezőség ellenőrzése
- [ ] Tranzitív függőség validálás

### Fázis 2: .LIB Generálás
- [ ] Függőségi gráf építése fordítás közben
- [ ] Relokációs tábla generálása
- [ ] .LIB header generálása
- [ ] .LIB fájl írása

### Fázis 3: Static Linking
- [ ] .LIB parse
- [ ] Tree-shaking (tranzitív lezárás)
- [ ] Kód összefűzés + relokáció
- [ ] Egységes PRG generálás

### Fázis 4: Runtime Loader
- [ ] Loader rutin assembly-ben
- [ ] Index beolvasás
- [ ] Szelektív betöltés
- [ ] Runtime relokáció
- [ ] Loaded registry kezelés

### Fázis 5: Notebook Integráció
- [ ] Init cell kezelés
- [ ] Inkrementális fordítás
- [ ] Modul cache

## Összefoglalás

| Tulajdonság | Érték |
|-------------|-------|
| Import szintaxis | `from modul import fv1, fv2` |
| Hívás szintaxis | `modul.fv(args)` (prefix kötelező) |
| Import helye | Csak fájl elején / init cell |
| Wildcard import | NINCS (`from x import *` tiltott) |
| Modul formátum | `.LIB` (SEQ típus, nincs load address) |
| Betöltési egység | Függvény (nem teljes modul!) |
| Függőségek | Tranzitív, automatikus |
| Dupla betöltés | Registry-ből kiszűrve |
| Max függvény/modul | 8 (bitmask limit) |

---

*Verzió: 1.0 - 2025-12-05*
