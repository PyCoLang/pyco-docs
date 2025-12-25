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

### @kernal

Kernal ROM engedélyezése (legacy mód). Alapértelmezetten a PyCo **kikapcsolja a Kernal ROM-ot** (+8KB RAM), a `@kernal` dekorátor megtartja aktívként.

```python
@kernal
def main():
    # Kernal ROM aktív - $FFD2, $FFE4 stb. elérhető
    pass
```

**Különbségek:**

| Funkció                     | Alapértelmezett (Kernal OFF) | @kernal (Kernal ON)    |
| --------------------------- | ---------------------------- | ---------------------- |
| ROM beállítás               | $01 = $35 (mindkét ROM ki)   | $01 = $36 (BASIC ki)   |
| print()                     | Saját screen rutin           | $FFD2 CHROUT           |
| getkey() / waitkey()        | Saját keyboard rutin         | $FFE4 GETIN            |
| @irq handler                | Rendszer IRQ-hoz láncolódik  | Direkt `rti`           |
| Extra RAM                   | +8KB ($E000-$FFFF)           | Nincs extra            |

**Mikor használd:**
- Kernal rutinok közvetlen hívása (pl. floppy I/O)
- Kompatibilitás régebbi kóddal
- Teljes Kernal API elérése

**Mikor NE használd:**
- Ha nincs szükség Kernal-ra → több RAM, gyorsabb
- Raster effektek → stabil timing a ROM nélkül

### @noreturn

A program soha nem tér vissza BASIC-be. A kilépési cleanup kód (ROM visszakapcsolás, I/O inicializálás, BASIC állapot visszaállítás) kimarad.

```python
@noreturn
def main():
    while True:
        # Végtelen loop - soha nem lép ki
        pass
```

**Generált kód:**
- Normál program: cleanup + `rts`
- @noreturn program: `jmp *` (végtelen loop)

**Megtakarítás:** ~50-100 byte kimenő kód

**Mikor használd:**
- Demók, intro-k
- Játékok amik soha nem lépnek ki
- Végtelen loop programok

**Kombinálható más dekorátorral:**

```python
@noreturn
@lowercase
def main():
    # Kisbetűs mód + soha nem tér vissza
    pass
```

---

## Memória elrendezés

### Alapértelmezett mód (Kernal OFF)

```
┌──────────────────────────────────────────────────────────────┐
│ Cím tartomány  │ Méret  │ Leírás                             │
├──────────────────────────────────────────────────────────────┤
│ $0000 - $00FF  │ 256 B  │ Zero Page (rendszer + PyCo ZP)     │
│ $0100 - $01FF  │ 256 B  │ Hardware Stack (6502)              │
│ $0200 - $03FF  │ 512 B  │ Rendszer terület                   │
│ $0400 - $07FF  │ 1 KB   │ Képernyő memória (alapértelmezett) │
│ $0801 - $BFFF  │ ~46 KB │ PyCo program terület               │
│                │        │ (BASIC ROM kikapcsolva)            │
│ $C000 - $CFFF  │ 4 KB   │ Szabad RAM                         │
│ $D000 - $D3FF  │ 1 KB   │ VIC-II regiszterek                 │
│ $D400 - $D7FF  │ 1 KB   │ SID regiszterek                    │
│ $D800 - $DBFF  │ 1 KB   │ Szín memória                       │
│ $DC00 - $DCFF  │ 256 B  │ CIA1 (billentyűzet, joystick)      │
│ $DD00 - $DDFF  │ 256 B  │ CIA2 (soros port, VIC bank)        │
│ $E000 - $FFFF  │ 8 KB   │ RAM (Kernal ROM kikapcsolva!)      │
└──────────────────────────────────────────────────────────────┘
```

**Alapértelmezetten a PyCo mindkét ROM-ot kikapcsolja:**
- BASIC ROM ($A000-$BFFF): +8KB RAM
- Kernal ROM ($E000-$FFFF): +8KB RAM
- **Összesen +16KB felszabadított memória!**

