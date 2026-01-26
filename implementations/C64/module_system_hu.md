# PyCo Modul Rendszer - Tervezési Dokumentum

## Áttekintés

A PyCo modul rendszer lehetővé teszi külső kód használatát más `.pyco` fájlokból. A rendszer két működési módot támogat, a Python szintaxisát követve:

1. **Statikus import** (`from X import a, b`): Compile-time linkelés, a kód befordul a PRG-be
2. **Dinamikus import** (`import X`): Modul regisztráció + explicit runtime betöltés

### Tervezési elvek

- **Python szintaxis**: Ismerős `from`/`import` kulcsszavak, eltérő szemantikával
- **Egyszerűség**: Nincs relokációs tábla, marker-byte alapú relokáció
- **Hatékonyság**: Nulla overhead a modul méretben
- **Programozói kontroll**: Explicit `load_module()`, nincs automatikus életciklus-kezelés
- **Forward compatible**: C64-en futó fordító számára is működik (minden előre regisztrált)

## Import Szintaxis

### Statikus Import: `from X import`

A felsorolt elemek **befordulnak a PRG-be**, közvetlenül használhatók:

```python
# Fájl eleje - STATIKUS import
from math import sin, cos         # sin, cos kódja befordul
from gfx import Sprite, draw_line # Sprite osztály, draw_line fv befordul
from screen import row_offsets    # Globális tuple befordul

def main():
    x = sin(0.5)                  # Közvetlen hívás, prefix nélkül!
    y = cos(0.5)
    s: Sprite
    s()
    draw_line(0, 0, x, y)
    offset: word = row_offsets[5] # Tuple hozzáférés
```

**Jellemzők:**

| Tulajdonság      | Érték                                       |
| ---------------- | ------------------------------------------- |
| Compile-time     | Kód befordul a PRG-be                       |
| Runtime overhead | Nincs (statikus linkelés)                   |
| Használat        | Prefix nélkül: `sin()`, `Sprite`, `tuple[]` |
| Tree-shaking     | Csak a felsorolt elemek fordulnak be        |
| Típusellenőrzés  | Compile-time                                |

### Dinamikus Import: `import X`

A modul **regisztrálódik**, de a kód **NEM fordul be**:

```python
# DINAMIKUS modul regisztráció
import math                       # Info Section olvasás + BSS pointer foglalás
import sprites                    # __mod_math: .word 0, __mod_sprites: .word 0

def game_session():
    load_module(math)             # Runtime betöltés stack-re
    load_module(sprites)

    while running:
        x = math.sin(0.5)         # Namespace-szel! math.sin
        player: sprites.Sprite    # sprites.Sprite
        player()
        player.update()

    # Return → stack visszaáll → modulok "eltűnnek"
    # BSS pointerek maradnak - programozó felelőssége!

def game_loop():
    # Ha game_session() már betöltötte, működik
    x = math.sin(0.5)             # __mod_math + SIN_OFFSET
    # Ha nincs betöltve → crash (pointer = 0 vagy garbage)
```

**Jellemzők:**

| Tulajdonság   | Érték                                          |
| ------------- | ---------------------------------------------- |
| Compile-time  | Csak Info Section olvasás (aláírások)          |
| BSS foglalás  | 2 byte pointer modulonként                     |
| Runtime       | `load_module()` explicit hívás                 |
| Használat     | Namespace-szel: `math.sin()`, `sprites.Sprite` |
| Felszabadítás | Programozó felelőssége (stack alapú)           |

### Összehasonlítás

| Szintaxis         | Befordul? | Használat | Betöltés        |
| ----------------- | --------- | --------- | --------------- |
| `from X import a` | ✓ Igen    | `a()`     | Automatikus     |
| `import X`        | ✗ Nem     | `X.a()`   | `load_module()` |

## A `load_module()` Függvény

### Szintaxis

```python
load_module(module_name)
```

### Működés

1. **SSP mentés**: Aktuális SSP értéke = module_base (ide fog töltődni a modul)
2. **SSP növelés ELŐRE** (IRQ-safe!): SSP += code_size + 4 (compile-time ismert méret + header)
3. **IRQ letiltás + ROM engedélyezés**: SEI, majd `$01 = $37` (Kernal ROM be)
4. **Kernal I/O inicializálás**: CLALL ($FFE7) + CLRCH ($FFCC)
5. **Fájlnév beállítás**: SETNAM ($FFBD) Pascal stringből
6. **Fájl megnyitás**: SETLFS ($FFBA) device 8, **SA=0** (fontos!)
7. **Betöltés**: LOAD ($FFD5) module_base címre
   - A Kernal **kihagyja az első 2 byte-ot** (magic) SA=0 miatt
   - A maradék (code_size + code_end + kód) töltődik module_base-re
8. **Relokáció**: Utasításról utasításra scan, JAM marker + JMP/JSR átírás
9. **BSS pointer beállítás**: `__mod_X = betöltési cím + 4` (header után)
10. **ROM visszaállítás + IRQ engedélyezés**: `$01` restore, CLI

### Miért IRQ-safe? (2026-01)

A korábbi implementációban az SSP-t a LOAD **után** növeltük. Ez problémát okozott, ha IRQ beütött a betöltés közben:

```
LOAD közben (ROSSZ - régi):           IRQ beütéskor:

SSP → ┌────────────────┐              SSP → ┌────────────────┐
      │ MODUL TÖLTŐDIK │ ← LOAD             │ MODUL TÖLTŐDIK │
+4 →  ├────────────────┤              +4 →  ├────────────────┤
      │ (modul adat)   │                    │ IRQ lokális #1 │ ← FELÜLÍRÁS!
      └────────────────┘                    └────────────────┘
```

Az új megoldás: az SSP-t **ELŐRE** növeljük a modul méretével, **MIELŐTT** a LOAD elkezdődik. Így az IRQ handler az SSP+4-től ír (ami már a "fenntartott" terület fölött van), és nem írja felül a töltés alatt lévő modult.

