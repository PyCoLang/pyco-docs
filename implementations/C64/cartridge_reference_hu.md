# PyCo EasyFlash Cartridge Referencia

**Verzió:** 1.0
**Dátum:** 2026-01-26

## Áttekintés

EasyFlash cartridge támogatás a PyCo-ban:
- Natív C64 cartridge kimenet (.crt fájlok)
- Programok közvetlenül ROM-ból futnak
- **Modul-alapú bank rendszer** - meglévő `import` szintaxis újrahasznosítása
- Flash írás/olvasás az `easyflash` könyvtár modullal

**Célplatformok:**
- Fizikai EasyFlash 1/1CR/3 cartridge-ek
- Ultimate 64 / Ultimate II+L (EasyFlash emuláció)
- VICE emulátor

---

## EasyFlash Hardver

### Specifikáció

| Komponens   | Részletek                                        |
|-------------|--------------------------------------------------|
| Flash ROM   | 1 MB (2×512KB chip)                              |
| SRAM        | 256 byte ($DF00-$DFFF) - **írható!**             |
| Bankok      | 64 bank × 8KB ROML                               |
| Regiszterek | $DE00 (bank választó), $DE02 (vezérlő)           |

### Cartridge Módok

| Mód     | ROML        | ROMH         | $01 működik? | Kernal ki? |
|---------|-------------|--------------|--------------|------------|
| Ultimax | $8000-$9FFF | $E000-$FFFF  | ✗ NEM        | N/A        |
| 16KB    | $8000-$9FFF | $A000-$BFFF  | ✗ NEM        | ✗ NEM      |
| **8KB** | $8000-$9FFF | -            | **✓ IGEN**   | **✓ IGEN** |

**8KB mód előnyei:** Csak a ROML cartridge-vezérelt. A memória többi része ($A000-$FFFF) a $01 regiszter kontrollja alatt áll → A Kernal kikapcsolható!

### Vezérlő Regiszter ($DE02)

| Érték | Bitek     | Jelentés                          |
|-------|-----------|-----------------------------------|
| $04   | %000100   | Cartridge ROM ki                  |
| $05   | %000101   | Ultimax mód (ROML@$8000, ROMH@$E000) |
| $06   | %000110   | 8KB mód (ROML@$8000)              |
| $07   | %000111   | 16KB mód (ROML@$8000, ROMH@$A000) |
| $8x   | %1xxxxxx  | LED be (OR-olható a móddal)       |

---

## Memória Térkép

### 8KB Cartridge Mód + Kernal KI

```
$0000-$00FF  Zero Page (RAM) - PyCo runtime
$0100-$01FF  Hardver Stack (RAM)
$0200-$025F  Bank dispatcher (~60 byte) - FOGLALT!
$0260-$02FF  Szabad RAM
$0300-$07FF  Szabad RAM (cassette buffer is)
$0800+       SSP alapértelmezett kezdőcím
$8000-$9FFF  ROML - Aktuális bank (8KB Flash ROM)
$A000-$BFFF  Szabad RAM (8KB) - adatnak használható!
$C000-$CFFF  Szabad RAM (4KB)
$D000-$DFFF  I/O + EasyFlash regiszterek
  $DE00      Bank regiszter (csak írható, 0-63)
  $DE02      Vezérlő regiszter (csak írható)
  $DF00-$DF33  SMC Helper (52 byte)
  $DF34-$DF3F  EasyFlash modul SRAM változók
  $DF40-$DF7F  Read trampoline rutin
  $DF80-$DFFF  EAPI terület (flash programozás)
$E000-$FFFF  Szabad RAM (8KB) - IRQ vektorok itt!
```

**Összesen ~50KB szabad RAM!** (vs. ~34KB 16KB módban)

### FONTOS: Foglalt Címek