A `@kernal` dekorátorral a Kernal ROM aktív marad (lásd [Dekorátorok](#kernal)).

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

### Áttekintés

```
┌─────────────┬────────────────┬────────────────────────────────────┐
│ Cím         │ Név            │ Leírás                             │
├─────────────┼────────────────┼────────────────────────────────────┤
│ $02-$07     │ tmp0-5         │ Általános temp regiszterek         │
│ $08-$09     │ FP             │ Frame Pointer                      │
│ $0A-$0B     │ SSP            │ Software Stack Pointer             │
│ $0C-$0D     │ spbuf          │ Sprint buffer pointer              │
│ $0E         │ sppos          │ Sprint buffer pozíció              │
│ $0F-$12     │ retval         │ Return value (4 byte, float-hoz)   │
│ $0F-$10     │ spsave         │ Sprint CHROUT (átfedés retval-lal) │
│ $11         │ sptmp          │ Sprint temp (átfedés retval+2-vel) │
│ $13-$15     │ tmp6-8         │ Kiterjesztett temp regiszterek     │
│ $16-$17     │ ZP_SELF        │ Self pointer (metódusokhoz)        │
│ $18-$19     │ scr_tmp0-1     │ Screen rutinok pointer (scroll)    │
│ $1A-$1F     │ irq_tmp0-5     │ IRQ temp regiszterek (izoláció!)   │
│ $20         │ putchar_save_y │ CHROUT Y regiszter mentés          │
│ $21         │ irq_cia1_cache │ CIA1 IRQ cache (lazy reading)      │
│ $22-$56     │ ---            │ User-available (53 byte)           │
│ $57-$5D     │ RESULT..       │ Float/szorzás munkaterület         │
│ $61-$66     │ FAC            │ Float Accumulator                  │
│ $69-$6E     │ ARG            │ Float Argument                     │
├─────────────┼────────────────┼────────────────────────────────────┤
│ $A0-$A2     │ TIME           │ Jiffy clock (Kernal-kompatibilis)  │
│ $C5         │ LSTX           │ Utolsó billentyű matrix kódja      │
│ $C6         │ NDX            │ Keyboard buffer count              │
│ $D1-$D2     │ PNT            │ Screen line pointer                │
│ $D3         │ PNTR           │ Cursor oszlop (0-39)               │
│ $D6         │ TBLX           │ Cursor sor (0-24)                  │
│ $F3-$F4     │ ---            │ Color RAM line pointer             │
│ $0277-$0280 │ KEYD           │ Keyboard buffer (10 byte)          │
│ $028C       │ KOUNT          │ Key repeat delay                   │
│ $028D       │ SHFLAG         │ Shift/Ctrl/C= flags                │
└─────────────┴────────────────┴────────────────────────────────────┘
```

### Részletes temp regiszter használat

A temp regiszterek ($02-$07 és $13-$15) különböző műveleteknél kerülnek felhasználásra:

#### tmp0-tmp5 ($02-$07) - Alapvető műveletek

| Cím   | Label | Használat                                          |
|-------|-------|----------------------------------------------------|
| $02   | tmp0  | Általános temp, pointer low byte                   |
| $03   | tmp1  | Általános temp, pointer high byte                  |
| $04   | tmp2  | Szorzás/osztás operandus, loop counter             |
| $05   | tmp3  | Szorzás/osztás operandus                           |
| $06   | tmp4  | Összetett kifejezések, f16/f32 operandus           |
| $07   | tmp5  | Összetett kifejezések, f16/f32 operandus           |

**Mely műveletek használják:**
- ✅ Byte/word aritmetika (+, -, *, &, |, ^, <<, >>)
- ✅ Összehasonlítások (<, >, ==, !=, <=, >=)
- ✅ Array indexelés (kis offset)
- ✅ Pointer dereferálás
- ✅ Változó hozzáférés

#### tmp6-tmp8 ($13-$15) - Kiterjesztett műveletek

| Cím   | Label | Használat                                          |
|-------|-------|----------------------------------------------------|
| $13   | tmp6  | Osztás, string műveletek, nagy offset számítás     |
| $14   | tmp7  | Osztás, string műveletek, nagy offset számítás     |
| $15   | tmp8  | String multiply, f32 műveletek                     |

**Mely műveletek használják:**
- ⚠️ Osztás (`/`) és modulo (`%`)
- ⚠️ String konkatenáció (`+`)
- ⚠️ String szorzás (`*`)
- ⚠️ f16/f32 aritmetika
- ⚠️ Bonyolult kifejezések (ha tmp0-5 nem elég)
- ⚠️ Nagy array offset számítás

### Stack és függvényhívás regiszterek

| Cím       | Label   | Használat                                        |
|-----------|---------|--------------------------------------------------|
| $08-$09   | FP      | Frame Pointer - aktuális stack frame bázis       |
| $0A-$0B   | SSP     | Software Stack Pointer - stack teteje            |
| $0F-$12   | retval  | Függvény visszatérési érték (max 4 byte)         |
| $16-$17   | ZP_SELF | `self` pointer metódushívásokhoz                 |

### Print (sprint) regiszterek

| Cím       | Label   | Használat                                        |
|-----------|---------|--------------------------------------------------|
| $0C-$0D   | spbuf   | Sprint buffer pointer                            |
| $0E       | sppos   | Aktuális pozíció a bufferben                     |
| $0F-$10   | spsave  | Mentett CHROUT vektor (átfedés retval-lal!)      |
| $11       | sptmp   | Sprint temp (átfedés retval+2-vel!)              |

> **Megjegyzés:** A `spsave` és `retval` átfedésben vannak, de soha nem aktívak egyszerre (print közben nincs függvény return).

### Kernal-kompatibilis rendszerváltozók

A Kernal-mentes mód ugyanazokat a memóriacímeket használja, mint a Kernal ROM, így a kilépés zökkenőmentes:

| Cím         | Kernal név | Használat                                     |
|-------------|------------|-----------------------------------------------|
| $A0-$A2     | TIME       | Jiffy clock (1/60 sec, növekvő)               |
| $C5         | LSTX       | Utolsó lenyomott billentyű matrix kódja       |
| $C6         | NDX        | Keyboard buffer-ben lévő karakterek száma     |
| $D1-$D2     | PNT        | Screen line pointer (aktuális sor címe)       |
| $D3         | PNTR       | Cursor oszlop (0-39)                          |
| $D6         | TBLX       | Cursor sor (0-24)                             |
| $F3-$F4     | USER       | Color RAM line pointer                        |
| $0277-$0280 | KEYD       | Keyboard buffer (10 byte)                     |
| $028C       | KOUNT      | Key repeat delay counter                      |
| $028D       | SHFLAG     | Shift/Ctrl/C= flag (bit 0=SHIFT, 1=C=, 2=CTRL)|

> **Fontos:** A `$C5` (LSTX) változó biztosítja, hogy a kilépéskor még lenyomott billentyű ne kerüljön újra a bufferbe. Ha ezt nem ugyanazon a címen tárolnánk, a Kernal "új gombnak" látná.

### Float regiszterek

A float műveletek a BASIC ROM által is használt területet foglalják:

| Cím       | Label     | Használat                                      |
|-----------|-----------|------------------------------------------------|
| $57-$59   | RESULT    | Szorzás eredmény (3 byte)                      |
| $5A-$5B   | INDEX     | Memory pointer                                 |
| $5C       | SGNCPR    | Előjel összehasonlítás                         |
| $5D       | SHIFTSIGN | Shift előjel kiterjesztés                      |
| $61-$66   | FAC       | Float Accumulator (exponens + mantissza + jel) |
| $69-$6E   | ARG       | Float Argument (második operandus)             |

### IRQ handler-ek (`@irq`, `@irq_raw`, `@irq_hook` dekorátorok)

Az `@irq`, `@irq_raw` és `@irq_hook` dekorátorral jelölt függvények megszakítás-kezelőként működnek.

#### @irq vs @irq_raw vs @irq_hook

| Tulajdonság         | @irq                          | @irq_raw                    | @irq_hook                     |
| ------------------- | ----------------------------- | --------------------------- | ----------------------------- |
| IRQ vector          | $FFFE/$FFFF (hardver)         | $FFFE/$FFFF (hardver)       | $0314/$0315 (Kernal szoftver) |
| Prologue/epilogue   | A/X/Y mentés + `rti`          | A/X/Y mentés + `rti`        | Nincs + `jmp $ea31`           |
| Rendszer IRQ lánc   | Igen (alapért. módban)        | Soha                        | N/A (Kernal kezeli)           |
| @kernal módban      | Direkt `rti`                  | Direkt `rti`                | Nincs hatás                   |
| Keyboard scan       | Automatikus (alapért. módban) | Nincs                       | Kernal végzi                  |
| Használat           | Általános IRQ-k               | Időkritikus/bare metal      | Kernal hook (leggyorsabb)     |

**@irq:** Teljes IRQ handler A/X/Y mentéssel. Alapértelmezett módban a rendszer IRQ-hoz láncolódik.

**@irq_raw:** Teljes IRQ handler, de soha nem láncolódik a rendszer IRQ-hoz.

**@irq_hook:** Könnyűsúlyú hook a Kernal szoftver IRQ vectorhoz ($0314/$0315). A Kernal már elmentette A/X/Y-t, így nincs szükség prologue-ra. A handler végén `JMP $EA31`-re ugrik, ami a Kernal alapértelmezett IRQ kezelője (keyboard, jiffy clock, RTI).

> **Miért JMP és nem RTS?** A Kernal `JMP ($0314)`-et használ a hook meghívására, nem `JSR`-t! Ezért nincs visszatérési cím a stack-en, és az `RTS` hibás címre ugrana.

**@kernal mód:** Az `@irq` és `@irq_raw` direkt `rti`-t használ, nincs láncolás. Az `@irq_hook` változatlan.

```python
# Általános IRQ - keyboard működik
@irq
def raster_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF

# Bare metal IRQ - teljes kontroll
@irq_raw
def timing_critical_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF  # Gyorsabb, de keyboard nem működik!

# Kernal hook - leggyorsabb, keyboard automatikusan működik
@irq_hook
def frame_counter():
    frame_count: byte[0x02F0]
    frame_count = frame_count + 1  # Nincs prologue/epilogue overhead!
```

#### Temp regiszterek

Az IRQ **bármikor** megszakíthatja a főprogramot - beleértve amikor épp temp regisztereket használ. Ezért az IRQ handler **külön ZP területet** használ:

| Normál kontextus | IRQ kontextus   | Használat                      |
|------------------|-----------------|--------------------------------|
| $02-$07 (tmp0-5) | $1A-$1F         | Alapvető műveletek             |
| $13-$15 (tmp6-8) | (nem helyettesítve) | Kerülendő IRQ-ban!         |

**Fontos:** A tmp6-8 ($13-$15) nem kerül automatikusan helyettesítésre IRQ-ban! Ezek osztáshoz, f16/f32-höz és string műveletekhez kellenek - ezek a műveletek **tiltottak** IRQ handlerben a szemantikai ellenőrző által.

#### Lokális változók

Az IRQ handler a **software stack-et** használja lokális változókhoz - UGYANAZT mint a főprogram! De **NEM módosítja** sem az SSP-t, sem az FP-t. Ehelyett közvetlenül az `(SSP) + offset` címet használja.

```
IRQ belépéskor:                      IRQ közben:
┌─────────────┐                      ┌─────────────┐
│  (szabad)   │                      │ IRQ lokális │ ← (SSP) + 4 + offset
├─────────────┤ ← SSP                │  változók   │
│  főprogram  │                      ├─────────────┤ ← (SSP) + 4
│  változói   │                      │  (4 byte    │
└─────────────┘                      │   védőzóna) │
                                     ├─────────────┤ ← SSP (változatlan!)
                                     │  főprogram  │
                                     │  változói   │
                                     └─────────────┘
```

**Miért +4 byte védőzóna?** A főprogram max 4 byte-ot ír egyszerre az SSP-re (float paraméter). Ha az IRQ pont akkor jön, a +4 offset garantálja, hogy nem írjuk felül.

**Optimalizáció:** Ha `frame_size == 0` (nincs stack-alapú lokális változó), csak A/X/Y mentés kell (~15 ciklus)!

#### IRQ paraméterek - Interrupt flag regiszterek olvasása

Az IRQ handlerek speciális paramétereket kaphatnak, amelyek az interrupt flag regiszterek értékét tartalmazzák. Ezek a paraméterek **olvashatók ÉS írhatók** - valójában a háttérben mapped változóként működnek:

| Paraméter | Regiszter | Leírás                                                         | Olvasás               | Írás                 |
| --------- | --------- | -------------------------------------------------------------- | --------------------- | -------------------- |
| `vic`     | $D019     | VIC-II interrupt flag (bit 0 = raster)                         | Közvetlen             | Közvetlen            |
| `cia1`    | $DC0D     | CIA1 interrupt control (bit 0 = Timer A, bit 1 = Timer B, ...) | **Lazy cache**        | Közvetlen            |
| `cia2`    | $DD0D     | CIA2 interrupt control (ugyanaz mint CIA1)                     | Közvetlen             | Közvetlen            |

**Fontos különbségek:**
- **VIC ($D019):** Olvasás NEM törli az értéket → közvetlen hozzáférés biztonságos, többször olvasható
- **CIA1 ($DC0D):** Olvasás TÖRLI az értéket, ÉS a belső rutin (keyboard scan) is használja → lazy cache kötelező
- **CIA2 ($DD0D):** Olvasás TÖRLI az értéket, DE belső rutin nem használja → közvetlen (user felelőssége)

```python
@irq
def raster_handler(vic: byte, cia1: byte):
    # Ellenőrzés: melyik interrupt jött?
    if vic & 0x01:
        # VIC raster interrupt - vissza kell igazolni!
        vic = 0x01  # Acknowledge - közvetlenül $D019-be ír
        # raster logika...

    if cia1 & 0x01:
        # CIA1 Timer A interrupt
        # A cia1 paraméter lazy reading-et használ, tehát
        # a CIA1 regiszter CSAK MOST olvasódik be először!
        pass
```

**Paraméterek írása:**

A paraméterek írása közvetlenül a hardware regiszterbe megy, nem a stack-re. Ez kényelmessé teszi az interrupt acknowledge-t:

```python
@irq
def handler(vic: byte, cia1: byte):
    if vic & 0x01:
        vic = 0x01      # → sta $D019 (VIC interrupt acknowledge)
    if cia1 & 0x01:
        cia1 = 0x7f     # → sta $DC0D (CIA interrupt mask írás)
```

**Miért mapped változóként működnek?**

A háttérben ezek a paraméterek speciális kezelést kapnak:
- **Olvasás:** Cache-ből (lazy read a CIA1-nél, azonnali a többinél)
- **Írás:** Közvetlenül a hardware regiszterbe (`sta $D019`, `sta $DC0D`, `sta $DD0D`)

Ez megszünteti a korábbi redundanciát, amikor külön mapped változót kellett deklarálni az íráshoz.

**Lazy reading optimalizáció (CIA1):**

A `cia1` paraméter **lazy reading**-et használ, ami ~7 ciklust takarít meg raszter IRQ-knál:

1. A prologue inicializál egy cache-t (`irq_cia1_cache = $80`)
2. A CIA1 regiszter **CSAK akkor** olvasódik be, ha:
   - A user kód használja a `cia1` paramétert, VAGY
   - Az epilogue dönti el, kell-e system handler hívás
3. Raszter IRQ-nál, ha a VIC kód hamarabb fut és return-öl, a CIA1 soha nem olvasódik!

**Ciklus megtakarítás:**
| Eset | Régi (azonnal) | Új (lazy) | Megtakarítás |
|------|----------------|-----------|--------------|
| Prologue | 25 ciklus | 18 ciklus | **7 ciklus** |
| Raszter IRQ (nincs CIA ellenőrzés) | N/A | +0 ciklus | **~12 ciklus!** |

**Fontos:**
- A paraméter nevek számítanak, a sorrend mindegy
- Mindegyik paraméter opcionális - csak a deklaráltak olvasódnak be
- A `vic` regiszter azonnal olvasódik (nem törlődik olvasáskor)
- **KRITIKUS:** A CIA regiszterek olvasása TÖRLI a flaget! A lazy cache megoldja

**Generált kód példa (lazy reading):**
```asm
// IRQ prologue: save A/X/Y
pha
txa
pha
tya
pha
// Initialize CIA1 cache (lazy reading)
lda #$80                  ; $80 = "még nem olvasva" marker
sta irq_cia1_cache
// Read VIC $D019 -> vic at (SSP)+4  (azonnal, biztonságos)
lda $d019
ldy #4
sta (SSP),y

; ... user code: if vic & 0x01: ... (gyors, nincs CIA olvasás)

; Ha a user code használja a cia1 paramétert:
; Lazy read CIA: check cache first
lda irq_cia1_cache
bpl __cia_cache_ok        ; bit 7 clear = már olvasva
lda $dc0d                 ; első olvasás: CIA1 beolvasása
sta irq_cia1_cache        ; cache-elés
__cia_cache_ok:
; A regiszter most a cache-elt értéket tartalmazza

; IRQ epilogue: ellenőrzi a cache-t a system handler döntéshez
lda irq_cia1_cache
bpl __cache_valid         ; ha már volt olvasva, cache-ből dolgozik
lda $dc0d                 ; ha nem volt olvasva, most olvassa
sta irq_cia1_cache
__cache_valid:
and #$01                  ; CIA1 Timer A IRQ?
beq __skip_system
jmp __R_system_irq_tail   ; keyboard scan, stb.
__skip_system:
pla / tay / pla / tax / pla / rti
```

#### Változó típusok IRQ-ban

A user választhat a sebesség és kényelem között:

| Változó típus | Sebesség | Használat |
|---------------|----------|-----------|
| Memory-mapped (`x: byte[$1A]`) | ⚡ Leggyorsabb | Abszolút címzés, 3 ciklus |
| Stack-alapú (`x: byte`) | 🐢 Kicsit lassabb | `(SSP)+offset` címzés, 5-6 ciklus |

**Ajánlás:** Időkritikus IRQ-kban (raster effektek) használj mapped változókat!

#### Generált kód

**Minimális IRQ (frame_size == 0, csak mapped változók):**
```asm
irq_handler:
    pha                            ; 3 ciklus
    txa
    pha                            ; 3 ciklus
    tya
    pha                            ; 3 ciklus  (összesen ~15 ciklus)

    ; ... IRQ kód (IRQ temp regiszterekkel) ...

    pla
    tay
    pla
    tax
    pla                            ; ~15 ciklus
    rti
```

**IRQ stack változókkal (frame_size > 0):**
```asm
irq_handler:
    pha / txa / pha / tya / pha    ; A/X/Y mentés

    ; Lokális változók: (SSP) + 4 + offset
    ; Az SSP NEM módosul, az FP NEM módosul!
    ldy #4+offset                  ; +4 a védőzóna
    lda (SSP),y                    ; Olvasás
    sta (SSP),y                    ; Írás

    ; ... IRQ kód ...

    pla / tay / pla / tax / pla    ; A/X/Y visszaállítás
    rti
```

> **Megjegyzés:** Az IRQ handler NEM módosítja az SSP-t és FP-t! Közvetlenül `(SSP) + 4 + offset` címzést használ. A +4 védőzóna megvédi a főprogram épp írt adatait.

#### IRQ-ban TILOS műveletek (compiler ellenőrzi!)

A compiler fordítási időben ellenőrzi ezeket a szabályokat:

| Művelet | Hibaüzenet | Miért tilos? |
|---------|------------|--------------|
| `float`, `f16`, `f32` típusok | "Float type not allowed in @irq" | FAC/ARG ($61-$6E) nem mentődik |
| Függvényhívás | "Function calls not allowed in @irq" | A hívott fv. normál temp-et használna |
| Metódushívás | "Method calls not allowed in @irq" | ZP_SELF + függvényhívás |
| `print()` | "print() not allowed in @irq" | spbuf/spsave nem mentődik |
| Konstruktor hívás (`obj()`) | "Constructor calls not allowed in @irq" | Metódushívással egyenértékű |

#### IRQ-ban ENGEDÉLYEZETT műveletek

- ✅ `byte`, `word`, `int`, `char`, `bool` típusok (aritmetika, bitműveletek)
- ✅ Összehasonlítások, feltételek, ciklusok
- ✅ Memory-mapped változók (`x: byte[0xD020]`)
- ✅ Array/subscript hozzáférés
- ✅ `__sei__()`, `__cli__()`, `__inc__()`, `__dec__()` intrinsics
- ✅ `__asm__()` inline assembly
- ✅ `addr()`, `size()` compile-time függvények

#### IRQ handler beállítása

##### `__set_irq__()` intrinsic (ajánlott)

A legegyszerűbb módszer a `__set_irq__()` intrinsic használata, ami automatikusan:
- Letiltja a megszakításokat (`sei`)
- Beállítja a megfelelő IRQ vector-t a dekorátor alapján
- Újra engedélyezi a megszakításokat (`cli`)

```python
@irq_hook
def frame_counter():
    frame_count: byte[0x02F0]
    frame_count = frame_count + 1

@irq
def raster_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF

def main():
    __set_irq__(frame_counter)  # → $0314/$0315 (mert @irq_hook)
    __set_irq__(raster_handler) # → $FFFE/$FFFF (mert @irq)
```

A `__set_irq__` automatikusan felismeri a dekorátor típust:

| Dekorátor     | Beállított vector     |
| ------------- | --------------------- |
| `@irq`        | $FFFE/$FFFF (hardver) |
| `@irq_raw`    | $FFFE/$FFFF (hardver) |
| `@irq_hook`   | $0314/$0315 (Kernal)  |

##### Manuális beállítás

Az IRQ handler címét manuálisan is beállíthatjuk az `addr()` függvénnyel:

```python
@irq
def raster_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF  # Acknowledge

def main():
    irq_vector: word[0x0314]  # C64 Kernal IRQ vector

    __sei__()                      # IRQ tiltás
    irq_vector = addr(raster_handler)  # IRQ vector beállítása
    __cli__()                      # IRQ engedélyezés
```

**Fontos címek:**

| Cím           | Leírás                                   |
| ------------- | ---------------------------------------- |
| `$0314-$0315` | Kernal szoftver IRQ vector (írható RAM)  |
| `$FFFE-$FFFF` | Hardware IRQ vector (ROM, nem írható)    |

> **Megjegyzés:** A hardver vector ($FFFE/$FFFF) csak akkor írható, ha a Kernal ROM ki van kapcsolva (alapértelmezett mód).

#### Példa: Raster scroll

```python
# Globális változó (a főprogram állítja)
scroll_x: byte[0x02F0] = 0

@irq
def raster_handler():
    vic_ctrl2: byte[0xD016]
    vic_irq: byte[0xD019]

    # Gyors - mapped változók, nincs stack
    vic_ctrl2 = (vic_ctrl2 & 0xF8) | scroll_x
    vic_irq = 0xFF  # Acknowledge
```

#### SSP védett frissítés (ha van IRQ a programban)

**Probléma:** A 6502-n a 16-bites SSP frissítése nem atomi. Page boundary crossing esetén (pl. $10FF → $1100) az SSP ideiglenesen inkonzisztens lehet:

```asm
; Probléma: 16-bit inkonzisztencia
lda SSP
adc #8           ; A = $07, carry = 1
sta SSP          ; SSP low = $07
                 ; <<< IRQ ITT >>> SSP = $1007 (hibás! valódi: $10FF)
inc SSP+1        ; SSP high = $11, most már OK
```

**Megoldás:** Ha a programban van `@irq` handler, a kódgenerátor **védett SSP frissítést** használ `php`/`plp`-vel:

```asm
; Védett SSP frissítés (php/plp megőrzi a user __sei__ állapotát)
clc
lda SSP
adc #<frame_size
bcc .no_carry       ; Ha nincs carry → biztonságos
php                 ; Page crossing → mentsük az I flag-et!
sei                 ; Védelem
sta SSP
inc SSP+1
plp                 ; Visszaállítjuk az EREDETI I flag állapotot
jmp .done
.no_carry:
sta SSP             ; Nincs carry, csak low byte változik
.done:
```

**Miért `php`/`plp` és nem `sei`/`cli`?**

Ha a user `__sei__()`-t hívott és utána függvényt hív, a sima `cli` visszakapcsolná az IRQ-t a user szándéka ellenére. A `php`/`plp` megőrzi az eredeti I flag állapotot:
- Ha IRQ engedélyezve volt (I=0) → `plp` visszakapcsolja
- Ha IRQ tiltva volt (I=1) → `plp` **tiltva hagyja**

Ez működik importált library-kkal is, amik `__sei__()`/`__cli__()` párokat használhatnak.

**Overhead:**
- Nincs page crossing: **0 extra ciklus** (a `bcc` ugrik, `sta SSP` fut)
- Page crossing: **+12 ciklus** (php + sei + plp + jmp)
- Page crossing esélye: ~5-15% (frame_size / 256)

> **Megjegyzés:** Ha nincs `@irq` a programban, a kódgenerátor a régi, egyszerű SSP frissítést használja (0 overhead).

#### irq_safe wrapper típus

Az `irq_safe` wrapper típus **atomi hozzáférést** biztosít memory-mapped változókhoz, amelyeket mind a főprogram, mind az IRQ handler használ. A fordító automatikusan `PHP`/`SEI`/`PLP` védelmet generál az olvasás és írás műveletekhez.

**Szintaxis:**

```python
név: irq_safe[típus[cím]]
```

```python
@singleton
class Game:
    score: irq_safe[word[0x00FB]]    # Atomi hozzáférés
```

**Probléma (irq_safe nélkül):**

A többbájtos típusok (word, int) olvasása és írása több gépi utasítást igényel. Ha az IRQ pont középen szakítja meg a műveletet, "torn read/write" történik:

```
; Normál word írás - VESZÉLYES!
    lda #$39
    sta $FB          ; ← IRQ itt szakíthatja meg
    lda #$30         ;   Az IRQ handler $30FB helyett $??39-et olvas!
    sta $FC
```

**Megoldás (irq_safe-fel):**

```
; irq_safe word írás - BIZTONSÁGOS
    php              ; Eredeti I flag mentése (3 ciklus)
    sei              ; IRQ tiltás (2 ciklus)
    lda #$39
    sta $FB
    lda #$30
    sta $FC
    plp              ; Eredeti I flag visszaállítása (4 ciklus)
```

**Miért PHP/PLP és nem SEI/CLI?**

A `CLI` mindig engedélyezi az IRQ-t, de ha a user korábban `__sei__()`-t hívott:

```python
__sei__()               # User tiltja az IRQ-t valami okból
Game.score = 12345      # irq_safe írás
# Ha CLI-t használnánk, itt az IRQ újra engedélyezve lenne - BUG!
__cli__()               # User itt akarta visszaengedélyezni
```

A `PLP` visszaállítja az **eredeti** I flag állapotot, így a user szándéka megmarad.

**IRQ kontextus detektálás:**

Az IRQ handlerekben (`@irq`, `@irq_raw`, `@irq_hook`) a védelem **automatikusan kimarad**, mert:

1. A 6502 CPU automatikusan I=1-re állítja az IRQ belépéskor
2. További SEI/CLI felesleges overhead lenne

```python
@irq_hook
def raster_irq():
    # Itt NEM generálódik PHP/SEI/PLP!
    Game.score = Game.score + 10    # Közvetlen hozzáférés
```

**Támogatott típusok:**

| Típus   | Méret    | Generált védelem                    |
| ------- | -------- | ----------------------------------- |
| `byte`  | 1 byte   | PHP/SEI/STA/PLP (konzisztencia)     |
| `sbyte` | 1 byte   | PHP/SEI/STA/PLP (konzisztencia)     |
| `word`  | 2 byte   | PHP/SEI/STA×2/PLP (kritikus!)       |
| `int`   | 2 byte   | PHP/SEI/STA×2/PLP (kritikus!)       |

> **Megjegyzés:** A `byte` típusnál technikailag nem szükséges a védelem (egyetlen utasítás), de a fordító mégis generálja a konzisztencia és jövőbiztonság érdekében.

**Overhead:**

| Művelet         | Extra ciklus | Megjegyzés                          |
| --------------- | ------------ | ----------------------------------- |
| irq_safe olvasás | +9 ciklus   | PHP (3) + SEI (2) + PLP (4)         |
| irq_safe írás    | +9 ciklus   | PHP (3) + SEI (2) + PLP (4)         |
| IRQ-ban          | +0 ciklus   | Védelem kimarad                     |

**Generált kód példa:**

```python
# PyCo forrás
@singleton
class State:
    counter: irq_safe[word[0x00FB]]

def main():
    x: word = State.counter    # olvasás
    State.counter = 12345      # írás
```

```asm
; irq_safe word olvasás
    php
    sei
    lda $FB
    sta tmp0
    lda $FC
    sta tmp1
    plp
    ; x = tmp0/tmp1

; irq_safe word írás
    php
    sei
    lda #$39          ; 12345 = $3039
    sta $FB
    lda #$30
    sta $FC
    plp
```

---

## Stack frame felépítése

> **Megjegyzés:** Ez a szekció haladó téma - a legtöbb programozáshoz nem szükséges ismerni. Akkor lehet hasznos, ha debuggolsz, inline assembly-t írsz, vagy meg akarod érteni a generált kódot.

A C64-en a PyCo két stack-et használ:
- **Software stack**: A paraméterek és lokális változók itt tárolódnak, az FP (Frame Pointer) segítségével érjük el őket
- **Hardware stack** ($0100-$01FF): A 6502 processzor beépített verme, ide csak a visszatérési cím kerül (JSR automatikusan)

```
Software stack:                      Hardware stack ($0100-$01FF):

┌─────────────────────────┐          ┌─────────────────────────┐
│                         │          │                         │
│    Lokális változók     │          │    Visszatérési cím     │
│    (a deklaráció        │          │    (2 byte, JSR teszi)  │
│     sorrendjében)       │          │                         │
│                         │          └─────────────────────────┘
├─────────────────────────┤
│                         │
│    Paraméterek          │
│                         │
└─────────────────────────┘ ← FP (Frame Pointer) ide mutat
                          ↑
                    SSP (stack teteje)
```

A **Frame Pointer (FP)** egy fix pont, amihez képest a fordító eléri a paramétereket és lokális változókat. Az FP-t a hívó függvény újraszámolja minden hívás után (`FP = SSP - frame_size`), így nem kell a HW stack-re menteni. Ez 2.7× gyorsabb hívási konvenciót eredményez, és 2× több rekurzív hívást tesz lehetővé.

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
@lowercase
def main():
    border: byte[0xD020]
    i: byte

    while True:
        for i in range(16):
            border = i
```

---

## Float túlcsordulás kezelése

A PyCo 32-bites MBF (Microsoft Binary Format) lebegőpontos számokat használ. Amikor egy művelet eredménye meghaladja az ábrázolható tartományt, **signed saturation** (előjeles telítés) történik.

### Ábrázolható tartomány

| Érték | Hexadecimális | Decimális közelítés |
| ----- | ------------- | ------------------- |
| Max pozitív | `$FF7FFFFF` | ~1.7×10³⁸ |
| Max negatív | `$FFFFFFFF` | ~-1.7×10³⁸ |

### Túlcsordulás viselkedése

| Művelet | Feltétel | Eredmény |
| ------- | -------- | -------- |
| Összeadás | Pozitív overflow | `$FF7FFFFF` (max pozitív) |
| Összeadás | Negatív overflow | `$FFFFFFFF` (max negatív) |
| Szorzás | Pozitív overflow | `$FF7FFFFF` (max pozitív) |
| Szorzás | Negatív overflow | `$FFFFFFFF` (max negatív) |
| Osztás nullával | Pozitív/nulla osztandó | `$FF7FFFFF` (max pozitív) |
| Osztás nullával | Negatív osztandó | `$FFFFFFFF` (max negatív) |

### Példa

```python
def main():
    huge: float = 1e38
    result: float

    # Overflow pozitív irányba → max pozitív
    result = huge * 10.0

    # Overflow negatív irányba → max negatív
    result = -huge * 10.0
```

> **Megjegyzés:** Ez a viselkedés eltér a Commodore BASIC-től, ami `?OVERFLOW ERROR`-t dob. A PyCo a DSP/SIMD processzoroknál megszokott "saturation" megközelítést használja, ami lehetővé teszi a program folytatását.

## Hardver-közeli intrinsic függvények

A C64-es fordító speciális beépített függvényeket biztosít a hardver közvetlen eléréséhez.

### `__sei__()` - Interrupt tiltás

A 6502 `SEI` (Set Interrupt Disable) utasítását generálja. Letiltja a maszkolható megszakításokat (IRQ).

```python
__sei__()  # Interrupts disabled
```

### `__cli__()` - Interrupt engedélyezés

A 6502 `CLI` (Clear Interrupt Disable) utasítását generálja. Engedélyezi a maszkolható megszakításokat.

```python
__cli__()  # Interrupts enabled
```

### `__nop__()` - Üres utasítás

A 6502 `NOP` (No Operation) utasítását generálja. Nem csinál semmit, csak 2 CPU ciklust vár.

```python
__nop__()     # 1 NOP = 2 ciklus késleltetés
__nop__(5)    # 5 NOP = 10 ciklus késleltetés
```

**Szintaxis:**
- `__nop__()` - egyetlen NOP utasítás (2 ciklus)
- `__nop__(n)` - n darab NOP utasítás (n × 2 ciklus), ahol n pozitív egész konstans

**Tipikus használati esetek:**
- Precíz timing beállítása raster effekteknél
- Ciklus-pontos késleltetés IRQ handlerekben
- Placeholder kódban (később módosítható)

**Példa: Raster stabilizálás**

```python
@irq
def raster_irq():
    __nop__(7)  # 14 ciklus timing finomhangolás
    border: byte[0xD020]
    border = 1
```

### Példa: Character ROM olvasása

A Character ROM ($D000) csak akkor érhető el, ha az I/O ki van kapcsolva. Ehhez az interruptokat is le kell tiltani:

```python
def copy_charset():
    cpu_port: byte[0x01]
    char_rom: array[byte, 2048][0xD000]
    char_ram: array[byte, 2048][0xA000]
    old_port: byte
    i: word

    __sei__()                        # Interrupt tiltás
    old_port = cpu_port
    cpu_port = old_port & 0xFB       # I/O kikapcsolása, CHAROM láthatóvá tétele

    for i in range(2048):
        char_ram[i] = char_rom[i]    # Másolás

    cpu_port = old_port              # I/O visszakapcsolása
    __cli__()                        # Interrupt engedélyezés
```

> **Fontos:** A `__sei__()` és `__cli__()` mindig párban használandók! Az interrupt tiltás ideje alatt a rendszer nem reagál billentyűzetre, időzítőkre stb.

---

## Automatikus optimalizációk

A C64 fordító automatikusan alkalmaz bizonyos optimalizációkat a generált kódban.

### Tömb másolás (Array Copy)

A `arr1 = arr2` típusú tömb értékadás inline memcpy-t generál. A fordító automatikusan felismeri, ha mindkét tömb fix címen van (mapped arrays), és ilyenkor gyorsabb kódot generál.

**Címzési módok összehasonlítása:**

| Típus              | Forrás     | Cél        | Ciklus/byte | Megjegyzés                      |
| ------------------ | ---------- | ---------- | ----------- | ------------------------------- |
| Indirekt           | `(ptr),Y`  | `(ptr),Y`  | ~17-19      | Stack/alias tömbök              |
| **Hibrid (src)**   | `$addr,Y`  | `(ptr),Y`  | ~15-16      | Mapped forrás → stack/alias cél |
| **Hibrid (dst)**   | `(ptr),Y`  | `$addr,Y`  | ~15-16      | Stack/alias forrás → mapped cél |
| **Absolute (SMC)** | `$addr,Y`  | `$addr,Y`  | ~13-15      | **Mindkét mapped**              |

**Példa - Mapped tömbök (gyors):**

```python
def main():
    screen: array[byte, 1000][0x0400]  # Képernyő memória
    backup: array[byte, 1000][0xC000]  # Backup terület

    backup = screen  # SMC optimalizált: ~13-15 cy/byte
```

Generált assembly:
```asm
    lda $0400,y    ; 4-5 ciklus (absolute,Y)
    sta $C000,y    ; 5 ciklus (absolute,Y)
    iny            ; 2 ciklus
    cpy #...       ; 2 ciklus
    bne loop       ; 2-3 ciklus
```

**Példa - Stack tömbök (általános):**

```python
def main():
    src: array[byte, 100]
    dst: array[byte, 100]

    dst = src  # Indirekt címzés: ~17-19 cy/byte
```

Generált assembly:
```asm
    lda (tmp0),y   ; 5-6 ciklus (indirect,Y)
    sta (tmp2),y   ; 6 ciklus (indirect,Y)
    iny            ; 2 ciklus
    cpy #...       ; 2 ciklus
    bne loop       ; 2-3 ciklus
```

**Példa - Hibrid másolás (mapped ↔ stack):**

```python
def main():
    screen: array[byte, 40][0x0400]  # Mapped tömb
    buffer: array[byte, 40]          # Stack tömb

    buffer = screen  # Hibrid: lda $0400,y + sta (tmp2),y
    screen = buffer  # Hibrid: lda (tmp0),y + sta $0400,y
```

A fordító automatikusan felismeri, ha az egyik oldal mapped, és használja az absolute,Y címzést arra az oldalra. Ez ~10-15% gyorsítást jelent a tisztán indirekt módhoz képest.

**Multi-page tömbök (>256 byte):**

Nagy tömbök esetén a fordító automatikusan page-alapú másolást generál. Mapped tömbök esetén önmódosító kódot (SMC) használ a cím frissítésére:

```python
backup: array[byte, 1000][0xC000]
screen: array[byte, 1000][0x0400]
backup = screen  # 3 page + 232 byte maradék
```

A generált kód automatikusan kezeli a page-határokat, és a végén visszaállítja az eredeti címeket, hogy a másolás többször is lefuttatható legyen.

**Teljesítmény összehasonlítás (1000 byte másolás):**

| Módszer                       | Ciklus összesen | Idő @1MHz |
| ----------------------------- | --------------- | --------- |
| Indirekt (stack ↔ stack)      | ~17,000-19,000  | ~17-19 ms |
| **Hibrid (mapped ↔ stack)**   | ~15,000-16,000  | ~15-16 ms |
| **Absolute (mapped ↔ mapped)**| ~13,000-15,000  | ~13-15 ms |

> **Megjegyzés:** Az optimalizáció automatikus minden esetben:
> - Ha **mindkét** tömb mapped → teljes SMC (leggyorsabb)
> - Ha **egyik** tömb mapped → hibrid (egy absolute, egy indirect)
> - Ha **egyik sem** mapped → mindkét oldalon indirect

### Téglalap másolás (blkcpy)

A `blkcpy()` intrinsic gyors téglalap (block) memóriamásolást valósít meg. Ideális képernyő scroll, double buffering, tile/sprite blit műveletekhez.

**Szintaxis:**

```python
# 7 paraméteres (közös stride):
blkcpy(src_arr, src_offset, dst_arr, dst_offset, width, height, stride)

# 8 paraméteres (külön stride forrásra és célra):
blkcpy(src_arr, src_offset, src_stride, dst_arr, dst_offset, dst_stride, width, height)
```

**Paraméterek:**

| Paraméter    | Típus | Leírás                                        |
| ------------ | ----- | --------------------------------------------- |
| `src_arr`    | array | Forrás tömb                                   |
| `src_offset` | word  | Forrás kezdő offset (byte)                    |
| `src_stride` | byte  | Forrás sor hossz (csak 8-param verzió)        |
| `dst_arr`    | array | Cél tömb                                      |
| `dst_offset` | word  | Cél kezdő offset (byte)                       |
| `dst_stride` | byte  | Cél sor hossz (csak 8-param verzió)           |
| `width`      | byte  | Téglalap szélessége (byte-ban, max 255)       |
| `height`     | byte  | Téglalap magassága (sorok száma, max 255)     |
| `stride`     | byte  | Közös sor hossz (csak 7-param verzió)         |

**Használati példák:**

```python
screen: array[byte, 1000][0x0400]
buffer: array[byte, 1000][0x8000]
tile: array[byte, 16][0xC000]  # 4x4 tile

# Scroll left - 1 karakterrel balra
blkcpy(screen, 1, screen, 0, 39, 25, 40)

# Scroll up - 1 sorral felfelé
blkcpy(screen, 40, screen, 0, 40, 24, 40)

# Double buffer - 20x10 régió másolása
blkcpy(buffer, 5*40+10, screen, 5*40+10, 20, 10, 40)

# Tile blit - 4x4 tile másolása a képernyőre (különböző stride)
blkcpy(tile, 0, 4, screen, 5*40+10, 40, 4, 4)
```

**Automatikus irány-detektálás:**

Átfedő (overlapping) másolásnál a fordító automatikusan meghatározza a helyes másolási irányt:

| Eset                            | Irány    | Meghatározás         |
| ------------------------------- | -------- | -------------------- |
| Különböző tömbök                | Forward  | Compile-time (0 cy)  |
| Azonos tömb, mindkét offset fix | Megfelelő| Compile-time (0 cy)  |
| Azonos tömb, változó offset     | Megfelelő| Runtime (~20 cy)     |

- **Forward** (dst ≤ src): 0-tól width-1-ig másol
- **Backward** (dst > src): width-1-től 0-ig másol

**Példa - Scroll left (átfedő, forward):**

```python
# Forrás: screen+1, Cél: screen+0
# dst(0) < src(1) → forward irány automatikus
blkcpy(screen, 1, screen, 0, 39, 25, 40)
```

**Példa - Scroll right (átfedő, backward):**

```python
# Forrás: screen+0, Cél: screen+1
# dst(1) > src(0) → backward irány automatikus
blkcpy(screen, 0, screen, 1, 39, 25, 40)
```

**Teljesítmény:**

| Tömb típusok                     | Ciklus/byte | Módszer      |
| -------------------------------- | ----------- | ------------ |
| Mindkét mapped                   | ~13         | Full SMC     |
| Egyik mapped, másik stack        | ~17         | Hybrid SMC   |
| Mindkét stack                    | ~21         | Indirect     |

A fordító automatikusan a leggyorsabb elérhető módszert választja.

**Tile blit példa (8 paraméteres verzió):**

```python
def main():
    # 8x8 pixeles tile (8 byte széles, 8 sor magas)
    tile: array[byte, 64][0xC000]  # stride = 8
    screen: array[byte, 1000][0x0400]  # stride = 40
    i: byte

    # Tile feltöltése mintával
    for i in range(64):
        tile[i] = 0xAA if (i & 1) else 0x55

    # Tile blit a képernyő közepére (16,12)
    # 8-param: src, src_ofs, src_stride, dst, dst_ofs, dst_stride, w, h
    blkcpy(tile, 0, 8, screen, 12*40+16, 40, 8, 8)
```

> **Megjegyzés:** A 8 paraméteres verzió lehetővé teszi különböző stride-ok használatát, ami nélkülözhetetlen tile/sprite rendszerekhez, ahol a tile-ok tömören tárolódnak, de a képernyőn 40 byte a sorhossz.

---

## Aritmetikai optimalizációk

A fordító automatikusan optimalizálja bizonyos aritmetikai műveleteket, hogy gyorsabb kódot generáljon a lassú runtime helper függvények helyett.

### Strength Reduction (O1)

Konstans 2-hatványokkal végzett szorzás, osztás és modulo műveletek bit shift és AND műveletekre cserélődnek:

| Művelet  | Optimalizált kód                | Megtakarítás  |
| -------- | ------------------------------- | ------------- |
| `a * 2`  | `asl` (1 shift)                 | ~80 → 2 cy    |
| `a * 4`  | `asl` `asl` (2 shift)           | ~80 → 4 cy    |
| `a * 8`  | `asl` `asl` `asl` (3 shift)     | ~80 → 6 cy    |
| `a / 2`  | `lsr` (1 shift)                 | ~80 → 2 cy    |
| `a / 4`  | `lsr` `lsr` (2 shift)           | ~80 → 4 cy    |
| `a % 16` | `and #15`                       | ~100 → 2 cy   |
| `a % 256`| `and #$FF` (word: low byte)     | ~100 → 2 cy   |

**Word típusnál** a shift műveletek carry-vel propagálódnak:

```asm
; w * 4 (16-bit)
asl tmp0    ; low byte shift
rol tmp1    ; high byte shift + carry
asl tmp0
rol tmp1
```

**Kommutativitás:** A szorzás mindkét irányban optimalizált (`a * 4` és `4 * a`), de az osztás és modulo csak jobb oldali konstanssal (`a / 4`, `a % 16`).

### Konstans szorzás dekompozíció (O2)

Kis konstansokkal való szorzás shift+add/sub kombinációkra bomlik:

| Konstans | Dekompozíció             | Műveletek           | Ciklus |
| -------- | ------------------------ | ------------------- | ------ |
| 3        | `(a << 1) + a`           | 2a + a              | ~12    |
| 5        | `(a << 2) + a`           | 4a + a              | ~14    |
| 7        | `(a << 3) - a`           | 8a - a              | ~16    |
| 9        | `(a << 3) + a`           | 8a + a              | ~16    |
| 10       | `(a << 3) + (a << 1)`    | 8a + 2a             | ~20    |

**Generált kód példa (`a * 5`):**

```asm
; tmp2 = eredeti érték (a)
pha             ; Save original
asl             ; *2
asl             ; *4
sta tmp3        ; Store shifted
pla             ; Load original
clc
adc tmp3        ; 4a + a = 5a
```

**Megjegyzések:**
- A dekompozíció `tmp2` és `tmp3` regisztereket használ
- Word típusnál 16-bites shift+add/sub műveletek generálódnak
- A nem optimalizált konstansok (pl. 6, 11, 13) továbbra is runtime helper-t használnak
- IRQ handler-ekben automatikusan `irq_tmp2`/`irq_tmp3` használatos

**Teljesítmény összehasonlítás:**

| Művelet     | Runtime helper | O1 (shift) | O2 (decomp) |
| ----------- | -------------- | ---------- | ----------- |
| `a * 2`     | ~80 cy         | ~2 cy      | -           |
| `a * 3`     | ~80 cy         | -          | ~12 cy      |
| `a * 4`     | ~80 cy         | ~4 cy      | -           |
| `a * 5`     | ~80 cy         | -          | ~14 cy      |
| `a * 8`     | ~80 cy         | ~6 cy      | -           |
| `a / 4`     | ~120 cy        | ~4 cy      | -           |
| `a % 16`    | ~100 cy        | ~2 cy      | -           |

A konstans kifejezések (pl. `3 * 4`) továbbra is fordítási időben kiértékelődnek (constant folding), így a fenti optimalizációk csak változó operandusokra vonatkoznak.