```
LOAD közben (HELYES - új):            IRQ beütéskor:

module_base → ┌────────────────┐      module_base → ┌────────────────┐
              │ MODUL TÖLTŐDIK │ ← LOAD             │ MODUL TÖLTŐDIK │ ← Biztonságos!
              ├────────────────┤                    ├────────────────┤
SSP ────────► │ (üres - guard) │      SSP ────────► │ (üres - guard) │
        +4 →  ├────────────────┤              +4 →  ├────────────────┤
              │                │                    │ IRQ lokális #1 │ ← OK!
              └────────────────┘                    └────────────────┘
```

### Fontos: Modul újrafordítás szükséges!

**Ha egy dinamikusan importált modul (`.pm` fájl) változik, a fő programot is ÚJRA KELL fordítani!**

Ennek oka, hogy a modul `code_size` értéke **compile-time** kerül a fő programba az IRQ-biztos betöltéshez. Ha a modul mérete változik (új funkció, módosított kód), de a fő program még a régi méretet tartalmazza:
- Kisebb modul → memóriapazarlás (nem kritikus)
- **Nagyobb modul** → **túlírás, crash!** (a LOAD túlnyúlik a fenntartott területen)

**Statikus importnál ez automatikus** (a modul befordul a programba).

### Kritikus implementációs részletek

| Kérdés                        | Megoldás                                                    |
| ----------------------------- | ----------------------------------------------------------- |
| Miért SA=0?                   | SA=1 a file első 2 byte-jára töltene ($0000)!               |
| Miért SEI?                    | ROM bekapcsolás alatt az IRQ vector rossz helyre mutatna    |
| Hol van module_base?          | tmp2/tmp3-ban, hw stack-re mentve (Kernal elrontja a ZP-t!) |
| Mi van ha LOAD error?         | A/X = 0 (null pointer), stack cleanup, rts                  |
| Miért előre növeljük az SSP-t? | IRQ-safe: az IRQ handler már nem írja felül a töltődő modult |

### Stack kezelés (LIFO)

```
                    ┌─────────────────┐
                    │ sprites modul   │ ← load_module(sprites) - 2.
      SSP ────────► ├─────────────────┤
                    │ math modul      │ ← load_module(math) - 1.
                    ├─────────────────┤
                    │ lokális változók│
                    ├─────────────────┤
                    │ stack frame     │
                    └─────────────────┘
```

**Fontos:** A modulok LIFO sorrendben "tűnnek el" a függvény return-jekor!

### Nincs `unload_module()`

Nincs szükség explicit unload-ra:

- A függvény returnjakor az SSP visszaáll
- A modul memóriája automatikusan felszabadul
- **DE:** A BSS pointer (`__mod_X`) megmarad!

**Programozói felelősség:** Ha a pointer "szemét" címre mutat és meghívod a modult → crash. Ez rendben van - trust the programmer.

## Alias (`as`) Támogatás

### Statikus importnál

```python
from math import sin as math_sin
from audio import sin as audio_sin    # Névütközés feloldása

x = math_sin(0.5)                     # Közvetlen hívás
freq = audio_sin(440)
```

### Dinamikus importnál

```python
import math as m                      # Rövidebb namespace
import very_long_module_name as vlm

load_module(m)
x = m.sin(0.5)                        # m.sin a math.sin helyett
```

### Névütközés kezelése

```python
from math import sin
from audio import sin     # HIBA: 'sin' already imported from 'math'!

# Megoldás - használj alias-t:
from math import sin
from audio import sin as audio_sin   # OK
```

## Export Szabályok

### Python-szerű konvenció

```python
# Egyszerű szabály:
# _prefix = privát (NEM exportálva)
# Nincs prefix = publikus (exportálva)
```

### Példa modul

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

### Statikus import és re-export

A statikusan importált nevek **automatikusan exportálva** lesznek, KIVÉVE ha `_` prefixes alias-t kapnak:

```python
# my_game_utils.pyco - saját "csomag" összeállítása

# Ezek PUBLIKUSAK lesznek (exportálva):
from math import sin, cos
from physics import update_pos

# Ez PRIVÁT marad (nem exportálva):
from internal import debug_helper as _debug

# Saját publikus függvény:
def rotate(x: int, y: int, angle: float) -> int:
    _debug("rotating...")
    return int(x * cos(angle) - y * sin(angle))
```

**Eredmény - my_game_utils.pm exportjai:**

| Név          | Forrás               | Exportálva? |
| ------------ | -------------------- | ----------- |
| `sin`        | math                 | ✓ Igen      |
| `cos`        | math                 | ✓ Igen      |
| `update_pos` | physics              | ✓ Igen      |
| `rotate`     | saját                | ✓ Igen      |
| `_debug`     | internal (as _debug) | ✗ Nem       |

## Egyedi Modul Összeállítás

### Koncepció

Ha nagy lib-ekből csak néhány függvényre van szükség, készíthetsz saját modult:

```
┌─────────────────────────────────────────────────────────────┐
│ NAGY LIB-EK:                                                │
│   math.pyco (20 függvény)                                   │
│   gfx.pyco (30 függvény)                                    │
│   physics.pyco (15 függvény)                                │
└────────────────────┬────────────────────────────────────────┘
                     │ statikus import (válogatás)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ SAJÁT MODUL (csak ami kell + saját kód):                    │
│   my_game_utils.pyco:                                       │
│     from math import sin, cos      # 2 függvény            │
│     from gfx import draw_sprite    # 1 függvény            │
│     def rotate(): ...              # saját                 │
│                                                             │
│   Fordítás: pycoc compile my_game_utils.pyco --module      │
│   Eredmény: MY_GAME_UTILS.PM (kis méret!)               │
└────────────────────┬────────────────────────────────────────┘
                     │ dinamikus import (runtime)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ FŐ PROGRAM:                                                 │
│   import my_game_utils                                      │
│                                                             │
│   def game_screen():                                        │
│       load_module(my_game_utils)                            │
│       my_game_utils.rotate(...)                             │
│       x = my_game_utils.sin(0.5)                            │
└─────────────────────────────────────────────────────────────┘
```

### Előnyök

- **Tree-shaking**: Csak a használt függvények fordulnak be a modulba
- **Fejlesztői kontroll**: Te döntöd el, mi tartozik össze
- **Kis méret**: A PRG-ben csak a loader kód, a modul külön fájl

### Modulok és `main()`

