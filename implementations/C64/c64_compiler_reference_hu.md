# C64 fordító referencia

Ez a dokumentum a PyCo C64 (6502) backend specifikus funkcióit írja le.

## Dekorátorok

A `main()` függvény speciális dekorátorokkal módosítható, amik a C64-specifikus viselkedést befolyásolják.

### @lowercase

Kisbetűs/nagybetűs karakterkészlet módba kapcsolja a képernyőt.

```python
@lowercase
def main():
    print("Hello World!")  # Kisbetűkkel jelenik meg
```

A C64 alapértelmezetten nagybetűs/grafikus módban indul. A `@lowercase` dekorátor kisbetűs/nagybetűs módba kapcsolja, ahol a kisbetűk is megjelennek.

---

## Memória elrendezés

```
┌──────────────────────────────────────────────────────────────┐
│ Cím tartomány  │ Méret  │ Leírás                             │
├──────────────────────────────────────────────────────────────┤
│ $0000 - $00FF  │ 256 B  │ Zero Page (rendszer + PyCo ZP)     │
│ $0100 - $01FF  │ 256 B  │ Hardware Stack (6502)              │
│ $0200 - $03FF  │ 512 B  │ Rendszer terület                   │
│ $0400 - $07FF  │ 1 KB   │ Képernyő memória (alapértelmezett) │
│ $0801 - $BFFF  │ ~46 KB │ PyCo program terület               │
│                │        │ (BASIC ROM kikapcsolva)            │
│ $C000 - $CFFF  │ 4 KB   │ Szabad RAM                         │
│ $D000 - $D3FF  │ 1 KB   │ VIC-II regiszterek                 │
│ $D400 - $D7FF  │ 1 KB   │ SID regiszterek                    │
│ $D800 - $DBFF  │ 1 KB   │ Szín memória                       │
│ $DC00 - $DCFF  │ 256 B  │ CIA1 (billentyűzet, joystick)      │
│ $DD00 - $DDFF  │ 256 B  │ CIA2 (soros port, VIC bank)        │
│ $E000 - $FFFF  │ 8 KB   │ KERNAL ROM                         │
└──────────────────────────────────────────────────────────────┘
```

---

## Gyakran használt címek

| Cím     | Név      | Leírás                  |
| ------- | -------- | ----------------------- |
| `$D020` | BORDER   | Keret színe             |
| `$D021` | BGCOLOR  | Háttér színe            |
| `$D012` | RASTER   | Aktuális rasztersor     |
| `$DC00` | CIA1_PRA | Keyboard matrix / Joy 2 |
| `$DC01` | CIA1_PRB | Keyboard matrix / Joy 1 |

---

## PyCo Zero Page használat

### Áttekintés

```
┌───────────┬──────────┬────────────────────────────────────┐
│ Cím       │ Név      │ Leírás                             │
├───────────┼──────────┼────────────────────────────────────┤
│ $02-$07   │ tmp0-5   │ Általános temp regiszterek         │
│ $08-$09   │ FP       │ Frame Pointer                      │
│ $0A-$0B   │ SSP      │ Software Stack Pointer             │
│ $0C-$0D   │ spbuf    │ Sprint buffer pointer              │
│ $0E       │ sppos    │ Sprint buffer pozíció              │
│ $0F-$12   │ retval   │ Return value (4 byte, float-hoz)   │
│ $0F-$10   │ spsave   │ Sprint CHROUT (átfedés retval-lal) │
│ $11       │ sptmp    │ Sprint temp (átfedés retval+2-vel) │
│ $13-$15   │ tmp6-8   │ Kiterjesztett temp regiszterek     │
│ $16-$17   │ ZP_SELF  │ Self pointer (metódusokhoz)        │
│ $18-$56   │ ---      │ User-available (63 byte)           │
│ $57-$5D   │ RESULT.. │ Float/szorzás munkaterület         │
│ $61-$66   │ FAC      │ Float Accumulator                  │
│ $69-$6E   │ ARG      │ Float Argument                     │
└───────────┴──────────┴────────────────────────────────────┘
```

### Részletes temp regiszter használat

A temp regiszterek ($02-$07 és $13-$15) különböző műveleteknél kerülnek felhasználásra:

#### tmp0-tmp5 ($02-$07) - Alapvető műveletek

