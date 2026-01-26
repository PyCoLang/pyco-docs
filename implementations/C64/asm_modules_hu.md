# Assembly Modulok Írása PyCo-ban

**Verzió:** 1.0.0
**Dátum:** 2026-01-25

Ez a dokumentum leírja a legjobb gyakorlatokat inline assembly kódot tartalmazó PyCo modulok írásához, különös tekintettel a modul relokációs kompatibilitásra.

## Tartalomjegyzék

1. [Áttekintés](#áttekintés)
2. [Modul Relokációs Rendszer](#modul-relokációs-rendszer)
3. [Automatikus Relokáció](#automatikus-relokáció)
4. [Driver Kód Beágyazása](#driver-kód-beágyazása)
5. [Legjobb Gyakorlatok](#legjobb-gyakorlatok)
6. [Kerülendő Minták](#kerülendő-minták)
7. [Példa: RLE Dekompresszor](#példa-rle-dekompresszor)

## Áttekintés

A PyCo modulok (`.pm` fájlok) relokálható bináris kódok, amelyek beágyazhatók programokba vagy dinamikusan betölthetők futás közben. Inline assembly-t tartalmazó modulok írásakor meg kell értened, hogyan működik a relokáció, hogy a kódod helyesen működjön bármilyen betöltési címen.

## Modul Relokációs Rendszer

Amikor egy modul beágyazódik vagy betöltődik, a kódját relokálni kell a `$0000` báziscímről a tényleges betöltési címre. A PyCo modul rendszer **marker-alapú relokációt** használ:

| Marker | Opcode | Cél |
|--------|--------|-----|
| `$02` (JAM) | `$A9` (LDA #) | Immediate magas bájt relokáció |
| `$12` (JAM) | `$BD` (LDA abs,X) | ADAT elérés X indexszel |
| `$22` (JAM) | `$AD` (LDA abs) | Közvetlen ADAT elérés |
| `$32` (JAM) | `$B9` (LDA abs,Y) | ADAT elérés Y indexszel |
| `$42` (JAM) | `$4C` (JMP abs) | Belső ugrás (nagy modulokhoz) |
| `$52` (JAM) | `$20` (JSR abs) | Belső hívás (nagy modulokhoz) |

## Automatikus Relokáció

A következő minták **automatikusan relokálódnak** a modul betöltő által:

### 1. Belső JSR/JMP Hívások

```asm
jsr _my_subroutine    // Automatikusan relokálódik
jmp _loop_start       // Automatikusan relokálódik
```

Amikor az assembler `JSR $00xx` vagy `JMP $00xx` címet generál (címek `$0000-$07FF` tartományban), ezek automatikusan felismerésre és relokálásra kerülnek.

### 2. Abszolút Címzés Labelekkel

```asm
lda my_data_table,x   // LDA abs,X - relokálódik
sta my_buffer,y       // STA abs,Y - relokálódik
lda my_variable       // LDA abs - relokálódik
```

A modul betöltő ellenőrzi az abszolút címek magas bájtját. Ha `$00-$07` tartományban van, a cím relokálódik a modul báziscím hozzáadásával.

## Driver Kód Beágyazása

Inline assembly modulok írásakor gyakori minta a "driver kód" (szubrutinok), amelyeket több függvényből hívnak. A kihívás az, hogy a Dead Code Elimination (DCE) eltávolíthatja azokat a függvényeket, amelyeket nem hívnak közvetlenül.

### A Probléma

```python
# HIBÁS: A DCE eltávolítja a _driver()-t, mert nem hívják közvetlenül!
@naked
def _driver():
    __asm__("""
_my_subroutine:
    // ... szubrutin kód ...
    rts
    """)

def my_function():
    __asm__("""
    jsr _my_subroutine  // HIBA: Ismeretlen szimbólum!
    """)
```

A `_driver()` függvény `_`-sal kezdődik, ami priváttá teszi. Mivel semelyik PyCo kód nem hívja közvetlenül, a DCE eltávolítja. A benne definiált labelek (`_my_subroutine`) is eltávolításra kerülnek, ami assembler hibát okoz.

### A Megoldás: Driver Beágyazása Exportált Függvénybe

Ágyazd be a driver kódot egy exportált függvény elejére, egy `JMP`-vel átugorva:

```python
def my_function(param: byte) -> byte:
    __asm__("""
    // Driver kód átugrása
    jmp _my_function_entry

// ============================================================
// DRIVER KÓD (ide beágyazva a DCE elkerülésére)
// ============================================================
_my_subroutine:
    // ... szubrutin implementáció ...
    rts

_helper_routine:
    // ... segéd kód ...
    rts

// ============================================================
// DRIVER KÓD VÉGE
// ============================================================

_my_function_entry:
    // A tényleges függvény kód itt kezdődik
    ldy #0
    lda (FP),y      // Paraméter betöltése
    jsr _my_subroutine
    // ... függvény többi része ...
    """)
```

Ez biztosítja:
1. A driver kód bekerül (egy exportált függvény része)
2. A JMP utasítás átugorja a drivert normál hívásoknál
3. Minden label elérhető a modul többi függvénye számára

## Legjobb Gyakorlatok

### 1. Használj Lokális Labeleket Rövid Ugrásokhoz

A `!:` / `!+` / `!-` szintaxis preferált rövid ugrásokhoz egy szubrutinon belül:

```asm
_my_loop:
    dex
    bne !+          // Következő utasítás átugrása ha X != 0
    ldy #0          // Y visszaállítása amikor X eléri a 0-t
!:  dey
    bne _my_loop    // Külső ciklus folytatása
```

### 2. Driver Változók a Kód Szegmensben

A driver kód által használt változókat a kód szegmensben tárold (nem BSS-ben), hogy biztosan relokálódjanak a modullal:

```asm
_my_counter:
    .byte 0         // Kód szegmensben, relokálódik a modullal

_my_buffer:
    .fill 16, 0     // 16 bájtos puffer a kód szegmensben
```

### 3. Használd a Zero Page Temp Regisztereket

Ideiglenes tároláshoz használd a standard PyCo zero page regisztereket:

| Regiszter | Cél |
|-----------|-----|
| `tmp0-tmp5` | Általános ideiglenes (fő kód) |
| `irq_tmp0-irq_tmp5` | IRQ-biztos ideiglenes |

```asm
// tmp regiszterek használata (mindig fix címeken)
sta tmp0
lda tmp2
// Ezek működnek a modul betöltési címétől függetlenül
```

### 4. Dokumentáld a Regiszter Használatot

Mindig dokumentáld, mely regisztereket és ideiglenes változókat használja a driver kód:

```asm
// ============================================================
// MY_ROUTINE - Valami hasznosat csinál
// ============================================================
// Bemenet:
//   tmp0-tmp1: Forrás pointer
//   tmp2-tmp3: Cél pointer
//   A: Feldolgozandó érték
// Kimenet:
//   A: Eredmény
// Módosít: A, X, Y, tmp0-tmp5
// ============================================================
_my_routine:
    // ... implementáció ...
```

## Kerülendő Minták

### 1. LDA #>label (Immediate Magas Bájt)

**KERÜLD** az immediate magas bájt címzést labelekkel:

```asm
// VESZÉLYES: JAM markert igényel, lehet hogy nem működik várt módon
lda #>my_data_table
sta ptr_high
lda #<my_data_table
sta ptr_low
```

Ez a minta megköveteli, hogy a compiler JAM markereket (`$02`) generáljon a relokációhoz. Bár támogatott, hibára hajlamos és kerülendő ha lehetséges.

**JOBB**: Használj futásidőben számított címeket:

```asm
// Adat tábla címének lekérése (ha paraméter vagy globális tuple)
lda data_table_addr
sta ptr_low
lda data_table_addr+1
sta ptr_high
```

### 2. Önmódosító Kód Abszolút Címekkel

SMC használatakor biztosítsd, hogy a módosított címek megfelelően kezelve legyenek:

```asm
// KOCKÁZATOS: A $1234 cím nem relokálódik!
    lda #$00
    sta $1234   // Fix cím, nem modul-belső
```

Modul-belső SMC esetén a címek relokálódnak, de ez még mindig törékeny minta.

### 3. Hardkódolt Modul-Belső Címek

Soha ne hardkódolj címeket, amelyeknek modul-relatívnak kellene lenniük:

```asm
// HIBÁS: A $0050 nem relokálódik
jsr $0050

// HELYES: Használj labelt
jsr _my_subroutine
```

## Példa: RLE Dekompresszor

A `compress` modul bemutatja a helyes inline assembly modul tervezést:

```python
def rle_decompress_addr(src_addr: word, dest_addr: word, compressed_size: word):
    """RLE adat dekompresszió nyers címekről."""
    __asm__("""
    // Ugrás a tényleges függvény kódra (driver átugrása)
    jmp _rle_decompress_addr_entry

// ============================================================
// RLE DEKOMPRESSZIÓS RUTIN (beágyazott driver)
// ============================================================
// Bemenet:
//   tmp2-tmp3: forrás pointer (tömörített adat)
//   tmp0-tmp1: cél pointer
//   tmp4-tmp5: BEMENETI méret (olvasandó tömörített bájtok)
//
// Használ: A, X, Y, tmp0-tmp5
// ============================================================

_rle_decompress:
    ldy #0              // Y = forrás index a lapon belül
    ldx #0              // X = cél index (mindig 0 indirect-hez)

_rle_loop:
    lda tmp4
    ora tmp5
    beq _rle_done       // bemeneti méret == 0, kész

    lda (tmp2),y
    pha
    jsr _rle_dec_input
    jsr _rle_inc_src
    pla

    cmp #$FF
    beq _rle_marker

_rle_store_byte:
    sta (tmp0,x)
    inc tmp0
    bne _rle_loop
    inc tmp1
    jmp _rle_loop

// ... további driver kód ...

_rle_done:
    rts

// Ideiglenes változók a kód szegmensben
_rle_count:
    .byte 0
_rle_value:
    .byte 0

// ============================================================
// DRIVER KÓD VÉGE
// ============================================================

_rle_decompress_addr_entry:
    // Paraméterek betöltése és driver hívása
    ldy #0
    lda (FP),y
    sta tmp2
    // ... többi paraméter betöltése ...
    jsr _rle_decompress
    """)
```

Főbb pontok ebből a példából:

1. **Driver beágyazva az első exportált függvénybe** - Megelőzi a DCE-t
2. **JMP a driver átugrására** - Normál hívások átugorják a driver kódot
3. **tmp0-tmp5 használata** - Standard ZP ideiglenes változók
4. **Változók a kód szegmensben** - `_rle_count`, `_rle_value`
5. **Jól dokumentált** - Bemenet/kimenet/módosítások dokumentálva
6. **Csak belső JSR** - `jsr _rle_decompress` használata (nincs `LDA #>` minta)

## Összefoglaló

Assembly modulok írásakor:

| Tedd | Ne tedd |
|------|---------|
| Ágyazd be a drivert exportált függvénybe | Tedd a drivert külön `@naked` privát függvénybe |
| Használj `tmp0-tmp5`-öt ideiglenesekhez | Hozz létre BSS változókat ideiglenesekhez |
| Használj labeleket minden címhez | Hardkódolj modul-belső címeket |
| Dokumentáld a regiszter használatot | Hagyj dokumentálatlan kódot |
| Tesztelj statikus és dinamikus importtal is | Feltételezd, hogy egy import módszer mindenhol működik |