| Cím         | Foglalta         | Megjegyzés                              |
|-------------|------------------|-----------------------------------------|
| $0200-$025F | Bank dispatcher  | Multi-bank modul hívásokhoz             |
| $0277-$028D | Kernal változók  | Keyboard buffer, szín, key repeat       |
| $DF00-$DF33 | SMC Helper       | Fill/copy műveletek SRAM-ból            |
| $DF34-$DF3F | EasyFlash modul  | Shadow regiszterek, EAPI argumentumok   |
| $DF40-$DF7F | Read trampoline  | Biztonságos bank-váltással olvasás      |
| $DF80-$DFFF | EAPI             | Flash programozási rutinok              |

---

## @cartridge Dekorátor

### Szintaxis

```python
@cartridge              # mode=8, stack=0x0800 (alapértelmezett)
@cartridge()            # ugyanaz
@cartridge(8)           # mode=8, stack=0x0800
@cartridge(16)          # mode=16, stack=0x0800
@cartridge(8, 0x0300)   # mode=8, stack=0x0300
def main():
    pass
```

### Paraméterek

| Paraméter     | Típus | Alapértelmezett | Leírás                    |
|---------------|-------|-----------------|---------------------------|
| `mode`        | int   | 8               | 8KB vagy 16KB mód         |
| `stack_start` | int   | 0x0800          | SSP kezdőcíme             |

### Dekorátor Kompatibilitás

| Dekorátor    | Kompatibilis? | Megjegyzés                            |
|--------------|---------------|---------------------------------------|
| `@cartridge` | Kötelező      | Jelzi, hogy cartridge mód             |
| `@lowercase` | ✓ Igen        | Normálisan működik                    |
| `@noreturn`  | ✓ Igen        | Implicit (cartridge sosem tér vissza) |
| `@irq`       | ✓ Igen        | **Teljes raster IRQ támogatás!**      |
| `@irq_raw`   | ✓ Igen        | Minimális overhead IRQ                |
| `@irq_hook`  | ✓ Igen        | Működik (de Kernal ki van kapcsolva)  |
| `@kernal`    | ✗ Nem         | Kernal le van tiltva                  |

---

## Indítási Szekvencia

1. **Reset** → Ultimax mód aktív
2. CPU olvassa a reset vektort $FFFC/$FFFD-ről (ROMH @ $E000)
3. Kernal ellenőrzi a "CBM80" szignatúrát $8004-nél
4. Ha megvan → `JMP ($8000)` végrehajtja a cartridge kódot
5. **8KB módra váltás** ($DE02 = $06) + **SHADOW_CTRL inicializálás** ($DF35 = $06)
6. **SMC Helper másolása** ROMH → SRAM ($DF00)
7. **Kernal init** ($FDA3, $FD50, $FD15, $FF5B)
8. SSP/FP inicializálása
9. JMP main

---

## Bank Váltás és Visszatérés

### A Probléma

Ha a program ROM-ból fut (pl. $8100) és bank-ot vált:

```
$8100: JSR set_bank    ; visszatérési cím ($8103) → stack-re
       ...
       ; set_bank végrehajtja: STA $DE00
       ; AZONNAL a másik bank tartalma látható $8000-$9FFF-en
       ; A visszatérési cím ($8103) most GARBAGE-ra mutat!
       ; RTS → CRASH!
```

### Megoldás 1: SRAM Trampoline (easyflash modul)

Az `easyflash.read_byte()` függvény SRAM-ból ($DF50) futó rutint használ:

```
1. Rutin SRAM-ban ($DF50) - MINDIG látható, bármely bank aktív
2. Bank váltás a cél bankra
3. Byte olvasása
4. Bank 0 visszaállítása
5. RTS → biztonságos, mert bank 0 újra aktív
```

### Megoldás 2: Bank Dispatcher (multi-bank modulok)

A TOML-ben definiált modulok a RAM-ban lévő dispatcher-t ($0200) használják:

```
Hívó (bank 0):
  1. tmp0/tmp1 = célcím a másik bankban
  2. A = célbank szám
  3. JSR $0200

Dispatcher ($0200, RAM-ban):
  4. PHA → célbank elmentve
  5. LDA aktuális_bank
  6. PHA → hívó bank STACK-RE MENTVE
  7. PLA → célbank vissza
  8. STA $DE00 → bank váltás
  9. JSR (tmp0) → célkód végrehajtása

Visszatérés:
  10. PLA → hívó bank a stack-ről
  11. STA $DE00 → eredeti bank visszaállítva
  12. RTS → biztonságos visszatérés
```

