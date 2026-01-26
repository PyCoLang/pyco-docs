# C64 Library Reference

This document describes the built-in include files and library modules available for C64 development with PyCo.

**Version:** 1.0
**Last Updated:** 2026-01-26

---

## Table of Contents

1. [Include Files Overview](#include-files-overview)
2. [Hardware Include Files](#hardware-include-files)
   - [c64 - Complete Hardware](#c64---complete-hardware)
   - [vic - VIC-II Video Controller](#vic---vic-ii-video-controller)
   - [sid - SID Sound Chip](#sid---sid-sound-chip)
   - [cia - CIA Timer Chips](#cia---cia-timer-chips)
   - [col - Color Palette](#col---color-palette)
   - [mem - Memory Map](#mem---memory-map)
   - [key - Keyboard & Joystick](#key---keyboard--joystick)
   - [pet - PETSCII Codes](#pet---petscii-codes)
   - [krn - Kernal Functions](#krn---kernal-functions)
   - [zp - Zero Page Locations](#zp---zero-page-locations)
   - [vec - Interrupt Vectors](#vec---interrupt-vectors)
3. [Meta-Include Files](#meta-include-files)
4. [Library Modules](#library-modules)
   - [compress - Data Compression](#compress---data-compression)
   - [diskio - Disk I/O](#diskio---disk-io)

---

## Include Files Overview

Include files are `.pyco` source files that get inserted into your program by the preprocessor. They can contain:

- **UPPERCASE constants** - Symbolic names for hardware addresses (e.g., `BORDER = 0xD020`)
- **Global tuples** - Lookup tables stored in the data segment (e.g., `scrrowoff` in `mem.pyco`)
- **Functions** - Helper functions with `@mapped` decorators or inline assembly (e.g., `chrout()` in `krn.pyco`)

**Usage:**
```python
include("vic")    # Include VIC-II definitions
include("c64")    # Include ALL C64 hardware definitions
```

**How it works:** The preprocessor inserts the include file's content into your source. The compiler then applies Dead Code Elimination (DCE) - only the constants, tuples, and functions you actually use end up in the final binary.

---

## Hardware Include Files

### c64 - Complete Hardware

**File:** `c64.pyco`

A meta-include that imports all other hardware files. Use this for convenience when you need access to all C64 hardware.

```python
include("c64")  # Includes: vic, sid, cia, col, mem, key, krn, vec, zp, pet
```

---

### vic - VIC-II Video Controller

**File:** `vic.pyco`

Constants for the VIC-II video chip ($D000-$D02E).

#### Sprite Positions

| Constant | Address | Description                          |
|----------|---------|--------------------------------------|
| `SP0X`   | $D000   | Sprite 0 X position (low byte)       |
| `SP0Y`   | $D001   | Sprite 0 Y position                  |
| `SP1X`   | $D002   | Sprite 1 X position (low byte)       |
| `SP1Y`   | $D003   | Sprite 1 Y position                  |
| ...      | ...     | (continues for sprites 2-7)          |
| `SP7X`   | $D00E   | Sprite 7 X position (low byte)       |
| `SP7Y`   | $D00F   | Sprite 7 Y position                  |
| `MSIGX`  | $D010   | Sprite X MSB (bit 8 for all sprites) |

#### Display Control

| Constant | Address | Description                    |
|----------|---------|--------------------------------|
| `CTRL1`  | $D011   | Control register 1             |
| `RASTER` | $D012   | Raster line                    |
| `LPX`    | $D013   | Light pen X                    |
| `LPY`    | $D014   | Light pen Y                    |
| `SPENA`  | $D015   | Sprite enable                  |
| `CTRL2`  | $D016   | Control register 2             |
| `YXPAND` | $D017   | Sprite Y expand                |
| `VMCSB`  | $D018   | Memory pointers                |
| `VICIRQ` | $D019   | IRQ status                     |
| `IRQMSK` | $D01A   | IRQ enable mask                |
| `SPPRI`  | $D01B   | Sprite priority                |
| `SPMC`   | $D01C   | Sprite multicolor enable       |
| `XXPAND` | $D01D   | Sprite X expand                |
| `SPSPCL` | $D01E   | Sprite-sprite collision        |
| `SPBGCL` | $D01F   | Sprite-background collision    |

#### Colors

| Constant | Address | Description          |
|----------|---------|----------------------|
| `BORDER` | $D020   | Border color         |
| `BGCOL0` | $D021   | Background 0         |
| `BGCOL1` | $D022   | Background 1         |
| `BGCOL2` | $D023   | Background 2         |
| `BGCOL3` | $D024   | Background 3         |
| `SPMC0`  | $D025   | Sprite multicolor 0  |
| `SPMC1`  | $D026   | Sprite multicolor 1  |
| `SP0COL` | $D027   | Sprite 0 color       |
| ...      | ...     | (continues 1-7)      |
| `SP7COL` | $D02E   | Sprite 7 color       |

#### CTRL1 Bit Flags

| Constant | Value | Description        |
|----------|-------|--------------------|
| `RSEL`   | $08   | 25/24 rows         |
| `DEN`    | $10   | Display enable     |
| `BMM`    | $20   | Bitmap mode        |
| `ECM`    | $40   | Extended color     |
| `RST8`   | $80   | Raster bit 8       |

#### CTRL2 Bit Flags

| Constant | Value | Description    |
|----------|-------|----------------|
| `CSEL`   | $08   | 40/38 columns  |
| `MCM`    | $10   | Multicolor     |
| `RES`    | $20   | Reset bit      |

#### IRQ Flags

| Constant | Value | Description                  |
|----------|-------|------------------------------|
| `IRQRST` | $01   | Raster IRQ                   |
| `IRQMBC` | $02   | Sprite-background collision  |
| `IRQMMC` | $04   | Sprite-sprite collision      |
| `IRQLP`  | $08   | Light pen                    |

**Example:**
```python
include("vic")

def main():
    border: byte[BORDER]
    ctrl1: byte[CTRL1]

    border = 0                    # Black border
    ctrl1 = ctrl1 | DEN | BMM     # Enable display + bitmap mode
```

---

### sid - SID Sound Chip

**File:** `sid.pyco`

Constants for the SID sound chip ($D400-$D41C).

#### Voice Registers

Each voice (1-3) has these registers:

| Voice 1   | Voice 2   | Voice 3   | Description       |
|-----------|-----------|-----------|-------------------|
| `V1FREQL` | `V2FREQL` | `V3FREQL` | Frequency low     |
| `V1FREQH` | `V2FREQH` | `V3FREQH` | Frequency high    |
| `V1PWL`   | `V2PWL`   | `V3PWL`   | Pulse width low   |
| `V1PWH`   | `V2PWH`   | `V3PWH`   | Pulse width high  |
| `V1CTRL`  | `V2CTRL`  | `V3CTRL`  | Control register  |
| `V1AD`    | `V2AD`    | `V3AD`    | Attack/Decay      |
| `V1SR`    | `V2SR`    | `V3SR`    | Sustain/Release   |

#### Filter & Volume

| Constant | Address | Description         |
|----------|---------|---------------------|
| `FCUTL`  | $D415   | Filter cutoff low   |
| `FCUTH`  | $D416   | Filter cutoff high  |
| `RESON`  | $D417   | Resonance & filter  |
| `SIGVOL` | $D418   | Filter mode/volume  |

#### Read-Only

| Constant | Address | Description          |
|----------|---------|----------------------|
| `POTX`   | $D419   | Paddle X             |
| `POTY`   | $D41A   | Paddle Y             |
| `OSC3`   | $D41B   | Oscillator 3 output  |
| `ENV3`   | $D41C   | Envelope 3 output    |

#### Waveform Bits

| Constant | Value | Description       |
|----------|-------|-------------------|
| `GATE`   | $01   | Gate              |
| `SYNC`   | $02   | Sync              |
| `RING`   | $04   | Ring modulation   |
| `TEST`   | $08   | Test bit          |
| `TRI`    | $10   | Triangle          |
| `SAW`    | $20   | Sawtooth          |
| `PULSE`  | $40   | Pulse             |
| `NOISE`  | $80   | Noise             |

#### Filter Bits

| Constant | Value | Description    |
|----------|-------|----------------|
| `LP`     | $10   | Low-pass       |
| `BP`     | $20   | Band-pass      |
| `HP`     | $40   | High-pass      |
| `V3OFF`  | $80   | Voice 3 off    |

**Example:**
```python
include("sid")

def main():
    freq_lo: byte[V1FREQL]
    freq_hi: byte[V1FREQH]
    ctrl: byte[V1CTRL]
    ad: byte[V1AD]
    sr: byte[V1SR]
    vol: byte[SIGVOL]

    freq_lo = 0x51              # ~440 Hz (A4)
    freq_hi = 0x1C
    ad = 0x09                   # Attack: 2ms, Decay: 6ms
    sr = 0xA5                   # Sustain: 10, Release: 300ms
    vol = 15                    # Max volume
    ctrl = GATE | TRI           # Gate on, triangle wave
```

---

### cia - CIA Timer Chips

**File:** `cia.pyco`

Constants for the two CIA 6526 chips.

#### CIA 1 ($DC00-$DC0F) - Keyboard, Joystick, IRQ

| Constant   | Address | Description          |
|------------|---------|----------------------|
| `CIA1PA`   | $DC00   | Port A (kbd cols)    |
| `CIA1PB`   | $DC01   | Port B (kbd rows)    |
| `CIA1DDA`  | $DC02   | Data direction A     |
| `CIA1DDB`  | $DC03   | Data direction B     |
| `CIA1TAL`  | $DC04   | Timer A low          |
| `CIA1TAH`  | $DC05   | Timer A high         |
| `CIA1TBL`  | $DC06   | Timer B low          |
| `CIA1TBH`  | $DC07   | Timer B high         |
| `CIA1T10`  | $DC08   | TOD 1/10 sec         |
| `CIA1SEC`  | $DC09   | TOD seconds          |
| `CIA1MIN`  | $DC0A   | TOD minutes          |
| `CIA1HR`   | $DC0B   | TOD hours            |
| `CIA1SDR`  | $DC0C   | Serial data          |
| `CIA1ICR`  | $DC0D   | Interrupt control    |
| `CIA1CRA`  | $DC0E   | Control register A   |
| `CIA1CRB`  | $DC0F   | Control register B   |

#### CIA 2 ($DD00-$DD0F) - VIC Bank, Serial, NMI

| Constant   | Address | Description          |
|------------|---------|----------------------|
| `CIA2PA`   | $DD00   | Port A (VIC bank)    |
| `CIA2PB`   | $DD01   | Port B (userport)    |
| `CIA2DDA`  | $DD02   | Data direction A     |
| `CIA2DDB`  | $DD03   | Data direction B     |
| `CIA2TAL`  | $DD04   | Timer A low          |
| ...        | ...     | (same pattern as CIA1) |
| `CIA2CRB`  | $DD0F   | Control register B   |

#### ICR Bits

| Constant  | Value | Description         |
|-----------|-------|---------------------|
| `ICRTA`   | $01   | Timer A             |
| `ICRTB`   | $02   | Timer B             |
| `ICRALRM` | $04   | TOD alarm           |
| `ICRSP`   | $08   | Serial port         |
| `ICRFLG`  | $10   | FLAG pin            |
| `ICRSET`  | $80   | Set/clear (write)   |
| `ICRIR`   | $80   | IRQ occurred (read) |

#### VIC Bank Selection

| Constant   | Value | Address Range   |
|------------|-------|-----------------|
| `VICBANK0` | $03   | $0000-$3FFF     |
| `VICBANK1` | $02   | $4000-$7FFF     |
| `VICBANK2` | $01   | $8000-$BFFF     |
| `VICBANK3` | $00   | $C000-$FFFF     |

---

### col - Color Palette

**File:** `col.pyco`

Standard C64 color values (0-15).

| Constant | Value | Color        |
|----------|-------|--------------|
| `BLACK`  | 0     | Black        |
| `WHITE`  | 1     | White        |
| `RED`    | 2     | Red          |
| `CYAN`   | 3     | Cyan         |
| `PURPLE` | 4     | Purple       |
| `GREEN`  | 5     | Green        |
| `BLUE`   | 6     | Blue         |
| `YELLOW` | 7     | Yellow       |
| `ORANGE` | 8     | Orange       |
| `BROWN`  | 9     | Brown        |
| `LRED`   | 10    | Light red    |
| `DGRAY`  | 11    | Dark gray    |
| `GRAY`   | 12    | Medium gray  |
| `LGREEN` | 13    | Light green  |
| `LBLUE`  | 14    | Light blue   |
| `LGRAY`  | 15    | Light gray   |

**Example:**
```python
include("vic")
include("col")

def main():
    border: byte[BORDER]
    bgcol: byte[BGCOL0]

    border = BLUE
    bgcol = LBLUE
```

---

### mem - Memory Map

**File:** `mem.pyco`

Memory layout constants and screen row offset table.

#### Screen Memory

| Constant   | Value | Description            |
|------------|-------|------------------------|
| `SCREEN`   | $0400 | Screen RAM (default)   |
| `SCRSIZE`  | 1000  | Screen size (bytes)    |
| `SCRCOLS`  | 40    | Columns                |
| `SCRROWS`  | 25    | Rows                   |
| `SPRPTR`   | $07F8 | Sprite pointers        |
| `COLRAM`   | $D800 | Color RAM (fixed)      |
| `COLSIZE`  | 1000  | Color RAM size         |
| `CHRROM`   | $D000 | Character ROM          |

#### CPU I/O Port

| Constant  | Value | Description      |
|-----------|-------|------------------|
| `CPUDDR`  | $00   | Data direction   |
| `CPUPORT` | $01   | I/O port         |

#### Banking Bits

| Constant | Value | Description    |
|----------|-------|----------------|
| `LORAM`  | $01   | BASIC ROM      |
| `HIRAM`  | $02   | Kernal ROM     |
| `CHAREN` | $04   | Char ROM / I/O |

#### Banking Configurations

| Constant  | Value | Description     |
|-----------|-------|-----------------|
| `ALLRAM`  | $30   | All RAM visible |
| `IOONLY`  | $35   | RAM + I/O       |
| `DEFAULT` | $37   | Default config  |

#### Screen Row Offsets

The file also provides a global tuple for fast row offset calculation:

```python
scrrowoff: tuple[word] = (0, 40, 80, 120, ..., 960)
```

**Example:**
```python
include("mem")

def plot(x: byte, y: byte, ch: byte):
    screen: array[byte, 1000][SCREEN]
    offset: word

    offset = scrrowoff[y]        # Fast lookup: y * 40
    screen[offset + x] = ch
```

---

### key - Keyboard & Joystick

**File:** `key.pyco`

Keyboard and joystick constants.

#### Joystick Bits (Active LOW!)

| Constant  | Value | Description |
|-----------|-------|-------------|
| `JOYUP`   | $01   | Up          |
| `JOYDN`   | $02   | Down        |
| `JOYLF`   | $04   | Left        |
| `JOYRT`   | $08   | Right       |
| `JOYFIRE` | $10   | Fire        |

#### Joystick Ports

| Constant | Address | Description     |
|----------|---------|-----------------|
| `JOY1`   | $DC01   | Joystick port 1 |
| `JOY2`   | $DC00   | Joystick port 2 |

#### Keyboard

| Constant  | Address | Description         |
|-----------|---------|---------------------|
| `KEYBUF`  | $0277   | Keyboard buffer     |
| `KEYCNT`  | $C6     | Keys in buffer      |
| `KEYMAT`  | $C5     | Last matrix code    |
| `SHFLAG`  | $028D   | Shift flags         |
| `RPTFLG`  | $028A   | Key repeat control  |
| `NOKEY`   | 64      | No key pressed      |
| `STOPKEY` | 63      | RUN/STOP code       |

#### PETSCII Key Codes

| Constant  | Value | Key          |
|-----------|-------|--------------|
| `KEYUP`   | 145   | Cursor up    |
| `KEYDN`   | 17    | Cursor down  |
| `KEYLF`   | 157   | Cursor left  |
| `KEYRT`   | 29    | Cursor right |
| `KEYRET`  | 13    | Return       |
| `KEYDEL`  | 20    | Delete       |
| `KEYHOME` | 19    | Home         |
| `KEYCLR`  | 147   | Clear screen |

#### Game Keys (Uppercase/Lowercase)

| Uppercase | Value | Lowercase | Value |
|-----------|-------|-----------|-------|
| `KEYW`    | 87    | `KEYWLO`  | 119   |
| `KEYA`    | 65    | `KEYALO`  | 97    |
| `KEYS`    | 83    | `KEYSLO`  | 115   |
| `KEYD`    | 68    | `KEYDLO`  | 100   |
| `KEYT`    | 84    | `KEYTLO`  | 116   |
| `KEYF`    | 70    | `KEYFLO`  | 102   |
| `KEYN`    | 78    | `KEYNLO`  | 110   |

**Example:**
```python
include("key")

def check_joystick():
    joy: byte[JOY2]

    if (joy & JOYUP) == 0:      # Active LOW!
        move_up()
    if (joy & JOYFIRE) == 0:
        fire()
```

---

### pet - PETSCII Codes

**File:** `pet.pyco`

PETSCII control codes and screen codes.

#### Screen Control

| Constant | Value    | Description  |
|----------|----------|--------------|
| `HOME`   | `"\x13"` | Cursor home  |
| `CLR`    | `"\x93"` | Clear screen |
| `RET`    | `"\x0d"` | Return       |
| `DEL`    | `"\x14"` | Delete       |

#### Cursor Movement

| Constant | Value    | Description  |
|----------|----------|--------------|
| `UP`     | `"\x91"` | Cursor up    |
| `DOWN`   | `"\x11"` | Cursor down  |
| `LEFT`   | `"\x9d"` | Cursor left  |
| `RIGHT`  | `"\x1d"` | Cursor right |

#### Case Mode

| Constant | Value    | Description    |
|----------|----------|----------------|
| `LOWER`  | `"\x0e"` | Lowercase mode |
| `UPPER`  | `"\x8e"` | Uppercase mode |

#### Reverse Mode

| Constant | Value    | Description |
|----------|----------|-------------|
| `RVSON`  | `"\x12"` | Reverse on  |
| `RVSOFF` | `"\x92"` | Reverse off |

#### Color Codes

| Constant   | Value    | Color       |
|------------|----------|-------------|
| `CBLACK`   | `"\x90"` | Black       |
| `CWHITE`   | `"\x05"` | White       |
| `CRED`     | `"\x1c"` | Red         |
| `CCYAN`    | `"\x9f"` | Cyan        |
| `CPURPLE`  | `"\x9c"` | Purple      |
| `CGREEN`   | `"\x1e"` | Green       |
| `CBLUE`    | `"\x1f"` | Blue        |
| `CYELLOW`  | `"\x9e"` | Yellow      |
| `CORANGE`  | `"\x81"` | Orange      |
| `CBROWN`   | `"\x95"` | Brown       |
| `CLRED`    | `"\x96"` | Light red   |
| `CDGRAY`   | `"\x97"` | Dark gray   |
| `CGRAY`    | `"\x98"` | Medium gray |
| `CLGREEN`  | `"\x99"` | Light green |
| `CLBLUE`   | `"\x9a"` | Light blue  |
| `CLGRAY`   | `"\x9b"` | Light gray  |

#### Function Keys (Scan Codes)

| Constant | Value |
|----------|-------|
| `F1`     | 133   |
| `F2`     | 137   |
| `F3`     | 134   |
| `F4`     | 138   |
| `F5`     | 135   |
| `F6`     | 139   |
| `F7`     | 136   |
| `F8`     | 140   |

#### Screen Codes

| Constant  | Value | Description            |
|-----------|-------|------------------------|
| `SCSPACE` | 32    | Space                  |
| `SCBLOCK` | 160   | Solid block (inverse)  |

**Example:**
```python
include("pet")

def main():
    print(CLR)              # Clear screen
    print(CGREEN)           # Green text
    print("HELLO")
    print(CWHITE)           # White text
```

---

### krn - Kernal Functions

**File:** `krn.pyco`

Kernal ROM entry points and type-safe wrapper functions.

> **Note:** Use with `@kernal` decorator on `main()` to keep Kernal ROM enabled.

#### Constants (ROM Entry Points)

| Constant  | Address | Description              |
|-----------|---------|--------------------------|
| `CHROUT`  | $FFD2   | Output character         |
| `CHRIN`   | $FFCF   | Input character          |
| `GETIN`   | $FFE4   | Get from keyboard buffer |
| `PLOT`    | $FFF0   | Cursor position          |
| `SCINIT`  | $FF81   | Initialize screen        |
| `SCNKEY`  | $FF9F   | Scan keyboard            |
| `STOP`    | $FFE1   | Check STOP key           |
| `SETLFS`  | $FFBA   | Set logical file         |
| `SETNAM`  | $FFBD   | Set filename             |
| `OPEN`    | $FFC0   | Open file                |
| `CLOSE`   | $FFC3   | Close file               |
| `CHKIN`   | $FFC6   | Set input channel        |
| `CHKOUT`  | $FFC9   | Set output channel       |
| `CLRCHN`  | $FFCC   | Clear channels           |
| `CLALL`   | $FFE7   | Close all files          |
| `LOAD`    | $FFD5   | Load file                |
| `SAVE`    | $FFD8   | Save file                |
| `READST`  | $FFB7   | Read I/O status          |
| `RESTOR`  | $FF8A   | Restore I/O vectors      |
| `IOINIT`  | $FF84   | Initialize I/O           |
| `RAMTAS`  | $FF87   | Initialize RAM           |
| `UDTIM`   | $FFEA   | Update jiffy clock       |
| `RDTIM`   | $FFDE   | Read jiffy clock         |
| `SETTIM`  | $FFDB   | Set jiffy clock          |

#### Type-Safe Functions

**Screen I/O:**

```python
def chrout(ch: byte)                     # Output character
def chrin() -> byte                      # Read character
def getin() -> byte                      # Get from buffer (0 if empty)
def scinit()                             # Initialize screen
def screen_size(cols: alias[byte], rows: alias[byte])
def plot_set(col: byte, row: byte)       # Set cursor position
def plot_get(col: alias[byte], row: alias[byte])
```

**Keyboard:**

```python
def scnkey()                             # Scan keyboard matrix
def stop() -> byte                       # Check STOP key
```

**File I/O:**

```python
def setlfs(la: byte, fa: byte, sa: byte) # Set logical file
def setnam(len: byte, name_lo: byte, name_hi: byte)
def open()                               # Open file
def close(la: byte)                      # Close file
def chkin(la: byte)                      # Set input channel
def chkout(la: byte)                     # Set output channel
def clrchn()                             # Clear channels
def clall()                              # Close all files
def load(verify: byte, addr_lo: byte, addr_hi: byte) -> word
def save(zp_ptr: byte, end_lo: byte, end_hi: byte) -> byte
def readst() -> byte                     # Read status
```

**Serial Bus (IEC):**

```python
def listen(device: byte)                 # Send LISTEN
def talk(device: byte)                   # Send TALK
def lstnsa(sa: byte)                     # Secondary address after LISTEN
def talksa(sa: byte)                     # Secondary address after TALK
def unlstn()                             # Send UNLISTEN
def untalk()                             # Send UNTALK
def iecin() -> byte                      # Read from serial bus
def iecout(data: byte)                   # Write to serial bus
```

**System:**

```python
def restor()                             # Restore I/O vectors
def ioinit()                             # Initialize I/O
def ramtas()                             # Initialize RAM
def udtim()                              # Update jiffy clock
def settim(hi: byte, mid: byte, lo: byte)
def rdtim(hi: alias[byte], mid: alias[byte], lo: alias[byte])
def setmsg(flag: byte)                   # Control messages
def memtop_get(hi: alias[byte], lo: alias[byte])
def memtop_set(hi: byte, lo: byte)
def membot_get(hi: alias[byte], lo: alias[byte])
def membot_set(hi: byte, lo: byte)
def iobase(hi: alias[byte], lo: alias[byte])
```

**Example:**
```python
include("krn")

@kernal
def main():
    ch: byte

    plot_set(0, 0)           # Home cursor
    chrout(65)               # Print 'A'

    ch = getin()             # Get key (non-blocking)
    if ch != 0:
        chrout(ch)
```

---

### zp - Zero Page Locations

**File:** `zp.pyco`

Zero page addresses safe for user programs.

#### User-Safe Locations

| Constant | Address | Description |
|----------|---------|-------------|
| `USR02`  | $02     | Free        |
| `USRFB`  | $FB     | Free        |
| `USRFC`  | $FC     | Free        |
| `USRFD`  | $FD     | Free        |
| `USRFE`  | $FE     | Free        |

#### Cursor

| Constant | Address | Description            |
|----------|---------|------------------------|
| `CURCOL` | $D3     | Cursor column          |
| `CURROW` | $D6     | Cursor row             |
| `CURLIN` | $D1     | Line pointer (2 bytes) |

#### Keyboard

| Constant | Address | Description     |
|----------|---------|-----------------|
| `LSTKEY` | $C5     | Last key        |
| `NKEYS`  | $C6     | Keys in buffer  |

#### Kernal SAVE

| Constant      | Address | Description        |
|---------------|---------|-------------------|
| `SAVESTART`   | $C1     | Start address low  |
| `SAVESTARTHI` | $C2     | Start address high |

#### Jiffy Clock

| Constant  | Address | Description  |
|-----------|---------|--------------|
| `JIFFYHI` | $A0     | High byte    |
| `JIFFYMI` | $A1     | Middle byte  |
| `JIFFYLO` | $A2     | Low byte     |

---

### vec - Interrupt Vectors

**File:** `vec.pyco`

System interrupt and I/O vectors.

#### RAM Vectors (User Modifiable)

| Constant | Address | Description  |
|----------|---------|--------------|
| `IRQVEC` | $0314   | IRQ handler  |
| `BRKVEC` | $0316   | BRK handler  |
| `NMIVEC` | $0318   | NMI handler  |

#### I/O Vectors

| Constant | Address | Description |
|----------|---------|-------------|
| `OPNVEC` | $031A   | OPEN        |
| `CLSVEC` | $031C   | CLOSE       |
| `CIOVEC` | $031E   | CHKIN       |
| `COOVEC` | $0320   | CHKOUT      |
| `CCOVEC` | $0322   | CLRCHN      |
| `CINVEC` | $0324   | CHRIN       |
| `COUVEC` | $0326   | CHROUT      |
| `STPVEC` | $0328   | STOP        |
| `GETVEC` | $032A   | GETIN       |
| `CLOVEC` | $032C   | CLALL       |
| `LODVEC` | $0330   | LOAD        |
| `SAVVEC` | $0332   | SAVE        |

#### CPU Vectors (ROM, Fixed)

| Constant | Address | Description |
|----------|---------|-------------|
| `CNMI`   | $FFFA   | NMI         |
| `CRESET` | $FFFC   | Reset       |
| `CIRQ`   | $FFFE   | IRQ         |

**Example:**
```python
include("vec")

@irq
def my_irq():
    # Custom IRQ handler
    border: byte[0xD020]
    border = border + 1

def main():
    irq_lo: byte[IRQVEC]
    irq_hi: byte[IRQVEC + 1]

    irq_lo = byte(addr(my_irq) & 0xFF)
    irq_hi = byte(addr(my_irq) / 256)

    while True:
        pass
```

---

## Meta-Include Files

These files combine related hardware includes for convenience.

| File       | Includes                | Use Case              |
|------------|-------------------------|-----------------------|
| `gfx.pyco` | vic, col, mem           | Graphics programming  |
| `snd.pyco` | sid                     | Sound programming     |
| `inp.pyco` | cia, key                | Input handling        |
| `sys.pyco` | krn, vec, zp            | System programming    |

**Example:**
```python
include("gfx")   # Includes VIC, colors, memory map
include("inp")   # Includes CIA, keyboard/joystick
```

---

## Library Modules

Library modules are compiled PyCo code that can be imported into your programs. Unlike include files, modules generate actual code and can be loaded statically (embedded in PRG) or dynamically (loaded at runtime).

### compress - Data Compression

**Source:** `src/pyco/lib/compress.pyco`
**Compiled:** `src/pyco/lib/imports/compress.pm`

Provides RLE (Run-Length Encoding) decompression for compressed data.

#### RLE Format

| Byte Sequence        | Meaning                        |
|---------------------|--------------------------------|
| `0xFF 0xNN 0xVV`    | Repeat VV byte NN times (N>=2) |
| `0xFF 0x00`         | Literal 0xFF byte              |
| Any other byte      | Literal copy                   |

#### Functions

**`rle_decompress_addr(src_addr: word, dest_addr: word, compressed_size: word)`**

Decompress RLE data from raw memory addresses.

| Parameter         | Type | Description                   |
|-------------------|------|-------------------------------|
| `src_addr`        | word | Source address of RLE data    |
| `dest_addr`       | word | Destination for output        |
| `compressed_size` | word | Compressed bytes to read      |

**`rle_decompress(src: tuple[byte], dest: alias[array[byte, 1]])`**

Decompress from tuple to array. Reads size from tuple header automatically.

| Parameter | Type                    | Description             |
|-----------|-------------------------|-------------------------|
| `src`     | `tuple[byte]`           | Source tuple (RLE data) |
| `dest`    | `alias[array[byte, 1]]` | Destination array       |

#### Usage Example (Static Import)

```python
from compress import rle_decompress

# Image data generated by: pycoc image title.koa -C rle -o title.pyco
BITMAP_RLE = (0x00, 0xFF, 0x08, 0x3C, ...)  # Compressed data

def show_title():
    bitmap_rle: tuple[byte] = BITMAP_RLE
    bitmap: array[byte, 8000][0x6000]

    rle_decompress(bitmap_rle, bitmap)
```

#### Usage Example (Dynamic Import)

```python
import compress

def show_title():
    bitmap_rle: tuple[byte] = BITMAP_RLE
    bitmap: array[byte, 8000][0x6000]

    load_module(compress)
    compress.rle_decompress(bitmap_rle, bitmap)
```

---

### diskio - Disk I/O

**Source:** `src/pyco/lib/diskio.pyco`
**Compiled:** `src/pyco/lib/imports/diskio.pm`

High-level disk operations using Kernal routines. Automatically handles ROM banking and interrupt management.

#### Functions

**`load_file(filename: alias[string], address: word) -> word`**

Load file to specific address.

| Parameter  | Type            | Description               |
|------------|-----------------|---------------------------|
| `filename` | `alias[string]` | Pascal string (filename)  |
| `address`  | word            | Target address            |
| **Returns**| word            | Loaded size (0 on error)  |

**`load_file_default(filename: alias[string]) -> word`**

Load file to its built-in header address.

| Parameter  | Type            | Description               |
|------------|-----------------|---------------------------|
| `filename` | `alias[string]` | Pascal string (filename)  |
| **Returns**| word            | End address of data       |

**`save_file(filename: alias[string], start_addr: word, size: word) -> bool`**

Save memory range to file.

| Parameter    | Type            | Description              |
|--------------|-----------------|--------------------------|
| `filename`   | `alias[string]` | Pascal string (filename) |
| `start_addr` | word            | Start of memory range    |
| `size`       | word            | Bytes to save            |
| **Returns**  | bool            | True on success          |

#### Key Features

- Automatically enables/restores Kernal ROM
- Suppresses Kernal messages ("SEARCHING FOR...", etc.)
- Disables interrupts during disk I/O for safety
- Uses Pascal string format (length byte + characters)

#### Usage Example (Static Import)

```python
from diskio import load_file, save_file

def load_level():
    level_data: array[byte, 1000][0xC000]
    size: word

    size = load_file("LEVEL1", 0xC000)
    if size > 0:
        print("Level loaded!")

def save_game():
    save_data: array[byte, 100][0xC800]

    if save_file("SAVEGAME", 0xC800, 100):
        print("Game saved!")
```

#### Usage Example (Dynamic Import)

```python
import diskio

def load_level():
    level_data: array[byte, 1000][0xC000]

    load_module(diskio)
    diskio.load_file("LEVEL1", 0xC000)
```

---

## See Also

- [Module System](module_system_en.md) - How modules work in PyCo
- [C64 Compiler Reference](c64_compiler_reference_en.md) - Compiler internals
- [Language Reference](../../language-reference/language_reference_en.md) - PyCo language syntax
