# PyCo Kódgenerátor Terv

Ez a dokumentum a PyCo fordító kódgenerátor komponensének tervezési döntéseit tartalmazza.

## Áttekintés

A kódgenerátor a validált AST-ből Kick Assembler forráskódot állít elő, ami aztán 6502 gépi kódra fordul.

```
┌─────────┐    ┌──────────┐    ┌───────────┐    ┌────────────┐    ┌─────────┐
│ Parser  │ →  │ Include  │ →  │ Validator │ →  │ CodeGen    │ →  │ .asm    │
│         │    │ Resolver │    │           │    │            │    │ output  │
└─────────┘    └──────────┘    └───────────┘    └────────────┘    └─────────┘
```

## C64 Memória Layout

### Teljes memóriatérkép

```
$0000-$00FF   Zero Page (256 byte) - Gyors elérésű változók
$0100-$01FF   Stack (256 byte) - 6502 hardver stack
$0200-$03FF   OS munka terület
$0400-$07FF   Screen RAM (1000 byte + színkódok)
$0801-$CFFF   PROGRAM + STACK (~51KB, nincs fix határ)
$D000-$DFFF   I/O + Character ROM
$E000-$FFFF   KERNAL ROM (marad, kell az I/O-hoz)
```

**BASIC ROM kikapcsolva!** A PyCo programok automatikusan kikapcsolják a BASIC ROM-ot ($A000-$BFFF), mert:
- Nem használjuk a BASIC interpretert
- +8KB extra RAM
- A KERNAL ROM ($E000-$FFFF) **marad bekapcsolva** - szükséges a CHROUT, file I/O, stb. rutinokhoz

**Megjegyzés:** A $0801-$CFFF terület nincs felosztva "program" és "stack" részre. A program $0801-től foglal helyet felfelé, a stack a program végétől nő tovább. Nincs ellenőrzés - a user felelőssége, hogy a memory-mapped változói ne ütközzenek a stack-kel.

### PyCo Program Struktúra

A BasicUpstart2 makró automatikusan generálja a BASIC loadert, és a kód **közvetlenül utána** kezdődik. Nincs szükség fix címre (pl. $1000) - ez memóriát takarít meg.

```
$0801         BASIC loader (SYS xxxx) - BasicUpstart2 generálja
$080D~        ┌─────────────────────────────┐  ← Kód RÖGTÖN a loader után!
              │ CODE SEGMENT                │
              │ - main()                    │
              │ - user functions            │
              │ - class methods             │
              │ - runtime helpers           │
              └─────────────────────────────┘
              ┌─────────────────────────────┐
              │ DATA SEGMENT                │
              │ - string literals           │
              │ - array constants           │
              └─────────────────────────────┘
              ┌─────────────────────────────┐
              │ BSS SEGMENT (runtime)       │
              │ - global object instances   │
              │ - static arrays             │
              └─────────────────────────────┘
$00-$7F       ┌─────────────────────────────┐
(Zero Page)   │ RUNTIME VARIABLES           │
              │ - stack pointer simulation  │
              │ - temp registers            │
              │ - frame pointer             │
              │ - function params/returns   │
              └─────────────────────────────┘
```

**Megjegyzés:** A BasicUpstart2 kb. 12 byte-ot foglal, így a kód ~$080D-nél kezdődik. A pontos cím a Kick Assembler-re van bízva - nekünk csak címkéket kell használni.

## Zero Page Allokáció

A Zero Page a legértékesebb memória a 6502-n - 1 byte-os címzés, gyorsabb műveletek.

### Fordító által használt terület

| Cím        | Méret | Cél                                                     |
| ---------- | ----- | ------------------------------------------------------- |
| $02-$07    | 6     | Temp regiszterek (tmp0-tmp5)                            |
| $08-$09    | 2     | Frame Pointer (FP)                                      |
| $0A-$0B    | 2     | Software Stack Pointer (SSP)                            |
| $0C-$0D    | 2     | Sprint buffer pointer (spbuf)                           |
| $0E        | 1     | Sprint buffer position (sppos)                          |
| $0F-$12    | 4     | Return value (retval) - 4 byte float támogatáshoz       |
| $0F        | 2     | Sprint saved CHROUT (spsave) - átfedi retval-t          |
| $11        | 1     | Sprint temp (sptmp) - átfedi retval+2-t                 |
| $13-$15    | 3     | String temp registers (tmp6-tmp8)                       |
| $16-$17    | 2     | Self pointer (ZP_SELF) - metódus optimalizáláshoz       |

**Megjegyzések:**
- **Sprint overlap**: spsave/sptmp átfedi retval-t, de sosem aktívak egyszerre
- **Compiler ZP** ($02-$17): Folytonos blokk a fordító számára

### Float regiszterek (BASIC FAC/ARG területén)

A float regiszterek a C64 BASIC saját FAC/ARG helyén vannak - ez elkerüli a ZP konfliktusokat és nem korruptálja a BASIC-et program kilépéskor.

| Cím        | Méret | Cél                                                     |
| ---------- | ----- | ------------------------------------------------------- |
| $57-$59    | 3     | RESULT buffer (multiply/divide)                         |
| $5A-$5B    | 2     | INDEX pointer                                           |
| $5C        | 1     | SGNCPR (sign compare result)                            |
| $5D        | 1     | SHIFTSIGNEXT (shift sign extension)                     |
| $61        | 1     | FAC exponent - BASIC FAC helye                          |
| $62-$64    | 3     | FAC mantissa (FAC1, FAC2, FAC3)                         |
| $65        | 1     | FAC sign (FACSGN)                                       |
| $66        | 1     | FAC extension (FACEXT)                                  |
| $69        | 1     | ARG exponent - BASIC ARG helye                          |
| $6A-$6C    | 3     | ARG mantissa (ARG1, ARG2, ARG3)                         |
| $6D        | 1     | ARG sign (ARGSGN)                                       |
| $6E        | 1     | ARG extension (ARGEXT)                                  |