**A dispatcher RAM-ból fut, így a bank váltás nem érinti!**

---

## Multi-Bank Modul Rendszer

### TOML Konfiguráció

```toml
[cartridge]
name = "MY GAME"
type = "easyflash"
stack_address = 0x0800    # Opcionális

[cartridge.main]
source = "main.pyco"
bank = 0

[[cartridge.modules]]
name = "common"
source = "common.pyco"
bank = 2

[[cartridge.modules]]
name = "editor"
source = "editor.pyco"
bank = 3
size = 16  # 16KB modul (ROML + ROMH)
```

### Használat

```python
# main.pyco - VÁLTOZATLAN SZINTAXIS!
import common        # TOML-ből tudja: bank 2
import editor        # TOML-ből tudja: bank 3

@cartridge(8, 0x0800)
def main():
    common.init()           # Automatikus bank váltás!
    common.draw_menu("Help")

    if key == 'e':
        editor.run()        # Átváltás az editor bankra
```

### CLI Parancsok

```bash
# CRT generálás TOML-ből
pycoc crt game.toml -o build/game.crt

# Force újrafordítás
pycoc crt game.toml --force
```

### Validációk

- Bank szám: 0-63 (0 a main-nek fenntartva)
- Bank méret: 8 vagy 16 KB
- Nincs duplikált bank szám
- Nincs duplikált modul név

---

## SRAM Használat

### Elrendezés

| Cím         | Méret    | Tartalom                              |
|-------------|----------|---------------------------------------|
| $DF00-$DF33 | 52 byte  | SMC Helper (fill/copy műveletek)      |
| $DF34       | 1 byte   | SHADOW_BANK (aktuális bank)           |
| $DF35       | 1 byte   | SHADOW_CTRL (mód + LED státusz)       |
| $DF36       | 1 byte   | SHADOW_INIT (EAPI inicializált?)      |
| $DF37-$DF3D | 7 byte   | EAPI argumentumok                     |
| $DF40-$DF7F | 64 byte  | Read trampoline rutin                 |
| $DF80-$DFFF | 128 byte | EAPI futásidejű kód                   |

### Miért SRAM?

Az SRAM ($DF00-$DFFF) **MINDIG látható**, függetlenül:
- Melyik bank aktív ($DE00)
- Melyik mód aktív ($DE02)
- A $01 regiszter értékétől

Ez teszi lehetővé:
- Bank-váltás közbeni kód futtatást
- Flash programozást (EAPI)
- Shadow regisztereket (write-only regiszterek olvasása)

---

## CRT Fájl Formátum

### Struktúra

```
Header (64 byte):
  - "C64 CARTRIDGE   " szignatúra
  - EasyFlash típus ($0020)
  - Cartridge név

Bank 0 ROML CHIP (8KB @ $8000):
  - JMP __romh_boot ($FE00-ra)
  - NOP
  - CBM80 szignatúra
  - Phase 3 kód (__phase3)
  - Main program kód

Bank 0 ROMH CHIP (8KB @ $E000):
  - Boot kód @ $FE00
  - SMC Helper adat
  - Reset vektor @ $FFFC → $8000

Bank N ROML CHIP-ek (modulonként):
  - Jump table @ $8000
  - Modul kód
  - (16KB módban: ROMH @ $A000 is)
```

---

## Flash Programozás

Az `easyflash` könyvtár modul biztosítja a flash írást/olvasást.

Lásd: [c64_library_en.md - easyflash modul](../c64_library_en.md#easyflash---easyflash-cartridge)

---

## Hivatkozások

- [EasyFlash Programmer's Guide](http://skoe.de/easyflash/files/devdocs/EasyFlash-ProgRef.pdf)
- [CRT File Format (VICE Manual)](https://vice-emu.sourceforge.io/vice_15.html)
- [Ultimate Documentation](https://1541u-documentation.readthedocs.io/)
- [C64 Wiki - EasyFlash](https://www.c64-wiki.com/wiki/EasyFlash)
