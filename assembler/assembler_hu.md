# PyCo Beépített 6502 Assembler

A PyCo tartalmaz egy beépített 6502 assemblert, amely **Kick Assembler szintaxist** használ. Ez lehetővé teszi a teljes fordítási folyamatot Python-ből, külső eszközök (Java, Kick Assembler) nélkül.

## Jellemzők

- **Zero dependency**: Nincs szükség Java-ra vagy külső assembler-re
- **Pip installable**: `pip install pyco` után azonnal használható
- **Kick Assembler kompatibilis**: A PyCo által generált `.asm` fájlok mindkét assemblerrel fordíthatók
- **Byte-pontos**: 66 összehasonlító teszt garantálja a Kick Assemblerrel azonos kimenetet

## Használat

### Parancssorból

```bash
# Alapértelmezett: .prg generálás beépített assemblerrel
pycoc compile program.pyco

# Csak .asm generálás (ha Kick Assemblert szeretnél használni)
pycoc compile program.pyco --asm-only
```

### Python API

```python
from pyco.assembler import assemble, AssemblerError

asm_source = """
    .pc = $0801
    BasicUpstart2(main)

main:
    lda #$00
    sta $d020
    rts
"""

try:
    prg_bytes = assemble(asm_source)
    with open("program.prg", "wb") as f:
        f.write(prg_bytes)
except AssemblerError as e:
    print(f"Hiba: {e}")
```

## Támogatott Utasítások

### Load/Store

| Utasítás | Leírás                    |
|----------|---------------------------|
| `LDA`    | Load Accumulator          |
| `LDX`    | Load X Register           |
| `LDY`    | Load Y Register           |
| `STA`    | Store Accumulator         |
| `STX`    | Store X Register          |
| `STY`    | Store Y Register          |

### Transfer

| Utasítás | Leírás                    |
|----------|---------------------------|
| `TAX`    | Transfer A to X           |
| `TAY`    | Transfer A to Y           |
| `TXA`    | Transfer X to A           |
| `TYA`    | Transfer Y to A           |
| `TSX`    | Transfer Stack Pointer to X |
| `TXS`    | Transfer X to Stack Pointer |

### Stack

| Utasítás | Leírás                    |
|----------|---------------------------|
| `PHA`    | Push Accumulator          |
| `PLA`    | Pull Accumulator          |
| `PHP`    | Push Processor Status     |
| `PLP`    | Pull Processor Status     |

### Arithmetic

| Utasítás | Leírás                    |
|----------|---------------------------|
| `ADC`    | Add with Carry            |
| `SBC`    | Subtract with Carry       |
| `INC`    | Increment Memory          |
| `DEC`    | Decrement Memory          |
| `INX`    | Increment X               |
| `INY`    | Increment Y               |
| `DEX`    | Decrement X               |
| `DEY`    | Decrement Y               |

### Compare

| Utasítás | Leírás                    |
|----------|---------------------------|
| `CMP`    | Compare with Accumulator  |
| `CPX`    | Compare with X            |
| `CPY`    | Compare with Y            |

### Logic

| Utasítás | Leírás                    |
|----------|---------------------------|
| `AND`    | Logical AND               |
| `ORA`    | Logical OR                |
| `EOR`    | Exclusive OR              |

### Shift/Rotate

| Utasítás | Leírás                    |
|----------|---------------------------|
| `ASL`    | Arithmetic Shift Left     |
| `LSR`    | Logical Shift Right       |
| `ROL`    | Rotate Left               |
| `ROR`    | Rotate Right              |

### Branch

| Utasítás | Leírás                    |
|----------|---------------------------|
| `BEQ`    | Branch if Equal (Z=1)     |
| `BNE`    | Branch if Not Equal (Z=0) |
| `BCC`    | Branch if Carry Clear     |
| `BCS`    | Branch if Carry Set       |
| `BPL`    | Branch if Plus (N=0)      |
| `BMI`    | Branch if Minus (N=1)     |
| `BVC`    | Branch if Overflow Clear  |
| `BVS`    | Branch if Overflow Set    |

### Jump

| Utasítás | Leírás                    |
|----------|---------------------------|
| `JMP`    | Jump                      |
| `JSR`    | Jump to Subroutine        |
| `RTS`    | Return from Subroutine    |

### Flag

| Utasítás | Leírás                    |
|----------|---------------------------|
| `CLC`    | Clear Carry               |
| `SEC`    | Set Carry                 |
| `CLI`    | Clear Interrupt Disable   |
| `SEI`    | Set Interrupt Disable     |
| `CLD`    | Clear Decimal Mode        |
| `SED`    | Set Decimal Mode          |
| `CLV`    | Clear Overflow            |

### Interrupt

| Utasítás | Leírás                    |
|----------|---------------------------|
| `BRK`    | Software Break/Interrupt  |
| `RTI`    | Return from Interrupt     |

### Egyéb

| Utasítás | Leírás                    |
|----------|---------------------------|
| `NOP`    | No Operation              |
| `BIT`    | Bit Test                  |

