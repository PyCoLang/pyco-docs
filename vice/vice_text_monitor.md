# VICE Text Monitor parancsok

A VICE beépített monitor parancssoros felületének referenciája. Bár a VS Code debugger integrációhoz a bináris protokollt használjuk, a text monitor hasznos debug és teszt célokra.

## Kapcsolódás

```bash
# Remote monitor engedélyezése
x64sc -remotemonitor -remotemonitoraddress 127.0.0.1:6510

# Telnet/netcat csatlakozás
nc localhost 6510
```

## Breakpoint parancsok

### break - Végrehajtási breakpoint

```
break [load|store|exec] [address [address] [if <cond_expr>]]

# Példák:
break $0820                    # Breakpoint a $0820 címen
break $0820 $0830              # Breakpoint a $0820-$0830 tartományban
break exec $0820               # Csak végrehajtásra (alapértelmezett)
break load $d020               # Olvasásra triggerel
break store $d020              # Írásra triggerel
break $0820 if a == $ff        # Feltételes breakpoint
```

### watch - Memória watchpoint

```
watch [load|store] [address [address] [if <cond_expr>]]

# Példák:
watch $d020                    # Watch a border color regiszteren
watch store $0400 $07ff        # Screen RAM írás figyelése
```

### trace - Tracepoint (nem állítja meg)

```
trace [load|store|exec] [address [address] [if <cond_expr>]]

# Példák:
trace $0820                    # Trace message, de nem áll meg
```

### Checkpoint kezelés

```
delete <checkpoint_id>         # Checkpoint törlése
enable <checkpoint_id>         # Checkpoint engedélyezése
disable <checkpoint_id>        # Checkpoint letiltása
ignore <checkpoint_id> <count> # N találat figyelmen kívül hagyása
```

## Végrehajtás vezérlés

```
g [address]                    # Go - futtatás (opcionális címtől)
n [count]                      # Next - step over (subroutine-on átlép)
z [count]                      # Step - step into
return                         # Futás RTS/RTI-ig
until <address>                # Futás adott címig
```

## Memória parancsok

### m/mem - Memória megjelenítés

```
m [radix] [address_range]

# Radix opciók:
# (default) - hex
# b - bináris
# o - oktális
# d - decimális

# Példák:
m $0800 $08ff                  # Hex dump $0800-$08ff
m b $d020 $d021                # Bináris megjelenítés
```

### > - Memória írás

```
> [address] <data_list>

# Példák:
> $0400 $01 $02 $03            # Bájtok írása
> $c000 .hello                 # Címke értékének írása
```

### f/fill - Memória kitöltés

```
f <address_range> <data_list>

# Példák:
f $0400 $07ff $20              # Screen RAM törlése (space)
f $d800 $dbff $01              # Color RAM fehérre
```

### h/hunt - Memória keresés

```
h <address_range> <data_list>

# Példák:
h $0800 $ffff $4c $00 $08      # JMP $0800 keresése
h $0800 $ffff "hello"          # String keresése
h $0800 $ffff ? $00 $08        # Wildcard (?) használata
```

### c/compare - Memória összehasonlítás

```
c <address_range> <address>

# Példa:
c $0800 $08ff $0900            # $0800-$08ff összehasonlítása $0900-tól
```

## Regiszterek

### r/registers - Regiszter megjelenítés/módosítás

```
r [reg_name = value]

# Példák:
r                              # Összes regiszter kiírása
r a = $ff                      # A regiszter beállítása
r pc = $0820                   # Program counter beállítása
```

**Regiszterek:**
- `PC` - Program Counter
- `A` - Akkumulátor
- `X` - X regiszter
- `Y` - Y regiszter
- `SP` - Stack Pointer
- `FL` - Status flags

## Disassembly

```
d [address [address]]          # Disassembly

# Példák:
d                              # Aktuális PC-től
d $0800                        # $0800-tól
d $0800 $08ff                  # Tartomány
```

## Label kezelés

### ll - Label fájl betöltése

```
ll "filename"

# Példák:
ll "program.lbl"               # VICE label fájl
ll "program.sym"               # Szimbólum fájl
```

### al - Label hozzáadása

```
al <address> <label>

# Példák:
al c:$0820 .main               # Label hozzáadása
```

### Label fájl formátum

```
al C:080d .entry
al C:0854 .entry::frame_loop
al C:0890 ._main
```

Minden sor: `al C:[hex_address] [label_name]`

- Label neveknek `.` karakterrel kell kezdődniük
- A `::` szeparátor használható nested/scoped labelekhez
- A `C:` prefix a CPU memspace-t jelöli

## I/O parancsok

### l - Program betöltése

```
l "filename" [device] [address]

# Példák:
l "program.prg"                # PRG betöltése (első 2 byte = load address)
l "program.prg" 0 $0800        # Betöltés adott címre
```

### s - Memória mentése

```
s "filename" <device> <address> <address>

# Példák:
s "dump.bin" 0 $0800 $08ff     # Mentés fájlba
```

### @ - Disk parancs

```
@                              # Disk status lekérdezése
@$                             # Directory listázás
```

## Egyéb hasznos parancsok

```
x                              # Kilépés a monitorból (folytatás)
reset [0|1]                    # 0=soft reset, 1=hard reset
bank [id]                      # Aktív memória bank váltása
cpu [6502|z80]                 # CPU típus (C128)
io                             # I/O regiszterek megjelenítése
screen                         # Screen RAM tartalom
```

## Feltételes kifejezések

Breakpoint és watch feltételekben használható operátorok:

```
# Összehasonlítás
== != < > <= >=

# Logikai
&& || !

# Bitwise
& | ^

# Regiszterek
a x y sp pc

# Memória elérés
@($address)

# Példák:
break $0820 if a == $00 && x > $10
break $0820 if @($d020) == $00
```

## Források

- [VICE Manual - Monitor](https://vice-emu.sourceforge.io/vice_12.html)
- [cc65 Debugging Guide](https://cc65.github.io/doc/debugging.html)
