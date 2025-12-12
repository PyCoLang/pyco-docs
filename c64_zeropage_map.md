# C64 Zero Page Memory Map for PyCo

This document describes the C64 Zero Page ($00-$FF) usage by BASIC, KERNAL, and PyCo compiler.

## Overview

The Zero Page is the most valuable memory area on the 6502 CPU due to:
- Single-byte addressing (faster, smaller code)
- Special addressing modes (indirect indexed)

However, both BASIC and KERNAL use most of the Zero Page, leaving very few addresses completely safe for user programs.

## Safe Addresses (Guaranteed Free)

| Address | Size | Notes                                    |
|---------|------|------------------------------------------|
| $02     | 1    | Completely unused by BASIC/KERNAL        |
| $FB-$FE | 4    | RS-232 work area, safe if RS-232 unused  |

## BASIC Zero Page Usage ($00-$8F)

| Address   | Name     | Purpose                                          |
|-----------|----------|--------------------------------------------------|
| $00-$01   | D6510    | CPU I/O port (hardware, not RAM)                 |
| $02       | -        | **UNUSED - SAFE**                                |
| $03-$04   | ADRAY1   | Float-to-int conversion vector                   |
| $05-$06   | ADRAY2   | Int-to-float conversion vector                   |
| $07       | CHARAC   | Search character for BASIC text                  |
| $08       | ENDCHR   | Statement termination search character           |
| $09       | TRMPOS   | TAB/SPC cursor column position                   |
| $0A       | VERCK    | LOAD/VERIFY flag (0=LOAD, 1=VERIFY)              |
| $0B       | COUNT    | Input buffer index / array dimension counter     |
| $0C       | DIMFLG   | Array operation flags                            |
| $0D       | VALTYP   | Data type flag ($FF=string, $00=numeric)         |
| $0E       | INTFLG   | Numeric type ($80=integer, $00=float)            |
| $0F       | GARBFL   | Garbage collection / LIST quote flag             |
| $10       | SUBFLG   | Array subscript / user function flag             |
| $11       | INPFLG   | GET/READ/INPUT source flag                       |
| $12       | TANSGN   | TAN/SIN sign or comparison result                |
| $13       | CHANNL   | Current I/O channel number                       |
| $14-$15   | LINNUM   | **Integer line number value** (LIST uses this!)  |
| $16       | TEMPPT   | Temporary string descriptor stack pointer        |
| $17-$21   | TEMPST   | Temporary string descriptor stack (9 bytes)      |
| $22-$25   | INDEX    | Utility pointers                                 |
| $26-$2A   | RESHO    | Floating point product result                    |
| $2B-$2C   | TXTTAB   | Pointer to start of BASIC text                   |
| $2D-$2E   | VARTAB   | Pointer to start of BASIC variables              |
| $2F-$30   | ARYTAB   | Pointer to start of BASIC arrays                 |
| $31-$32   | STREND   | Pointer to end of BASIC arrays                   |
| $33-$34   | FRETOP   | Pointer to bottom of string storage              |
| $35-$36   | FRESPC   | Utility string pointer                           |
| $37-$38   | MEMSIZ   | Pointer to highest BASIC RAM location            |
| $39-$3A   | CURLIN   | Current BASIC line number                        |
| $3B-$3C   | OLDLIN   | Previous BASIC line number (CONT)                |
| $3D-$3E   | OLDTXT   | Pointer to previous BASIC statement              |
| $3F-$40   | DATLIN   | Current DATA line number                         |
| $41-$42   | DATPTR   | Pointer to current DATA item                     |
| $43-$44   | INPPTR   | Pointer to INPUT source                          |
| $45-$46   | VARNAM   | Current variable name                            |
| $47-$48   | VARPNT   | Pointer to current variable                      |
| $49-$4A   | FORPNT   | Pointer to FOR/NEXT variable                     |
| $4B-$60   | -        | Temporary work area                              |
| $61-$66   | FAC      | Floating Point Accumulator                       |
| $67-$68   | FACSGN   | FAC overflow / sign extension                    |
| $69-$6E   | ARG      | Floating Point Argument                          |
| $6F-$70   | ARGSGN   | ARG sign                                         |
| $71-$8F   | -        | BASIC work area                                  |

## KERNAL Zero Page Usage ($90-$FF)

