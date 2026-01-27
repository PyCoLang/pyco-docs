# C64 Compiler Reference

Ez a dokumentum a PyCo C64 (6502) compiler implementációjának technikai referenciája.

## 1. Bevezetés

### Mi ez a dokumentum?

Ez a referencia a **PyCo C64 compiler** platformspecifikus működését dokumentálja. A dokumentum a [Nyelvi referenciával](../../language-reference/language_reference_hu.md) együtt olvasandó:

| Dokumentum                 | Tartalom                                                         |
| -------------------------- | ---------------------------------------------------------------- |
| **Nyelvi referencia**      | PyCo szintaxis, típusok, nyelvi konstrukciók (platformfüggetlen) |
| **C64 Compiler Reference** | C64-specifikus implementáció, memóriakezelés, optimalizációk     |

### A C64 compiler jellemzői

A PyCo C64 compiler 6502 assembly kódot generál a Commodore 64-re. Főbb jellemzők:

- **Kick Assembler** vagy **beépített assembler** kimenet
- **Kernal-mentes mód** alapértelmezetten (+16KB RAM)
- **Zero Page optimalizált** temp regiszterek
- **Software stack** a lokális változókhoz
- **Dead Code Elimination** - csak a használt kód kerül a binárisba

### Fordítási folyamat

```
source.pyco → Parser → Preprocessor → SemanticAnalyzer → CodeGen → output.asm
                                              ↓
                                        SymbolTable
```

A generált `.asm` fájl Kick Assembler szintaxisú, vagy a beépített assemblerrel közvetlenül `.prg` bináris készíthető.

---

## 2. Memória architektúra

### 2.1 C64 memória térkép

A PyCo alapértelmezetten **mindkét ROM-ot kikapcsolja** (+16KB RAM):

```
┌──────────────────────────────────────────────────────────────┐
│ Cím tartomány  │ Méret  │ Leírás                             │
├──────────────────────────────────────────────────────────────┤
│ $0000 - $00FF  │ 256 B  │ Zero Page (rendszer + PyCo ZP)     │
│ $0100 - $01FF  │ 256 B  │ Hardware Stack (6502)              │
│ $0200 - $03FF  │ 512 B  │ Rendszer terület (lásd megjegyzés) │
│ $0400 - $07FF  │ 1 KB   │ Képernyő memória (alapértelmezett) │
│ $0801 - $BFFF  │ ~46 KB │ PyCo program terület               │
│                │        │ (BASIC ROM kikapcsolva)            │
│ $C000 - $CFFF  │ 4 KB   │ Szabad RAM                         │
│ $D000 - $D3FF  │ 1 KB   │ VIC-II regiszterek                 │
│ $D400 - $D7FF  │ 1 KB   │ SID regiszterek                    │
│ $D800 - $DBFF  │ 1 KB   │ Szín memória                       │
│ $DC00 - $DCFF  │ 256 B  │ CIA1 (billentyűzet, joystick)      │
│ $DD00 - $DDFF  │ 256 B  │ CIA2 (soros port, VIC bank)        │
│ $E000 - $FFFF  │ 8 KB   │ RAM (Kernal ROM kikapcsolva!)      │
└──────────────────────────────────────────────────────────────┘
```

**Megjegyzés a $0200-$03FF területről:**
- **PRG módban:** Szabad használatra
- **Cartridge módban (`@cartridge`):** A $0200-$025F (~60 byte) **FOGLALT** a bank dispatcher számára! A $0277-$028D terület szintén foglalt a Kernal-kompatibilis változók miatt (keyboard buffer, szín, key repeat).