## Címzési Módok

| Mód           | Szintaxis       | Példa            | Leírás                    |
|---------------|-----------------|------------------|---------------------------|
| Immediate     | `#$XX`          | `LDA #$00`       | Konstans érték            |
| Zero Page     | `$XX`           | `LDA $02`        | ZP cím (0-255)            |
| Zero Page,X   | `$XX,X`         | `LDA $10,X`      | ZP + X index              |
| Zero Page,Y   | `$XX,Y`         | `LDX $10,Y`      | ZP + Y index              |
| Absolute      | `$XXXX`         | `LDA $0400`      | 16-bites cím              |
| Absolute,X    | `$XXXX,X`       | `LDA $0400,X`    | Abszolút + X index        |
| Absolute,Y    | `$XXXX,Y`       | `STA table,Y`    | Abszolút + Y index        |
| Indirect      | `($XXXX)`       | `JMP ($FFFE)`    | Indirekt (csak JMP)       |
| Indirect,X    | `($XX,X)`       | `LDA ($FB,X)`    | Indexed Indirect          |
| Indirect,Y    | `($XX),Y`       | `LDA ($FB),Y`    | Indirect Indexed          |
| Implied       | (nincs)         | `RTS`            | Nincs operandus           |
| Accumulator   | `A` (opcionális)| `ASL`            | Akkumulátoron végzett     |

### Indirekt Címzési Módok

A 6502 két indirekt címzési módot támogat, fontos megérteni a különbséget:

**Indexed Indirect `($XX,X)`** - "Pointer tábla"
```asm
// X a pointer-tábla indexe, NEM az adat indexe
// pointer = ($FB + X), majd adat = *pointer
ldx #$02        // 2. pointer a táblában
lda ($fb,x)     // pointer = $FB+2 = $FD, adat = *$FD
```
Használat: Pointer táblák (pl. jump table, callback táblák)

**Indirect Indexed `($XX),Y`** - "Tömb hozzáférés"
```asm
// Pointer fix, Y az adat indexe
// pointer = ($FB), majd adat = *pointer + Y
ldy #$05        // 5. elem a tömbben
lda ($fb),y     // pointer = *$FB, adat = pointer+5
```
Használat: Tömbök és stringek bejárása pointerrel

### Zero Page Optimalizáció

Ha egy kifejezés értéke 0-255 közé esik, automatikusan a rövidebb (2-bájtos) Zero Page címzést használjuk:

```asm
.label ZP = $02
lda ZP      // 2 bájt: $A5 $02 (Zero Page)
lda ZP + 1  // 2 bájt: $A5 $03 (Zero Page - optimalizált!)
lda $0400   // 3 bájt: $AD $00 $04 (Absolute)
```

## Direktívák

### .pc - Program Counter

A program kezdőcímének beállítása:

```asm
.pc = $0801    // C64 BASIC terület
```

### .byte - Byte adatok

```asm
.byte $00              // Egy byte
.byte $12, $34, $56    // Több byte
.byte 0, 1, 2, 3       // Decimális értékek
```

### .word - Word adatok (little-endian)

```asm
.word $1234            // $34, $12 (little-endian)
.word $abcd, $ef01     // Több word
```

### .fill - Memória kitöltés

```asm
.fill 10, $00          // 10 byte nullával
.fill 100, $ea         // 100 NOP utasítás
```

### .label / .const - Konstans definíció

```asm
.label SCREEN = $0400
.label ZP_PTR = $fb
.const BORDER = $d020

lda SCREEN
sta ZP_PTR
```

### .encoding - Karakterkódolás

```asm
.encoding "petscii_upper"   // Nagybetűs mód (alapértelmezett)
.encoding "petscii_mixed"   // Kis/nagybetűs mód
```

### .text - Szöveg (PETSCII)

A `@"..."` szintaxis escape szekvenciákat támogat:

```asm
.encoding "petscii_upper"
.text @"HELLO WORLD"

.encoding "petscii_mixed"
.text @"Hello World"
```

#### Escape szekvenciák

| Escape    | Jelentés              | Kód   |
|-----------|-----------------------|-------|
| `\n`      | Új sor (CR)           | $0D   |
| `\r`      | Kocsi vissza          | $0D   |
| `\t`      | Tab                   | $09   |
| `\\`      | Backslash             | $5C   |
| `\"`      | Idézőjel              | $22   |
| `\$XX`    | Hex byte              | $XX   |

#### PETSCII vezérlőkódok

A `{name}` szintaxissal speciális PETSCII kódokat illeszthetsz be:

```asm
.text @"{clr}HELLO{return}"   // Képernyő törlés, szöveg, új sor
```