| Address   | Name     | Purpose                                          |
|-----------|----------|--------------------------------------------------|
| $90       | STATUS   | I/O status word                                  |
| $91       | STKEY    | STOP key flag                                    |
| $92       | SVXT     | Tape timing constant                             |
| $93       | VERCK2   | LOAD/VERIFY flag                                 |
| $94       | C3PO     | Serial bus output cache flag                     |
| $95       | BSOUR    | Serial bus output cache character                |
| $96       | SYESSION | Tape block sync                                  |
| $97       | XSESSION | Tape block count                                 |
| $98       | LDTND    | Number of open files                             |
| $99       | DTEFLN   | Input device number                              |
| $9A       | DTEFHI   | Output device number                             |
| $9B       | PTESSION | Tape parity                                      |
| $9C       | TIESSION | Tape timing flag                                 |
| $9D       | MSGFLG   | KERNAL message control flag                      |
| $9E       | TESSION1 | Tape pass/error                                  |
| $9F       | TESSION2 | Tape pass/error                                  |
| $A0-$A2   | TIME     | Software jiffy clock (3 bytes)                   |
| $A3-$B1   | -        | Serial/tape work area                            |
| $B2-$B3   | TAPE1    | Tape buffer pointer                              |
| $B4-$B6   | -        | Tape work area                                   |
| $B7       | FNLEN    | Filename length                                  |
| $B8       | LA       | Logical file number                              |
| $B9       | SA       | Secondary address                                |
| $BA       | FA       | Device number                                    |
| $BB-$BC   | FNADR    | Pointer to filename                              |
| $BD       | ROESSION | Tape read pass flag                              |
| $BE       | STALESSION| Tape block status                               |
| $BF       | MEMUSS   | Tape load start address                          |
| $C0       | LDTB1    | Screen line link table (high bytes)              |
| $C1-$C2   | TESSION3 | I/O start address                                |
| $C3-$C4   | TESSION4 | I/O end address                                  |
| $C5       | RIESSION | Tape timing constant                             |
| $C6       | NDX      | Number of characters in keyboard buffer          |
| $C7       | RVS      | Reverse video flag                               |
| $C8       | INDX     | Input cursor log (row)                           |
| $C9       | LSTX     | Previous key pressed                             |
| $CA       | SESSION  | Input cursor log (column)                        |
| $CB       | SHFLAG   | Shift key flag                                   |
| $CC       | BLESSION | Cursor blink enable                              |
| $CD       | BLESSION | Cursor blink counter                             |
| $CE       | GDESSION | Character under cursor                           |
| $CF       | BLESSION | Cursor blink status                              |
| $D0       | GESSION  | Input from screen/keyboard flag                  |
| $D1-$D2   | PNT      | Pointer to current screen line                   |
| $D3       | PNTR     | Cursor column                                    |
| $D4       | QUESSION | Quote mode flag                                  |
| $D5       | LNMX     | Maximum screen line length                       |
| $D6       | TBLX     | Cursor row                                       |
| $D7       | DATAX    | Last character printed                           |
| $D8       | INSRT    | Insert mode count                                |
| $D9-$F2   | LDTB1    | Screen line link table                           |
| $F3-$F4   | USER     | Color RAM pointer                                |
| $F5-$F6   | KEYTAB   | Keyboard decode table pointer                    |
| $F7-$FA   | RIBESSION| RS-232 work area - **SAFE IF RS-232 UNUSED**     |
| $FB-$FE   | -        | **FREE FOR USER PROGRAMS**                       |
| $FF       | BESSION  | BASIC temp                                       |

## KERNAL Functions and Their ZP Usage

### CHROUT ($FFD2) - Character Output

When outputting to SCREEN (device 3), CHROUT uses:
- $9A: Reads output device number
- $D0-$D7: Cursor and screen editor variables (read/write)
- $D8: Insert count
- $D9+: Line pointer table
- $F3-$F4: Color RAM pointer

**Does NOT modify**: $02-$0F directly, but calls to screen editor may affect screen-related ZP.

### GETIN ($FFE4) - Get Character from Keyboard

Uses:
- $C6: Keyboard buffer count
- $0277-$0280: Keyboard buffer (not ZP)

### LOAD ($FFD5) / SAVE ($FFD8)

Uses extensively:
- $90: Status
- $93: LOAD/VERIFY
- $B7-$BC: File parameters
- $C1-$C4: I/O addresses

## PyCo Zero Page Strategy

### Option 1: Minimal Conflict (Current)

Use $02-$17 for compiler, accept that:
- BASIC may behave unexpectedly after program exit
- Must clean up critical locations before RTS to BASIC

### Option 2: BASIC-Safe (Recommended)

Use only truly safe addresses:
- $02: One temp register
- $FB-$FE: Four bytes (FP and SSP)
- $57-$70: FAC/ARG area (BASIC expects these to be volatile)

### Option 3: Clean Exit

Before returning to BASIC, zero out:
- $13 (CHANNL) = 0
- $14-$15 (LINNUM) = 0
- Any other modified BASIC work area

## Current PyCo Allocation

| Address   | PyCo Name | Conflict                                        |
|-----------|-----------|------------------------------------------------|
| $02-$07   | tmp0-tmp5 | $03-$06 = ADRAY (vectors, rarely modified)     |
| $08-$09   | FP        | $08-$09 = ENDCHR/TRMPOS (BASIC uses)           |
| $0A-$0B   | SSP       | $0A-$0B = VERCK/COUNT (BASIC uses)             |
| $0C-$0E   | spbuf     | $0C-$0E = DIMFLG/VALTYP/INTFLG                 |
| $0F-$12   | retval    | $0F-$12 = GARBFL/SUBFLG/INPFLG/TANSGN          |
| $13-$15   | tmp6-tmp8 | **$13=CHANNL, $14-$15=LINNUM** ← LIST problem! |
| $16-$17   | ZP_SELF   | $16-$17 = TEMPPT/LASTPT                        |

## Recommended Fix

Add cleanup code before returning to BASIC:

```asm
// Before final RTS in main()
lda #0
sta $13    // CHANNL
sta $14    // LINNUM low
sta $15    // LINNUM high
sta $16    // TEMPPT
```

This ensures BASIC state is consistent after PyCo program exits.

## References

- [C64-Wiki: Zeropage](https://www.c64-wiki.com/wiki/Zeropage)
- [Mapping the C64](http://unusedino.de/ec64/technical/project64/mapping_c64.html)
- [Ultimate C64 Reference](https://www.pagetable.com/c64ref/c64mem/)
- C64 KERNAL/BASIC ROM Disassembly