A moduloknak is lehet `main()` függvényük - ez teszt vagy demó kódot tartalmazhat:

```python
# mylib.pyco
def useful_function():
    pass

def another_function():
    pass

def main():
    # Teszt kód - csak közvetlen futtatáskor fut le
    print("Testing mylib...\n")
    useful_function()
```

**Fordítási módok:**

| Parancs                             | Eredmény  | `main()`                 |
| ----------------------------------- | --------- | ------------------------ |
| `pycoc compile mylib.pyco`          | mylib.prg | ✓ Benne van, lefut       |
| `pycoc compile mylib.pyco --module` | mylib.pm  | ✗ Kimarad (tree-shaking) |

A `--module` flag esetén a `main()` automatikusan kimarad a .pm fájlból, mert senki nem importálja/hívja. Ez nem igényel külön fájl struktúrát - egyszerűen a tree-shaking működése.

**Használat:**
- **Fejlesztés közben:** Fordítsd PRG-nek, teszteld a `main()`-nel
- **Éles használatkor:** Fordítsd .pm-nek, importáld más programból

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

| Cím tartomány | Tartalom             | Modul ugorhat ide? |
| ------------- | -------------------- | ------------------ |
| `$0000-$00FF` | Zero Page            | ❌ SOHA (adat)      |
| `$0100-$01FF` | Hardware Stack       | ❌ SOHA (adat)      |
| `$0200-$02FF` | OS változók          | ❌ SOHA             |
| `$0300-$03FF` | Vektorok, buffer     | ❌ SOHA             |
| `$0400-$07FF` | Screen RAM (alapból) | ❌ SOHA (adat)      |
| `$0800-$FFFF` | **Program terület**  | ✓ IGEN             |

**FONTOS:** A high byte `$00-$07` tartomány **NEM garantáltan** modul-belső cím!

A C64 memória térképe azt mutatja, hogy a `$0000-$07FF` tartomány rendszerterület
(Zero Page, Stack, Screen RAM). Azonban a modul belső címei is `$0000`-tól indulnak!
Ez azt jelenti, hogy egy modul-belső `$0400` offset és a C64 Screen RAM (`$0400`)
**megkülönböztethetetlen** a binárisban.

**Megoldás:** Explicit marker opcode-ok használata a relokálandó címekhez:
- **JMP/JSR** - high byte `$00-$07` alapján (ezek biztosan belső címek)
- **Immediate high byte** - JAM marker (`$02`) jelöli
- **ABS,X/ABS,Y DATA elérés** - Speciális marker opcode-ok (`$12`, `$32`) jelölik

### Marker tartomány

```
High byte alapú detektálás (csak JMP/JSR/JMP(ind) esetén!):
────────────────────────────────────────────────────────────
High byte: $00-$07 = Belső cím (relokálandó)
High byte: $08-$FF = Fix külső cím (HW regiszter, stb.)

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

### Marker Opcode-ok

A 6502 illegális opcode-okat használjuk markerként, mert:
1. Normál kódban nem fordulnak elő
2. Ha véletlenül végrehajtódnának (relokáció nélkül), a CPU megáll (JAM)
3. A relokátor visszacseréli őket a valódi opcode-ra

| Marker | Eredeti opcode | Utasítás típus | Használat |
|--------|----------------|----------------|-----------|
| `$02`  | `$A9`          | LDA #          | Immediate high byte pointer betöltés |
| `$12`  | `$BD`          | LDA ABS,X      | DATA szekció olvasás X indexszel |
| `$22`  | `$AD`          | LDA ABS        | DATA szekció közvetlen olvasás |
| `$32`  | `$B9`          | LDA ABS,Y      | DATA szekció olvasás Y indexszel |
| `$42`  | `$4C`          | JMP ABS        | Belső ugrás (>2KB modulokhoz) |
| `$52`  | `$20`          | JSR ABS        | Belső hívás (>2KB modulokhoz) |

**Miért kellenek JMP/JSR markerek?**

A 2KB-nál nagyobb modulokban a JMP/JSR célcímek high byte-ja meghaladhatja a `$07`
értéket. A high byte alapú detektálás ezeket külső címeknek hiszi! A marker egyértelműen
jelöli a modul-belső ugrásokat.

**Miért kellenek külön markerek az ABS,X/ABS,Y-hoz?**

A modulokban a tuple/konstans adatok a DATA szekcióban vannak. Konstans indexű
eléréskor a compiler közvetlen ABS,X/ABS,Y címzést generál a hatékonyság érdekében:

```asm
; tuple[5] elérése - közvetlen ABS címzés
lda tuple_data+10    ; Hatékony, de a cím relokálandó!
```

A probléma: ha ez a cím pl. `$0400`, az megegyezik a C64 Screen RAM címével!
A high byte alapú detektálás nem tudja megkülönböztetni őket. A marker viszont
egyértelműen jelöli, hogy ez modul-belső DATA cím.

```asm
; Modulban generált kód:
.byte $12            ; Marker (volt: $BD = LDA ABS,X)
.word $0400          ; DATA offset (történetesen = Screen RAM cím!)

; Relokáció után:
lda $C400,x          ; $BD + relokált cím
```

### Relokáció betöltéskor

A relokátor **utasításról utasításra** halad (nem byte-ról byte-ra!), és három típusú
relokációt végez:

1. **JMP/JSR/JMP(ind)** - 16-bit abszolút címek (high byte `$00-$07` alapján)
2. **JAM marker ($02)** - immediate high byte értékek (pointer betöltés)
3. **ABS marker ($12/$32)** - DATA szekció közvetlen elérése

#### Utasítás-alapú scan

```asm
; Minden utasításnál:
; 1. Opcode olvasása
; 2. Relokáció szükséges?
; 3. Utasítás hosszának megfelelően továbblépés

relocate:
    LDY #4              ; Skip 6-byte header (Y starts at code)
