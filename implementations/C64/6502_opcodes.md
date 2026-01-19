# 6502 Opcode Reference - Instruction Lengths

## Opcode Matrix (Hex)

```
     | x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xA  xB  xC  xD  xE  xF
-----+----------------------------------------------------------------
0x   | BRK ORA --- --- --- ORA ASL --- PHP ORA ASL --- --- ORA ASL ---
     |  2   2   -   -   -   2   2   -   1   2   1   -   -   3   3   -
-----+----------------------------------------------------------------
1x   | BPL ORA --- --- --- ORA ASL --- CLC ORA --- --- --- ORA ASL ---
     |  2   2   -   -   -   2   2   -   1   3   -   -   -   3   3   -
-----+----------------------------------------------------------------
2x   | JSR AND --- --- BIT AND ROL --- PLP AND ROL --- BIT AND ROL ---
     |  3   2   -   -   2   2   2   -   1   2   1   -   3   3   3   -
-----+----------------------------------------------------------------
3x   | BMI AND --- --- --- AND ROL --- SEC AND --- --- --- AND ROL ---
     |  2   2   -   -   -   2   2   -   1   3   -   -   -   3   3   -
-----+----------------------------------------------------------------
4x   | RTI EOR --- --- --- EOR LSR --- PHA EOR LSR --- JMP EOR LSR ---
     |  1   2   -   -   -   2   2   -   1   2   1   -   3   3   3   -
-----+----------------------------------------------------------------
5x   | BVC EOR --- --- --- EOR LSR --- CLI EOR --- --- --- EOR LSR ---
     |  2   2   -   -   -   2   2   -   1   3   -   -   -   3   3   -
-----+----------------------------------------------------------------
6x   | RTS ADC --- --- --- ADC ROR --- PLA ADC ROR --- JMP ADC ROR ---
     |  1   2   -   -   -   2   2   -   1   2   1   -   3   3   3   -
-----+----------------------------------------------------------------
7x   | BVS ADC --- --- --- ADC ROR --- SEI ADC --- --- --- ADC ROR ---
     |  2   2   -   -   -   2   2   -   1   3   -   -   -   3   3   -
-----+----------------------------------------------------------------
8x   | --- STA --- --- STY STA STX --- DEY --- TXA --- STY STA STX ---
     |  -   2   -   -   2   2   2   -   1   -   1   -   3   3   3   -
-----+----------------------------------------------------------------
9x   | BCC STA --- --- STY STA STX --- TYA STA TXS --- --- STA --- ---
     |  2   2   -   -   2   2   2   -   1   3   1   -   -   3   -   -
-----+----------------------------------------------------------------
Ax   | LDY LDA LDX --- LDY LDA LDX --- TAY LDA TAX --- LDY LDA LDX ---
     |  2   2   2   -   2   2   2   -   1   2   1   -   3   3   3   -
-----+----------------------------------------------------------------
Bx   | BCS LDA --- --- LDY LDA LDX --- CLV LDA TSX --- LDY LDA LDX ---
     |  2   2   -   -   2   2   2   -   1   3   1   -   3   3   3   -
-----+----------------------------------------------------------------
Cx   | CPY CMP --- --- CPY CMP DEC --- INY CMP DEX --- CPY CMP DEC ---
     |  2   2   -   -   2   2   2   -   1   2   1   -   3   3   3   -
-----+----------------------------------------------------------------
Dx   | BNE CMP --- --- --- CMP DEC --- CLD CMP --- --- --- CMP DEC ---
     |  2   2   -   -   -   2   2   -   1   3   -   -   -   3   3   -
-----+----------------------------------------------------------------
Ex   | CPX SBC --- --- CPX SBC INC --- INX SBC NOP --- CPX SBC INC ---
     |  2   2   -   -   2   2   2   -   1   2   1   -   3   3   3   -
-----+----------------------------------------------------------------
Fx   | BEQ SBC --- --- --- SBC INC --- SED SBC --- --- --- SBC INC ---
     |  2   2   -   -   -   2   2   -   1   3   -   -   -   3   3   -
```

Legend: `-` = illegal opcode, number = instruction length in bytes

## Addressing Mode Patterns

The 6502 opcode structure follows a pattern based on bits:

```
Opcode: aaabbbcc

cc = instruction group
bbb = addressing mode
aaa = operation
```

### Group cc=01 (ORA, AND, EOR, ADC, STA, LDA, CMP, SBC)

| bbb | Mode          | Length | Example      |
|-----|---------------|--------|--------------|
| 000 | (indirect,X)  | 2      | ORA ($44,X)  |
| 001 | zero page     | 2      | ORA $44      |
| 010 | immediate     | 2      | ORA #$44     |
| 011 | absolute      | 3      | ORA $4400    |
| 100 | (indirect),Y  | 2      | ORA ($44),Y  |
| 101 | zero page,X   | 2      | ORA $44,X    |
| 110 | absolute,Y    | 3      | ORA $4400,Y  |
| 111 | absolute,X    | 3      | ORA $4400,X  |