| Cím   | Label | Használat                                          |
|-------|-------|----------------------------------------------------|
| $02   | tmp0  | Általános temp, pointer low byte                   |
| $03   | tmp1  | Általános temp, pointer high byte                  |
| $04   | tmp2  | Szorzás/osztás operandus, loop counter             |
| $05   | tmp3  | Szorzás/osztás operandus                           |
| $06   | tmp4  | Összetett kifejezések, f16/f32 operandus           |
| $07   | tmp5  | Összetett kifejezések, f16/f32 operandus           |

**Mely műveletek használják:**
- ✅ Byte/word aritmetika (+, -, *, &, |, ^, <<, >>)
- ✅ Összehasonlítások (<, >, ==, !=, <=, >=)
- ✅ Array indexelés (kis offset)
- ✅ Pointer dereferálás
- ✅ Változó hozzáférés

#### tmp6-tmp8 ($13-$15) - Kiterjesztett műveletek

| Cím   | Label | Használat                                          |
|-------|-------|----------------------------------------------------|
| $13   | tmp6  | Osztás, string műveletek, nagy offset számítás     |
| $14   | tmp7  | Osztás, string műveletek, nagy offset számítás     |
| $15   | tmp8  | String multiply, f32 műveletek                     |

**Mely műveletek használják:**
- ⚠️ Osztás (`/`) és modulo (`%`)
- ⚠️ String konkatenáció (`+`)
- ⚠️ String szorzás (`*`)
- ⚠️ f16/f32 aritmetika
- ⚠️ Bonyolult kifejezések (ha tmp0-5 nem elég)
- ⚠️ Nagy array offset számítás

### Stack és függvényhívás regiszterek

| Cím       | Label   | Használat                                        |
|-----------|---------|--------------------------------------------------|
| $08-$09   | FP      | Frame Pointer - aktuális stack frame bázis       |
| $0A-$0B   | SSP     | Software Stack Pointer - stack teteje            |
| $0F-$12   | retval  | Függvény visszatérési érték (max 4 byte)         |
| $16-$17   | ZP_SELF | `self` pointer metódushívásokhoz                 |

### Print (sprint) regiszterek

| Cím       | Label   | Használat                                        |
|-----------|---------|--------------------------------------------------|
| $0C-$0D   | spbuf   | Sprint buffer pointer                            |
| $0E       | sppos   | Aktuális pozíció a bufferben                     |
| $0F-$10   | spsave  | Mentett CHROUT vektor (átfedés retval-lal!)      |
| $11       | sptmp   | Sprint temp (átfedés retval+2-vel!)              |

> **Megjegyzés:** A `spsave` és `retval` átfedésben vannak, de soha nem aktívak egyszerre (print közben nincs függvény return).

### Float regiszterek

A float műveletek a BASIC ROM által is használt területet foglalják:

| Cím       | Label     | Használat                                      |
|-----------|-----------|------------------------------------------------|
| $57-$59   | RESULT    | Szorzás eredmény (3 byte)                      |
| $5A-$5B   | INDEX     | Memory pointer                                 |
| $5C       | SGNCPR    | Előjel összehasonlítás                         |
| $5D       | SHIFTSIGN | Shift előjel kiterjesztés                      |
| $61-$66   | FAC       | Float Accumulator (exponens + mantissza + jel) |
| $69-$6E   | ARG       | Float Argument (második operandus)             |

### IRQ handler-ek (`@irq` dekorátor)

Az `@irq` dekorátorral jelölt függvények megszakítás-kezelőként működnek.

####Temp regiszterek

Az IRQ **bármikor** megszakíthatja a főprogramot - beleértve amikor épp temp regisztereket használ. Ezért az IRQ handler **külön ZP területet** használ:

| Normál kontextus | IRQ kontextus | Használat                    |
|------------------|---------------|------------------------------|
| $02-$07          | $1A-$1F       | tmp0-5 (alapvető műveletek)  |
| $13-$15          | $20-$22       | tmp6-8 (osztás, f16/f32)     |

#### Lokális változók

Az IRQ handler a **software stack-et** használja lokális változókhoz - UGYANAZT mint a főprogram! De **NEM módosítja** sem az SSP-t, sem az FP-t. Ehelyett közvetlenül az `(SSP) + offset` címet használja.