.loop:
    LDA (module_ptr),Y  ; Opcode olvasása

    ; === Marker opcode-ok (explicit jelölés) ===
    CMP #$02            ; JAM marker? (immediate high byte)
    BEQ .do_jam
    CMP #$12            ; ABS,X marker? (LDA data,X)
    BEQ .do_abs_marker
    CMP #$22            ; ABS marker? (LDA data)
    BEQ .do_abs_marker
    CMP #$32            ; ABS,Y marker? (LDA data,Y)
    BEQ .do_abs_marker
    CMP #$42            ; JMP marker? (JMP belső címre)
    BEQ .do_abs_marker
    CMP #$52            ; JSR marker? (JSR belső címre)
    BEQ .do_abs_marker

    ; === JMP/JSR (high byte alapú, backward compat) ===
    CMP #$20            ; JSR? (csak <2KB modulokhoz)
    BEQ .do_jmp
    CMP #$4C            ; JMP? (csak <2KB modulokhoz)
    BEQ .do_jmp
    CMP #$6C            ; JMP indirect?
    BEQ .do_jmp

    ; ... skip instruction by length ...
```

#### JMP/JSR relokáció (teljes 16-bit)

```asm
.do_abs:
    INY                     ; Low byte pozíció
    INY                     ; High byte pozíció
    LDA (module_ptr),Y      ; High byte olvasása
    CMP #$08                ; Belső cím? (< $08)
    BCS .skip               ; Külső: ne relokáld

    ; TELJES 16-bit relokáció (fontos a carry!)
    DEY                     ; Vissza low byte-ra
    LDA (module_ptr),Y
    CLC
    ADC base_lo             ; Low byte + base_lo
    STA (module_ptr),Y
    INY                     ; High byte-ra
    LDA (module_ptr),Y
    ADC base_hi             ; High byte + base_hi + CARRY!
    STA (module_ptr),Y
```

#### JAM marker relokáció

A fordító az immediate high byte-okat JAM marker-rel jelöli:

```asm
; Fordított kód (modulban):
    LDA #<label         ; $A9 LL   (low byte)
    STA tmp0            ; $85 $02
    .byte $02           ; JAM marker (illegális opcode)
    .byte >label        ; HH (high byte)
    STA tmp1            ; $85 $03

; Relokáció után ($C000 base esetén):
    LDA #<label+$C000   ; $A9 LL'  (low byte relokálva)
    STA tmp0
    LDA #>label+$C000   ; $A9 HH'  (JAM → LDA #, high relokálva)
    STA tmp1
```

**KRITIKUS:** A JAM marker relokációnál mindkét byte-ot (low ÉS high) relokálni
kell, és a carry-t át kell vinni! Ha `LL + base_lo > 255`, a high byte is nő!

```asm
.do_jam:
    INY                     ; High byte pozíció (JAM utáni byte)
    LDA (module_ptr),Y
    CMP #$08                ; Valódi JAM marker?
    BCS .skip               ; >= $08: nem marker, hadd

    ; Low byte relokálása (Y-4 pozíción!)
    DEY
    DEY
    DEY
    DEY                     ; LDA # operandus pozíció
    LDA (module_ptr),Y
    CLC
    ADC base_lo
    STA (module_ptr),Y

    ; JAM → LDA # átalakítás
    INY
    INY
    INY                     ; JAM opcode pozíció
    LDA #$A9                ; LDA # opcode
    STA (module_ptr),Y

    ; High byte relokálása carry-vel!
    INY
    LDA (module_ptr),Y
    ADC base_hi             ; + carry from low byte!
    STA (module_ptr),Y
```

#### ABS,X/ABS,Y marker relokáció

A DATA szekció közvetlen eléréseihez a compiler marker opcode-okat használ:
- `$12` jelöli az `LDA abs,X` (`$BD`) utasításokat
- `$32` jelöli az `LDA abs,Y` (`$B9`) utasításokat

```asm
; Fordított kód (modulban) - tuple konstans indexű elérése:
    .byte $12           ; Marker (eredeti: $BD = LDA ABS,X)
    .word $0400         ; DATA offset (véletlen egyezés Screen RAM-mal!)

; Relokáció után ($C000 base esetén):
    LDA $C400,X         ; $BD $00 $C4 - helyes relokált cím!
```

A relokátor egyszerűen visszacseréli a marker opcode-ot és relokálja a címet:

```asm
.do_abs_marker:
    ; A = marker opcode ($12, $22, $32, $42, $52)
    TAX                     ; Mentés X-be

    ; Marker → eredeti opcode csere (lookup table)
    CPX #$12
    BNE .not_12
    LDA #$BD                ; LDA ABS,X
    JMP .patch_opcode
.not_12:
    CPX #$22
    BNE .not_22
    LDA #$AD                ; LDA ABS
    JMP .patch_opcode
.not_22:
    CPX #$32
    BNE .not_32
    LDA #$B9                ; LDA ABS,Y
    JMP .patch_opcode
.not_32:
    CPX #$42
    BNE .not_42
    LDA #$4C                ; JMP ABS
    JMP .patch_opcode
.not_42:
    LDA #$20                ; JSR ABS ($52)

.patch_opcode:
    STA (module_ptr),Y      ; Opcode visszaírása

    ; 16-bit cím relokálása (Y+1, Y+2 pozíción)
    INY                     ; Low byte
    LDA (module_ptr),Y
    CLC
    ADC base_lo
    STA (module_ptr),Y
    INY                     ; High byte
    LDA (module_ptr),Y
    ADC base_hi             ; + carry!
    STA (module_ptr),Y

    INY                     ; Következő utasításra
    JMP .loop
```

**Miért nem elég a high byte alapú detektálás az ABS,X/ABS,Y-nál?**

```asm
; Probléma: mindkét utasítás $04 high byte-tal:
LDA $0400,X         ; Screen RAM elérés - NE relokáld!
LDA tuple_data,Y    ; ahol tuple_data = $0400 offset - RELOKÁLD!