**Miért itt?** A BASIC is float műveletekhez használja ezeket a címeket. Ha a program visszatér a BASIC-be, a BASIC úgyis felülírja őket a következő float műveletkor - nincs korrupció!

### Felhasználó számára elérhető

| Cím        | Méret | Cél                                        |
| ---------- | ----- | ------------------------------------------ |
| $18-$56    | 63    | Szabad - memory-mapped változókhoz         |
| $5E-$60    | 3     | Szabad (float work terület után)           |
| $67-$68    | 2     | Szabad (FAC és ARG között)                 |
| $6F-$7F    | 17    | Szabad (ARG után)                          |

**A felhasználó saját maga mappelhet ZP-re** ha gyors elérésű változóra van szüksége:

```python
# Gyors változók a Zero Page-en
# $18-$56 folytonos blokk szabad! (63 byte)
fast_x: byte[0x18]
fast_y: byte[0x19]
temp_ptr: word[0x1A]
```

**Miért nincs automatikus ZP allokáció lokális változókhoz?**
- Beágyazott függvényhívásoknál a ZP változók felülíródnának
- A user jobban tudja, minek kell igazán gyorsnak lennie
- Egyszerűbb fordító, kevesebb mágikus viselkedés

**Megjegyzés:** A $00-$01 a 6502 CPU portja, $80-$FF-et a KERNAL használja.

## Típusok Memória Reprezentációja

### Primitív típusok