```
IRQ belépéskor:                      IRQ közben:
┌─────────────┐                      ┌─────────────┐
│  (szabad)   │                      │ IRQ lokális │ ← (SSP) + 4 + offset
├─────────────┤ ← SSP                │  változók   │
│  főprogram  │                      ├─────────────┤ ← (SSP) + 4
│  változói   │                      │  (4 byte    │
└─────────────┘                      │   védőzóna) │
                                     ├─────────────┤ ← SSP (változatlan!)
                                     │  főprogram  │
                                     │  változói   │
                                     └─────────────┘
```

**Miért +4 byte védőzóna?** A főprogram max 4 byte-ot ír egyszerre az SSP-re (float paraméter). Ha az IRQ pont akkor jön, a +4 offset garantálja, hogy nem írjuk felül.

**Optimalizáció:** Ha `frame_size == 0` (nincs stack-alapú lokális változó), csak A/X/Y mentés kell (~15 ciklus)!

#### Változó típusok IRQ-ban

A user választhat a sebesség és kényelem között:

| Változó típus | Sebesség | Használat |
|---------------|----------|-----------|
| Memory-mapped (`x: byte[$1A]`) | ⚡ Leggyorsabb | Abszolút címzés, 3 ciklus |
| Stack-alapú (`x: byte`) | 🐢 Kicsit lassabb | `(SSP)+offset` címzés, 5-6 ciklus |

**Ajánlás:** Időkritikus IRQ-kban (raster effektek) használj mapped változókat!

#### Generált kód

**Minimális IRQ (frame_size == 0, csak mapped változók):**
```asm
irq_handler:
    pha                            ; 3 ciklus
    txa
    pha                            ; 3 ciklus
    tya
    pha                            ; 3 ciklus  (összesen ~15 ciklus)

    ; ... IRQ kód (IRQ temp regiszterekkel) ...

    pla
    tay
    pla
    tax
    pla                            ; ~15 ciklus
    rti
```

**IRQ stack változókkal (frame_size > 0):**
```asm
irq_handler:
    pha / txa / pha / tya / pha    ; A/X/Y mentés

    ; Lokális változók: (SSP) + 4 + offset
    ; Az SSP NEM módosul, az FP NEM módosul!
    ldy #4+offset                  ; +4 a védőzóna
    lda (SSP),y                    ; Olvasás
    sta (SSP),y                    ; Írás

    ; ... IRQ kód ...

    pla / tay / pla / tax / pla    ; A/X/Y visszaállítás
    rti
```

> **Megjegyzés:** Az IRQ handler NEM módosítja az SSP-t és FP-t! Közvetlenül `(SSP) + 4 + offset` címzést használ. A +4 védőzóna megvédi a főprogram épp írt adatait.

#### IRQ-ban TILOS műveletek (compiler ellenőrzi!)

A compiler fordítási időben ellenőrzi ezeket a szabályokat:

| Művelet | Hibaüzenet | Miért tilos? |
|---------|------------|--------------|
| `float`, `f16`, `f32` típusok | "Float type not allowed in @irq" | FAC/ARG ($61-$6E) nem mentődik |
| Függvényhívás | "Function calls not allowed in @irq" | A hívott fv. normál temp-et használna |
| Metódushívás | "Method calls not allowed in @irq" | ZP_SELF + függvényhívás |
| `print()` | "print() not allowed in @irq" | spbuf/spsave nem mentődik |
| Konstruktor hívás (`obj()`) | "Constructor calls not allowed in @irq" | Metódushívással egyenértékű |

#### IRQ-ban ENGEDÉLYEZETT műveletek

- ✅ `byte`, `word`, `int` típusok (aritmetika, bitműveletek)
- ✅ Összehasonlítások, feltételek, ciklusok
- ✅ Memory-mapped változók (`x: byte[0xD020]`)
- ✅ Array/subscript hozzáférés
- ✅ `__sei__()`, `__cli__()`, `__inc__()`, `__dec__()` intrinsics
- ✅ `__asm__()` inline assembly
- ✅ `addr()`, `size()` compile-time függvények

#### IRQ handler beállítása

Az IRQ handler címét az `addr()` függvénnyel kaphatjuk meg:

```python
@irq
def raster_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF  # Acknowledge

def main():
    irq_vector: word[0x0314]  # C64 Kernal IRQ vector

    __sei__()                      # IRQ tiltás
    irq_vector = addr(raster_handler)  # IRQ vector beállítása
    __cli__()                      # IRQ engedélyezés
```