A `@kernal` dekorátorral a Kernal ROM aktív marad (lásd [4.2 @kernal](#42-kernal)).

### 2.2 Zero Page kiosztás

A Zero Page ($00-$FF) a 6502 processzor leggyorsabb memóriaterülete. A PyCo a következőképpen osztja ki:

#### Temp regiszterek

| Cím     | Név        | Használat                                |
| ------- | ---------- | ---------------------------------------- |
| $02-$07 | tmp0-5     | Általános temp regiszterek               |
| $13-$15 | tmp6-8     | Kiterjesztett temp (osztás, string, f32) |
| $1A-$1F | irq_tmp0-5 | IRQ handler temp regiszterek             |

**tmp0-tmp5 ($02-$07)** - Alapvető műveletek:
- Byte/word aritmetika (+, -, *, &, |, ^, <<, >>)
- Összehasonlítások (<, >, ==, !=, <=, >=)
- Array indexelés, pointer dereferálás
- Változó hozzáférés

**tmp6-tmp8 ($13-$15)** - Kiterjesztett műveletek:
- Osztás (`/`) és modulo (`%`)
- String konkatenáció és szorzás
- f16/f32 aritmetika
- Nagy array offset számítás

#### Stack és függvényhívás regiszterek

| Cím     | Név     | Használat                             |
| ------- | ------- | ------------------------------------- |
| $08-$09 | FP      | Frame Pointer - stack frame bázis     |
| $0A-$0B | SSP     | Software Stack Pointer - stack teteje |
| $0F-$12 | retval  | Függvény visszatérési érték (4 byte)  |
| $16-$17 | ZP_SELF | `self` pointer metódushívásokhoz      |

#### Print (sprint) regiszterek

| Cím     | Név    | Használat                        |
| ------- | ------ | -------------------------------- |
| $0C-$0D | spbuf  | Sprint buffer pointer            |
| $0E     | sppos  | Aktuális pozíció a bufferben     |
| $0F-$10 | spsave | Mentett CHROUT vektor (átfedés!) |
| $11     | sptmp  | Sprint temp (átfedés!)           |

> **Megjegyzés:** A `spsave` és `retval` átfedésben vannak, de soha nem aktívak egyszerre.

#### Float regiszterek

A float regiszterek megegyeznek a C64 BASIC ROM által használt címekkel. Ez lehetővé teszi a kompatibilitást, de egyben azt is jelenti, hogy a BASIC ROM float rutinjai nem használhatók közvetlenül (a PyCo 32-bit MBF formátumot használ, míg a BASIC 40-bit MBF-et).

| Cím     | Név       | Használat                              |
| ------- | --------- | -------------------------------------- |
| $57-$5D | RESULT... | Szorzás/memory munkaterület            |
| $61-$66 | FAC       | Float Accumulator (exponens+mantissza) |
| $69-$6E | ARG       | Float Argument (második operandus)     |

> **Tipp:** Ha a program nem használ `float` típust, a $57-$6E terület (24 byte) szabadon használható memory-mapped változóknak. Ez jelentős extra Zero Page terület játékokhoz és demókhoz!

#### Leaf function lokális változók

| Cím     | Név     | Használat                               |
| ------- | ------- | --------------------------------------- |
| $22-$29 | LEAF_ZP | Leaf függvény lokális változók (8 byte) |

A "leaf" függvények (amelyek nem hívnak más függvényt) lokális változói a Zero Page-en tárolódnak. Feltételek:

1. Leaf függvény (nem hív más függvényt)
2. Nincs paramétere
3. Lokális változók mérete ≤ 8 byte
4. Nem IRQ handler, nem `@naked`, nem `@mapped`

**Megtakarítás:**

| Megközelítés | Prologue | Hozzáférés       | Epilogue |
| ------------ | -------- | ---------------- | -------- |
| SSP/FP       | ~25 byte | `ldy #N; (FP),y` | ~15 byte |
| LEAF_ZP      | 0 byte   | `lda $xx`        | 0 byte   |

#### Kernal-kompatibilis rendszerváltozók

A Kernal-mentes mód ugyanazokat a címeket használja, így a kilépés zökkenőmentes:

| Cím         | Kernal név | Használat                     |
| ----------- | ---------- | ----------------------------- |
| $A0-$A2     | TIME       | Jiffy clock (1/60 sec)        |
| $C5         | LSTX       | Utolsó billentyű matrix kódja |
| $C6         | NDX        | Keyboard buffer count         |
| $D1-$D2     | PNT        | Screen line pointer           |
| $D3         | PNTR       | Cursor oszlop (0-39)          |
| $D6         | TBLX       | Cursor sor (0-24)             |
| $0277-$0280 | KEYD       | Keyboard buffer (10 byte)     |
| $028C       | KOUNT      | Key repeat delay              |
| $028D       | SHFLAG     | Shift/Ctrl/C= flags           |

#### Felhasználó számára szabad területek

| Cím     | Méret   | Leírás                                   |
| ------- | ------- | ---------------------------------------- |
| $2A-$56 | 45 byte | PyCo által nem használt terület          |
| $FB-$FE | 4 byte  | Commodore dokumentáció szerint is szabad |

> **Megjegyzés:** A $FB-$FE terület a Commodore Programmer's Reference Guide-ban is "Free for user programs" jelöléssel szerepel. Ez a 4 byte különösen hasznos memory-mapped változóknak vagy gyors ZP pointereknek.

### 2.3 Software Stack

A C64-en a PyCo két stack-et használ:

- **Hardware stack** ($0100-$01FF): 6502 beépített verme - visszatérési címek
- **Software stack**: Paraméterek és lokális változók

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
└─────────────────────────┘ ← FP (Frame Pointer)
                          ↑
                    SSP (stack teteje)
```

A **Frame Pointer (FP)** egy fix pont, amihez képest a fordító eléri a változókat. Az FP-t a hívó függvény újraszámolja minden hívás után (`FP = SSP - frame_size`).

---

## 3. Generált kód

### 3.1 Name mangling

A generált assembly-ben a PyCo nevek prefixet kapnak:

| Prefix | Jelentés       | Példa                 |
| ------ | -------------- | --------------------- |
| `__F_` | Függvény       | `__F_calculate_score` |
| `__C_` | Class metódus  | `__C_Player_move`     |
| `__B_` | BSS változó    | `__B_game_state`      |
| `__R_` | Runtime helper | `__R_mul16`           |

### 3.2 Hívási konvenció

**Paraméter átadás:**

1. Paraméterek a software stack-re kerülnek (jobbról balra)
2. `JSR` a függvénybe
3. A hívott függvény beállítja FP-t
4. Visszatérési érték `retval`-ban ($0F-$12)

**Register-based ABI (csak `@naked` és `@mapped`):**

| Paraméterek          | Regiszterek    |
| -------------------- | -------------- |
| `(byte)`             | A              |
| `(byte, byte)`       | A, X           |
| `(byte, byte, byte)` | A, X, Y        |
| `(word)`             | X (lo), Y (hi) |

### 3.3 Típusok mérete

| Típus | Méret  | Tartomány               |
| ----- | ------ | ----------------------- |
| bool  | 1 byte | 0, 1                    |
| char  | 1 byte | PETSCII karakter        |
| byte  | 1 byte | 0 - 255                 |
| sbyte | 1 byte | -128 - 127              |
| word  | 2 byte | 0 - 65535               |
| int   | 2 byte | -32768 - 32767          |
| f16   | 2 byte | Fix pont (8.8)          |
| f32   | 4 byte | Fix pont (16.16)        |
| float | 4 byte | 32-bit MBF lebegőpontos |

---

## 4. C64 dekorátorok

A dekorátorok a függvények viselkedését módosítják. A C64 compiler speciális dekorátorokat biztosít.

### 4.1 @lowercase

Kisbetűs/nagybetűs karakterkészlet módba kapcsolja a képernyőt.

```python
@lowercase
def main():
    print("Hello World!")  # Kisbetűkkel jelenik meg
```

A C64 alapértelmezetten nagybetűs/grafikus módban indul. A `@lowercase` dekorátor kisbetűs/nagybetűs módba kapcsolja.

#### Screen code string literálok (`s"..."`)

A C64 VIC chip közvetlenül **screen code**-okkal dolgozik, nem PETSCII-vel. A `s"..."` szintaxis lehetővé teszi screen code-ra konvertált stringek definiálását fordítási időben:

```python
SCREEN = 0x0400

def example():
    row: array[char, 40][SCREEN]

    row = "Hello!"         # PETSCII kódolás (Kernal-kompatibilis)
    row = s"Hello!"        # Screen code kódolás (közvetlen VIC megjelenítés)
```

**Screen code vs PETSCII:**

| Szintaxis | Kódolás     | Használat                                  |
| --------- | ----------- | ------------------------------------------ |
| `"..."`   | PETSCII     | `print()`, fájlműveletek, Kernal rutinok   |
| `s"..."`  | Screen code | Közvetlen képernyő RAM írás                |

**Karakterkonverzió az `@lowercase` dekorátortól függően:**

| Karakter   | Uppercase mód (alap) | Mixed mód (`@lowercase`) |
| ---------- | -------------------- | ------------------------ |
| `'A'-'Z'`  | 1-26 ($01-$1A)       | 65-90 ($41-$5A)          |
| `'a'-'z'`  | 1-26 (= nagybetű)    | 1-26 ($01-$1A)           |
| `'@'`      | 0 ($00)              | 0 ($00)                  |
| Space, 0-9 | Változatlan          | Változatlan              |

```python
@lowercase
def main():
    screen: array[char, 40][SCREEN]
    screen = s"Hello World"  # H=72, e=5, l=12, ..., W=87, o=15, ...
```

> **Fontos:** Az `array[char, N]` típust kell használni (nem `array[byte, N]`), mert a `char` tömb speciális másolási logikát használ, ami átlépi a Pascal string hossz byte-ját.

### 4.2 @kernal

Kernal ROM engedélyezése (legacy mód). Alapértelmezetten a PyCo **kikapcsolja a Kernal ROM-ot** (+8KB RAM).

```python
@kernal
def main():
    # Kernal ROM aktív - $FFD2, $FFE4 stb. elérhető
    pass
```

**Különbségek:**

| Funkció              | Alapértelmezett (Kernal OFF) | @kernal (Kernal ON)  |
| -------------------- | ---------------------------- | -------------------- |
| ROM beállítás        | $01 = $35 (mindkét ROM ki)   | $01 = $36 (BASIC ki) |
| print()              | Saját screen rutin           | $FFD2 CHROUT         |
| getkey() / waitkey() | Saját keyboard rutin         | $FFE4 GETIN          |
| @irq handler         | Rendszer IRQ-hoz láncolódik  | Direkt `rti`         |
| Extra RAM            | +8KB ($E000-$FFFF)           | Nincs extra          |

**Mikor használd:**
- Kernal rutinok közvetlen hívása (pl. floppy I/O)
- Ha kritikus a fájlméret (kisebb PRG)

**Mikor NE használd:**
- Ha több RAM kell → +8KB ($E000-$FFFF)
- Raster effektek → stabil timing a ROM nélkül

**Fájlméret vs RAM trade-off:**

| Mód             | print/getkey forrása      | PRG méret | Szabad RAM     |
| --------------- | ------------------------- | --------- | -------------- |
| `@kernal`       | Kernal ROM ($FFD2, $FFE4) | Kisebb    | ROM marad      |
| Alapértelmezett | Beépített PyCo kód        | Nagyobb   | Nettó több RAM |

A PyCo alapértelmezetten saját képernyő- és billentyűzetkezelő kódot fordít a programba. A $E000-$FFFF terület (8KB) felszabadul RAM-nak, és bár a saját rutinok foglalnak helyet, ezek kompaktabbak és gyorsabbak a Kernal rutinoknál.

### 4.3 @noreturn

A program soha nem tér vissza BASIC-be. A kilépési cleanup kód kimarad.

```python
@noreturn
def main():
    while True:
        pass  # Végtelen loop
```

**Generált kód:**
- Normál program: cleanup + `rts`
- @noreturn program: `jmp *` (végtelen loop)

**Megtakarítás:** ~50-100 byte

### 4.4 @relocate(address)

Függvény relokálása a megadott memóriacímre futásidőben.

```python
@relocate(0xC000)
def helper_function():
    # Ez a kód $C000-ra kerül futáskor
    pass
```

**Működés:**

1. A dekorált függvények a program végére kerülnek, `.pseudopc` blokkban
2. A program indulásakor egy tábla-alapú másoló átmásolja őket a célcímre
3. Az SSP a felszabadult fizikai helyre áll → több stack hely!

```
Fordítás után:                        Futásidőben (main előtt):

$0801 ┌────────────────────┐         $0801 ┌────────────────────┐
      │ Fő program kód     │               │ Fő program kód     │
$xxxx ├────────────────────┤         $xxxx ├────────────────────┤
      │ Relokált függvények│               │ (felszabadult)     │ ← SSP
      │ [fizikai hely]     │               │                    │
$yyyy └────────────────────┘         $yyyy └────────────────────┘

                                     $C000 ┌────────────────────┐
                                           │ Relokált függvények│
                                     $C0xx └────────────────────┘
```

**Dinamikus régió-kiosztás:**

Azonos célcímmel megadott függvények automatikusan egymás után kerülnek:

```python
@relocate(0xC000)
def helper1():      # → $C000-tól
    print("*")

@relocate(0xC000)   # Folytatja, nem felülír!
def helper2():      # → helper1 után
    print("#")
```

**Tipikus használati esetek:**

| Cél terület   | Mikor használd                                 |
| ------------- | ---------------------------------------------- |
| `$C000-$CFFF` | VIC Bank 3 szabad területe (4KB), leggyakoribb |
| `$A000-$BFFF` | BASIC ROM területe (ha ki van kapcsolva)       |
| `$E000-$FFFF` | Kernal ROM területe (ha ki van kapcsolva)      |

> **Megjegyzés:** A `$0400-$07FF` (alapértelmezett képernyő RAM) elméletileg használható, ha a VIC bank != 0, de a másolás közben "szemét" jelenik meg a képernyőn. Érdemes inkább a `$C000-$CFFF` területet preferálni.

**Fontos tudnivalók:**

| Szabály                       | Leírás                       |
| ----------------------------- | ---------------------------- |
| Nincs átfedés-ellenőrzés      | A programozó felelőssége     |
| Kombináció más dekorátorokkal | `@relocate` + `@irq` működik |

### 4.5 @charset_rom(address)

A C64 karakter ROM-ot (2KB) a megadott RAM címre másolja induláskor.

```python
@charset_rom(0xC800)  # 2KB ROM charset → $C800-$CFFF
@lowercase
def main():
    # A charset már készen van!
    pass
```

**Működés:**

1. A startup kód SEI-vel letiltja az IRQ-t
2. Átkapcsolja a CPU portot a character ROM eléréshez
3. Átmásolja a 2KB-os ROM charset-et a célcímre
4. Visszakapcsolja az I/O-t és CLI-vel engedélyezi az IRQ-t
5. Ezután futnak a relokációk (ha vannak)

**Kombináció `relocate[tuple[byte], address]`-tel:**

A `@charset_rom` ELŐBB másolja a ROM-ot, a `relocate` tuple-ök UTÁNA felülírják az egyedi karaktereket:

```python
# Custom karakter 60 - felülírja a ROM-ot!
char_60: relocate[tuple[byte], 0xC9E0] = (0x00, 0x3F, 0x7F, 0x7F, ...)

@charset_rom(0xC800)
@lowercase
def main():
    # ROM charset $C800-ra másolva, char 60 patch-elve
    pass
```

### 4.6 @origin(address)

Egyéni program kezdőcím beállítása BASIC loader nélkül.

```python
@origin(0x1000)
def main():
    # Program a $1000 címen indul
    pass
```

**Működés:**

- A program a megadott címen kezdődik (nem $0801-en)
- **Nincs BASIC loader** - a `BasicUpstart2` makró kimarad
- A PRG fájl első 2 byte-ja a megadott cím (little-endian)

**Betöltés és futtatás:**

```
LOAD "FILE",8,1
SYS 4096
```

A `,1` paraméter szükséges a `LOAD` parancsban, hogy a fájlban tárolt címre töltse (ne a $0801-re).

**Használati esetek:**

1. **Cartridge fejlesztés** - Program $8000-en cartridge ROM-ként
2. **Hibakereső/monitor** - Program a felső memóriában ($C000+)
3. **Több-részes programok** - Overlay-ek különböző címeken
4. **Autostart letiltás** - Program ne induljon automatikusan RUN-nal

**Kombináció más dekorátorokkal:**

```python
@origin(0xC000)
@noreturn
@lowercase
def main():
    # Program $C000-en, soha nem tér vissza BASIC-be
    pass
```

**Kombináció @relocate-tel:**

```python
@relocate(0xE000)
def irq_handler():
    pass

@origin(0xC000)
def main():
    # Fő program $C000-en
    # IRQ handler $E000-re relokálva
    __set_irq__(irq_handler)
```

A relokáció ugyanúgy működik: a forrás kód a fő program végén, induláskor átmásolódik a célcímre.

**Címtartomány:** $0000-$FFFF (teljes 64KB)

> **Figyelem:** Az `@origin` csak a `main()` függvényen használható!

### 4.7 @cartridge(mode, stack_start)

EasyFlash cartridge kimenet generálása (.crt fájl). A program közvetlenül ROM-ból fut.

```python
@cartridge              # mode=8, stack=0x0800 (alapértelmezett)
@cartridge()            # ugyanaz
@cartridge(8)           # 8KB mód
@cartridge(16)          # 16KB mód
@cartridge(8, 0x0300)   # 8KB mód, stack $0300-nál
def main():
    pass
```

**Paraméterek:**

| Paraméter     | Érték     | Leírás                            |
|---------------|-----------|-----------------------------------|
| `mode`        | 8 vagy 16 | EasyFlash mód (8KB vagy 16KB ROM) |
| `stack_start` | cím       | SSP kezdőcím (default: $0800)     |

**Memória térkép (8KB mód, Kernal bekapcsolva):**

```
$0000-$00FF  Zero Page (RAM) - PyCo runtime
$0100-$01FF  Hardware Stack (RAM)
$0200-$07FF  Szabad RAM (bank dispatcher itt lehet multi-bank módban)
$0800+       SSP alapértelmezett kezdőcím
$8000-$9FFF  ROML - Cartridge ROM (8KB)
$A000-$BFFF  Szabad RAM (8KB) - 8KB módban!
$C000-$CFFF  Szabad RAM (4KB)
$D000-$DFFF  I/O + EasyFlash regiszterek
  $DE00      Bank regiszter (0-63)
  $DE02      Mód regiszter ($06=8KB, $07=16KB)
  $DF00-$DF7F  SRAM - SMC helper ide másolódik
$E000-$FFFF  Kernal ROM (bekapcsolva)
```

**Generált fájlok:**

| Fájl típus | Leírás                                |
|------------|---------------------------------------|
| `.crt`     | EasyFlash cartridge (VICE, Ultimate)  |
| `.prg`     | NEM generálódik cartridge módban!     |

**Dekorátor kompatibilitás:**

| Dekorátor    | Működik? | Megjegyzés                          |
|--------------|----------|-------------------------------------|
| `@lowercase` | ✓        | Normálisan működik                  |
| `@noreturn`  | ✓        | Implicit (cartridge sosem tér vissza) |
| `@irq`       | ✓        | Teljes raster IRQ támogatás         |
| `@irq_raw`   | ✓        | Minimális overhead IRQ              |
| `@kernal`    | ✗        | A Kernal alapértelmezetten be van kapcsolva |

**SMC Helper SRAM-ban:**

A nagy méretű (≥64 byte) fill és copy műveletek SMC (Self-Modifying Code) helpert használnak. Cartridge módban ez a helper a boot kódban másolódik az SRAM-ba ($DF00, 52 byte), mert a ROM-ból nem módosítható.

> **Részletek:** Lásd `docs/implementations/C64/native/cartridge_plan_hu.md`

### 4.8 IRQ dekorátorok

Az IRQ kezeléshez négy dekorátor áll rendelkezésre. Részletes leírás: [5. IRQ kezelés](#5-irq-kezelés).

| Dekorátor     | IRQ vector            | Használat                      |
| ------------- | --------------------- | ------------------------------ |
| `@irq`        | $FFFE/$FFFF (hardver) | Általános IRQ handler          |
| `@irq_raw`    | $FFFE/$FFFF (hardver) | Bare metal, nincs láncolás     |
| `@irq_hook`   | $0314/$0315 (Kernal)  | Leggyorsabb, Kernal hook       |
| `@irq_helper` | N/A                   | Segédfüggvény IRQ-ból híváshoz |

### 4.9 @naked

Tisztán assembly-ben írt függvényekhez. A compiler csak egy címkét generál, semmi mást - nincs prologue, epilogue, vagy bármilyen PyCo overhead.

```python
@naked
def sid_play():
    __asm__("""
    jsr $1003       // Külső zenelejátszó rutin
    rts
    """)

def main():
    sid_play()      // Egyszerű JSR _sid_play hívás
```

**Mikor használd:**
- Külső könyvtárak (pl. zenemotor) wrapper függvényeihez
- Teljes egészében assembly-ben írt rutinokhoz
- Amikor a PyCo calling convention nem kell

**Register-based paraméterek:**

A naked függvények regiszterekben kapják a paramétereket:

| Paraméterek          | Regiszterek    |
| -------------------- | -------------- |
| `(byte)`             | A              |
| `(byte, byte)`       | A, X           |
| `(byte, byte, byte)` | A, X, Y        |
| `(word)`             | X (lo), Y (hi) |

**Szabályok:**
- A függvénynek magának kell gondoskodnia a regiszter megőrzésről
- Nem kombinálható `@irq` dekorátorral
- **Modul export:** `@naked` függvények exportálhatók modulból, a PMI tartalmazza az `is_naked` flaget

> **Megjegyzés:** IRQ handler-ből való hatékony híváshoz lásd az `@irq_helper` dekorátort (5.4 fejezet).

---

## 5. IRQ kezelés

### 5.1 Áttekintés

A C64-en két IRQ vector van:

| Vector       | Cím         | Trigger                           |
| ------------ | ----------- | --------------------------------- |
| Hardware IRQ | $FFFE/$FFFF | VIC-II raster, CIA timer          |
| Kernal hook  | $0314/$0315 | Kernal által hívott szoftver hook |

### 5.2 @irq vs @irq_raw vs @irq_hook vs @irq_helper

| Tulajdonság       | @irq                   | @irq_raw             | @irq_hook           | @irq_helper |
| ----------------- | ---------------------- | -------------------- | ------------------- | ----------- |
| IRQ vector        | $FFFE/$FFFF            | $FFFE/$FFFF          | $0314/$0315         | N/A         |
| Prologue/epilogue | A/X/Y mentés + `rti`   | A/X/Y mentés + `rti` | Nincs + `jmp $ea31` | Csak `rts`  |
| Rendszer IRQ lánc | Igen (alapért. módban) | Soha                 | N/A (Kernal kezeli) | N/A         |
| Temp regiszterek  | irq_tmp0-5             | irq_tmp0-5           | irq_tmp0-5          | irq_tmp0-5  |

**@irq:** Teljes IRQ handler. Alapértelmezett módban a rendszer IRQ-hoz láncolódik (keyboard működik).

**@irq_raw:** Teljes IRQ handler, de soha nem láncolódik. Teljes kontroll, de keyboard nem működik automatikusan.

**@irq_hook:** Könnyűsúlyú hook a Kernal szoftver IRQ vectorhoz. A Kernal már elmentette A/X/Y-t, így nincs prologue. A handler végén `JMP $EA31`-re ugrik.

> **Fontos:** Az `@irq_hook` csak a CIA system timer-hez alkalmas (zene lejátszás, frame számláló, stb.). Raster vagy más VIC interruptokhoz használj `@irq`-t vagy `@irq_raw`-t, mert a Kernal IRQ handler nem acknowledgeol VIC interruptokat és nem végez forrás-szűrést.

**@irq_helper:** Segédfüggvény IRQ handlerből való híváshoz. `irq_tmp0-5` regisztereket használ. **Modul export:** `@irq_helper` függvények exportálhatók modulból, a PMI tartalmazza az `is_irq_helper` flaget.

```python
# Általános IRQ - keyboard működik
@irq
def raster_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF

# Bare metal IRQ - teljes kontroll
@irq_raw
def timing_critical_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF

# Kernal hook - legkisebb saját overhead
@irq_hook
def frame_counter():
    frame_count: byte[0x02F0]
    frame_count = frame_count + 1
```

### 5.3 IRQ paraméterek

Az IRQ handlerek speciális paramétereket kaphatnak:

| Paraméter | Regiszter | Leírás                 | Olvasás        |
| --------- | --------- | ---------------------- | -------------- |
| `vic`     | $D019     | VIC-II interrupt flag  | Közvetlen      |
| `cia1`    | $DC0D     | CIA1 interrupt control | **Lazy cache** |
| `cia2`    | $DD0D     | CIA2 interrupt control | Közvetlen      |

> **Speciális:** A paraméterek sorrendje tetszőleges, és bármelyik elhagyható. A `(cia1: byte, vic: byte)` ugyanúgy működik, mint a `(vic: byte, cia1: byte)`, és a `(vic: byte)` is érvényes, ha csak VIC-et használsz.

**Fontos különbségek:**
- **VIC ($D019):** Olvasás NEM törli az értéket → többször olvasható
- **CIA1 ($DC0D):** Olvasás TÖRLI az értéket → lazy cache kötelező
- **CIA2 ($DD0D):** Olvasás TÖRLI az értéket → user felelőssége

```python
@irq
def raster_handler(vic: byte, cia1: byte):
    if vic & 0x01:
        vic = 0x01  # Acknowledge - közvetlenül $D019-be ír
        # raster logika...

    if cia1 & 0x01:
        # CIA1 Timer A interrupt
        pass
```

**Paraméterek írása:** közvetlenül a hardware regiszterbe megy:

```python
@irq
def handler(vic: byte, cia1: byte):
    if vic & 0x01:
        vic = 0x01      # → sta $D019
    if cia1 & 0x01:
        cia1 = 0x7f     # → sta $DC0D
```

**Lazy reading optimalizáció (CIA1):**

A `cia1` paraméter lazy reading-et használ, ami ~7 ciklust takarít meg raszter IRQ-knál:

1. A prologue inicializál egy cache-t (`irq_cia1_cache = $80`)
2. A CIA1 regiszter CSAK akkor olvasódik be, ha a kód használja
3. Az epilogue-ban (ha eléri) a CIA1 mindig olvasódik az acknowledge miatt

**Korai return raszter IRQ-knál:**

Ha `return`-t használsz a handler közepén (pl. gyors raszter effekthez), az epilogue nem fut le. Ha CIA1 is triggelt közben, az IRQ **azonnal újrahívódik** RTI után (a CIA1 /IRQ vonal LOW marad). Ez nem probléma - a következő hívásban kezelheted a CIA1-et, ha szükséges.

### 5.4 Temp regiszterek

Az IRQ bármikor megszakíthatja a főprogramot. Ezért az IRQ handler **külön ZP területet** használ:

| Normál kontextus | IRQ kontextus | Használat          |
| ---------------- | ------------- | ------------------ |
| $02-$07 (tmp0-5) | $1A-$1F       | Alapvető műveletek |
| $13-$15 (tmp6-8) | (nincs)       | Kerülendő IRQ-ban! |

**Fontos:** A tmp6-8 nem kerül automatikusan helyettesítésre IRQ-ban! Ezek osztáshoz, f16/f32-höz és string műveletekhez kellenek - ezek **tiltottak** IRQ handlerben.

### 5.5 Lokális változók IRQ-ban

Az IRQ handler a software stack-et használja, de **NEM módosítja** az SSP-t és FP-t. Közvetlenül `(SSP) + 4 + offset` címet használ.

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
                                     └─────────────┘
```

**Miért +4 byte védőzóna?** A főprogram max 4 byte-ot ír egyszerre (float paraméter), SSP módosítás nélkül. A +4 offset garantálja, hogy nem írjuk felül.

### 5.6 IRQ-ban TILOS műveletek

A compiler fordítási időben ellenőrzi:

| Művelet                       | Hibaüzenet                       | Miért tilos?              |
| ----------------------------- | -------------------------------- | ------------------------- |
| `float`, `f16`, `f32` típusok | "Float type not allowed in @irq" | FAC/ARG nem mentődik      |
| `print()`                     | "print() not allowed in @irq"    | spbuf/spsave nem mentődik |

**IRQ-ban ENGEDÉLYEZETT:**
- `byte`, `word`, `int`, `char`, `bool` típusok
- Összehasonlítások, feltételek, ciklusok
- Memory-mapped változók
- Array/subscript hozzáférés
- `__sei__()`, `__cli__()`, `__inc__()`, `__dec__()`, `__asm__()`
- Függvényhívás (normál függvények is!) és `@naked`/`@irq_helper` hívás

**Normál függvények hívása IRQ-ból:**

Az IRQ handler hívhat normál függvényeket is! A compiler automatikusan generálja a szükséges wrapper kódot:

```python
def calculate_score(base: word, multiplier: byte) -> word:
    return base * multiplier

@irq
def raster_handler(vic: byte):
    if vic & 0x01:
        vic = 0x01
        new_score: word = calculate_score(100, 5)  # Normál hívás - működik!
```

**A compiler automatikusan:**
1. Menti a főprogram `tmp0-tmp5`, `FP`, `SSP` értékeit a HW stack-re
2. Beállítja az `SSP`-t és `FP`-t a hívott függvény számára
3. Hívás után visszaállítja az eredeti értékeket

**Overhead:** ~100-120 ciklus per hívás (a mentés/visszaállítás miatt).

**Előny:** A normál függvények **mind IRQ-ból, mind a főprogramból hívhatók** - ugyanaz a kód újrahasználható mindkét kontextusban.

**Optimalizálás:** Ha minimális overhead kell és a függvény **csak IRQ-ból** lesz hívva, használj `@irq_helper` dekorátort. Ez `irq_tmp0-5` regisztereket használ, ezért főprogramból NEM hívható!

### 5.7 irq_safe wrapper típus

Az `irq_safe` wrapper típus **atomi hozzáférést** biztosít változókhoz, amelyeket mind a főprogram, mind az IRQ handler használ.

```python
@singleton
class Game:
    score: irq_safe[word[0x00FB]]    # Atomi hozzáférés
```

**Probléma (irq_safe nélkül):**

```
; Normál word írás - VESZÉLYES!
    lda #$39
    sta $FB          ; ← IRQ itt szakíthatja meg
    lda #$30         ;   Az IRQ hibás értéket olvas!
    sta $FC
```

**Megoldás (irq_safe-fel):**

```
; irq_safe word írás - BIZTONSÁGOS
    php              ; I flag mentése
    sei              ; IRQ tiltás
    lda #$39
    sta $FB
    lda #$30
    sta $FC
    plp              ; I flag visszaállítása
```

**Miért PHP/PLP és nem SEI/CLI?**

A `PLP` visszaállítja az **eredeti** I flag állapotot. Ha a user korábban `__sei__()`-t hívott, a CLI visszakapcsolná az IRQ-t a szándéka ellenére.

**IRQ kontextus detektálás:**

Az IRQ handlerekben a védelem **automatikusan kimarad** (a 6502 CPU automatikusan I=1-re állítja).

**Overhead:**

| Művelet          | Extra ciklus |
| ---------------- | ------------ |
| irq_safe olvasás | +9 ciklus    |
| irq_safe írás    | +9 ciklus    |
| IRQ-ban          | +0 ciklus    |

### 5.8 IRQ handler beállítása

**`__set_irq__()` intrinsic (ajánlott):**

```python
@irq_hook
def frame_counter():
    frame_count: byte[0x02F0]
    frame_count = frame_count + 1

def main():
    __set_irq__(frame_counter)  # Automatikusan felismeri a dekorátort
```

| Dekorátor   | Beállított vector     |
| ----------- | --------------------- |
| `@irq`      | $FFFE/$FFFF (hardver) |
| `@irq_raw`  | $FFFE/$FFFF (hardver) |
| `@irq_hook` | $0314/$0315 (Kernal)  |

**Manuális beállítás:**

```python
def main():
    irq_vector: word[0x0314]
    __sei__()
    irq_vector = addr(raster_handler)
    __cli__()
```

### 5.9 SSP védett frissítés

Ha a programban van `@irq` handler, a kódgenerátor **védett SSP frissítést** használ page boundary crossing esetén:

```asm
; Védett SSP frissítés (php/plp megőrzi a user __sei__ állapotát)
clc
lda SSP
adc #<frame_size
bcc .no_carry       ; Ha nincs carry → biztonságos
php                 ; Page crossing → védelem!
sei
sta SSP
inc SSP+1
plp                 ; EREDETI I flag visszaállítása
jmp .done
.no_carry:
sta SSP
.done:
```

**Overhead:**
- Nincs page crossing: **0 extra ciklus**
- Page crossing: **+12 ciklus**

---

## 6. Intrinsic függvények

### 6.1 Interrupt kezelés

**`__sei__()` - Interrupt tiltás:**

```python
__sei__()  # Interrupts disabled
```

A 6502 `SEI` utasítását generálja.

**`__cli__()` - Interrupt engedélyezés:**

```python
__cli__()  # Interrupts enabled
```

A 6502 `CLI` utasítását generálja.

> **Fontos:** A `__sei__()` és `__cli__()` mindig párban használandók!

### 6.2 Timing

**`__nop__()` - Üres utasítás:**

```python
__nop__()     # 1 NOP = 2 ciklus
__nop__(5)    # 5 NOP = 10 ciklus
```

Tipikus használat: precíz timing raster effekteknél.

### 6.3 Raster IRQ segédfüggvények

**`__enable_raster_irq__(line)` - Raster IRQ bekapcsolása:**

```python
IRQ_LINE = 100

def main():
    __set_irq__(raster_handler)
    __enable_raster_irq__(IRQ_LINE)
```

Automatikusan kezeli a SEI/CLI-t és a $D011 bit 7-et (9. raster bit).

**`__disable_raster_irq__()` - Raster IRQ kikapcsolása:**

```python
def cleanup():
    __disable_raster_irq__()
```

**`__set_raster__(line)` - Raster sor beállítása:**

```python
@irq
def split_screen(vic: byte, cia1: byte):
    vic = 0x01
    current: word = __get_raster__()

    if current < 100:
        __set_raster__(SECOND_LINE)
    else:
        __set_raster__(FIRST_LINE)
```

IRQ kontextusban **nincs** SEI/CLI overhead.

**`__get_raster__()` - Aktuális raster sor:**

```python
current: word = __get_raster__()  # 0-311
```

**Összefoglaló:**

| Függvény                 | Visszatérés | IRQ védelem                      |
| ------------------------ | ----------- | -------------------------------- |
| `__enable_raster_irq__`  | void        | PHP/SEI...PLP (mindig)           |
| `__disable_raster_irq__` | void        | PHP/SEI...PLP (mindig)           |
| `__set_raster__`         | void        | PHP/SEI...PLP (csak IRQ-n kívül) |
| `__get_raster__`         | word        | Nincs (csak olvasás)             |

### 6.4 Egyéb intrinsics

**`__inc__(var)` / `__dec__(var)` - Belső használatú:**

> **Megjegyzés:** Ezeket nem kell közvetlenül használni! A compiler automatikusan INC/DEC utasításra alakítja a `counter += 1` és `counter -= 1` kifejezéseket. Egyszerűen használd a `+=` / `-=` operátorokat - az optimalizáció automatikus.
>
> **Fontos:** A `c = c + 1` forma NEM alakul át automatikusan, csak a `c += 1`!

---

## 7. Automatikus optimalizációk

### 7.1 Tömb másolás (Array Copy)

A `arr1 = arr2` típusú tömb értékadás inline memcpy-t generál.

**Címzési módok:**

| Típus          | Módszer   | Ciklus/byte |
| -------------- | --------- | ----------- |
| Indirekt       | `(ptr),Y` | ~17-19      |
| Hibrid         | Vegyes    | ~15-16      |
| Absolute (SMC) | `$addr,Y` | ~13-15      |

```python
def main():
    screen: array[byte, 1000][0x0400]  # Mapped
    backup: array[byte, 1000][0xC000]  # Mapped

    backup = screen  # SMC optimalizált: ~13-15 cy/byte
```

A fordító automatikusan a leggyorsabb módszert választja:
- Mindkét mapped → teljes SMC (leggyorsabb)
- Egyik mapped → hibrid
- Egyik sem mapped → indirekt

### 7.2 Téglalap másolás (blkcpy)

A `blkcpy()` intrinsic gyors block memóriamásolást valósít meg.

**Szintaxis:**

```python
# 7 paraméteres (közös stride):
blkcpy(src_arr, src_offset, dst_arr, dst_offset, width, height, stride)

# 8 paraméteres (külön stride):
blkcpy(src_arr, src_offset, src_stride, dst_arr, dst_offset, dst_stride, width, height)
```

**Használati példák:**

```python
screen: array[byte, 1000][0x0400]

# Scroll left
blkcpy(screen, 1, screen, 0, 39, 25, 40)

# Scroll up
blkcpy(screen, 40, screen, 0, 40, 24, 40)

# Tile blit (8x8 tile → screen)
blkcpy(tile, 0, 8, screen, 12*40+16, 40, 8, 8)
```

**Automatikus irány-detektálás:**

Átfedő másolásnál a fordító automatikusan meghatározza a helyes irányt:
- **Forward** (dst ≤ src): 0-tól width-1-ig
- **Backward** (dst > src): width-1-től 0-ig

**Teljesítmény:**

| Tömb típusok   | Ciklus/byte |
| -------------- | ----------- |
| Mindkét mapped | ~13         |
| Egyik mapped   | ~17         |
| Mindkét stack  | ~21         |

### 7.3 Aritmetikai optimalizációk

#### Strength Reduction (O1)

Konstans 2-hatványokkal végzett műveletek bit shift-re cserélődnek:

| Művelet  | Optimalizált kód | Megtakarítás |
| -------- | ---------------- | ------------ |
| `a * 2`  | `asl`            | ~80 → 2 cy   |
| `a * 4`  | `asl` `asl`      | ~80 → 4 cy   |
| `a / 2`  | `lsr`            | ~80 → 2 cy   |
| `a % 16` | `and #15`        | ~100 → 2 cy  |

#### Konstans szorzás dekompozíció (O2)

Kis konstansokkal való szorzás shift+add/sub kombinációkra bomlik:

| Konstans | Dekompozíció        | Ciklus |
| -------- | ------------------- | ------ |
| 3        | `(a << 1) + a`      | ~12    |
| 5        | `(a << 2) + a`      | ~14    |
| 7        | `(a << 3) - a`      | ~16    |
| 9        | `(a << 3) + a`      | ~16    |
| 10       | `(a << 3) + (a<<1)` | ~20    |

**Teljesítmény összehasonlítás:**

| Művelet | Runtime helper | O1 (shift) | O2 (decomp) |
| ------- | -------------- | ---------- | ----------- |
| `a * 2` | ~80 cy         | ~2 cy      | -           |
| `a * 3` | ~80 cy         | -          | ~12 cy      |
| `a * 5` | ~80 cy         | -          | ~14 cy      |

---

## 8. Típus implementáció

### 8.1 Float formátum

A PyCo **32-bites MBF** (Microsoft Binary Format) lebegőpontos számokat használ:

| Byte | Tartalom                       |
| ---- | ------------------------------ |
| 0    | Exponens (biased by 128)       |
| 1-3  | Mantissza (24 bit, implicit 1) |
| 3    | bit 7 = előjel                 |

**Ábrázolható tartomány:**

| Érték       | Decimális közelítés |
| ----------- | ------------------- |
| Max pozitív | ~1.7×10³⁸           |
| Max negatív | ~-1.7×10³⁸          |

### 8.2 Float túlcsordulás

Túlcsordulás esetén **signed saturation** történik:

| Művelet           | Feltétel         | Eredmény    |
| ----------------- | ---------------- | ----------- |
| Összeadás/szorzás | Pozitív overflow | Max pozitív |
| Összeadás/szorzás | Negatív overflow | Max negatív |
| Osztás nullával   | Pozitív osztandó | Max pozitív |
| Osztás nullával   | Negatív osztandó | Max negatív |

> **Megjegyzés:** Ez eltér a Commodore BASIC-től (`?OVERFLOW ERROR`). A PyCo a DSP/SIMD processzoroknál megszokott saturation megközelítést használja.

---

## 9. Build rendszer

### 9.1 D64 lemezképek

A PyCo támogatja a multi-file projektek D64 lemezképbe csomagolását TOML konfigurációval.

**Projekt struktúra:**

```
project/
├── game.pyco       # Fő program
├── game.toml       # Projekt konfiguráció
├── build/
│   ├── game.prg
│   ├── game.d64
│   └── ...
└── includes/
```

### 9.2 TOML konfiguráció

```toml
[project]
name = "MyGame"
version = "1.0"

[disk]
label = "MYGAME"      # Lemez neve (max 16 karakter)
id = "01"             # Lemez ID (2 karakter)

[[disk.files]]
source = "build/game.prg"
name = "MYGAME"

[[disk.files]]
source = "build/title_bitmap_rle.prg"
name = "TITLEBIT"

[run]
autostart = true
warp = true
```

**Disk ID:** A 2 karakteres ID fontos a 1541 drive BAM cache-elése miatt. Lemezcserénél az ID változása jelzi a drive-nak az újraolvasást.

### 9.3 CLI használat

```bash
# Fordítás
pycoc compile game.pyco              # → build/game.prg

# D64 létrehozás
pycoc d64 game.toml                  # → build/game.d64

# Futtatás VICE-ban
pycoc run game.pyco
pycoc run game.toml
```

**Tipikus workflow:**

```bash
pycoc compile game.pyco   # 1. Fordítás
pycoc image title.koa ... # 2. Képek konvertálása
pycoc music song.fur ...  # 3. Zene konvertálása
pycoc d64 game.toml       # 4. D64 összeállítása
```

### 9.4 PRG fájl formátum

```
┌──────────────┬─────────────────────┐
│ Byte 0-1     │ Byte 2 - végéig     │
│ Load address │ Raw data            │
│ (little-end) │                     │
└──────────────┴─────────────────────┘
```

A C64 `LOAD "FILE",8,1` parancs a PRG-ben tárolt címre tölti az adatot.

### 9.5 Binary konverterek

```bash
# Kép → PRG
pycoc image title.koa --binary -C rle -O build/

# Zene → PRG
pycoc music song.fur --binary -L 0xA000 -O build/
```

---

## Példák

### Memory-mapped változók

```python
BORDER = 0xD020
BGCOLOR = 0xD021

def main():
    border: byte[BORDER]
    bgcolor: byte[BGCOLOR]

    border = 0       # fekete keret
    bgcolor = 6      # kék háttér
```

### Képernyő memória

```python
SCREEN = 0x0400
COLOR = 0xD800

def main():
    screen: array[byte, 1000][SCREEN]
    color: array[byte, 1000][COLOR]

    screen[0] = 1    # 'A' karakter
    color[0] = 1     # fehér szín
```

### Színes keret

```python
@lowercase
def main():
    border: byte[0xD020]
    i: byte

    while True:
        for i in range(16):
            border = i
```

### Raster scroll

```python
scroll_x: byte[0x02F0] = 0

@irq
def raster_handler():
    vic_ctrl2: byte[0xD016]
    vic_irq: byte[0xD019]

    vic_ctrl2 = (vic_ctrl2 & 0xF8) | scroll_x
    vic_irq = 0xFF
```