| Név          | Leírás                | Kód   |
|--------------|-----------------------|-------|
| `{clr}`      | Képernyő törlés       | $93   |
| `{home}`     | Kurzor home           | $13   |
| `{down}`     | Kurzor le             | $11   |
| `{up}`       | Kurzor fel            | $91   |
| `{left}`     | Kurzor balra          | $9D   |
| `{right}`    | Kurzor jobbra         | $1D   |
| `{rvson}`    | Inverz be             | $12   |
| `{rvsoff}`   | Inverz ki             | $92   |
| `{return}`   | Enter                 | $0D   |
| `{black}`    | Fekete szín           | $90   |
| `{white}`    | Fehér szín            | $05   |
| `{red}`      | Piros szín            | $1C   |
| `{cyan}`     | Cián szín             | $9F   |
| `{purple}`   | Lila szín             | $9C   |
| `{green}`    | Zöld szín             | $1E   |
| `{blue}`     | Kék szín              | $1F   |
| `{yellow}`   | Sárga szín            | $9E   |

## Makrók

### BasicUpstart2

BASIC loader generálása a C64-hez:

```asm
.pc = $0801
BasicUpstart2(main)

main:
    // A program itt kezdődik
    lda #$00
    sta $d020
    rts
```

Ez a következő BASIC sort generálja:
```
10 SYS <main címe>
```

## Labelek

### Globális labelek

```asm
main:
    jsr subroutine
    rts

subroutine:
    lda #$00
    rts
```

### Lokális (scoped) labelek

A `!name:` szintaxissal definiált labelek csak a következő globális labelig érvényesek:

```asm
func1:
!loop:              // Lokális: func1 scope
    dex
    bne !loop-      // Vissza a lokális labelre
    rts

func2:
!loop:              // Másik lokális: func2 scope (nem ütközik!)
    dey
    bne !loop-
    rts
```

A `-` (előző) vagy `+` (következő) utótag jelzi az irányt.

### Anonim labelek

A `!:` definiál egy anonim labelt, a `!+` és `!-` hivatkozik rájuk:

```asm
!:                  // Első anonim label
    lda #$00
    beq !+          // Ugrás a következő anonimra
    jmp !-          // Ugrás az előző anonimra
!:                  // Második anonim label
    rts
```

#### Többszörös hivatkozás

A `!++` a második következő, a `!--` a második előző anonim labelre mutat:

```asm
!:                  // 1. anonim
    bmi !++         // A 3. anonimra ugrik
!:                  // 2. anonim
    nop
!:                  // 3. anonim
    rts
```

## Kifejezések

### Aritmetika

```asm
.label BASE = $0400
.label OFFSET = $28

lda BASE + 10           // $0400 + 10 = $040A
sta BASE + OFFSET * 2   // $0400 + 40*2 = $0450
```

### Lo/Hi byte operátorok

```asm
.label ADDR = $1234

lda #<ADDR      // Low byte: $34
ldx #>ADDR      // High byte: $12
```

### Labelek címe

```asm
lda #<subroutine    // Szubrutin címének alsó bájtja
ldx #>subroutine    // Szubrutin címének felső bájtja
```

## Karakter literálok

```asm
lda #'A'        // ASCII kód: $41
cmp #' '        // Space: $20
```

## Kommentek

```asm
// Ez egy komment
lda #$00    // Inline komment
```

## Hibaüzenetek

Az assembler részletes hibaüzeneteket ad:

```
Line 10: Unknown instruction: LDB
Line 15: Branch target out of range: -150 bytes (limit: -128)
Line 20: Undefined label: undefined_label
```

## Korlátozások

A beépített assembler a teljes 6502 utasításkészletet támogatja. **Nem implementált** funkciók:

| Funkció                | Miért nem kell                          |
|------------------------|-----------------------------------------|
| Makró rendszer         | Csak BasicUpstart2 kell, az beépített   |
| `.include`             | A runtime kódot a compiler generálja    |
| Kondicionális fordítás | Nem használjuk                          |
| 65C02 utasítások       | Csak 6502/6510 támogatott               |
| `.align`, `.org`       | Nem szükséges                           |

## Kompatibilitás

A PyCo Assembler **byte-pontosan azonos** kimenetet ad a Kick Assemblerrel minden támogatott funkció esetén. Ez 78 összehasonlító teszttel van garantálva.

Ha Kick Assemblert szeretnél használni:

```bash
# Csak .asm generálás
pycoc compile program.pyco --asm-only

# Kick Assemblerrel fordítás
java -jar KickAss.jar build/program.asm
```

## Architektúra

```
src/pyco/assembler/
    __init__.py     # Public API: assemble()
    lexer.py        # Tokenizálás
    parser.py       # AST építés (két-pass)
    codegen.py      # Bináris generálás
    opcodes.py      # 6502 opcode táblák
    petscii.py      # PETSCII konverzió
    errors.py       # Hibakezelés
```

### Két-pass algoritmus

1. **Pass 1**: Label címek gyűjtése
   - Végigmegy a forráson
   - Minden labelt felvesz a szimbólumtáblába a címével

2. **Pass 2**: Kód generálás
   - A labelek már ismertek
   - Generálja a tényleges gépi kódot
   - Branch távolság ellenőrzés

### PRG formátum

A kimenet C64 PRG formátumú:
- Első 2 byte: load address (little-endian, általában $0801)
- Többi byte: a program kódja