; A binárisban megkülönböztethetetlen:
; $BD $00 $04  vs  $B9 $00 $04
```

A marker egyértelműen jelöli a modul-belső címeket:
```asm
STA $0400,X         ; $9D $00 $04 - külső, változatlan
.byte $12, $00, $04 ; belső DATA - relokálandó!
```

### Példa

```
Modul eredetileg $0000-ra fordítva:
────────────────────────────────────
$0000: JSR $0050     ; 20 50 00  → relokálandó (JMP/JSR)
$0003: STA $0400,X   ; 9D 00 04  → NEM relokálandó (Screen RAM!)
$0006: STA $D400     ; 8D 00 D4  → NEM relokálandó (SID regiszter)
$0009: LDA #<$0200   ; A9 00     → relokálandó (JAM pattern)
$000B: STA tmp0      ; 85 02
$000D: .byte $02     ; 02        → JAM marker
$000E: .byte >$0200  ; 02        → high byte
$000F: STA tmp1      ; 85 03
$0011: .byte $12     ; 12        → ABS,X marker (tuple elérés)
$0012: .word $0400   ; 00 04     → DATA offset (történetesen = Screen RAM!)
$0015: STA tmp0      ; 85 02

Betöltés $C000-ra:
────────────────────────────────────
$C000: JSR $C050     ; 20 50 C0  ✓ (JMP/JSR relokálva)
$C003: STA $0400,X   ; 9D 00 04  ✓ (változatlan - külső cím!)
$C006: STA $D400     ; 8D 00 D4  ✓ (változatlan - HW regiszter)
$C009: LDA #$00      ; A9 00     ✓ (low relokálva)
$C00B: STA tmp0      ; 85 02     ✓
$C00D: LDA #$C2      ; A9 C2     ✓ (JAM → LDA #, high relokálva)
$C00F: STA tmp1      ; 85 03     ✓
$C011: LDA $C400,X   ; BD 00 C4  ✓ (marker → LDA, cím relokálva!)
$C014: STA tmp0      ; 85 02     ✓
```

**Kulcs megfigyelés:** A `$0400` cím kétszer szerepel:
1. `STA $0400,X` - Screen RAM elérés → **NEM** relokálódik (nincs marker)
2. `$12 $00 $04` - DATA szekció elérés → **RELOKÁLÓDIK** (marker jelöli!)

### Előnyök

| Tulajdonság             | Érték                         |
| ----------------------- | ----------------------------- |
| Relokációs tábla mérete | **0 byte!**                   |
| Extra modul overhead    | **0 byte!**                   |
| Loader komplexitás      | Nagyon egyszerű               |
| Max modul belső méret   | 2KB (bővíthető long jump-pal) |

## Modul Fájl Formátumok (.PM és .PMI)

A PyCo modul rendszer **két külön fájlt** használ:

| Fájl   | Tartalom         | Hol van        | Ki olvassa     |
| ------ | ---------------- | -------------- | -------------- |
| `.pm`  | Futtatható kód   | C64 floppy     | Runtime loader |
| `.pmi` | Típusinformációk | Fejlesztői gép | Compiler       |

### Miért két fájl?

1. **Kisebb terjesztési méret**: A `.pmi` (type info) SOHA nem kerül a C64 floppy-ra
2. **Gyorsabb runtime**: A loader nem parse-ol metaadatokat, csak kódot tölt
3. **Hordozhatóság**: A `.pmi` formátum működik PC-n és C64-en futó fordítóval is
4. **Védelem**: A típusinformációk nem kerülnek ki a terjesztett programmal

### .PM Fájl Formátum (Runtime Code)

```
┌─────────────────────────────────────────────────────────────┐
│ .PM FÁJL - Ez töltődik be a C64-re!                         │
├─────────────────────────────────────────────────────────────┤
│ HEADER (6 byte)                                             │
│   magic (2 byte): "PM" ASCII ($50 $4D)                │
│   code_size (2 byte): betöltendő méret (little-endian)      │
│   code_end (2 byte): kód vége, relokációs határ             │
├─────────────────────────────────────────────────────────────┤
│ JUMP TABLE (entry_count × 3 byte)                           │
│   JMP entry_0_code      ; $4C xx xx                         │
│   JMP entry_1_code      ; $4C xx xx                         │
│   ...                                                       │
├─────────────────────────────────────────────────────────────┤
│ CODE                                                        │
│   entry_0_code: ...                                         │
│   entry_1_code: ...                                         │
│   internal_functions: ...                                   │
│   ← code_end határ (relokáció csak eddig!)                  │
├─────────────────────────────────────────────────────────────┤
│ DATA (string literals, tuple data, etc.)                    │
├─────────────────────────────────────────────────────────────┤
│ SINGLETON DATA (ha van)                                     │
│   field1: .byte 0                                           │
│   field2: .word 0                                           │
└─────────────────────────────────────────────────────────────┘
```

**Header mezők:**

| Offset | Méret | Név        | Leírás                                              |
| ------ | ----- | ---------- | --------------------------------------------------- |
| 0-1    | 2     | magic      | `$1C $0E` - fájl azonosító ("P1C0 Extension")       |
| 2-3    | 2     | code_size  | Betöltendő byte-ok száma (header nélkül)            |
| 4-5    | 2     | code_end   | Hol végződik a kód, hol kezdődik az adat            |

**Miért kell a `code_end`?**

A relokátor végigmegy a modulon utasításról utasításra. Az adat szekcióban viszont
lehet olyan byte, ami véletlenül opcode-nak néz ki (pl. `$4C` egy string közepén).
Ha a relokátor ezt "JMP"-nak nézné, hibás relokáció történne. A `code_end` megmondja,
hol kell megállni.

**Miért van magic?**

A Kernal LOAD (`$FFD5`) secondary address 0-val betölt, és **kihagyja az első 2
byte-ot** (PRG header). Ezt a helyet használjuk a magic-re. A fordító compile-time
ellenőrzi a fájl érvényességét, futásidőben nincs overhead.

**Méret**: 6 byte header + futtatható kód, minimális metadata overhead!

### .PMI Fájl Formátum (Module Info)

A `.pmi` fájl kompakt bináris formátumú, hogy a C64-en futó fordító is tudja olvasni.

```
┌─────────────────────────────────────────────────────────────┐
│ .PMI FÁJL - Csak a fordító olvassa!                         │
├─────────────────────────────────────────────────────────────┤
│ HEADER                                                      │
│   magic (3 byte): "PMI"                                     │
│   version (1 byte): 1                                       │
│   module_name_len (1 byte)                                  │
│   module_name (N byte)                                      │
│   export_count (1 byte)                                     │
├─────────────────────────────────────────────────────────────┤
│ EXPORT ENTRIES (export_count darab)                         │
│   name_len (1 byte)                                         │
│   name (N byte)                                             │
│   export_type (1 byte): 0=func, 1=class, 2=singleton, 3=tuple│
│   jump_index (1 byte): pozíció a jump table-ben             │
│     (NINCS tuple-nél!)                                      │
│   [típus-specifikus adatok...]                              │
├─────────────────────────────────────────────────────────────┤
│ FUNCTION ENTRY (ha export_type = 0)                         │
│   param_count (1 byte)                                      │
│   param_types (N byte, kódolt típusok)                      │
│   return_type (1 byte, kódolt típus)                        │
│   flags (1 byte): bit0=is_naked, bit1=is_irq_helper         │
├─────────────────────────────────────────────────────────────┤
│ CLASS ENTRY (ha export_type = 1)                            │
│   instance_size (2 byte, word)                              │
│   property_count (1 byte)                                   │
│   PROPERTY ENTRIES (property_count darab):                  │
│     name_len (1 byte)                                       │
│     name (N byte)                                           │
│     type (N byte, kódolt típus)                             │
│     offset (2 byte, word)                                   │
│     size (1 byte)                                           │
│     flags (1 byte): bit0=has_address                        │
│     address (2 byte, csak ha has_address)                   │
│   method_count (1 byte)                                     │
│   METHOD ENTRIES (method_count darab):                      │
│     name_len (1 byte)                                       │
│     name (N byte)                                           │
│     jump_index (1 byte)                                     │
│     param_count (1 byte)                                    │
│     param_types (N byte)                                    │
│     return_type (1 byte)                                    │
│     flags (1 byte): bit0=is_naked, bit1=is_irq_helper       │
├─────────────────────────────────────────────────────────────┤
│ SINGLETON ENTRY (ha export_type = 2)                        │
│   (Azonos struktúra mint CLASS ENTRY)                       │
├─────────────────────────────────────────────────────────────┤
│ GLOBAL_TUPLE ENTRY (ha export_type = 3)                     │
│   element_type (1 byte, kódolt típus: byte, word, stb.)     │
│   element_count (2 byte, little-endian)                     │
│   offset (2 byte, little-endian) - offset a modul elejétől  │
└─────────────────────────────────────────────────────────────┘
```

### Típuskódolás a .PMI-ben

A típusok 1 vagy több byte-tal vannak kódolva:

#### Egyszerű típusok ($00-$1F) - 1 byte

| Kód | Típus  | Méret   |
| --- | ------ | ------- |
| $00 | void   | 0       |
| $01 | byte   | 1       |
| $02 | sbyte  | 1       |
| $03 | word   | 2       |
| $04 | int    | 2       |
| $05 | float  | 4       |
| $06 | f16    | 2       |
| $07 | f32    | 4       |
| $08 | bool   | 1       |
| $09 | char   | 1       |
| $0A | string | 2 (ptr) |

#### Összetett típusok ($20-$3F) - változó hossz

| Kód | Típus      | Formátum                       |
| --- | ---------- | ------------------------------ |
| $20 | array[T,N] | +1 byte elem_type +2 byte size |
| $21 | tuple[T]   | +1 byte elem_type              |

#### Referencia típusok ($40-$5F) - változó hossz

| Kód | Típus    | Formátum                       |
| --- | -------- | ------------------------------ |
| $40 | alias[T] | +N byte target_type (rekurzív) |

#### Osztály referenciák ($80-$FF)

| Kód     | Típus             | Jelentés          |
| ------- | ----------------- | ----------------- |
| $80-$BF | belső osztály     | index = kód & $3F |
| $C0-$FF | importált osztály | index = kód & $3F |

#### Típuskódolás referencia

| PyCo típus                 | Kódolás (hex)    |
| -------------------------- | ---------------- |
| `void`                     | `00`             |
| `byte`                     | `01`             |
| `sbyte`                    | `02`             |
| `word`                     | `03`             |
| `int`                      | `04`             |
| `float`                    | `05`             |
| `f16`                      | `06`             |
| `f32`                      | `07`             |
| `bool`                     | `08`             |
| `char`                     | `09`             |
| `string`                   | `0A`             |
| `alias[byte]`              | `40 01`          |
| `alias[word]`              | `40 03`          |
| `alias[char]`              | `40 09`          |
| `alias[string]`            | `40 0A`          |
| `tuple[byte]`              | `21 01`          |
| `tuple[word]`              | `21 03`          |
| `tuple[char]`              | `21 09`          |
| `array[byte, 64]`          | `20 01 40 00`    |
| `array[char, 256]`         | `20 09 00 01`    |
| `alias[array[byte, 1000]]` | `40 20 01 E8 03` |
| `Screen` (belső, index 0)  | `80`             |

### Fordítási és betöltési folyamat

**1. Modul fordítása:**
```bash
pycoc compile math.pyco --module
```
Eredmény:
- `math.pm` → Bináris kód (megy a C64 floppy-ra)
- `math.pmi` → Típusinfo (MARAD a fejlesztői gépen)

**2. Import feldolgozás (fordításkor):**
- Compiler megnyitja a `.pmi` fájlt
- Ellenőrzi: létezik-e az importált név?
- Ellenőrzi: publikus-e? (nincs `_` prefix)
- Ellenőrzi: paraméter típusok stimmelnek?
- Megjegyzi: entry point offset-ek

**3. Runtime betöltés:**
- Loader megnyitja a `.pm` fájlt
- Olvassa a `code_size`-t (2 byte)
- Betölti a kódot → SSP (stack teteje)
- Relokáció a marker-byte/JAM alapján
- **Nincs .pmi olvasás runtime-ban!**

## Betöltési Mechanizmus

### Statikus Import (compile-time)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Fordító látja: from math import sin                      │
│                          ↓                                  │
│ 2. Megnyitja: math.pm                                    │
│    - Olvassa az Info Section-t (metaadatok)                 │
│    - Ellenőrzi: van 'sin' szimbólum? ✓                      │
│    - Ellenőrzi: publikus? ✓ (nincs _ prefix)                │
│    - Ellenőrzi: paraméterek OK? ✓                           │
│                          ↓                                  │
│ 3. Beolvassa a Code Section-t                               │
│    - Beilleszti a PRG-be                                    │
│    - Compile-time relokáció (ismert fix cím)                │
│                          ↓                                  │
│ 4. Hívás: JSR sin_relocated_address                         │
└─────────────────────────────────────────────────────────────┘
```

