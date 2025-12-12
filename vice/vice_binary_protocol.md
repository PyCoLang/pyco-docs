# VICE Binary Monitor Protocol

A VICE 3.5+ verziótól elérhető bináris monitor protokoll specifikációja. Ez a protokoll biztosítja az IDE-k számára a debugger integrációt.

## Kapcsolódás

### Parancssori opciók

```bash
# Bináris monitor engedélyezése (alapértelmezett port: 6502)
x64sc -binarymonitor

# Egyedi port megadása
x64sc -binarymonitor -binarymonitoraddress 127.0.0.1:6502

# Text monitor is (opcionális, debug célra hasznos)
x64sc -remotemonitor -remotemonitoraddress 127.0.0.1:6510
```

### TCP kapcsolat

- **Protokoll**: TCP/IP
- **Alapértelmezett port**: 6502 (bináris), 6510 (text)
- **Byte sorrend**: Little-endian minden többbájtos értékhez

## Üzenet formátum

### Parancs (Request) struktúra

```
Offset  Méret  Leírás
──────────────────────────────────────────────────────────
0       1      STX marker (0x02)
1       1      API verzió (jelenleg: 0x02)
2-5     4      Body hossza (UInt32LE, header és command byte nélkül)
6-9     4      Request ID (UInt32LE)
10      1      Command típus
11+     N      Command body
```

### Válasz (Response) struktúra

```
Offset  Méret  Leírás
──────────────────────────────────────────────────────────
0       1      STX marker (0x02)
1       1      API verzió (jelenleg: 0x02)
2-5     4      Body hossza (UInt32LE)
6       1      Response típus
7       1      Hibakód (0x00 = OK)
8-11    4      Request ID (0xFFFFFFFF = event)
12+     N      Response body
```

## Hibakódok

| Kód    | Jelentés                       |
|--------|--------------------------------|
| 0x00   | OK - sikeres                   |
| 0x01   | Object nem létezik             |
| 0x02   | Érvénytelen memspace           |
| 0x80   | Hibás hossz                    |
| 0x81   | Érvénytelen paraméter          |
| 0x82   | Nem támogatott API verzió      |
| 0x83   | Ismeretlen parancs             |
| 0x8F   | Általános hiba                 |

## Parancs típusok

### Memória műveletek

| Kód    | Parancs            | Leírás                              |
|--------|--------------------|-------------------------------------|
| 0x01   | Memory Get         | Memória tartalom olvasása           |
| 0x02   | Memory Set         | Memória tartalom írása              |

#### Memory Get (0x01) Request

```
Offset  Méret  Leírás
──────────────────────────────────────────────────────────
0       1      Side effects (0x00=nincs, 0x01=van)
1-2     2      Kezdő cím (UInt16LE)
3-4     2      Záró cím (UInt16LE, inclusive)
5       1      Memspace (0x00=main, 0x01-0x04=drive 8-11)
6-7     2      Bank ID (UInt16LE)
```

#### Memory Get Response

```
Offset  Méret  Leírás
──────────────────────────────────────────────────────────
0-1     2      Hossz (UInt16LE)
2+      N      Memória adat
```

### Checkpoint (breakpoint/watchpoint) műveletek

| Kód    | Parancs              | Leírás                            |
|--------|----------------------|-----------------------------------|
| 0x11   | Checkpoint Get       | Checkpoint lekérdezése ID alapján |
| 0x12   | Checkpoint Set       | Új checkpoint létrehozása         |
| 0x13   | Checkpoint Delete    | Checkpoint törlése                |
| 0x14   | Checkpoint List      | Összes checkpoint listázása       |
| 0x15   | Checkpoint Toggle    | Checkpoint engedélyezése/tiltása  |
| 0x22   | Condition Set        | Feltétel hozzáadása               |

#### Checkpoint Set (0x12) Request

```
Offset  Méret  Leírás
──────────────────────────────────────────────────────────
0-1     2      Kezdő cím (UInt16LE)
2-3     2      Záró cím (UInt16LE)
4       1      Stop on hit (0x00=nem, 0x01=igen)
5       1      Engedélyezve (0x00=nem, 0x01=igen)
6       1      CPU művelet (lásd alább)
7       1      Temporary (0x00=nem, 0x01=igen)
8       1      Memspace (opcionális)
```

**CPU műveletek (bitmask):**

| Bit    | Érték  | Művelet                         |
|--------|--------|---------------------------------|
| 0      | 0x01   | Load - memória olvasás          |
| 1      | 0x02   | Store - memória írás            |
| 2      | 0x04   | Exec - végrehajtás (breakpoint) |

#### Checkpoint Info Response (0x11)

