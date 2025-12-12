# VICE Debugger Integration dokumentáció

Ez a mappa tartalmazza a VICE emulátorral való debugger integráció dokumentációját a PyCo VS Code extension számára.

## Tartalomjegyzék

| Dokumentum                                                        | Leírás                                     |
|-------------------------------------------------------------------|--------------------------------------------|
| [vice_binary_protocol.md](vice_binary_protocol.md)                | VICE bináris monitor protokoll             |
| [vice_text_monitor.md](vice_text_monitor.md)                      | VICE text monitor parancsok                |
| [debug_adapter_design.md](debug_adapter_design.md)                | PyCo debugger tervezési dokumentum         |
| [reference_implementations.md](reference_implementations.md)      | Létező debugger implementációk tanulságai  |

## Gyors áttekintés

### Mi kell a debugger működéséhez?

1. **VICE 3.5+** - A bináris monitor protokoll 3.5-től elérhető
2. **Binary monitor engedélyezése** - `-binarymonitor` kapcsoló
3. **Debug info** - Source ↔ address mapping (compiler generálja)

### VICE indítása debug módban

```bash
# Alapértelmezett port (6502)
x64sc -binarymonitor program.prg

# Egyedi port
x64sc -binarymonitor -binarymonitoraddress 127.0.0.1:6502 program.prg

# Warp módban (gyorsabb)
x64sc -binarymonitor -warp program.prg
```

### Debug workflow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   VS Code    │────▶│ Debug Adapter│────▶│    VICE      │
│  Breakpoint  │     │  (TCP 6502)  │     │  Emulator    │
└──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │
       │  1. Set BP at      │                    │
       │     line 10        │                    │
       │  ──────────────▶   │                    │
       │                    │  2. Checkpoint     │
       │                    │     Set $0820      │
       │                    │  ──────────────▶   │
       │                    │                    │
       │                    │  3. Stopped        │
       │                    │     (event)        │
       │                    │  ◀──────────────   │
       │  4. Show BP hit    │                    │
       │     at line 10     │                    │
       │  ◀──────────────   │                    │
```

## Kulcsfontosságú protokoll elemek

### Command típusok (legfontosabbak)

| Kód    | Parancs               | Debugger funkció            |
|--------|-----------------------|-----------------------------|
| 0x12   | Checkpoint Set        | Breakpoint beállítása       |
| 0x13   | Checkpoint Delete     | Breakpoint törlése          |
| 0x71   | Advance Instructions  | Step into / Step over       |
| 0xAA   | Exit                  | Continue (F5)               |
| 0x31   | Registers Get         | CPU regiszterek lekérdezése |
| 0x01   | Memory Get            | Változó értékek olvasása    |

### Event típusok

| Kód    | Event       | Jelentés                              |
|--------|-------------|---------------------------------------|
| 0x62   | Stopped     | Breakpoint elérve / step kész         |
| 0x63   | Resumed     | Futás folytatódott                    |
| 0x61   | JAM         | Illegális opcode                      |

## Debug info generálás (TODO)

A compiler-nek generálnia kell:

1. **JSON debug info** (`program.pyco.debug`)
   - Source line → assembly address mapping
   - Változó definíciók (cím, típus, scope)
   - Függvény határok (stack frame info)

2. **VICE label fájl** (`program.vs`)
   - `al C:080d .__F_main` formátum
   - Automatikusan betöltődik a PRG-vel együtt

## Referenciák

### Hivatalos dokumentáció

- [VICE Manual - Binary Monitor](https://vice-emu.sourceforge.io/vice_13.html)
- [VICE Manual - Monitor Commands](https://vice-emu.sourceforge.io/vice_12.html)
- [VS Code Debug Adapter Protocol](https://microsoft.github.io/debug-adapter-protocol/)

### Létező implementációk (tanuláshoz)

- **[VS64](https://github.com/rolandshacks/vs64)** - TypeScript, teljes C64 dev env
- **[vscode-cc65-vice-debug](https://github.com/empathicqubit/vscode-cc65-vice-debug)** - CC65 debugger
- **[IceBro Lite](https://github.com/Sakrac/IceBroLite)** - C++, standalone debugger

### Hasznos források

- [c64jasm debug info](https://nurpax.github.io/posts/2021-02-22-c64jasm-debug-info.html) - Source mapping koncepció
- [cc65 debugging guide](https://cc65.github.io/doc/debugging.html) - VICE label formátum

## Fejlesztési terv

### Fázis 1: Alapok
- [ ] VICE binary client implementáció
- [ ] Debug Adapter skeleton
- [ ] Launch/Attach konfiguráció
- [ ] Alap breakpoint kezelés

### Fázis 2: Source mapping
- [ ] Debug info generálás (compiler)
- [ ] Source ↔ address mapping
- [ ] Step into/over/out

### Fázis 3: Variable inspection
- [ ] Global változók
- [ ] Local változók (stack frame)
- [ ] Watch expressions

### Fázis 4: Advanced
- [ ] Call stack
- [ ] Conditional breakpoints
- [ ] Memory view
- [ ] Disassembly view
