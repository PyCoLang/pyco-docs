# VICE Binary Monitor Protocol

Specification of the binary monitor protocol available from VICE 3.5+. This protocol provides debugger integration for IDEs.

## Connection

### Command Line Options

```bash
# Enable binary monitor (default port: 6502)
x64sc -binarymonitor

# Specify custom port
x64sc -binarymonitor -binarymonitoraddress 127.0.0.1:6502

# Text monitor as well (optional, useful for debugging)
x64sc -remotemonitor -remotemonitoraddress 127.0.0.1:6510
```

### TCP Connection

- **Protocol**: TCP/IP
- **Default port**: 6502 (binary), 6510 (text)
- **Byte order**: Little-endian for all multi-byte values

## Message Format

### Command (Request) Structure

```
Offset  Size   Description
──────────────────────────────────────────────────────────
0       1      STX marker (0x02)
1       1      API version (currently: 0x02)
2-5     4      Body length (UInt32LE, excluding header and command byte)
6-9     4      Request ID (UInt32LE)
10      1      Command type
11+     N      Command body
```

### Response Structure

```
Offset  Size   Description
──────────────────────────────────────────────────────────
0       1      STX marker (0x02)
1       1      API version (currently: 0x02)
2-5     4      Body length (UInt32LE)
6       1      Response type
7       1      Error code (0x00 = OK)
8-11    4      Request ID (0xFFFFFFFF = event)
12+     N      Response body
```

## Error Codes

| Code   | Meaning                        |
|--------|--------------------------------|
| 0x00   | OK - success                   |
| 0x01   | Object does not exist          |
| 0x02   | Invalid memspace               |
| 0x80   | Invalid length                 |
| 0x81   | Invalid parameter              |
| 0x82   | Unsupported API version        |
| 0x83   | Unknown command                |
| 0x8F   | General error                  |

## Command Types

### Memory Operations

| Code   | Command            | Description                         |
|--------|--------------------|-------------------------------------|
| 0x01   | Memory Get         | Read memory contents                |
| 0x02   | Memory Set         | Write memory contents               |

#### Memory Get (0x01) Request

```
Offset  Size   Description
──────────────────────────────────────────────────────────
0       1      Side effects (0x00=none, 0x01=present)
1-2     2      Start address (UInt16LE)
3-4     2      End address (UInt16LE, inclusive)
5       1      Memspace (0x00=main, 0x01-0x04=drive 8-11)
6-7     2      Bank ID (UInt16LE)
```

#### Memory Get Response

```
Offset  Size   Description
──────────────────────────────────────────────────────────
0-1     2      Length (UInt16LE)
2+      N      Memory data
```

### Checkpoint (breakpoint/watchpoint) Operations

| Code   | Command              | Description                       |
|--------|----------------------|-----------------------------------|
| 0x11   | Checkpoint Get       | Get checkpoint by ID              |
| 0x12   | Checkpoint Set       | Create new checkpoint             |
| 0x13   | Checkpoint Delete    | Delete checkpoint                 |
| 0x14   | Checkpoint List      | List all checkpoints              |
| 0x15   | Checkpoint Toggle    | Enable/disable checkpoint         |
| 0x22   | Condition Set        | Add condition                     |

#### Checkpoint Set (0x12) Request

```
Offset  Size   Description
──────────────────────────────────────────────────────────
0-1     2      Start address (UInt16LE)
2-3     2      End address (UInt16LE)
4       1      Stop on hit (0x00=no, 0x01=yes)
5       1      Enabled (0x00=no, 0x01=yes)
6       1      CPU operation (see below)
7       1      Temporary (0x00=no, 0x01=yes)
8       1      Memspace (optional)
```

**CPU Operations (bitmask):**

| Bit    | Value  | Operation                       |
|--------|--------|---------------------------------|
| 0      | 0x01   | Load - memory read              |
| 1      | 0x02   | Store - memory write            |
| 2      | 0x04   | Exec - execution (breakpoint)   |

#### Checkpoint Info Response (0x11)