```
Offset  Méret  Leírás
──────────────────────────────────────────────────────────
0-3     4      Checkpoint ID (UInt32LE)
4       1      Currently hit (0x00=nem, 0x01=igen)
5-6     2      Kezdő cím
7-8     2      Záró cím
9       1      Stop on hit
10      1      Enabled
11      1      CPU operation
12      1      Temporary
13-16   4      Hit count (UInt32LE)
17-20   4      Ignore count (UInt32LE)
21      1      Has condition
22      1      Memspace
```

### Regiszter műveletek

| Kód    | Parancs              | Leírás                          |
|--------|----------------------|---------------------------------|
| 0x31   | Registers Get        | CPU regiszterek lekérdezése     |
| 0x32   | Registers Set        | CPU regiszterek módosítása      |
| 0x83   | Registers Available  | Elérhető regiszterek listája    |

#### Register Item formátum

```
Offset  Méret  Leírás
──────────────────────────────────────────────────────────
0       1      Item méret (ez a byte nélkül)
1       1      Register ID
2-3     2      Érték (UInt16LE)
```

### Végrehajtás vezérlés

| Kód    | Parancs                | Leírás                           |
|--------|------------------------|----------------------------------|
| 0x71   | Advance Instructions   | N utasítás léptetése             |
| 0x73   | Execute Until Return   | Futás RTS/RTI-ig                 |
| 0xAA   | Exit                   | Folytatás (resume)               |
| 0xBB   | Quit                   | VICE bezárása                    |
| 0xCC   | Reset                  | Rendszer reset                   |
| 0xDD   | Autostart              | Program betöltése és indítása    |

#### Advance Instructions (0x71) Request

```
Offset  Méret  Leírás
──────────────────────────────────────────────────────────
0       1      Step over subroutines (0x00=nem, 0x01=igen)
1-2     2      Lépések száma (UInt16LE)
```

#### Reset (0xCC) Request

```
Offset  Méret  Leírás
──────────────────────────────────────────────────────────
0       1      Reset mód:
               0x00 = soft reset
               0x01 = hard reset
               0x08-0x0B = drive 8-11 reset
```

### Egyéb parancsok

| Kód    | Parancs           | Leírás                              |
|--------|-------------------|-------------------------------------|
| 0x41   | Dump              | Snapshot mentése                    |
| 0x42   | Undump            | Snapshot betöltése                  |
| 0x51   | Resource Get      | Emulator beállítás lekérdezése      |
| 0x52   | Resource Set      | Emulator beállítás módosítása       |
| 0x72   | Keyboard Feed     | PETSCII szöveg billentyűzetbe       |
| 0x81   | Ping              | Keepalive                           |
| 0x82   | Banks Available   | Memória bankok listája              |
| 0x84   | Display Get       | Képernyő tartalom lekérdezése       |
| 0x85   | Emulator Info     | VICE verzió információ              |
| 0x91   | Palette Get       | Paletta lekérdezése                 |
| 0xA2   | Joyport Set       | Joystick szimuláció                 |

## Event típusok (aszinkron válaszok)

Ezek a válaszok bármikor érkezhetnek, request ID = 0xFFFFFFFF.

| Kód    | Event       | Leírás                                |
|--------|-------------|---------------------------------------|
| 0x61   | JAM         | CPU JAM állapot                       |
| 0x62   | Stopped     | Breakpoint elérve vagy step kész      |
| 0x63   | Resumed     | Végrehajtás folytatódott              |

## Példa: Breakpoint workflow

```
1. Kliens → VICE: Checkpoint Set (exec, enabled, $0820-$0820)
2. VICE → Kliens: Checkpoint Info (id=1, enabled=true)
3. Kliens → VICE: Exit (resume execution)
4. VICE → Kliens: Resumed event
... program fut ...
5. VICE → Kliens: Stopped event (PC=$0820)
6. VICE → Kliens: Checkpoint Info (id=1, hit=true)
7. Kliens → VICE: Registers Get
8. VICE → Kliens: Register Info (PC=$0820, A=$00, X=$01...)
9. Kliens → VICE: Advance Instructions (1, step_over=false)
10. VICE → Kliens: Stopped event
```

## TypeScript implementáció referencia

Lásd: [vscode-cc65-vice-debug](https://github.com/empathicqubit/vscode-cc65-vice-debug)
- `src/dbg/binary-dto.ts` - Típus definíciók
- `src/dbg/abstract-grip.ts` - Protokoll implementáció
- `src/dbg/vice-grip.ts` - VICE specifikus logika

## Források

- [VICE Manual - Binary Monitor](https://vice-emu.sourceforge.io/vice_13.html)
- [VS64 Extension](https://github.com/rolandshacks/vs64)
- [IceBro Lite](https://github.com/Sakrac/IceBroLite)