**Fontos címek:**
| Cím | Leírás |
|-----|--------|
| `$0314-$0315` | Kernal IRQ vector (ezt írjuk felül) |
| `$FFFE-$FFFF` | Hardware IRQ vector (ROM, nem írható) |

#### Példa: Raster scroll

```python
# Globális változó (a főprogram állítja)
scroll_x: byte[0x02F0] = 0

@irq
def raster_handler():
    vic_ctrl2: byte[0xD016]
    vic_irq: byte[0xD019]

    # Gyors - mapped változók, nincs stack
    vic_ctrl2 = (vic_ctrl2 & 0xF8) | scroll_x
    vic_irq = 0xFF  # Acknowledge
```

#### SSP védett frissítés (ha van IRQ a programban)

**Probléma:** A 6502-n a 16-bites SSP frissítése nem atomi. Page boundary crossing esetén (pl. $10FF → $1100) az SSP ideiglenesen inkonzisztens lehet:

```asm
; Probléma: 16-bit inkonzisztencia
lda SSP
adc #8           ; A = $07, carry = 1
sta SSP          ; SSP low = $07
                 ; <<< IRQ ITT >>> SSP = $1007 (hibás! valódi: $10FF)
inc SSP+1        ; SSP high = $11, most már OK
```

**Megoldás:** Ha a programban van `@irq` handler, a kódgenerátor **védett SSP frissítést** használ `php`/`plp`-vel:

```asm
; Védett SSP frissítés (php/plp megőrzi a user __sei__ állapotát)
clc
lda SSP
adc #<frame_size
bcc .no_carry       ; Ha nincs carry → biztonságos
php                 ; Page crossing → mentsük az I flag-et!
sei                 ; Védelem
sta SSP
inc SSP+1
plp                 ; Visszaállítjuk az EREDETI I flag állapotot
jmp .done
.no_carry:
sta SSP             ; Nincs carry, csak low byte változik
.done:
```

**Miért `php`/`plp` és nem `sei`/`cli`?**

Ha a user `__sei__()`-t hívott és utána függvényt hív, a sima `cli` visszakapcsolná az IRQ-t a user szándéka ellenére. A `php`/`plp` megőrzi az eredeti I flag állapotot:
- Ha IRQ engedélyezve volt (I=0) → `plp` visszakapcsolja
- Ha IRQ tiltva volt (I=1) → `plp` **tiltva hagyja**

Ez működik importált library-kkal is, amik `__sei__()`/`__cli__()` párokat használhatnak.

**Overhead:**
- Nincs page crossing: **0 extra ciklus** (a `bcc` ugrik, `sta SSP` fut)
- Page crossing: **+12 ciklus** (php + sei + plp + jmp)
- Page crossing esélye: ~5-15% (frame_size / 256)

> **Megjegyzés:** Ha nincs `@irq` a programban, a kódgenerátor a régi, egyszerű SSP frissítést használja (0 overhead).

---

## Stack frame felépítése

> **Megjegyzés:** Ez a szekció haladó téma - a legtöbb programozáshoz nem szükséges ismerni. Akkor lehet hasznos, ha debuggolsz, inline assembly-t írsz, vagy meg akarod érteni a generált kódot.

A C64-en a PyCo két stack-et használ:
- **Software stack**: A paraméterek és lokális változók itt tárolódnak, az FP (Frame Pointer) segítségével érjük el őket
- **Hardware stack** ($0100-$01FF): A 6502 processzor beépített verme, ide csak a visszatérési cím kerül (JSR automatikusan)

```
Software stack:                      Hardware stack ($0100-$01FF):

┌─────────────────────────┐          ┌─────────────────────────┐
│                         │          │                         │
│    Lokális változók     │          │    Visszatérési cím     │
│    (a deklaráció        │          │    (2 byte, JSR teszi)  │
│     sorrendjében)       │          │                         │
│                         │          └─────────────────────────┘
├─────────────────────────┤
│                         │
│    Paraméterek          │
│                         │
└─────────────────────────┘ ← FP (Frame Pointer) ide mutat
                          ↑
                    SSP (stack teteje)
```

