# C64 fordító referencia

Ez a dokumentum a PyCo C64 (6502) backend specifikus funkcióit írja le.

## Dekorátorok

A `main()` függvény speciális dekorátorokkal módosítható, amik a C64-specifikus viselkedést befolyásolják.

### @lowercase

Kisbetűs/nagybetűs karakterkészlet módba kapcsolja a képernyőt.

```python
@lowercase
def main():
    print("Hello World!")  # Kisbetűkkel jelenik meg
```

A C64 alapértelmezetten nagybetűs/grafikus módban indul. A `@lowercase` dekorátor kisbetűs/nagybetűs módba kapcsolja, ahol a kisbetűk is megjelennek.

### @standalone

Önálló program mód - kikapcsolja a BASIC ROM-ot, +8KB RAM érhető el.

```python
@standalone
@lowercase
def main():
    # Teljes gép, 8KB extra RAM a BASIC ROM helyén ($A000-$BFFF)
    while True:
        pass  # Végtelen ciklus - nem tér vissza BASIC-be
```

A `@standalone` dekorátor:
- A program indulásakor kikapcsolja a BASIC ROM-ot ($A000-$BFFF) → +8KB RAM
- A program végén visszakapcsolja a BASIC ROM-ot és visszatér a BASIC promptba

---

## Memória elrendezés

```
┌──────────────────────────────────────────────────────────────┐
│ Cím tartomány  │ Méret  │ Leírás                             │
├──────────────────────────────────────────────────────────────┤
│ $0000 - $00FF  │ 256 B  │ Zero Page (rendszer + PyCo ZP)     │
│ $0100 - $01FF  │ 256 B  │ Hardware Stack (6502)              │
│ $0200 - $03FF  │ 512 B  │ Rendszer terület                   │
│ $0400 - $07FF  │ 1 KB   │ Képernyő memória (alapértelmezett) │
│ $0801 - $9FFF  │ ~38 KB │ BASIC/PyCo program terület         │
│ $A000 - $BFFF  │ 8 KB   │ BASIC ROM (kikapcsolható)          │
│ $C000 - $CFFF  │ 4 KB   │ Szabad RAM                         │
│ $D000 - $D3FF  │ 1 KB   │ VIC-II regiszterek                 │
│ $D400 - $D7FF  │ 1 KB   │ SID regiszterek                    │
│ $D800 - $DBFF  │ 1 KB   │ Szín memória                       │
│ $DC00 - $DCFF  │ 256 B  │ CIA1 (billentyűzet, joystick)      │
│ $DD00 - $DDFF  │ 256 B  │ CIA2 (soros port, VIC bank)        │
│ $E000 - $FFFF  │ 8 KB   │ KERNAL ROM                         │
└──────────────────────────────────────────────────────────────┘
```

---

## Gyakran használt címek

| Cím     | Név      | Leírás                  |
| ------- | -------- | ----------------------- |
| `$D020` | BORDER   | Keret színe             |
| `$D021` | BGCOLOR  | Háttér színe            |
| `$D012` | RASTER   | Aktuális rasztersor     |
| `$DC00` | CIA1_PRA | Keyboard matrix / Joy 2 |
| `$DC01` | CIA1_PRB | Keyboard matrix / Joy 1 |

---

## PyCo Zero Page használat

```
┌─────────────────────────────────────────────────────────┐
│ Cím       │ Név      │ Leírás                           │
├─────────────────────────────────────────────────────────┤
│ $02-$07   │ tmp0-5   │ Temp regiszterek                 │
│ $08-$09   │ FP       │ Frame Pointer                    │
│ $0A-$0B   │ SSP      │ Software Stack Pointer           │
│ $0C-$0E   │ spbuf    │ Sprint buffer                    │
│ $0F-$10   │ ZP_SELF  │ Self pointer (metódusokhoz)      │
│ $11-$12   │ spsave   │ Sprint saved CHROUT              │
│ $13-$16   │ retval   │ Return value (4 byte)            │
│ $17-$19   │ tmp6-8   │ String temps                     │
│ $1A-$56   │ ---      │ User-available (61 byte)         │
│ $57-$6E   │ FAC/ARG  │ Float munkaterület               │
└─────────────────────────────────────────────────────────┘
```

---

## Stack frame felépítése

> **Megjegyzés:** Ez a szekció haladó téma - a legtöbb programozáshoz nem szükséges ismerni. Akkor lehet hasznos, ha debuggolsz, inline assembly-t írsz, vagy meg akarod érteni a generált kódot.

A C64-en a PyCo két stack-et használ:
- **Software stack**: A paraméterek és lokális változók itt tárolódnak, az FP (Frame Pointer) segítségével érjük el őket
- **Hardware stack** ($0100-$01FF): A 6502 processzor beépített verme, ide kerül a visszatérési cím (JSR automatikusan) és a mentett FP

```
Software stack:                      Hardware stack ($0100-$01FF):

┌─────────────────────────┐          ┌─────────────────────────┐
│                         │          │                         │
│    Lokális változók     │          │    Mentett FP (2 byte)  │
│    (a deklaráció        │          │    (előző frame-é)      │
│     sorrendjében)       │          ├─────────────────────────┤
│                         │          │    Visszatérési cím     │
├─────────────────────────┤          │    (2 byte, JSR teszi)  │
│                         │          │                         │
│    Paraméterek          │          └─────────────────────────┘
│                         │
└─────────────────────────┘ ← FP (Frame Pointer) ide mutat
```

A **Frame Pointer (FP)** egy fix pont, amihez képest a fordító eléri a paramétereket és lokális változókat. Ez teszi lehetővé, hogy a függvények egymást hívják (rekurzió is), és mindegyik a saját változóit lássa.

---

## Példák

### Memory-mapped változók

```python
# VIC regiszterek elérése
BORDER = 0xD020
BGCOLOR = 0xD021

def main():
    border: byte[BORDER]
    bgcolor: byte[BGCOLOR]

    border = 0       # fekete keret
    bgcolor = 6      # kék háttér
```

### Képernyő memória elérése

```python
SCREEN = 0x0400
COLOR = 0xD800

def main():
    screen: array[byte, 1000][SCREEN]
    color: array[byte, 1000][COLOR]

    screen[0] = 1        # 'A' karakter
    color[0] = 1         # fehér szín
```

### Teljes példa: Színes keret

```python
@standalone
@lowercase
def main():
    border: byte[0xD020]
    i: byte

    while True:
        for i in range(16):
            border = i
```