### Dinamikus Import (runtime)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Fordító látja: import math                               │
│                          ↓                                  │
│ 2. Megnyitja: math.pm                                    │
│    - Olvassa az Info Section-t (metaadatok, aláírások)      │
│    - BSS-ben helyet foglal: __mod_math: .word 0             │
│    - Megjegyzi entry offset-eket (sin = 0, cos = 3, ...)    │
│    - Kód NEM fordul be!                                     │
│                          ↓                                  │
│ 3. Runtime: load_module(math) hívás                         │
│    - OPEN 8,8,8,"MATH.PM,S,R"                            │
│    - READ 2 byte → code_size                                │
│    - READ code_size byte → SSP-re (stack teteje)            │
│    - Relokáció (marker-byte scan)                           │
│    - __mod_math = SSP (BSS pointer beállítás)               │
│    - SSP += code_size                                       │
│    - CLOSE                                                  │
│                          ↓                                  │
│ 4. Hívás: math.sin(0.5)                                     │
│    - Generált kód: JSR (__mod_math + SIN_OFFSET)            │
│                          ↓                                  │
│ 5. Függvény return → SSP visszaáll → modul "eltűnik"        │
│    - __mod_math pointer MARAD (programozó felelőssége!)     │
└─────────────────────────────────────────────────────────────┘
```

## Dinamikus Import Korlátozások

A dinamikus importoknak korlátozásai vannak a statikus importhoz képest a futásidejű modul betöltés miatt.

### Funkció Összehasonlítás

| Funkció                  | Statikus (`from X import`) | Dinamikus (`import X`)           |
|--------------------------|---------------------------|----------------------------------|
| Modul szintű függvények  | ✅ Teljes támogatás       | ✅ Teljes támogatás              |
| Singleton osztályok      | ✅ Auto-init default-ok   | ⚠️ Kötelező explicit `X.Class()` |
| Normál osztályok         | ✅ Teljes támogatás       | ✅ Teljes támogatás              |
| Property default értékek | ✅ Automatikus            | ⚠️ Csak `__init__`-ben           |

### Singleton vs Normál Osztály Használata

**Singleton osztályok** (BSS-ben tárolva):
```python
import config