A **Frame Pointer (FP)** egy fix pont, amihez képest a fordító eléri a paramétereket és lokális változókat. Az FP-t a hívó függvény újraszámolja minden hívás után (`FP = SSP - frame_size`), így nem kell a HW stack-re menteni. Ez 2.7× gyorsabb hívási konvenciót eredményez, és 2× több rekurzív hívást tesz lehetővé.

---

## Példák

### Memory-mapped változók

```python
# VIC regiszterek elérése
BORDER = 0xD020
BGCOLOR = 0xD021

def main():
    border: byte[BORDER]
    bgcolor: byte[BGCOLOR]

    border = 0       # fekete keret
    bgcolor = 6      # kék háttér
```

### Képernyő memória elérése

```python
SCREEN = 0x0400
COLOR = 0xD800

def main():
    screen: array[byte, 1000][SCREEN]
    color: array[byte, 1000][COLOR]

    screen[0] = 1        # 'A' karakter
    color[0] = 1         # fehér szín
```

### Teljes példa: Színes keret

```python
@lowercase
def main():
    border: byte[0xD020]
    i: byte

    while True:
        for i in range(16):
            border = i
```

---

## Float túlcsordulás kezelése

A PyCo 32-bites MBF (Microsoft Binary Format) lebegőpontos számokat használ. Amikor egy művelet eredménye meghaladja az ábrázolható tartományt, **signed saturation** (előjeles telítés) történik.

### Ábrázolható tartomány

| Érték | Hexadecimális | Decimális közelítés |
| ----- | ------------- | ------------------- |
| Max pozitív | `$FF7FFFFF` | ~1.7×10³⁸ |
| Max negatív | `$FFFFFFFF` | ~-1.7×10³⁸ |

### Túlcsordulás viselkedése

| Művelet | Feltétel | Eredmény |
| ------- | -------- | -------- |
| Összeadás | Pozitív overflow | `$FF7FFFFF` (max pozitív) |
| Összeadás | Negatív overflow | `$FFFFFFFF` (max negatív) |
| Szorzás | Pozitív overflow | `$FF7FFFFF` (max pozitív) |
| Szorzás | Negatív overflow | `$FFFFFFFF` (max negatív) |
| Osztás nullával | Pozitív/nulla osztandó | `$FF7FFFFF` (max pozitív) |
| Osztás nullával | Negatív osztandó | `$FFFFFFFF` (max negatív) |

### Példa

```python
def main():
    huge: float = 1e38
    result: float

    # Overflow pozitív irányba → max pozitív
    result = huge * 10.0

    # Overflow negatív irányba → max negatív
    result = -huge * 10.0
```

> **Megjegyzés:** Ez a viselkedés eltér a Commodore BASIC-től, ami `?OVERFLOW ERROR`-t dob. A PyCo a DSP/SIMD processzoroknál megszokott "saturation" megközelítést használja, ami lehetővé teszi a program folytatását.

## Hardver-közeli intrinsic függvények

A C64-es fordító speciális beépített függvényeket biztosít a hardver közvetlen eléréséhez.

### `__sei__()` - Interrupt tiltás

A 6502 `SEI` (Set Interrupt Disable) utasítását generálja. Letiltja a maszkolható megszakításokat (IRQ).

```python
__sei__()  # Interrupts disabled
```

### `__cli__()` - Interrupt engedélyezés

A 6502 `CLI` (Clear Interrupt Disable) utasítását generálja. Engedélyezi a maszkolható megszakításokat.

```python
__cli__()  # Interrupts enabled
```

### Példa: Character ROM olvasása

A Character ROM ($D000) csak akkor érhető el, ha az I/O ki van kapcsolva. Ehhez az interruptokat is le kell tiltani:

```python
def copy_charset():
    cpu_port: byte[0x01]
    char_rom: array[byte, 2048][0xD000]
    char_ram: array[byte, 2048][0xA000]
    old_port: byte
    i: word

    __sei__()                        # Interrupt tiltás
    old_port = cpu_port
    cpu_port = old_port & 0xFB       # I/O kikapcsolása, CHAROM láthatóvá tétele

    for i in range(2048):
        char_ram[i] = char_rom[i]    # Másolás

    cpu_port = old_port              # I/O visszakapcsolása
    __cli__()                        # Interrupt engedélyezés
```

> **Fontos:** A `__sei__()` és `__cli__()` mindig párban használandók! Az interrupt tiltás ideje alatt a rendszer nem reagál billentyűzetre, időzítőkre stb.
