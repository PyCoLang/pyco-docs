# VICE Text Monitor Commands

Reference for VICE's built-in command-line monitor interface. Although we use the binary protocol for VS Code debugger integration, the text monitor is useful for debugging and testing purposes.

## Connection

```bash
# Enable remote monitor
x64sc -remotemonitor -remotemonitoraddress 127.0.0.1:6510

# Connect via telnet/netcat
nc localhost 6510
```

## Breakpoint Commands

### break - Execution Breakpoint

```
break [load|store|exec] [address [address] [if <cond_expr>]]

# Examples:
break $0820                    # Breakpoint at address $0820
break $0820 $0830              # Breakpoint in range $0820-$0830
break exec $0820               # Execution only (default)
break load $d020               # Trigger on read
break store $d020              # Trigger on write
break $0820 if a == $ff        # Conditional breakpoint
```

### watch - Memory Watchpoint

```
watch [load|store] [address [address] [if <cond_expr>]]

# Examples:
watch $d020                    # Watch the border color register
watch store $0400 $07ff        # Watch screen RAM writes
```

### trace - Tracepoint (does not stop)

```
trace [load|store|exec] [address [address] [if <cond_expr>]]

# Examples:
trace $0820                    # Trace message, but doesn't stop
```

### Checkpoint Management

```
delete <checkpoint_id>         # Delete checkpoint
enable <checkpoint_id>         # Enable checkpoint
disable <checkpoint_id>        # Disable checkpoint
ignore <checkpoint_id> <count> # Ignore N hits
```

## Execution Control

```
g [address]                    # Go - run (optionally from address)
n [count]                      # Next - step over (steps over subroutines)
z [count]                      # Step - step into
return                         # Run until RTS/RTI
until <address>                # Run until address
```

## Memory Commands

### m/mem - Memory Display

```
m [radix] [address_range]

# Radix options:
# (default) - hex
# b - binary
# o - octal
# d - decimal

# Examples:
m $0800 $08ff                  # Hex dump $0800-$08ff
m b $d020 $d021                # Binary display
```

### > - Memory Write

```
> [address] <data_list>

# Examples:
> $0400 $01 $02 $03            # Write bytes
> $c000 .hello                 # Write label value
```

### f/fill - Memory Fill

```
f <address_range> <data_list>

# Examples:
f $0400 $07ff $20              # Clear screen RAM (space)
f $d800 $dbff $01              # Set color RAM to white
```

### h/hunt - Memory Search

```
h <address_range> <data_list>

# Examples:
h $0800 $ffff $4c $00 $08      # Search for JMP $0800
h $0800 $ffff "hello"          # Search for string
h $0800 $ffff ? $00 $08        # Use wildcard (?)
```

### c/compare - Memory Compare

```
c <address_range> <address>

# Example:
c $0800 $08ff $0900            # Compare $0800-$08ff with $0900
```

## Registers

### r/registers - Register Display/Modify

```
r [reg_name = value]

# Examples:
r                              # Display all registers
r a = $ff                      # Set A register
r pc = $0820                   # Set program counter
```

**Registers:**
- `PC` - Program Counter
- `A` - Accumulator
- `X` - X register
- `Y` - Y register
- `SP` - Stack Pointer
- `FL` - Status flags

## Disassembly

```
d [address [address]]          # Disassembly

# Examples:
d                              # From current PC
d $0800                        # From $0800
d $0800 $08ff                  # Range
```

## Label Management

### ll - Load Label File

```
ll "filename"

# Examples:
ll "program.lbl"               # VICE label file
ll "program.sym"               # Symbol file
```

### al - Add Label

```
al <address> <label>

# Examples:
al c:$0820 .main               # Add label
```

### Label File Format

```
al C:080d .entry
al C:0854 .entry::frame_loop
al C:0890 ._main
```

Each line: `al C:[hex_address] [label_name]`

- Label names must start with `.` character
- The `::` separator can be used for nested/scoped labels
- The `C:` prefix indicates the CPU memspace

## I/O Commands

### l - Load Program

```
l "filename" [device] [address]

# Examples:
l "program.prg"                # Load PRG (first 2 bytes = load address)
l "program.prg" 0 $0800        # Load to specific address
```

### s - Save Memory

```
s "filename" <device> <address> <address>

# Examples:
s "dump.bin" 0 $0800 $08ff     # Save to file
```

### @ - Disk Command

```
@                              # Get disk status
@$                             # Directory listing
```

## Other Useful Commands

```
x                              # Exit monitor (continue)
reset [0|1]                    # 0=soft reset, 1=hard reset
bank [id]                      # Switch active memory bank
cpu [6502|z80]                 # CPU type (C128)
io                             # Display I/O registers
screen                         # Screen RAM contents
```

## Conditional Expressions

Operators available in breakpoint and watch conditions:

```
# Comparison
== != < > <= >=

# Logical
&& || !

# Bitwise
& | ^

# Registers
a x y sp pc

# Memory access
@($address)

# Examples:
break $0820 if a == $00 && x > $10
break $0820 if @($d020) == $00
```

## Sources

- [VICE Manual - Monitor](https://vice-emu.sourceforge.io/vice_12.html)
- [cc65 Debugging Guide](https://cc65.github.io/doc/debugging.html)