```
Offset  Size   Description
──────────────────────────────────────────────────────────
0-3     4      Checkpoint ID (UInt32LE)
4       1      Currently hit (0x00=no, 0x01=yes)
5-6     2      Start address
7-8     2      End address
9       1      Stop on hit
10      1      Enabled
11      1      CPU operation
12      1      Temporary
13-16   4      Hit count (UInt32LE)
17-20   4      Ignore count (UInt32LE)
21      1      Has condition
22      1      Memspace
```

### Register Operations

| Code   | Command              | Description                     |
|--------|----------------------|---------------------------------|
| 0x31   | Registers Get        | Get CPU registers               |
| 0x32   | Registers Set        | Modify CPU registers            |
| 0x83   | Registers Available  | List available registers        |

#### Register Item Format

```
Offset  Size   Description
──────────────────────────────────────────────────────────
0       1      Item size (excluding this byte)
1       1      Register ID
2-3     2      Value (UInt16LE)
```

### Execution Control

| Code   | Command                | Description                      |
|--------|------------------------|----------------------------------|
| 0x71   | Advance Instructions   | Step N instructions              |
| 0x73   | Execute Until Return   | Run until RTS/RTI                |
| 0xAA   | Exit                   | Resume (continue)                |
| 0xBB   | Quit                   | Close VICE                       |
| 0xCC   | Reset                  | System reset                     |
| 0xDD   | Autostart              | Load and start program           |

#### Advance Instructions (0x71) Request

```
Offset  Size   Description
──────────────────────────────────────────────────────────
0       1      Step over subroutines (0x00=no, 0x01=yes)
1-2     2      Number of steps (UInt16LE)
```

#### Reset (0xCC) Request

```
Offset  Size   Description
──────────────────────────────────────────────────────────
0       1      Reset mode:
               0x00 = soft reset
               0x01 = hard reset
               0x08-0x0B = drive 8-11 reset
```

### Other Commands

| Code   | Command           | Description                         |
|--------|-------------------|-------------------------------------|
| 0x41   | Dump              | Save snapshot                       |
| 0x42   | Undump            | Load snapshot                       |
| 0x51   | Resource Get      | Get emulator setting                |
| 0x52   | Resource Set      | Set emulator setting                |
| 0x72   | Keyboard Feed     | PETSCII text to keyboard            |
| 0x81   | Ping              | Keepalive                           |
| 0x82   | Banks Available   | List memory banks                   |
| 0x84   | Display Get       | Get screen contents                 |
| 0x85   | Emulator Info     | VICE version information            |
| 0x91   | Palette Get       | Get palette                         |
| 0xA2   | Joyport Set       | Joystick simulation                 |

## Event Types (Asynchronous Responses)

These responses can arrive at any time, request ID = 0xFFFFFFFF.

| Code   | Event       | Description                           |
|--------|-------------|---------------------------------------|
| 0x61   | JAM         | CPU JAM state                         |
| 0x62   | Stopped     | Breakpoint hit or step complete       |
| 0x63   | Resumed     | Execution resumed                     |

## Example: Breakpoint Workflow

```
1. Client → VICE: Checkpoint Set (exec, enabled, $0820-$0820)
2. VICE → Client: Checkpoint Info (id=1, enabled=true)
3. Client → VICE: Exit (resume execution)
4. VICE → Client: Resumed event
... program runs ...
5. VICE → Client: Stopped event (PC=$0820)
6. VICE → Client: Checkpoint Info (id=1, hit=true)
7. Client → VICE: Registers Get
8. VICE → Client: Register Info (PC=$0820, A=$00, X=$01...)
9. Client → VICE: Advance Instructions (1, step_over=false)
10. VICE → Client: Stopped event
```

## TypeScript Implementation Reference

See: [vscode-cc65-vice-debug](https://github.com/empathicqubit/vscode-cc65-vice-debug)
- `src/dbg/binary-dto.ts` - Type definitions
- `src/dbg/abstract-grip.ts` - Protocol implementation
- `src/dbg/vice-grip.ts` - VICE specific logic

## Sources

- [VICE Manual - Binary Monitor](https://vice-emu.sourceforge.io/vice_13.html)
- [VS64 Extension](https://github.com/rolandshacks/vs64)
- [IceBro Lite](https://github.com/Sakrac/IceBroLite)