def main():
    load_module(config)
    config.Config()                    # Kötelező inicializálás!
    print(config.Config.value)         # Közvetlen property hozzáférés
```

**Normál osztályok** (stack-en allokálva):
```python
import counter

def main():
    c: counter.Counter                 # Stack allokáció (méret a PMI-ből)
    load_module(counter)
    c()                                # __init__ hívás
    c.increment()                      # Metódus hívás
    print(c.get_value())
```

### Property Default Értékek

A dinamikus importnál a property default értékek az `__init__` metódusban állítódnak be, mert:
- A fordító csak `.pmi` fájlokat olvas, amik típus információt tartalmaznak
- A property default értékek a modul kódjában vannak, nem a `.pmi`-ben
- Ezért a default-ok futásidőben, az `__init__` híváskor töltődnek be

**Fontos:** A normál osztályoknál az `__init__` hívás (`obj()`) kötelező a default értékek beállításához!

### Legjobb Gyakorlat

Mindig használj explicit `__init__` metódust a dinamikus importra szánt osztályoknál:

```python
# A modulodban (pl. config.pyco)
@singleton
class Config:
    value: byte
    timeout: word

    def __init__():
        # MINDEN default-ot itt állíts be!
        self.value = 42
        self.timeout = 1000
```

```python
# A hívóban
import config

def main():
    load_module(config)
    config.Config()          # KÖTELEZŐ - meghívja __init__-et, beállítja a default-okat
    print(config.Config.value)  # Most helyesen 42-t mutat
```

### BSS Memória Elrendezés Statikus Singleton-oknál

Statikus importnál (`from module import Class`) a singleton BSS a **modul kódjával együtt** ágyazódik be:

```
__MOD_modulename:
    │
    ├── Jump table (3 byte/entry)
    │
    ├── Modul kód (code_bytes)
    │
    └── .fill bss_size, 0     ← Singleton BSS rezerválva!
          │
          └── __SI_ClassName = __MOD_modulename + code_size
```

**Fontos:** A singleton BSS a modul RÉSZÉNEK számít, nem az importer BSS-ében van!
A JAM marker relokáció automatikusan működik: `__MOD_xxx + offset` pont a megfelelő helyre mutat.

**Példa generált assembly:**
```asm
// Modul beágyazás
__MOD_counter:
    .byte $4C, <(...), >(...)    // Jump table
    .byte ...                     // Modul kód
    .fill 1, 0                    // BSS (1 byte a Counter singleton-nak)
    .label __SI_Counter = __MOD_counter + $0059
```

### BSS Memória Elrendezés Dinamikus Singleton-oknál

Dinamikus importnál (`import module` + `load_module()`) a singleton BSS az **importer BSS-ében** van:

```
__program_end
    │
    ├── __SI_LocalSingleton (lokális singleton adat)
    │
    ├── __mod_screen (2 bájt - modul pointer)
    │
    └── __DSI_screen_Screen (singleton példány adat)
          │
          └── __singletons_end = SSP start
```

**Fontos különbség:**
- Statikus: `__SI_ClassName` a modul BSS-ére mutat (modul része)
- Dinamikus: `__DSI_module_ClassName` az importer BSS-ében (külön allokálva)

## Globális Tuple Export/Import

### Tuple Export

A modulok exportálhatják a globális tuple-jeiket, ha azok neve nem `_` prefixes:

```python
# screen.pyco - modul
SCREEN_RAM = 0x0400

# Exportált globális tuple (publikus)
row_offsets: tuple[word] = (
    0, 40, 80, 120, 160, 200, 240, 280, 320, 360,
    400, 440, 480, 520, 560, 600, 640, 680, 720, 760,
    800, 840, 880, 920, 960
)

# Privát tuple (NEM exportált)
_internal_buffer: tuple[byte] = (0, 1, 2, 3)