| Típus  | Méret   | Reprezentáció                          |
| ------ | ------- | -------------------------------------- |
| bool   | 1 byte  | 0 = false, ≠0 = true                   |
| char   | 1 byte  | PETSCII kód                            |
| byte   | 1 byte  | 0-255 unsigned                         |
| sbyte  | 1 byte  | -128 to 127 signed (two's complement)  |
| word   | 2 bytes | Little-endian, 0-65535                 |
| int    | 2 bytes | Little-endian, -32768 to 32767 signed  |
| float  | 4 bytes | Microsoft Binary Format (MBF) 32-bit   |

### String

Pascal-típusú string: első byte a hossz, utána a karakterek.

```
┌────────┬────────┬────────┬─────┬────────┐
│ length │ char 0 │ char 1 │ ... │ char N │
│ 1 byte │ 1 byte │ 1 byte │     │ 1 byte │
└────────┴────────┴────────┴─────┴────────┘
```

Max 255 karakter.

#### Deklaráció és méret

| Szintaxis                        | Lefoglalt méret | Magyarázat                        |
| -------------------------------- | --------------- | --------------------------------- |
| `s: string = "Hello"`            | 6 byte          | Konstansból: 1 (hossz) + 5 (kar)  |
| `s: string[80]`                  | 81 byte         | Explicit buffer méret             |
| `s: string[80] = "Hi"`           | 81 byte         | Buffer + kezdőérték               |
| `s: string[40][0x0400]`          | 0 byte (mapped) | Memory-mapped, fix címen          |

**Miért fontos az explicit méret?**
- `sprint()` híváshoz buffer kell, amibe írunk
- Dinamikusan épített stringekhez (pl. score kiírás)
- A fordító tudja, mennyi helyet foglaljon a stacken/BSS-ben

**Memória layout példa:**
```python
buffer: string[80]    # 81 byte a stacken
```

```
Stack:
┌────────┬────────────────────────────────────────┐
│ length │ 80 byte karakter buffer                │
│ 1 byte │ (aktuális tartalom + szabad hely)      │
└────────┴────────────────────────────────────────┘
```

### Array

Fix méretű, folytonos memóriaterület.

```
array[byte, 10]  →  10 byte folytonosan
array[int, 5]    →  10 byte (5 × 2)
array[Enemy, 8]  →  8 × sizeof(Enemy) byte
```

Az index típusa automatikus:
- ≤256 elem: byte index (gyorsabb)
- \>256 elem: word index

### Osztály Instance

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
│ offset │ offset │ offset       │
│ 0      │ 1      │ 2            │
└────────┴────────┴──────────────┘
```

### Öröklődés

A gyermek osztály a szülő property-jeit örökli az elejére:

```python
class Position:
    x: byte = 0      # offset 0
    y: byte = 0      # offset 1

class Player(Position):
    # örökölt: x (offset 0), y (offset 1)
    score: int = 0   # offset 2
    name: string[20] # offset 4 (20+1 = 21 byte buffer)
```

**Összméret számítás:**
- Position: 2 byte (x + y)
- Player: 2 + 2 + 21 = 25 byte (örökölt x,y + score + name buffer)

## Függvényhívási Konvenció

### Software Stack

A 6502 hardver stackje csak 256 byte és lassan kezelhető összetett adatokra. Ezért **software stack**-et használunk a lokális változókhoz és objektumokhoz.

**Nincs fix méretkorlát!** Mivel nincs dinamikus memóriakezelés (heap), a stack a **teljes szabad memóriát** használhatja.

```
$0801         ┌─────────────────────────────┐
              │ Program (code + data + bss) │
$xxxx         └─────────────────────────────┘ ← _program_end címke
              ┌─────────────────────────────┐
              │ STACK                       │
              │ (felfelé nő, ameddig kell)  │
              │                             │
$CFFF         └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘ ← nincs határ, csak I/O ($D000+)
```

**Nincs stack határ ellenőrzés!** A stack addig nő, ameddig a program viszi:
- Ha a user $C000-ra mappel sprite-ot és a stack sosem ér oda → működik
- Ha a stack mégis odaér → felülírja, undefined behavior
- Végtelen rekurzió → totális káosz (átmegy az I/O-n is)

Ez konzisztens a PyCo filozófiájával: nincs runtime overhead, teljes felelősség a programozónál.

**Inicializálás:**
```asm
.label _program_end = *           // A program végét jelöli
.label SSP = $0A                  // Zero Page pointer

// Runtime init (main előtt):
_pyco_init:
    // BASIC ROM kikapcsolása (+8KB RAM)
    lda $01
    and #%11111110                // Bit 0 = 0: BASIC ROM ki
    sta $01

    // Stack pointer inicializálása
    lda #<_program_end
    sta SSP
    lda #>_program_end
    sta SSP+1

    jmp main
```

**Miért felfelé nő?**
- A kezdőcím egyszerűen meghatározható (program vége)
- Nincs szükség a memória méretének ismeretére induláskor
- Stack overflow = belelóg a ROM-ba (ami amúgy is hiba lenne)

### Hívási sorrend

**Egyszerű konvenció:** Minden paraméter és lokális változó a stack-en van. Nincs ZP paraméter átadás - ez egyszerűsíti a fordítót és elkerüli a nested hívás problémákat.

1. **Caller** (hívó):
   ```asm
   ; Stack frame növelése a paramétereknek
   ; (a callee frame-jébe írunk)
   clc
   lda SSP
   adc #PARAM_SIZE
   sta SSP
   bcc +
   inc SSP+1
+:
   ; Paraméterek a stack-re
   lda #<value1
   ldy #0
   sta (frame_ptr),y     ; param1 low
   lda #>value1
   iny
   sta (frame_ptr),y     ; param1 high
   ; ... további paraméterek ...

   ; Függvény hívása
   jsr function_name

   ; Visszatérési érték: retval ($0E-$0F)
   ```

2. **Callee** (hívott):
   ```asm
   function_name:
       ; Frame már tartalmazza a paramétereket!
       ; Stack frame növelése a LOKÁLIS változóknak
       clc
       lda SSP
       adc #LOCAL_SIZE
       sta SSP
       bcc +
       inc SSP+1
   +:
       ; Paraméterek és lokálisok a frame-ben
       ; Paraméter offsets: 0, 2, 4, ...
       ; Lokális offsets: PARAM_SIZE + 0, +2, ...

       ; ... function body ...

       ; Frame cleanup - teljes frame (params + locals)
       sec
       lda SSP
       sbc #(PARAM_SIZE + LOCAL_SIZE)
       sta SSP
       bcs +
       dec SSP+1
   +:
       rts
   ```

### Paraméter átadás

**Nyelvi szabály:** Összetett típusok (objektum, tömb, string) **csak `alias[T]` típusként** adhatók át!

| Kategória                  | Paraméter típus           | Átadás módja           | Hely          |
| -------------------------- | ------------------------- | ---------------------- | ------------- |
| Primitív (1-2B)            | `byte`, `int`, stb.       | Érték szerint          | Stack frame   |
| Összetett (közvetlen)      | `Enemy`, `array[byte,10]` | ❌ **FORDÍTÁSI HIBA**  | -             |
| Alias                      | `alias[Enemy]`            | Pointer (2 byte)       | Stack frame   |

**Automatikus cím átadás:**

Ha a paraméter `alias[T]` típusú, a fordító automatikusan `addr()` hívást generál:

```python
def process(e: alias[Enemy]):
    e.x = 50

def main():
    enemy: Enemy
    process(enemy)           # Fordító: process(addr(enemy))
```

**Generált kód:**
```asm
; process(enemy) hívás - alias paraméter
clc
lda FP                       ; enemy címe a stack-en
adc #ENEMY_OFFSET
sta (SSP),y                  ; alias low byte a paraméter helyére
lda FP+1
adc #0
iny
sta (SSP),y                  ; alias high byte
jsr __F_process
```

**Miért stack és nem ZP?**
- Nested hívások nem írják felül a paramétereket
- Egyszerűbb fordító (nincs másolgatás)
- +16 byte ZP felszabadul a user számára
- Későbbi optimalizáció: "leaf function" detektálás → ZP használat automatikusan

### Visszatérési érték

**Nyelvi szabály:** Összetett típusok visszatérése **csak `alias[T]` típusként** lehetséges!

| Kategória             | Visszatérési típus     | Hol van az érték         | Élettartam           |
| --------------------- | ---------------------- | ------------------------ | -------------------- |
| Primitív (1 byte)     | `byte`, `bool`, stb.   | A regiszter              | Azonnal használható  |
| Primitív (2 byte)     | `word`, `int`          | `retval` ($0E-$0F)       | Azonnal használható  |
| Összetett (közvetlen) | `Enemy`                | ❌ **FORDÍTÁSI HIBA**    | -                    |
| Alias                 | `alias[Enemy]`         | `retval` (pointer)       | Statement végéig!    |

**Deferred cleanup:**

Összetett típus visszatérésekor a függvény **NEM takarítja el** a lokális változóit! Az adat a stack-en marad, és a `retval` erre mutat. A takarítás a **statement végén** történik.

```python
def create_enemy() -> alias[Enemy]:
    e: Enemy = Enemy()
    e.x = 100
    return e                 # NEM takarít! retval = &e

def main():
    result: Enemy = create_enemy()  # Másolás retval-ból, MAJD takarítás
```

Részletek: `docs/deferred_cleanup_hu.md`

## Metódusok és Self

### Self mint ZP-optimalizált paraméter

**Optimalizált megközelítés:** A `self` paraméter **stack-en kerül átadásra**, de a metódus belsejében **Zero Page cache-be ($0F-$10 = ZP_SELF) töltődik** a gyors property hozzáféréshez!

Ez kombinálja a stack biztonságát (nested hívások) a ZP sebességével (property access).

```asm
; === MAIN-BŐL HÍVÁS: player.move(10, 5) ===
; 1. Load player címe ZP_SELF-be
lda #<__B_player
sta ZP_SELF        ; $0F
lda #>__B_player
sta ZP_SELF+1      ; $10

; 2. Explicit paraméterek push (ha vannak)
lda #10
ldy #0
sta (SSP),y        ; dx
inc SSP
lda #5
sta (SSP),y        ; dy
inc SSP

; 3. Metódus hívás
jsr __C_Player_move
; KÖLTSÉG: ~12 ciklus (ZP load) vs. ~30 ciklus (stack push)!

; === SAJÁT METÓDUS HÍVÁS: self.update() ===
; self már ZP_SELF-ben van!
jsr __C_Player_update
; KÖLTSÉG: 0 extra ciklus! 🚀
```

### Property elérés metódusból (ZP-optimalizált!)

A metódus belsejében `self` pointer **már a ZP_SELF-ben van** ($0F-$10), így a property-k **direkt ZP indirect indexeléssel** érhetők el!

```python
self.health += 10
```

Assembly (ZP-optimalizált):
```asm
; Metódus prólog (egyszer, a metódus elején):
; (Nincs szükség self betöltésre - már ZP_SELF-ben van!)

; self.health olvasás és módosítás (offset 2, word)
ldy #2
lda (ZP_SELF),y      ; health low - DIREKT ZP ACCESS! 🚀
clc
adc #10
pha                  ; Mentés
iny
lda (ZP_SELF),y      ; health high
adc #0               ; Carry folytatás
tax                  ; Mentés X-be

; self.health írás
ldy #2
pla
sta (ZP_SELF),y      ; health low
iny
txa
sta (ZP_SELF),y      ; health high

; KÖLTSÉG: ~20 ciklus vs. ~50+ ciklus (stack-based)!
```

### Miért ZP cache (hibrid megközelítés)?

**Előnyök:**

1. **Sebesség** - Property hozzáférés 2-3X gyorsabb ZP indirect indexeléssel!
2. **Saját metódus hívás INGYENES** - `self.update()` → csak JSR, nincs ZP save/restore!
3. **Nested hívások biztonságosak** - Másik objektum hívásakor ZP save/restore automatikus
4. **Main-ből gyorsabb** - 18 ciklus megtakarítás már az első hívásnál!

**Kompromisszum:**

- Másik objektum hívása: +20 ciklus overhead (ZP save/restore)
- De ez **még mindig gyorsabb** a tisztán stack-based megoldásnál (+30 ciklus)!

**Összesítve:** Reális kódban (sok property access, saját metódus hívások) **3-4X sebességnövekedés**! 🚀

### Másik objektum hívása (ZP save/restore)

Amikor egy metódus **másik objektum metódusát** hívja, a `ZP_SELF` értékét meg kell menteni és vissza kell állítani:

```python
def process_bullet(self, bullet: Bullet):
    # self = player, bullet = másik objektum
    bullet.update()      # Nested call - másik objektum!
    self.score += 10     # self-et vissza kell állítani
```

Assembly kód:
```asm
__C_Player_process_bullet:
    ; self pointer már ZP_SELF-ben van (Player objektum)
    ; bullet paraméter SSP-1 címen (word pointer)

    ; === NESTED CALL - MÁSIK OBJEKTUM ===
    ; 1. ZP_SELF mentése stackre (save)
    lda ZP_SELF
    pha
    lda ZP_SELF+1
    pha
    ; KÖLTSÉG: ~10 ciklus

    ; 2. Új self betöltése (bullet pointer)
    dec SSP
    ldy #0
    lda (SSP),y       ; bullet pointer low
    sta ZP_SELF
    iny
    lda (SSP),y       ; bullet pointer high
    sta ZP_SELF+1
    dec SSP
    ; KÖLTSÉG: ~12 ciklus

    ; 3. Metódus hívás
    jsr __C_Bullet_update

    ; 4. Eredeti ZP_SELF visszaállítása (restore)
    pla
    sta ZP_SELF+1
    pla
    sta ZP_SELF
    ; KÖLTSÉG: ~8 ciklus

    ; === Most self ismét a Player objektum ===
    ; self.score += 10
    ldy #SCORE_OFFSET    ; score property offset
    lda (ZP_SELF),y      ; Player.score low
    clc
    adc #10
    sta (ZP_SELF),y
    iny
    lda (ZP_SELF),y      ; Player.score high
    adc #0
    sta (ZP_SELF),y

    rts

; ÖSSZESÍTETT KÖLTSÉG:
; Nested call overhead: ~30 ciklus (save + load + restore)
; vs. stack-based: ~60 ciklus (2x stack push/pop)
; NYERESÉG: 2X gyorsabb! 🚀
```

**Optimalizációs esetek:**

| Eset                      | ZP_SELF művelet     | Költség         |
| ------------------------- | ------------------- | --------------- |
| `player.move()`           | Load to ZP          | ~12 ciklus      |
| `self.update()`           | **NINCS**           | **0 ciklus!**   |
| `other.update()`          | Save + Load + Rest. | ~30 ciklus      |
| Property access (`self.x`)| **NINCS** (ZP van!) | ~7 ciklus       |

## Osztály Implementáció

### Nincs VMT (Virtual Method Table)

Egyszerűsítés: a PyCo **nem támogat polimorfizmust** futásidőben. Az osztályok csak adatstruktúrák + statikusan linkelt metódusok.

```python
class Enemy:
    def move(dx: byte):
        self.x += dx
```

Generált kód:
```asm
__C_Enemy_move:           ; Mangled name: __C_ClassName_method
    ; METÓDUS PRÓLOG:
    ; self pointer már ZP_SELF-ben van ($0F-$10) - a hívó töltötte be!
    ; dx paraméter a stack tetején (SSP-1)

    ; self.x olvasása (offset 0)
    ldy #0
    lda (ZP_SELF),y       ; self.x - ZP indirect indexed! 🚀
    pha                   ; Mentés stackre

    ; dx paraméter olvasása stackről
    dec SSP               ; SSP vissza dx-re
    ldy #0
    lda (SSP),y           ; dx
    tax                   ; dx mentése X-be

    ; self.x + dx
    pla                   ; self.x vissza
    clc
    stx tmp0              ; dx tmp0-ba (mert TXA+ADC nem lehet)
    adc tmp0              ; + dx

    ; self.x írása
    ldy #0
    sta (ZP_SELF),y       ; self.x = self.x + dx
    rts
```

### Name Mangling Konvenció

A `__` (dupla aláhúzás) prefix reserved a fordító számára. A nevek így alakulnak át assembly címkékké:

| Típus              | Prefix | Példa                | Eredeti PyCo kód       |
| ------------------ | ------ | -------------------- | ---------------------- |
| Osztály metódus    | `__C_` | `__C_Enemy_move`     | `Enemy.move()`         |
| Konstruktor        | `__C_` | `__C_Enemy_init`     | `Enemy.__init__()`     |
| String repr.       | `__C_` | `__C_Player_str`     | `Player.__str__()`     |
| Top-level függvény | `__F_` | `__F_main`           | `def main()`           |
| BSS instance       | `__B_` | `__B_player`         | `player: Player`       |
| String literal     | `__S_` | `__S_0`, `__S_1`     | `"Hello"`              |
| Type name string   | `__S_` | `__S_Enemy_typename` | `"<Enemy>"` (auto)     |
| Runtime helper     | `__R_` | `__R_mul16`          | (belső használat)      |

**Szabályok:**
- User **nem definiálhat** `__` prefixű nevet (kivéve magic methods)
- Magic methods (`__init__`, `__str__`) megengedettek - a mangled nevük: `__C_ClassName_init`, `__C_ClassName_str`

**Magic methods az első verzióban:**

| Magic method | Mikor hívódik                  | Visszatérés       |
| ------------ | ------------------------------ | ----------------- |
| `__init__`   | Objektum létrehozásakor        | void              |
| `__str__`    | `str(obj)` vagy `print(obj)`   | string            |

### Örökölt metódusok

```python
class Player(Position):
    def move(dx: byte, dy: byte):  # override
        # custom implementation
```

Ha nincs override, a szülő metódusát használjuk:
```asm
; player.show() → __C_Position_show (ha nincs __C_Player_show)
```

A compiler fordítási időben dönti el, melyik metódust hívja - nincs runtime dispatch.

### Konstruktor

```python
class Enemy:
    x: byte = 0
    y: byte = 0
    health: int = 100

    def __init__(start_x: byte, start_y: byte):
        self.x = start_x
        self.y = start_y
```

Generált kód:
```asm
__C_Enemy___init__:
    ; METÓDUS PRÓLOG:
    ; self pointer már ZP_SELF-ben van ($0F-$10) - a hívó töltötte be!
    ; Paraméterek: start_x (SSP-2), start_y (SSP-1)

    ; Default values first (property init)
    lda #0
    ldy #0
    sta (ZP_SELF),y       ; x = 0 (ZP-optimalizált!)
    iny
    sta (ZP_SELF),y       ; y = 0
    lda #<100
    ldy #2
    sta (ZP_SELF),y       ; health low
    iny
    lda #>100
    sta (ZP_SELF),y       ; health high

    ; __init__ body
    ; self.x = start_x (param 1)
    lda SSP
    sec
    sbc #2
    sta tmp0              ; tmp0 = SSP-2 (start_x címe)
    lda SSP+1
    sbc #0
    sta tmp1
    ldy #0
    lda (tmp0),y          ; start_x
    sta (ZP_SELF),y       ; self.x = start_x

    ; self.y = start_y (param 2)
    lda SSP
    sec
    sbc #1
    sta tmp0              ; tmp0 = SSP-1 (start_y címe)
    lda SSP+1
    sbc #0
    sta tmp1
    ldy #0
    lda (tmp0),y          ; start_y
    ldy #1
    sta (ZP_SELF),y       ; self.y = start_y
    rts
```

## Memória-mapped változók

```python
border: byte[0xD020] = 0
```

Generált kód:
```asm
lda #0
sta $D020
```

Nincs memóriafoglalás - közvetlenül a hardver címre ír/olvas.

## Lokális változók

**Minden lokális változó a software stack-en él.** Nincs automatikus Zero Page allokáció - ha a user gyors változót akar, memory-mappingot használ.

### Példa

```python
def calculate(a: int, b: int) -> int:
    result: int
    temp: byte

    temp = a + b
    result = temp * 2
    return result
```

Generált kód:
```asm
calculate:
    ; Locals: result (2B offset 0), temp (1B offset 2) = 3 bytes
    ; Stack frame setup
    clc
    lda SSP
    adc #3
    sta SSP
    bcc +
    inc SSP+1
+:
    ; temp = a + b
    clc
    lda param0            ; a low
    adc param2            ; b low
    ldy #2                ; temp offset
    sta (SSP),y           ; HIBA: SSP már frame UTÁN van!

    ; ... (stack frame pointer kezelés kell)

    ; Frame cleanup
    sec
    lda SSP
    sbc #3
    sta SSP
    bcs +
    dec SSP+1
+:
    rts
```

**Megjegyzés:** A pontos stack frame kezelés implementáció részlet - a lényeg, hogy minden lokális a stacken van.

## Vezérlési szerkezetek

### If-Else

```python
if x > 10:
    y = 1
else:
    y = 0
```

```asm
    lda x
    cmp #10
    bcc else_branch       ; x < 10
    beq else_branch       ; x == 10
    ; then branch (x > 10)
    lda #1
    sta y
    jmp endif
else_branch:
    lda #0
    sta y
endif:
```

### For ciklus

A `range()` függvény három formája támogatott:

| Forma                        | Leírás                                    |
| ---------------------------- | ----------------------------------------- |
| `range(vég)`                 | 0-tól vég-1-ig, lépés: 1                  |
| `range(kezdet, vég)`         | kezdettől vég-1-ig, lépés: 1              |
| `range(kezdet, vég, lépés)`  | kezdettől vég-1-ig, egyedi lépésközzel    |

#### Egyszerű eset: range(10) vagy range(0, 10)

```python
for i in range(10):
    print(i)
```

```asm
    lda #0
    sta i
for_loop:
    lda i
    cmp #10
    bcs for_end           ; i >= 10

    ; loop body
    lda i
    jsr __R_print_byte

    ; i++
    inc i
    jmp for_loop
for_end:
```

#### Pozitív lépésköz: range(0, 10, 2)

```python
for i in range(0, 10, 2):
    print(i)              # 0, 2, 4, 6, 8
```

```asm
    lda #0
    sta i
for_loop:
    lda i
    cmp #10
    bcs for_end           ; i >= 10

    ; loop body
    lda i
    jsr __R_print_byte

    ; i += 2
    lda i
    clc
    adc #2
    sta i
    jmp for_loop
for_end:
```

#### Negatív lépésköz: range(10, 0, -1)

```python
for i in range(10, 0, -1):
    print(i)              # 10, 9, 8, ... 1
```

```asm
    lda #10
    sta i
for_loop:
    ; Negatív lépésnél: i <= vég → kilépés
    lda i
    cmp #1                ; vég + 1 (mert > és nem >=)
    bcc for_end           ; i < 1 → kilépés
    beq for_end           ; i == 0 → kilépés (ha vég = 0)

    ; loop body
    lda i
    jsr __R_print_byte

    ; i += -1 (vagyis i--)
    dec i
    jmp for_loop
for_end:
```

**Megjegyzés:** Negatív lépésnél a feltétel fordított - addig fut, amíg `i > vég`. A fordító a lépés előjelétől függően generálja a megfelelő összehasonlítást.

### While ciklus

```python
while x > 0:
    x -= 1
```

```asm
while_loop:
    lda x
    beq while_end         ; x == 0
    ; x > 0
    dec x
    jmp while_loop
while_end:
```

## Runtime Helpers

Beépített assembly rutinok - **csak a ténylegesen használtak kerülnek a kimeneti fájlba!**

| Rutin             | Funkció                               | Mikor kell              |
| ----------------- | ------------------------------------- | ----------------------- |
| `__R_mul8`        | 8-bit szorzás                         | `byte * byte`           |
| `__R_mul16`       | 16-bit szorzás                        | `int * int`             |
| `__R_div8`        | 8-bit osztás                          | `byte / byte`           |
| `__R_div16`       | 16-bit osztás                         | `int / int`             |
| `__R_print_byte`  | Byte kiírás decimálisan               | `print(byte_var)`       |
| `__R_print_int`   | Int kiírás decimálisan                | `print(int_var)`        |
| `__R_print_str`   | String kiírás (Pascal format)         | `print(string_var)`     |
| `__R_strcpy`      | String másolás                        | `s1 = s2`               |
| `__R_memcpy`      | Memória másolás                       | array/object copy       |
| `__R_objcopy`     | Objektum másolás (sizeof alapján)     | `obj1 = obj2`           |
| `__R_str_byte`    | Byte → string konverzió               | `str(byte_var)`         |
| `__R_str_int`     | Int → string konverzió                | `str(int_var)`          |
| `__R_str_bool`    | Bool → string konverzió               | `str(bool_var)`         |
| `__R_str_float`   | Float → string konverzió              | `str(float_var)`        |

### Szelektív Runtime Linking

**Filozófia:** A PyCo fordító **csak azokat a runtime helpereket** illeszti be a kimeneti assembly-be, amelyeket a program ténylegesen használ. Ez kritikus a C64-en, ahol minden byte számít.

**Implementáció:**

1. **Használat nyomon követése** - A kódgenerátor futás közben gyűjti, mely helpereket használta:
   ```python
   # context.py-ban
   class CodeGenContext:
       used_helpers: set[str] = set()

       def use_helper(self, name: str):
           self.used_helpers.add(name)
   ```

2. **Feltételes beillesztés** - Az output fázisban csak a használtak kerülnek be:
   ```python
   # generator.py-ban
   def emit_runtime_helpers(self):
       for helper in self.context.used_helpers:
           self.emitter.emit(RUNTIME_CODE[helper])
   ```

**Példák:**

| Program használ         | Beillesztett helperek                    |
| ----------------------- | ---------------------------------------- |
| `print("Hello")`        | `__R_print_str`                          |
| `print(x)` ahol x: int  | `__R_print_int`                          |
| `a * b` ahol int        | `__R_mul16`                              |
| `str(x)` ahol x: byte   | `__R_str_byte`                           |
| semmi special           | **SEMMI** - csak a user kódja           |

**Függőségek:**

Egyes helperek másokat is igényelhetnek:

| Helper           | Függőség                                  |
| ---------------- | ----------------------------------------- |
| `__R_print_int`  | (önálló)                                  |
| `__R_str_int`    | (önálló)                                  |
| `__R_div16`      | (önálló, de használhat temp változókat)  |

**Megjegyzés:** A float támogatás különösen költséges (~1-2KB kód). Ha a program nem használ float-ot, a teljes float könyvtár kimarad.

### str() beépített függvény

A `str()` függvény bármilyen típust stringgé alakít:

```python
def example():
    s: string[20]
    x: int = 42

    s = str(x)            # "42"
    s = str(True)         # "True"
    s = str(player)       # → __str__ hívás vagy "<Player>"
```

**Fordítási logika:**

1. **Primitív típusok** → megfelelő `__R_str_*` runtime helper hívás
2. **Objektumok `__str__` metódussal** → `__C_ClassName_str` hívás
3. **Objektumok `__str__` nélkül** → konstans string visszaadása: `"<ClassName>"`

**Generált kód példa:**

```python
class Player:
    name: string[20] = "Hero"
    score: int = 0

    def __str__() -> string:
        result: string[40]
        sprint(result, ": ", self.name, self.score)
        return result
```

```asm
// Player.__str__ metódus
__C_Player___str__:
    ; METÓDUS PRÓLOG:
    ; self pointer már ZP_SELF-ben van ($0F-$10) - a hívó töltötte be!

    ; result: string[40] a stacken
    ; sprint(result, ": ", self.name, self.score)
    ; ... sprint kód generálás ...
    ; (self.name és self.score hozzáférés ZP_SELF-en keresztül történik!)

    ; return result → pointer a retval-ba ($11-$14)
    lda #<result_offset
    clc
    adc SSP
    sta retval        ; $11
    lda #>result_offset
    adc SSP+1
    sta retval+1      ; $12
    rts

// str(player) hívás → __C_Player___str__
    ; 1. self pointer ZP_SELF-be töltése
    lda #<__B_player
    sta ZP_SELF       ; $0F
    lda #>__B_player
    sta ZP_SELF+1     ; $10

    ; 2. Metódus hívás (nincs explicit paraméter)
    jsr __C_Player___str__

    ; 3. retval most a string pointert tartalmazza ($11-$12)
```

**`__str__` nélküli osztály:**

```python
class Enemy:
    x: int = 0

def example():
    e: Enemy = Enemy()
    s: string[20] = str(e)    # s = "<Enemy>"
```

```asm
// str(enemy) → konstans string
    lda #<__S_Enemy_typename
    sta retval
    lda #>__S_Enemy_typename
    sta retval+1

// Data segment:
__S_Enemy_typename:
    .byte 7                    // hossz
    .text "<Enemy>"
```

## Kódgenerátor Modulok

```
src/pyco/compiler/
├── codegen/
│   ├── __init__.py          # Public API
│   ├── generator.py         # Main AST visitor
│   ├── context.py           # Compilation context, symbol tables
│   ├── types.py             # Type sizes, layouts
│   ├── emitter.py           # Assembly output builder
│   ├── expressions.py       # Expression code generation
│   ├── statements.py        # Statement code generation
│   ├── functions.py         # Function/method generation
│   ├── classes.py           # Class layout, constructor gen
│   └── runtime.py           # Runtime helper code
```

## Generálás Fázisai

### 1. Fázis: Symbol Collection

- Konstansok összegyűjtése
- Osztály layoutok számítása (property offsets, sizes)
- Függvény signatúrák
- Metódus → osztály mapping

### 2. Fázis: Code Generation

- AST bejárás
- Assembly generálás az emitter-rel
- Label management
- Temp variable allokáció

### 3. Fázis: Output

- Runtime helpers beillesztése (csak a használtak!)
- Segment-ek rendezése
- Kick Assembler forrás írása

## Példa: Teljes fordítás

### Input (test.pyco)

```python
BORDER = 0xD020

class Counter:
    value: byte = 0

    def increment():
        self.value += 1

def main():
    border: byte[BORDER] = 0
    c: Counter = Counter()
    i: byte

    for i in range(0, 10):
        c.increment()

    border = c.value
```

### Output (test.asm)

```asm
// Generated by PyCo Compiler
// Target: C64 / Kick Assembler

// === CONSTANTS ===
.const BORDER = $D020

// === ZERO PAGE ===
.label tmp0 = $02
.label tmp1 = $03
.label FP = $08           // Frame Pointer
.label SSP = $0A          // Software Stack Pointer
.label retval = $0C       // Return value

// === BASIC UPSTART ===
BasicUpstart2(__F_main)

// === CODE SEGMENT ===

// --- Class: Counter ---
// Layout: value (offset 0, 1 byte)
// Size: 1 byte

__C_Counter___init__:
    ; METÓDUS PRÓLOG:
    ; self pointer már ZP_SELF-ben van ($0F-$10) - a hívó töltötte be!

    ; value = 0 (default property init)
    lda #0
    ldy #0
    sta (ZP_SELF),y   ; ZP-optimalizált! 🚀
    rts

__C_Counter_increment:
    ; METÓDUS PRÓLOG:
    ; self pointer már ZP_SELF-ben van ($0F-$10)

    ; self.value += 1
    ldy #0
    lda (ZP_SELF),y   ; self.value olvasás - ZP-optimalizált!
    clc
    adc #1
    sta (ZP_SELF),y   ; self.value írás
    rts

// --- Function: main ---
__F_main:
    ; Runtime init
    lda #<__program_end
    sta SSP
    lda #>__program_end
    sta SSP+1

    // border: byte[BORDER] = 0
    lda #0
    sta BORDER

    // c: Counter - lokális változó FP+0-nál (2 byte pointer)
    // c = Counter() - konstruktor hívás

    ; 1. self pointer ZP_SELF-be töltése (main → metódus optimalizáció!)
    clc
    lda FP
    adc #0                // c offset
    sta ZP_SELF           // $0F
    lda FP+1
    adc #0
    sta ZP_SELF+1         // $10

    ; 2. Konstruktor hívás (nincs explicit paraméter)
    jsr __C_Counter___init__
    ; KÖLTSÉG: ~12 ciklus (vs. ~30 stack-based)! 🚀

    // for i in range(0, 10):
    lda #0
    ldy #2                // i offset a frame-ben
    sta (FP),y
!loop:
    ldy #2
    lda (FP),y
    cmp #10
    bcs !end+

    // c.increment()
    ; self pointer már ZP_SELF-ben van (c ugyanaz az objektum)!
    ; NINCS LOAD SZÜKSÉG - same object call optimization! 🚀
    jsr __C_Counter_increment
    ; KÖLTSÉG: 0 ciklus overhead (vs. ~30 stack-based)!

    ; i++
    ldy #2
    lda (FP),y
    clc
    adc #1
    sta (FP),y
    jmp !loop-
!end:

    // border = c.value
    ; self pointer már ZP_SELF-ben van (c ugyanaz az objektum)!
    ldy #0
    lda (ZP_SELF),y       // c.value - ZP-optimalizált! 🚀
    sta BORDER

    rts

// === END ===
__program_end:
```

## Optimalizációs lehetőségek (későbbi fázis)

### Fordító optimalizációk

1. **Constant folding**: Konstans kifejezések kiszámítása fordítási időben
2. **Dead code elimination**: Nem használt kód eltávolítása
3. **Register allocation**: A, X, Y regiszterek optimális használata
4. **Inline small functions**: Kis függvények beillesztése
5. **Peephole optimization**: Redundáns utasítások eltávolítása
6. **Leaf function detection**: Automatikus ZP paraméterek ha nincs nested hívás

### Dekorátor-szerű annotációk (user kontroll)

```python
@fastcall                    # ZP paraméterek - gyorsabb, de nested hívás TILOS
def critical_inner_loop(x: byte, y: byte):
    ...

@check_stack(limit)          # Stack mélység ellenőrzés bekapcsolva
def recursive_function(n: int):
    ...

@inline                      # Függvény beillesztése hívás helyett
def tiny_helper() -> byte:
    ...
```

Ezek fordítási idejű annotációk (nem valódi Python dekorátorok). A user felelőssége a helyes használat.

## Alias típus implementáció

Az `alias[T]` egy típusos dinamikus referencia, ami futásidőben beállítható memóriacímre mutat.

### Tárolás

Az alias belsőleg egy 2 byte-os **pointer** (word), ami a hivatkozott memóriacímet tárolja.

| Elem            | Méret   | Leírás                              |
| --------------- | ------- | ----------------------------------- |
| `alias[T]`      | 2 byte  | Word típusú cím (little-endian)     |

### addr() függvény

Az `addr()` függvény visszaadja egy változó memóriacímét word-ként:

```asm
; addr(enemy) - stack változó esetén
clc
lda FP
adc #ENEMY_OFFSET
sta retval
lda FP+1
adc #0
sta retval+1

; addr(enemy) - BSS változó esetén
lda #<__B_enemy
sta retval
lda #>__B_enemy
sta retval+1
```

### alias() függvény

Az `alias(a, ptr)` beállítja az alias értékét a megadott címre:

```asm
; alias(e, addr(enemy)) - ahol ptr a retval-ban van
lda retval
sta e           ; alias low byte
lda retval+1
sta e+1         ; alias high byte
```

### Property elérés alias-on keresztül

A 6502 natívan támogatja az indirect indexed címzési módot:

```asm
; e.x olvasása (ahol e egy alias[Enemy])
lda e           ; Pointer low byte → tmp0
sta tmp0
lda e+1         ; Pointer high byte → tmp1
sta tmp1
ldy #OFFSET_X   ; x property offset
lda (tmp0),y    ; Indirect indexed load

; e.x = 50 írás
lda #50
sta (tmp0),y    ; Indirect indexed store
```

### Primitív alias olvasás/írás

```asm
; s olvasása (ahol s: alias[int])
lda s
sta tmp0
lda s+1
sta tmp1
ldy #0
lda (tmp0),y    ; low byte
sta retval
iny
lda (tmp0),y    ; high byte
sta retval+1

; s = 100 írás
ldy #0
lda #<100
sta (tmp0),y
iny
lda #>100
sta (tmp0),y
```

### Array indexelés alias-on keresztül

```asm
; b[5] olvasása (ahol b: alias[byte])
lda b
sta tmp0
lda b+1
sta tmp1
ldy #5          ; index
lda (tmp0),y    ; Indirect indexed load
```

### Teljesítmény

| Művelet                 | Ciklus (kb.) | Megjegyzés                        |
| ----------------------- | ------------ | --------------------------------- |
| Memory-mapped elérés    | 4-6          | Közvetlen cím, leggyorsabb        |
| Alias elérés            | 12-16        | Pointer load + indirect           |
| Lokális változó elérés  | 8-10         | Frame pointer + indirect          |

Az alias kicsit lassabb a közvetlen elérésnél, de a rugalmasság gyakran megéri.

