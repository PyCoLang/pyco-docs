# Jövőbeli Optimalizációs Lehetőségek

Ez a dokumentum a lehetséges fordító-optimalizációkat írja le, amelyek javíthatnák a generált kód minőségét. Ezek jelenleg nincsenek implementálva, de alacsony költségű fejlesztési lehetőségek.

## 1. Közvetlen ADC/SBC Globális Változókkal

**Jelenlegi viselkedés:**
```asm
; a = counter + increment
lda increment    ; 4 cycle, 3 byte
sta tmp0         ; 3 cycle, 2 byte
clc
lda counter      ; 4 cycle, 3 byte
adc tmp0         ; 3 cycle, 2 byte
sta counter      ; 4 cycle, 3 byte
                 ; Összesen: 18 cycle, 13 byte
```

**Optimalizált:**
```asm
; a = counter + increment
clc
lda counter      ; 4 cycle, 3 byte
adc increment    ; 4 cycle, 3 byte  <- közvetlen!
sta counter      ; 4 cycle, 3 byte
                 ; Összesen: 12 cycle, 9 byte
```

**Megtakarítás:** 6 cycle, 4 byte műveletenként

**Implementációs megjegyzések:**
- Peephole optimalizációs minta
- Csak egyszerű két-operandusú kifejezésekre alkalmazható globális változókkal
- A JAM markerek már támogatják az ADC abs ($C2) és SBC abs ($D2) utasításokat modul relokációhoz

## 2. Közvetlen AND/ORA/EOR Globális Változókkal

Ugyanaz a minta, mint az ADC/SBC:

**Jelenlegi:**
```asm
lda mask         ; 4 cycle, 3 byte
sta tmp0         ; 3 cycle, 2 byte
lda value        ; 4 cycle, 3 byte
and tmp0         ; 3 cycle, 2 byte
sta result       ; 4 cycle, 3 byte
```

**Optimalizált:**
```asm
lda value        ; 4 cycle, 3 byte
and mask         ; 4 cycle, 3 byte
sta result       ; 4 cycle, 3 byte
```

**Megtakarítás:** 6 cycle, 4 byte műveletenként

**Implementációs megjegyzések:**
- A JAM markerek támogatják az AND abs ($E2) és ORA abs ($F2) utasításokat
- Az EOR abs-hoz új marker kellene, ha szükséges

## 3. Erősség-csökkentés Szorzáshoz

**Jelenlegi (részben implementált):**
- `x * 2` → `x << 1` (balra shift)
- `x * 4` → `x << 2`
- `x * 8` → `x << 3`

**További lehetőségek:**
- `x * 3` → `(x << 1) + x`
- `x * 5` → `(x << 2) + x`
- `x * 6` → `(x << 2) + (x << 1)`
- `x * 7` → `(x << 3) - x`
- `x * 9` → `(x << 3) + x`
- `x * 10` → `(x << 3) + (x << 1)`

**Implementációs megjegyzések:**
- Trade-off a kódméret és sebesség között
- Kis szorzókhoz (2-10) a shift mindig gyorsabb, mint a MUL rutin
- Fontolandó az inline küszöb

## 4. Ciklus Kifejtés (Loop Unrolling)

**Jelenlegi:**
```asm
    ldx #0
loop:
    lda source,x
    sta dest,x
    inx
    cpx #8
    bne loop
```

**Kifejtett (kis számlálókhoz):**
```asm
    lda source+0
    sta dest+0
    lda source+1
    sta dest+1
    ; ... stb
```

**Implementációs megjegyzések:**
- Csak kis, fordítási időben ismert számlálókhoz előnyös
- Növeli a kódméretet
- Fontolandó opt-in optimalizációs flag-ként

## 5. Felesleges Tárolás Eltávolítása (Dead Store Elimination)

Azonnal felülírt tárolások eltávolítása:

```python
x = 5      # Felesleges tárolás
x = 10     # Csak ez számít
```

**Implementációs megjegyzések:**
- Adatfolyam-elemzés szükséges
- Óvatosnak kell lenni a memória-leképezett változókkal (tárolásnak lehet mellékhatása)

## 6. Közös Részkifejezés Kiemelése (CSE)

**Jelenlegi:**
```python
a = x + y
b = x + y  # Újraszámolva
```

**Optimalizált:**
```python
tmp = x + y
a = tmp
b = tmp
```

**Implementációs megjegyzések:**
- Kifejezés-követés szükséges utasításokon keresztül
- Figyelembe kell venni az aliasing-ot

## 7. Regiszter Allokáció Lokális Változókhoz

**Jelenlegi:** Minden lokális a stack-en van (FP-relatív címzés)

**Lehetőség:** Gyakran használt byte lokálisok A/X/Y regiszterekben tartása

**Implementációs megjegyzések:**
- Jelentős komplexitás növekedés
- Életesség-elemzés szükséges
- Csak leaf függvényekhez előnyös kevés lokálissal

## 8. Farokhívás Optimalizáció (Tail Call)

**Jelenlegi:**
```asm
    jsr other_function
    rts
```

**Optimalizált:**
```asm
    jmp other_function  ; Farokhívás
```

**Implementációs megjegyzések:**
- Csak ha a hívó és hívott kompatibilis stack frame-mel rendelkezik
- Visszatérési utak követése szükséges

## Prioritási Javaslatok

1. **Nagy hatás, kis ráfordítás:**
   - Közvetlen ADC/SBC/AND/ORA (peephole optimalizáció)
   - Kibővített erősség-csökkentés

2. **Közepes hatás, közepes ráfordítás:**
   - Ciklus kifejtés kis számlálókhoz
   - Felesleges tárolás eltávolítása

3. **Nagy hatás, nagy ráfordítás:**
   - Közös részkifejezés kiemelése
   - Regiszter allokáció

## JAM Marker Referencia

Modul relokációhoz a következő JAM markerek állnak rendelkezésre:

| Marker | Eredeti | Utasítás    |
|--------|---------|-------------|
| $42    | $4C     | JMP abs     |
| $52    | $20     | JSR abs     |
| $22    | $AD     | LDA abs     |
| $12    | $BD     | LDA abs,X   |
| $32    | $B9     | LDA abs,Y   |
| $62    | $8D     | STA abs     |
| $72    | $9D     | STA abs,X   |
| $82    | $99     | STA abs,Y   |
| $92    | $EE     | INC abs     |
| $B2    | $CE     | DEC abs     |
| $C2    | $6D     | ADC abs     |
| $D2    | $ED     | SBC abs     |
| $E2    | $2D     | AND abs     |
| $F2    | $0D     | ORA abs     |

**Megjegyzés:** Az $A2 NEM használható JAM markerként - ez a legális `LDX #imm` opcode!