def main():
    pass
```

### Statikus Tuple Import

```python
# main.pyco - használó program
from screen import row_offsets

@lowercase
def main():
    y: byte = 5
    offset: word
    offset = row_offsets[y]  # 200
    print(offset)
```

**Generált kód:**
```asm
; A tuple a modul kódjával együtt befordul
; Hozzáférés: __MOD_screen + tuple_offset + index*elem_size
lda __MOD_screen+762+10   ; row_offsets[5] low byte (5*2=10)
sta tmp0
lda __MOD_screen+762+11   ; row_offsets[5] high byte
sta tmp1
```

### PMI Tuple Entry

A `.pmi` fájlban a tuple export 6 byte:

| Offset | Méret | Mező          | Leírás                          |
| ------ | ----- | ------------- | ------------------------------- |
| 0      | 1     | export_type   | 3 (GLOBAL_TUPLE)                |
| 1      | 1     | element_type  | Elem típuskód (pl. $03 = word)  |
| 2-3    | 2     | element_count | Elemek száma (little-endian)    |
| 4-5    | 2     | offset        | Offset a modul elejétől (bytes) |

**Megjegyzés:** A tuple exportnál NINCS `jump_index`, mert a tuple adat, nem kód.

### Tuple vs Függvény Különbség

| Tulajdonság | Függvény/Osztály        | Tuple                      |
| ----------- | ----------------------- | -------------------------- |
| PMI entry   | jump_index + aláírás    | elem_type + count + offset |
| Hozzáférés  | JSR (jump table-ön át)  | LDA (közvetlen cím)        |
| Relokáció   | Jump table relokálva    | Base + offset számítás     |

### Dinamikus Tuple Import

```python
# main.pyco - dinamikus import
import screen

@lowercase
def main():
    load_module(screen)
    offset: word = screen.row_offsets[5]  # Futásidejű hozzáférés
    print(offset)  # 200
```

**Generált kód:**
```asm
; A modul BSS pointerét futásidőben olvassuk
clc
lda __mod_screen       ; BSS pointer (modul base)
adc #<762              ; + tuple offset
sta tmp0
lda __mod_screen+1
adc #>762
sta tmp1
; Indirekt címzés az indexszel
ldy #10                ; index * elem_size (5 * 2)
lda (tmp0),y           ; low byte
sta tmp2
iny
lda (tmp0),y           ; high byte
```

**Fontos:** A dinamikus tuple hozzáférés csak a `load_module()` hívás UTÁN működik!

## Használati Példák

### Példa 1: Egyszerű játék

```python
# Statikus - mindig kell
from utils import clear_screen, wait_key

# Dinamikus - screen-enként cserélhető
import menu_module
import game_module
import highscore_module

def main():
    while True:
        # Menu screen
        load_module(menu_module)
        choice = menu_module.show_menu()
        # Return → menu_module felszabadul

        if choice == 1:
            # Game screen - teljes RAM használható!
            load_module(game_module)
            score = game_module.play()
            # Return → game_module felszabadul

            # Highscore screen
            load_module(highscore_module)
            highscore_module.check_and_save(score)
            # Return → highscore_module felszabadul
```

### Példa 2: Megosztott modul több függvényben

```python
import math

def game_session():
    load_module(math)         # Betöltés

    while running:
        game_loop()           # math.sin() működik
        update_physics()      # math.cos() működik

    # Return → math felszabadul

def game_loop():
    # Nem kell load_module - game_session() már betöltötte
    x = math.sin(angle)       # Működik!

def update_physics():
    # Ez is használhatja
    force = math.cos(angle) * gravity
```

**Fontos:** A programozó felelőssége, hogy `game_loop()` és `update_physics()` csak `game_session()`-ből legyen hívva!

### Példa 3: Egymásba ágyazott modulok (LIFO)

```python
import math
import sprites

def render_frame():
    load_module(math)         # Stack: [math]
    load_module(sprites)      # Stack: [math, sprites]

    for obj in objects:
        x = math.sin(obj.angle)
        sprites.draw(obj.sprite, x, obj.y)

    # Return → Stack: [] (LIFO: sprites, majd math felszabadul)
```

## Hibaüzenetek

### Fordítási idejű hibák

```
main.pyco:3: Error: Unknown module 'maht'. Did you mean 'math'?
main.pyco:5: Error: Module 'math' has no export 'sn'. Did you mean 'sin'?
main.pyco:7: Error: Cannot import '_helper' from 'math': name is private
main.pyco:10: Error: 'sin' already imported from 'math'
main.pyco:15: Error: Type mismatch: math.sin expects float, got byte
```

### Futásidejű hibák

```
Runtime Error: Module 'MUSIC.PM' not found on disk
Runtime Error: Out of memory loading module (need 1234 bytes, have 500)
Runtime Error: Module format error (invalid magic)
```

## Összefoglalás

### Két import mód

| Szintaxis            | Compile-time           | Runtime          | Használat        |
| -------------------- | ---------------------- | ---------------- | ---------------- |
| `from X import a, b` | Kód befordul           | -                | `a()`, `b()`     |
| `import X`           | Info Section + BSS ptr | `load_module(X)` | `X.a()`, `X.b()` |

### Export szabályok

| Név formátum                | Exportálva? |
| --------------------------- | ----------- |
| `name`                      | ✓ Igen      |
| `_name`                     | ✗ Nem       |
| `from X import foo`         | ✓ Igen      |
| `from X import foo as _foo` | ✗ Nem       |

### Marker-byte rendszer

| High byte | Jelentés                              |
| --------- | ------------------------------------- |
| `$00-$07` | Marker (relokálandó, modul-belső cím) |
| `$08-$FF` | Fix cím (HW regiszter, külső memória) |

### Programozói felelősség

- A `load_module()` után a modul használható
- Függvény return után a stack visszaáll, modul "eltűnik"
- A BSS pointer (`__mod_X`) megmarad - **szemét címre mutathat!**
- Ha betöltés nélkül hívod → **crash** (és ez rendben van)

---

*Verzió: 3.6 - 2026-01-18*
*Változások: Dinamikus tuple import támogatás (`module.tuple[index]` a `load_module()` után)*