### Group cc=10 (ASL, ROL, LSR, ROR, STX, LDX, DEC, INC)

| bbb | Mode          | Length | Example      |
|-----|---------------|--------|--------------|
| 000 | immediate     | 2      | LDX #$44     |
| 001 | zero page     | 2      | ASL $44      |
| 010 | accumulator   | 1      | ASL A        |
| 011 | absolute      | 3      | ASL $4400    |
| 101 | zero page,X/Y | 2      | ASL $44,X    |
| 111 | absolute,X/Y  | 3      | ASL $4400,X  |

### Group cc=00 (BIT, JMP, STY, LDY, CPY, CPX + branches)

| bbb | Mode          | Length | Example      |
|-----|---------------|--------|--------------|
| 000 | immediate     | 2      | LDY #$44     |
| 001 | zero page     | 2      | BIT $44      |
| 011 | absolute      | 3      | JMP $4400    |
| 101 | zero page,X   | 2      | LDY $44,X    |
| 111 | absolute,X    | 3      | LDY $4400,X  |

## Key Observations

### 1. Length by Low Nibble Pattern

Looking at the low nibble (x & 0x0F):

| Low nibble | Typical length |
|------------|----------------|
| 0x00       | 1-2 (varies)   |
| 0x01       | 2 (indirect,X) |
| 0x02       | ILLEGAL        |
| 0x03       | ILLEGAL        |
| 0x04       | 2 (zero page)  |
| 0x05       | 2 (zero page)  |
| 0x06       | 2 (zero page)  |
| 0x07       | ILLEGAL        |
| 0x08       | 1 (implied)    |
| 0x09       | 2-3 (imm/abs,Y)|
| 0x0A       | 1 (accumulator)|
| 0x0B       | ILLEGAL        |
| 0x0C       | 3 (absolute)   |
| 0x0D       | 3 (absolute)   |
| 0x0E       | 3 (absolute)   |
| 0x0F       | ILLEGAL        |

### 2. Illegal Opcodes (all marked with `-`)

```
$02, $03, $04*, $07, $0B, $0C*, $0F,
$12, $13, $14, $17, $1A, $1B, $1C, $1F,
$22, $23, $27, $2B, $2F,
$32, $33, $34, $37, $3A, $3B, $3C, $3F,
$42, $43, $44*, $47, $4B, $4F,
$52, $53, $54, $57, $5A, $5B, $5C, $5F,
$62, $63, $64*, $67, $6B, $6F,
$72, $73, $74, $77, $7A, $7B, $7C, $7F,
$82, $83, $87, $8B, $8F,
$92, $93, $97, $9B, $9C, $9E, $9F,
$A3, $A7, $AB, $AF,
$B2, $B3, $B7, $BB, $BF,
$C2, $C3, $C7, $CB, $CF,
$D2, $D3, $D4, $D7, $DA, $DB, $DC, $DF,
$E2, $E3, $E7, $EB, $EF,
$F2, $F3, $F4, $F7, $FA, $FB, $FC, $FF
```

*Note: $04, $0C, $44, $64 are NOP with operands on some CPUs

### 3. Simple Length Rules (NOT 100% accurate but close)

```
If (opcode & 0x0F) == 0x08: length = 1  (implied: PHP, PHA, DEY, etc.)
If (opcode & 0x0F) == 0x0A: length = 1  (accumulator: ASL A, etc.)
If (opcode & 0x1F) == 0x10: length = 2  (branches: BPL, BMI, etc.)
If (opcode & 0x0F) == 0x0C/0D/0E: length = 3  (absolute addressing)
If opcode == 0x00: length = 2  (BRK)
If opcode == 0x20: length = 3  (JSR)
If opcode == 0x40: length = 1  (RTI)
If opcode == 0x4C: length = 3  (JMP abs)
If opcode == 0x60: length = 1  (RTS)
If opcode == 0x6C: length = 3  (JMP ind)
```

### 4. The cc=01 Group is Very Regular

For opcodes where (opcode & 0x03) == 0x01:
- If (opcode & 0x1C) == 0x08: length = 2 (immediate)
- If (opcode & 0x1C) == 0x0C: length = 3 (absolute)
- If (opcode & 0x1C) == 0x18: length = 3 (absolute,Y)
- If (opcode & 0x1C) == 0x1C: length = 3 (absolute,X)
- Otherwise: length = 2

## Compact Length Table (64 bytes instead of 256)

Since many opcodes share the same length pattern, we could use a lookup:

```
length = base_length[opcode >> 2] + adjustment[opcode & 0x03]
```

But this doesn't fully work due to irregularities.

## Conclusion

**There is NO simple formula** that works for all opcodes. The closest approach:

1. **Full 256-byte table** - simplest, most reliable
2. **Compact encoding** - possible but complex (maybe 64-96 bytes)
3. **Runtime calculation** - complex branching, slow

For reliable instruction boundary tracking, a lookup table is the cleanest solution.
