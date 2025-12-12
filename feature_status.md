# PyCo Feature Status

Ez a dokumentum a `language_reference_hu.md`-ben specifikált összes feature implementációs állapotát tartalmazza.

**Jelmagyarázat:**
- ✅ **KÉSZ** - Teljesen implementálva és tesztelve
- 🔶 **RÉSZBEN** - Részben implementálva, vannak hiányosságok
- ❌ **NINCS** - Még nincs implementálva
- 🔧 **VALIDÁCIÓ** - Semantic analyzer ellenőrzi, de code gen nincs

---

## 1. Alapvető szintaxis

| Feature                       | Státusz | Megjegyzés                     |
| ----------------------------- | ------- | ------------------------------ |
| Nevek, azonosítók             | ✅ KÉSZ  | Validáció működik              |
| `__` prefix fenntartott nevek | ✅ KÉSZ  | Kivétel: `__init__`, `__str__` |
| Kommentek (`#`)               | ✅ KÉSZ  | Parser kezeli                  |
| Többsoros utasítások (`\`)    | ✅ KÉSZ  | Parser kezeli                  |
| Blokkok (behúzás)             | ✅ KÉSZ  | Python AST kezeli              |
| `pass` kulcsszó               | ✅ KÉSZ  | Üres blokkok                   |

## 2. Modulrendszer

| Feature           | Státusz   | Megjegyzés                                      |
| ----------------- | --------- | ----------------------------------------------- |
| `include("file")` | ✅ KÉSZ    | Preprocessor implementálva                      |
| `import modul`    | 🔶 RÉSZBEN | Validálva, de modulbetöltés nincs implementálva |
| Modulok keresése  | ❌ NINCS   | `-M` kapcsoló definiálva, de nem működik        |

## 3. Konstansok

| Feature                      | Státusz | Megjegyzés                      |
| ---------------------------- | ------- | ------------------------------- |
| NAGYBETŰS konstansok         | ✅ KÉSZ  | Validáció + code gen működik    |
| Konstans kifejezések         | ✅ KÉSZ  | Fordításkor kiértékelve         |
| `const()` preprocessor       | ✅ KÉSZ  | String/tömb ismétlés beágyazása |
| Konstans védelem (read-only) | ✅ KÉSZ  | Validáció tiltja a módosítást   |

## 4. Típusok

### 4.1 Primitív típusok

| Típus   | Validáció | Code Gen | Megjegyzés                                              |
| ------- | --------- | -------- | ------------------------------------------------------- |
| `bool`  | ✅ KÉSZ    | ✅ KÉSZ   | True/False, 1 byte                                      |
| `char`  | ✅ KÉSZ    | ✅ KÉSZ   | 1 karakter, PETSCII konverzió @lowercase-nál            |
| `byte`  | ✅ KÉSZ    | ✅ KÉSZ   | 0-255, 8-bit unsigned                                   |
| `sbyte` | ✅ KÉSZ    | ✅ KÉSZ   | -128..127, 8-bit signed                                 |
| `word`  | ✅ KÉSZ    | ✅ KÉSZ   | 0-65535, 16-bit unsigned                                |
| `int`   | ✅ KÉSZ    | ✅ KÉSZ   | -32768..32767, 16-bit signed                            |
| `f16`   | ✅ KÉSZ    | ✅ KÉSZ   | 8.8 fixed-point, +−*/, print, float konverzió           |
| `f32`   | ✅ KÉSZ    | ✅ KÉSZ   | 16.16 fixed-point, +−*/, print, float konverzió         |
| `float` | ✅ KÉSZ    | ✅ KÉSZ   | 32-bit MBF, +−*/, összehasonlítás, print, 72 E2E teszt  |

### 4.2 Összetett típusok

| Típus                  | Validáció | Code Gen  | Megjegyzés                          |
| ---------------------- | --------- | --------- | ----------------------------------- |
| `string`               | ✅ KÉSZ    | ✅ KÉSZ    | Pascal-stílusú, max 255 karakter    |
| `string[size]`         | ✅ KÉSZ    | ✅ KÉSZ    | Explicit méret                      |
| `array[type, size]`    | ✅ KÉSZ    | ✅ KÉSZ    | Deklaráció, indexelés (r/w), negatív index |
| Memory-mapped változók | ✅ KÉSZ    | ✅ KÉSZ    | `var: byte[0xD020]`                 |
| Memory-mapped tömbök   | ✅ KÉSZ    | ✅ KÉSZ    | `screen: array[byte, 1000][0x0400]` - 5 E2E teszt |
| Memory-mapped string   | ✅ KÉSZ    | ✅ KÉSZ    | `line: string[40][0x0400]` - E2E tesztelt |
| User-defined class     | ✅ KÉSZ    | ✅ KÉSZ    | Konstruktor, metódusok, öröklés        |

### 4.3 Típuskonverziók

| Feature                   | Státusz | Megjegyzés                           |
| ------------------------- | ------- | ------------------------------------ |
| Implicit bővítés          | ✅ KÉSZ  | byte → word/int automatikus          |
| Implicit szűkítés         | ✅ KÉSZ  | word → byte (alsó byte)              |
| Signed/unsigned konverzió | ✅ KÉSZ  | Bit-pattern megmarad                 |
| Overflow wraparound       | ✅ KÉSZ  | 255+1=0, 32767+1=-32768              |
| Bool konverzió            | ✅ KÉSZ  | 0=False, minden más=True             |
| Fixed → float konverzió   | ✅ KÉSZ  | f16/f32 → float explicit és implicit |

## 5. Operátorok

### 5.1 Aritmetikai operátorok

| Operátor | 8-bit  | 16-bit | Megjegyzés                                |
| -------- | ------ | ------ | ----------------------------------------- |
| `+`      | ✅ KÉSZ | ✅ KÉSZ | Összeadás                                 |
| `-`      | ✅ KÉSZ | ✅ KÉSZ | Kivonás                                   |
| `*`      | ✅ KÉSZ | ✅ KÉSZ | Shift-and-add algoritmus                  |
| `/`      | ✅ KÉSZ | ✅ KÉSZ | Integer osztás (restore subtraction)      |
| `%`      | ✅ KÉSZ | ✅ KÉSZ | Maradék (modulo) - division mellékterméke |

### 5.2 Összehasonlító operátorok

| Operátor | 8-bit  | 16-bit | Megjegyzés                |
| -------- | ------ | ------ | ------------------------- |
| `==`     | ✅ KÉSZ | ✅ KÉSZ | Egyenlőség                |
| `!=`     | ✅ KÉSZ | ✅ KÉSZ | Nem egyenlő               |
| `<`      | ✅ KÉSZ | ✅ KÉSZ | Kisebb (signed/unsigned)  |
| `>`      | ✅ KÉSZ | ✅ KÉSZ | Nagyobb (signed/unsigned) |
| `<=`     | ✅ KÉSZ | ✅ KÉSZ | Kisebb-egyenlő            |
| `>=`     | ✅ KÉSZ | ✅ KÉSZ | Nagyobb-egyenlő           |

### 5.3 Logikai operátorok

| Operátor | Státusz | Megjegyzés                |
| -------- | ------- | ------------------------- |
| `and`    | ✅ KÉSZ  | Short-circuit kiértékelés |
| `or`     | ✅ KÉSZ  | Short-circuit kiértékelés |
| `not`    | ✅ KÉSZ  | Logikai negálás           |

### 5.4 Bitműveleti operátorok

| Operátor | 8-bit  | 16-bit | Megjegyzés                     |
| -------- | ------ | ------ | ------------------------------ |
| `&`      | ✅ KÉSZ | ✅ KÉSZ | Bitenkénti AND                 |
| `\|`     | ✅ KÉSZ | ✅ KÉSZ | Bitenkénti OR                  |
| `^`      | ✅ KÉSZ | ✅ KÉSZ | Bitenkénti XOR                 |
| `~`      | ✅ KÉSZ | ✅ KÉSZ | Bitenkénti NOT                 |
| `<<`     | ✅ KÉSZ | ✅ KÉSZ | Balra shift, 16-bit részleges  |
| `>>`     | ✅ KÉSZ | ✅ KÉSZ | Jobbra shift, 16-bit részleges |

### 5.5 Értékadó operátorok

| Operátor | Státusz | Megjegyzés                                                 |
| -------- | ------- | ---------------------------------------------------------- |
| `=`      | ✅ KÉSZ  | Alap értékadás                                             |
| `+=`     | ✅ KÉSZ  | +=1 optimalizált (INC), egyéb `a = a + n`-re transzformált |
| `-=`     | ✅ KÉSZ  | -=1 optimalizált (DEC), egyéb `a = a - n`-re transzformált |
| `*=`     | ✅ KÉSZ  | Transzformált `a = a * b`-re                               |
| `/=`     | ✅ KÉSZ  | Transzformált `a = a / b`-re                               |
| `%=`     | ✅ KÉSZ  | Transzformált `a = a % b`-re                               |
| `&=`     | ✅ KÉSZ  | Transzformált `a = a & b`-re                               |
| `\|=`    | ✅ KÉSZ  | Transzformált `a = a \| b`-re                              |
| `^=`     | ✅ KÉSZ  | Transzformált `a = a ^ b`-re                               |
| `<<=`    | ✅ KÉSZ  | Transzformált `a = a << b`-re                              |
| `>>=`    | ✅ KÉSZ  | Transzformált `a = a >> b`-re                              |

## 6. Vezérlési szerkezetek

### 6.1 Elágazások

| Feature        | Státusz | Megjegyzés          |
| -------------- | ------- | ------------------- |
| `if`           | ✅ KÉSZ  | Egyszerű feltétel   |
| `if-else`      | ✅ KÉSZ  | Kétirányú elágazás  |
| `if-elif-else` | ✅ KÉSZ  | Többirányú elágazás |

### 6.2 Ciklusok

| Feature                 | Státusz | Megjegyzés                 |
| ----------------------- | ------- | -------------------------- |
| `while`                 | ✅ KÉSZ  | Elöltesztelő ciklus        |
| `for ... in range()`    | ✅ KÉSZ  | Számlálós ciklus           |
| `range(end)`            | ✅ KÉSZ  | 0-tól end-1-ig             |
| `range(start, end)`     | ✅ KÉSZ  | start-tól end-1-ig         |
| `range(start,end,step)` | ✅ KÉSZ  | Pozitív és negatív lépésköz |
| `break`                 | ✅ KÉSZ  | Ciklusból kilépés          |
| `continue`              | ✅ KÉSZ  | Következő iterációra ugrás |

## 7. Függvények

| Feature                 | Státusz     | Megjegyzés                            |
| ----------------------- | ----------- | ------------------------------------- |
| `def` deklaráció        | ✅ KÉSZ      | Kötelező típus annotációk             |
| Paraméterek             | ✅ KÉSZ      | Stack-en átadva                       |
| Visszatérési érték      | ✅ KÉSZ      | A regiszter (byte) / retval ZP (word) |
| `return` utasítás       | ✅ KÉSZ      | Érték vagy üres                       |
| Lokális változók        | ✅ KÉSZ      | Stack frame, FP-relatív               |
| Rekurzió                | ✅ KÉSZ      | Stack-alapú, ~50 szint mélység        |
| `main()` belépési pont  | ✅ KÉSZ      | Program itt indul                     |
| `@lowercase` dekorátor      | ✅ KÉSZ      | Kisbetűs mód                          |
| `@standalone` dekorátor     | ✅ KÉSZ      | BASIC ROM ki, végtelen ciklus végén   |
| `@short_branches` dekorátor | ✅ KÉSZ      | Mindig rövid branch (lásd O8)         |
| Nested függvények           | 🔧 VALIDÁCIÓ | Tiltva (helyes viselkedés)            |

## 8. Osztályok

| Feature                  | Státusz     | Megjegyzés                              |
| ------------------------ | ----------- | --------------------------------------- |
| `class` deklaráció       | ✅ KÉSZ      | Kötelező property típusok               |
| Property-k               | ✅ KÉSZ      | self.x és obj.x read/write működik      |
| Property default értékek | ✅ KÉSZ      | Konstruktorban inicializálva            |
| Metódusok                | ✅ KÉSZ      | self rejtett paraméterként stack-en     |
| `__init__` konstruktor   | ✅ KÉSZ      | Paraméterekkel hívható                  |
| `__str__` metódus        | ✅ KÉSZ       | `str(obj)` hívja `obj.__str__()`-t      |
| Egyszeres öröklés        | ✅ KÉSZ      | Property-k öröklődnek                   |
| Többszörös öröklés       | 🔧 VALIDÁCIÓ | Tiltva (helyes viselkedés)              |
| Nested class-ok          | 🔧 VALIDÁCIÓ | Tiltva (helyes viselkedés)              |
| Objektum példányosítás   | ✅ KÉSZ      | Counter() konstruktor hívás             |
| Objektum paraméterátadás | ✅ KÉSZ      | alias[ClassName] paraméterként          |
| Objektum visszatérés     | ✅ KÉSZ       | `alias[T]` visszatérés + automatikus másolás |
| Memory-mapped property   | ✅ KÉSZ      | byte[0x0400] property típus             |

## 9. Beépített függvények

| Függvény     | Validáció | Code Gen  | Megjegyzés                            |
| ------------ | --------- | --------- | ------------------------------------- |
| `print()`    | ✅ KÉSZ    | ✅ KÉSZ    | Több érték, nincs szeparátor          |
| `printsep()` | ✅ KÉSZ    | ✅ KÉSZ    | Egyedi szeparátorral                  |
| `sprint()`   | ✅ KÉSZ    | ✅ KÉSZ    | String bufferbe írás                  |
| `str()`      | ✅ KÉSZ    | ✅ KÉSZ    | Primitívek + `obj.__str__()` hívás    |
| `len()`      | ✅ KÉSZ    | ✅ KÉSZ    | String/array hossz                    |
| `size()`     | ✅ KÉSZ    | ✅ KÉSZ    | Memória méret byte-okban              |
| `getkey()`   | ✅ KÉSZ    | ✅ KÉSZ    | Non-blocking billentyű                |
| `waitkey()`  | ✅ KÉSZ    | ✅ KÉSZ    | Blocking billentyű                    |
| `abs()`      | ✅ KÉSZ    | ✅ KÉSZ    | sbyte→byte, int→word (előjel nélküli)   |
| `min()`      | ✅ KÉSZ    | ✅ KÉSZ    | min(a,b), signed/unsigned, 8/16-bit   |
| `max()`      | ✅ KÉSZ    | ✅ KÉSZ    | max(a,b), signed/unsigned, 8/16-bit   |
| `int()`      | ✅ KÉSZ    | ✅ KÉSZ    | Típuskonverzió int-re (16-bit signed) |
| `word()`     | ✅ KÉSZ    | ✅ KÉSZ    | Típuskonverzió word-re (16-bit uns.)  |
| `byte()`     | ✅ KÉSZ    | ✅ KÉSZ    | Típuskonverzió byte-ra (8-bit uns.)   |
| `sbyte()`    | ✅ KÉSZ    | ✅ KÉSZ    | Típuskonverzió sbyte-ra (8-bit sign.) |
| `char()`     | ✅ KÉSZ    | ✅ KÉSZ    | Típuskonverzió char-ra (print/concat) |
| `bool()`     | ✅ KÉSZ    | ✅ KÉSZ    | Típuskonverzió bool-ra (0/nem-0)      |
| `float()`    | ✅ KÉSZ    | ✅ KÉSZ    | int/f16/f32 → float konverzió         |
| `f16()`      | ✅ KÉSZ    | ✅ KÉSZ    | int/float literál → f16               |
| `f32()`      | ✅ KÉSZ    | ✅ KÉSZ    | int/float literál → f32               |

## 10. String műveletek

| Művelet                  | Státusz | Megjegyzés                         |
| ------------------------ | ------- | ---------------------------------- |
| String literál           | ✅ KÉSZ  | Pascal-stílusú, deduplikált        |
| String értékadás         | ✅ KÉSZ  | `__R_copy_str` helper              |
| Escape szekvenciák       | ✅ KÉSZ  | `\n`, `\\`, `\"`, `\0`, `\xHH`     |
| String indexelés olvasás | ✅ KÉSZ  | `s[i]` - konstans és változó index |
| String indexelés írás    | ✅ KÉSZ  | `s[i] = 'x'` - konstans/változó    |
| Negatív index (string)   | ✅ KÉSZ  | `s[-1]` - Python-stílus, sbyte/int |
| String összefűzés (`+`)  | ✅ KÉSZ  | `s1 + s2` - temp buffer SSP-n      |
| String ismétlés (`*`)    | ✅ KÉSZ  | `s * n` és `n * s` - 255 max       |
| `len(string)`            | ✅ KÉSZ  | O(1) - első byte olvasás           |

## 11. Tömb műveletek

| Művelet                | Státusz | Megjegyzés                   |
| ---------------------- | ------- | ---------------------------- |
| Tömb deklaráció        | ✅ KÉSZ  | `arr: array[type, size]`     |
| Tömb fill inicializálás| ✅ KÉSZ  | `arr: array[...] = [literal]`|
| Tömb indexelés olvasás | ✅ KÉSZ  | `arr[i]` - byte/word elemek  |
| Tömb indexelés írás    | ✅ KÉSZ  | `arr[i] = x` - byte/word     |
| Negatív index (array)  | ✅ KÉSZ  | `arr[-1]` - Python-stílus    |
| `len(array)`           | ✅ KÉSZ  | Compile-time konstans        |
| `size(array)`          | ✅ KÉSZ  | elemszám × elemméret         |

## 12. Memória és változókezelés

| Feature                  | Státusz     | Megjegyzés                     |
| ------------------------ | ----------- | ------------------------------ |
| Lokális változók         | ✅ KÉSZ      | Stack frame, FP-relatív címzés |
| Pascal-stílus deklaráció | ✅ KÉSZ      | Függvény elején kötelező       |
| Paraméter by-value       | ✅ KÉSZ      | Primitív típusoknál            |
| Paraméter by-reference   | ✅ KÉSZ      | Összetett típusoknál (pointer) |
| Memory-mapped változók   | ✅ KÉSZ      | Fix cím, nincs stack foglalás  |
| Globális változók        | 🔧 VALIDÁCIÓ | Tiltva (helyes viselkedés)     |

## 13. Compiler infrastruktúra

| Feature                | Státusz   | Megjegyzés                        |
| ---------------------- | --------- | --------------------------------- |
| Python AST parser      | ✅ KÉSZ    | `.pyco` = valid Python            |
| Preprocessor (include) | ✅ KÉSZ    | Szöveges beillesztés              |
| Preprocessor (const)   | ✅ KÉSZ    | Fordításidejű kiértékelés         |
| Semantic analyzer      | ✅ KÉSZ    | ~30 validációs szabály            |
| Symbol table           | ✅ KÉSZ    | Osztályok, függvények, konstansok |
| Code generator         | ✅ KÉSZ     | Minden nyelvi feature implementálva |
| Source mapping         | ✅ KÉSZ    | Debug címkék (`__SRC_file_line`)  |
| Kick Assembler output  | ✅ KÉSZ    | `.asm` fájl generálás             |
| CLI (`pycoc`)          | ✅ KÉSZ    | compile, -O, -I, -M kapcsolók     |
| E2E testing framework  | ✅ KÉSZ    | VICE emulátorral                  |

## 14. Runtime helperek

| Helper                 | Státusz | Megjegyzés                      |
| ---------------------- | ------- | ------------------------------- |
| `__R_copy_str`         | ✅ KÉSZ  | String másolás                  |
| `__R_print_str`        | ✅ KÉSZ  | String kiírás (CHROUT)          |
| `__R_print_byte`       | ✅ KÉSZ  | Byte decimális kiírás           |
| `__R_print_int`        | ✅ KÉSZ  | 16-bit unsigned kiírás          |
| `__R_print_signed_int` | ✅ KÉSZ  | 16-bit signed kiírás            |
| `__R_print_bool`       | ✅ KÉSZ  | "True"/"False" kiírás           |
| `__R_waitkey`          | ✅ KÉSZ  | Blocking keyboard read          |
| `__R_mul8`             | ✅ KÉSZ  | 8-bit szorzás (shift-and-add)   |
| `__R_mul16`            | ✅ KÉSZ  | 16-bit szorzás (shift-and-add)  |
| `__R_div8`             | ✅ KÉSZ  | 8-bit osztás (subtract loop)    |
| `__R_mod8`             | ✅ KÉSZ  | 8-bit maradék                   |
| `__R_div16`            | ✅ KÉSZ  | 16-bit osztás (long division)   |
| `__R_mod16`            | ✅ KÉSZ  | 16-bit maradék                  |
| `__R_cmp16`            | ✅ KÉSZ  | 16-bit unsigned összehasonlítás |
| `__R_cmp16_signed`     | ✅ KÉSZ  | 16-bit signed összehasonlítás   |
| `__R_sprint_*`         | ✅ KÉSZ  | Sprint helper család            |

---

## Összefoglaló statisztika

| Kategória                 | Kész   | Részben | Nincs | Összesen |
| ------------------------- | ------ | ------- | ----- | -------- |
| Alapvető szintaxis        | 6      | 0       | 0     | 6        |
| Modulrendszer             | 1      | 1       | 1     | 3        |
| Konstansok                | 4      | 0       | 0     | 4        |
| Primitív típusok          | 9      | 0       | 0     | 9        |
| Összetett típusok         | 7      | 0       | 0     | 7        |
| Típuskonverziók           | 6      | 0       | 0     | 6        |
| Aritmetikai operátorok    | 5      | 0       | 0     | 5        |
| Összehasonlító operátorok | 6      | 0       | 0     | 6        |
| Logikai operátorok        | 3      | 0       | 0     | 3        |
| Bitműveleti operátorok    | 6      | 0       | 0     | 6        |
| Értékadó operátorok       | 11     | 0       | 0     | 11       |
| Elágazások                | 3      | 0       | 0     | 3        |
| Ciklusok                  | 6      | 0       | 0     | 6        |
| Függvények                | 11     | 0       | 0     | 11       |
| Osztályok                 | 10     | 0       | 0     | 10       |
| Beépített függvények      | 18     | 0       | 0     | 18       |
| String műveletek          | 9      | 0       | 0     | 9        |
| Tömb műveletek            | 7      | 0       | 0     | 7        |
| Memória és változókezelés | 6      | 0       | 0     | 6        |
| Compiler infrastruktúra   | 8      | 0       | 0     | 8        |
| Runtime helperek          | 18     | 0       | 0     | 18       |
| **ÖSSZESEN**              | **160**| **1**   | **2** | **163**  |

**Készültségi fok: ~98% (160 kész) - Csak a modulrendszer importja hiányzik!**

> **Megjegyzés:** A "🔧 VALIDÁCIÓ (tiltva)" elemek (nested fv, többszörös öröklés, nested class, globális változók)
> **KÉSZ**-nek számítanak, mert a helyes viselkedés az, hogy tiltva vannak és a fordító hibát jelez.

---

## Prioritásos TODO lista

### ✅ P1 - Kritikus - MIND KÉSZ!
1. ✅ ~~**16-bit szorzás** (`__R_mul16`)~~ - KÉSZ (2024-12-01)
2. ✅ ~~**Osztás és maradék** (`__R_div8`, `__R_div16`, `__R_mod8`, `__R_mod16`)~~ - KÉSZ (2024-12-01)
3. ✅ ~~**Float code generation**~~ - KÉSZ (2025-12-03) - 32-bit MBF, 72 E2E teszt
4. ✅ ~~**User-defined class code gen**~~ - KÉSZ (konstruktor, metódusok, öröklés)
5. ✅ ~~**Memory-mapped array indexelés**~~ - KÉSZ (2024-12-02) - `parse_type_annotation` javítva

### ✅ P2 - Fontos - MIND KÉSZ!
4. ✅ ~~**Tömb/String indexelés**~~ - KÉSZ (2024-12-02) `arr[i]`, `s[i]` olvasás/írás, negatív index
5. ✅ ~~**String összefűzés/ismétlés**~~ - KÉSZ (2025-12-03) `s1 + s2`, `s * n`, deferred cleanup
6. ✅ ~~**Fixed-point típusok**~~ - KÉSZ (2025-12-04) f16/f32, +−*/, print, float konverzió
7. 🔶 **Import modulrendszer** - Könyvtárak használatához (egyetlen hiányzó feature)

### ✅ P3 - Hasznos - MIND KÉSZ!
7. ✅ ~~**abs(), min(), max()**~~ - KÉSZ (2024-12-02)
8. ✅ ~~**`__str__` metódus**~~ - KÉSZ (2025-12-02) `str(obj)` hívja `obj.__str__()`-t
9. ✅ ~~**String indexelés írás**~~ - KÉSZ (2024-12-02) `s[i] = 'x'` + negatív index
10. ✅ ~~**Típuskonverziós függvények**~~ - KÉSZ (2024-12-01) `int()`, `word()`, `byte()`, `sbyte()`, `char()`, `bool()`, `float()`, `f16()`, `f32()`

### P4 - Optimalizációk (nice to have)
- Az összes nyelvi feature **KÉSZ**!
- A P4 csak optimalizációkat tartalmaz (O1-O7), lásd az Optimalizálási lehetőségek szekciót

---

## Optimalizálási lehetőségek

A 6502-n bizonyos műveletek nagyságrendekkel gyorsabbak másoknál. Ezeket a fordító automatikusan alkalmazhatná.

### O1 - Strength Reduction (2-hatvány szorzás/osztás)

A szorzás és osztás 2 hatványaival triviálisan gyorsítható bit-shifteléssel:

| Eredeti   | Optimalizált | Ciklusok (kb.) | Megjegyzés                      |
| --------- | ------------ | -------------- | ------------------------------- |
| `a *= 2`  | `a <<= 1`    | ~2 vs ~100     | ASL (8-bit) vagy 2×ASL (16-bit) |
| `a *= 4`  | `a <<= 2`    | ~4 vs ~100     | 2× vagy 4× ASL                  |
| `a *= 8`  | `a <<= 3`    | ~6 vs ~100     | 3× vagy 6× ASL                  |
| `a /= 2`  | `a >>= 1`    | ~2 vs ~150     | LSR (8-bit) vagy 2×LSR (16-bit) |
| `a /= 4`  | `a >>= 2`    | ~4 vs ~150     | 2× vagy 4× LSR                  |
| `a % 2`   | `a & 1`      | ~2 vs ~150     | AND #$01                        |
| `a % 4`   | `a & 3`      | ~2 vs ~150     | AND #$03                        |
| `a % 256` | `a & 255`    | ~2 vs ~150     | Alsó byte (word-nél ingyen!)    |

**Implementáció:** A preprocessor vagy code generator felismeri a 2-hatvány konstansokat és automatikusan átalakítja.

### O2 - Konstans szorzás dekompozíció

Nem 2-hatvány konstansok is gyorsíthatók shift+add kombinációval:

| Eredeti  | Optimalizált          | Magyarázat                   |
| -------- | --------------------- | ---------------------------- |
| `a * 3`  | `(a << 1) + a`        | 2a + a                       |
| `a * 5`  | `(a << 2) + a`        | 4a + a                       |
| `a * 6`  | `(a << 2) + (a << 1)` | 4a + 2a                      |
| `a * 7`  | `(a << 3) - a`        | 8a - a                       |
| `a * 9`  | `(a << 3) + a`        | 8a + a                       |
| `a * 10` | `(a << 3) + (a << 1)` | 8a + 2a                      |
| `a * 12` | `(a << 3) + (a << 2)` | 8a + 4a                      |
| `a * 15` | `(a << 4) - a`        | 16a - a                      |
| `a * 40` | `(a << 5) + (a << 3)` | 32a + 8a (C64 sorszélesség!) |

**Implementáció:** Lookup tábla a leggyakoribb szorzókhoz, vagy algoritmus ami shift+add sorozatot generál.

### O3 - Increment/Decrement optimalizáció

| Eredeti  | Jelenlegi  | Státusz |
| -------- | ---------- | ------- |
| `a += 1` | `INC addr` | ✅ KÉSZ  |
| `a -= 1` | `DEC addr` | ✅ KÉSZ  |

> **Megjegyzés:** A `a += 2` → `INC; INC` optimalizáció **nem éri meg**!
> `INC; INC` = 10 ciklus, `CLC; LDA; ADC #2; STA` = 10 ciklus (ZP). Ugyanannyi!

### O4 - Peephole optimalizációk

| Minta                   | Optimalizált    | Megjegyzés                   |
| ----------------------- | --------------- | ---------------------------- |
| `lda #0; sta x; lda #0` | `lda #0; sta x` | Redundáns load               |
| `sta tmp; lda tmp`      | `sta tmp`       | Redundáns load-back          |
| `pha; pla`              | (törlés)        | Felesleges push/pop          |
| `clc; adc #0`           | (törlés)        | Null hozzáadás               |
| `lda x; cmp #0`         | `lda x`         | LDA már beállítja a Z flaget |
| `jmp next; next:`       | (törlés)        | Jump a következő utasításra  |

### O5 - Zero Page használat

| Lehetőség                | Státusz | Megjegyzés                                               |
| ------------------------ | ------- | -------------------------------------------------------- |
| User-defined ZP változók | ✅ KÉSZ  | `i: byte[0x02]` - kézi, teljes kontroll                  |
| Automatikus ZP allokáció | ⛔ N/A   | Tudatosan NINCS - ütközéshez vezetne (KERNAL, IRQ, stb.) |

**A $10-$7F tartomány (112 byte) szabadon használható.** A programozó felelőssége az ütközések elkerülése.

```python
# Gyors loop változó ZP-ben
def fast_loop():
    i: byte[0x10]           # Zero Page - ~30% gyorsabb!

    for i in range(0, 100):
        # ...
```

**Tipp:** A `docs/language_reference_hu.md` "Memory-mapped változók" szekciója részletesen leírja a használatot.

### O6 - Loop optimalizációk

| Lehetőség                        | Státusz | Megjegyzés                         |
| -------------------------------- | ------- | ---------------------------------- |
| `for _ in range()` optimalizáció | ❌ NINCS | Visszafelé számlálás automatikusan |
| Loop unrolling                   | ❌ NINCS | Kis, fix iterációszámú ciklusoknál |
| Loop invariant kiemelés          | ❌ NINCS | Konstans kifejezések ciklus elé    |

**`_` változó konvenció (Python-ból átvéve):**

A `_` változónév azt jelzi: "nem érdekel az érték, csak a lefutások száma". Ezt a fordító felismerheti és **automatikusan visszafelé számlálásra** optimalizálhatja:

```python
# User írja:
for _ in range(10):       # "10-szer fuss le"
    do_something()

# Fordító generál (visszafelé, gyorsabb):
#   lda #10
# loop:
#   ...do_something...
#   dex                   # vagy dec zp
#   bne loop              # Z flag-et használja, nincs CMP!
```

| Forma                    | Viselkedés     | Miért?                                        |
| ------------------------ | -------------- | --------------------------------------------- |
| `for _ in range(10)`     | ✅ Optimalizált | `_` = nem használt, visszafelé mehet          |
| `for _ in range(0, 10)`  | ✅ Optimalizált | Ugyanaz, explicit 0 start                     |
| `for i in range(10)`     | Normál         | `i` értéke számíthat a ciklusban              |
| `for _ in range(5, 15)`  | ❌ **HIBA!**    | Ha `_`, minek start? Használj `range(10)`-et! |
| `for _ in range(0,10,2)` | ❌ **HIBA!**    | Ha `_`, minek step? Használj `range(5)`-öt!   |

**Ciklusszám:** ~30% gyorsulás byte változóval, ~50% word-del (nincs 16-bit CMP)!

### O7 - Egyéb lehetőségek

| Lehetőség                        | Státusz | Megjegyzés                                 |
| -------------------------------- | ------- | ------------------------------------------ |
| Tail call optimization           | ❌ NINCS | `JMP` a `JSR+RTS` helyett                  |
| Common subexpression elimination | ❌ NINCS | Azonos kifejezések újrahasználata          |
| Dead code elimination            | ⛔ SOHA  | Szándékosan NINCS (asm hívás, külső modul) |
| `@inline` dekorátor              | ❌ NINCS | User kéri explicit, nem automatikus        |
| Constant folding                 | ✅ KÉSZ  | Fordításidejű konstans számítás            |
| Self-modifying code              | ❌ NINCS | Haladó, veszélyes, de gyors                |

### O8 - Smart Branch Distance Kezelés

A 6502 relatív branch utasításai (BEQ, BNE, BCC, BCS, stb.) csak **±127 byte** távolságra tudnak ugrani. Ha a célcímke ennél távolabb van, assembly fordítási hiba keletkezik.

| Lehetőség                       | Státusz | Megjegyzés                                     |
| ------------------------------- | ------- | ---------------------------------------------- |
| Long branch nagy blokkoknál     | ✅ KÉSZ  | Konzervatív AST becslés alapján (>50 byte)     |
| `@short_branches` dekorátor     | ✅ KÉSZ  | User felülírhatja, mindig rövid branch-et kap  |
| Pontosabb méretbecslés          | ❌ NINCS | Finomhangolt becslés később optimalizálható    |

**Működés:**
- **Alapértelmezett:** Konzervatív AST-alapú méretbecslés. Ha a blokk becsült mérete >50 byte, automatikusan long branch pattern:
  ```asm
  ; Normál (±127 byte limit):
  beq target

  ; Long branch (nincs limit):
  bne skip         ; Invertált feltétel
  jmp target       ; JMP-nek nincs távolság limitje
  skip:
  ```
- **`@short_branches` dekorátor:** Ha a user tudja, hogy a függvény kicsi, kényszerítheti a normál branch-ek használatát:
  ```python
  @short_branches
  def fast_function():
      if condition:
          quick_action()
  ```
  **Figyelem:** Ha a blokk mégis túl nagy, assembly hiba keletkezik! A user felelőssége.

**Overhead:**
| Eset          | Méret   | Ciklusok  |
| ------------- | ------- | --------- |
| Normál branch | 2 byte  | 2-3 cycle |
| Long branch   | 5 byte  | 5-6 cycle |

A +3 byte és +3 ciklus overhead csak nagy blokkoknál jelentkezik, ahol amúgy sem számít.

**`@inline` dekorátor (tervezett):**

```python
@inline
def double(x: byte) -> byte:
    return x << 1

def main():
    a: byte = 5
    b: byte = double(a)   # Nem JSR, hanem beágyazott kód!
```

A user felelőssége eldönteni, mikor éri meg (kis függvény, gyakran hívott, nincs rekurzió).

---

*Utolsó frissítés: 2025-12-04 - **NYELVI FEATURE-ÖK KÉSZEN!** 160/163 feature (98%), csak import rendszer hiányzik*
