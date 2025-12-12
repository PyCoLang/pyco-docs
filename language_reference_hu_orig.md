# PyCo nyelvi referencia

A PyCo egy **Python-szerű nyelv, Pascal-szerű működéssel**, ami gépközeli programozást tesz lehetővé.

**Inspiráció:**
- **Python:** olvasható szintaxis, behúzás alapú blokkok, osztályok
- **Pascal:** strict típusosság, előre deklarált változók, Pascal-típusú stringek

**Jellemzők:**
- Gyors és memória hatékony
- Egyszerű, könnyen tanulható
- Interpretálható és fordítható
- Moduláris: csak a használt függvények töltődnek be

**Célplatformok:** 8/16 bites rendszerek (C64, Arduino, stb.)

**Nyelvi korlátozások:**
- Nincsenek globális változók - csak konstansok (NAGYBETŰS) lehetnek modul szinten
- Változókat a függvény elején kell deklarálni (Pascal-stílus)
- Egyszálú végrehajtás
- Nincs dinamikus memóriakezelés (de könyvtárból elérhető)
- Függvények és osztályok csak modul szinten definiálhatók (nincs beágyazás)
- Import és include csak modul szinten használható

Példa program:

```python
# Ez egy comment
import sys  # importok


class Position:
    # Minden property-t deklarálni kell. Default érték itt adható meg
    x: int = 0
    y: int = 0


class Hero(Position):
    # Declarálni kell előre a propertyket
    score: int = 0

    def move_right(inc: int):  # `self`-et nem szabad kitenni
        self.score += inc  # Itt viszont már a `self`

def create_hero() -> Hero:
    return Hero()

def main():
    # A függvényekben is mindent kell előre deklarálni
    i: int

    print("Hello world")

```

## Nevek, azonosítók

A nevek csak kis- és nagybetűket, számokat és aláhúzást tartalmazhatnak, de nem kezdődhetnek számmal.
A kis- és nagybetűt a nyelv megkülönbözteti.

**Fenntartott nevek:** A `__` (dupla aláhúzás) prefixű nevek fenntartottak a rendszer számára. Felhasználói kód nem definiálhat ilyen nevű függvényt, metódust vagy változót. Kivételek a dokumentált speciális metódusok:
- `__init__` - konstruktor
- `__str__` - string reprezentáció (tervezett)

### Interpreter mód

A neveket az interpreter és a fordító is így tárolja, hogy hatékonyak legyenek:

A neveket a rendszer 1 bájtos, vagy 8 bájtos slotokban tárolja. Így az 1 betűs nevek kevesebb memóriát foglalnak el, mint a hosszú nevek és gyorsabban elérhetőek. Ha 8 karakternél hosszabb nevet adunk meg, akkor több slotot foglal el úgy, hogy az első slot utolsó bájtja egy `\0` karakterrel végződik. Innent tudja az interpreter, hogy a név folytatódik.

| Név         | Hossz  | Slotok száma | Magyarázat                                                                                                                    |
| ----------- | ------ | ------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `i`         | 1 bájt | Gyors slot   | Ez a gyors slotok egyikét foglalja el.                                                                                        |
| `count`     | 5 bájt | 1 slot       | Ez egy 8 bájtos slotot foglal el.                                                                                             |
| `abcdefgh`  | 8 bájt | 1 slot       | Ez pont elfér egy slotban, 8 bájt hosszú.                                                                                     |
| `abcdefghi` | 9 bájt | 2 slot       | Ez két slotot foglal el: az első slot utolsó bájtja egy `\0` karakterrel végződik, a második slot első bájtja a `h` karakter. |

Így tulajdonképpen lehet bármilyen hosszú nevet adni, de a rövid nevek gyorsabban elérhetőek.

### Ajánlott nevezési szabályok

#### Class nevek

A class neveket nagybetűvel kell kezdni. És CamelCase-ben kell megadni.

Példa:

```python
class MyClass:
    pass
```

#### Függvény nevek
A függvény neveket kisbetűvel kell kezdni. És snake_case-ben ajánlott megadni.

Példa:

```python
def my_function():
    pass
```

#### Változó nevek

A változó neveket kisbetűvel kell kezdni. És snake_case-ben ajánlott megadni.

Példa:

```python
my_variable = 0
```

## Include

Fájlok szöveges beillesztése az `include()` függvénnyel történik. Ez egy preprocesszor-szerű művelet: a fordító első lépésként beolvassa a megadott fájl tartalmát és beilleszti a hívás helyére.

```python
include("fájlnév")
```

```python
include("hardware")
include("constants")
```

**Mire használjuk:**
- Konstansok megosztása több fájl között
- Hardver definíciók (memóriacímek, regiszterek)
- Közös konfigurációk

**Példa:**

```python
# hardware.pyco
VIC = 0xD000
BORDER = VIC + 0x20
BACKGROUND = VIC + 0x21
```

```python
# game.pyco
include("hardware")

def main():
    border: byte[BORDER]

    border = 0
```

**Fontos:** Az `include()` nem tölt be lefordított modult, csak szövegesen bemásolja a fájl tartalmát. Konstansok és definíciók megosztására való.

## Import

Modulok betöltése az `import` kulcsszóval történik. Ez lefordított modulokat tölt be, amikből függvényeket és osztályokat használhatunk.

```python
import modulnév
```

```python
import c64
import math
```

**Egyszerű szabályok:**
- Nincsenek névterek (namespace) - egy modulnév egy fájlt jelent
- A fordító csak a ténylegesen használt függvényeket tölti be a modulból
- Ajánlott hárombetűs prefix a saját modulokhoz az ütközések elkerülésére (pl. `abc_utils`)

**Modul elérése:**

```python
import math

def example():
    x: float

    x = math.sin(3.14)
```

**Include vs Import:**

| Kulcsszó         | Mit csinál                    | Mikor használjuk                  |
| ---------------- | ----------------------------- | --------------------------------- |
| `include("név")` | Szövegesen beilleszti a fájlt | Konstansok, definíciók megosztása |
| `import név`     | Lefordított modult tölt be    | Függvények, osztályok használata  |

## Konstansok

A konstansok modul szintű, NAGYBETŰS névvel ellátott értékek. A fordító behelyettesíti őket a használat helyén - nincs futásidejű memóriafoglalás.

```python
BORDER = 0xD020
MAX_ENEMIES = 8
PLAYER_SPEED = 2
```

**Szabályok:**
- Modul szinten kell definiálni (függvényen kívül)
- A név NAGYBETŰS_SNAKE_CASE kell legyen
- Csak primitív literál vagy másik konstansból számított érték lehet
- A fordító fordítási időben helyettesíti be

**Konstans kifejezések:**

```python
VIC = 0xD000
BORDER = VIC + 0x20          # OK - konstansból számított
BACKGROUND = VIC + 0x21
SPRITE_BASE = VIC + 0x00
```

**Használat:**

```python
BORDER = 0xD020
MAX_ENEMIES = 8

def main():
    border: byte[BORDER]     # memory-mapped változónál
    enemies: array[Enemy, MAX_ENEMIES]  # tömb méreténél
    i: byte

    border = 0               # értékként
    for i in range(0, MAX_ENEMIES):
        # ...
```

**Fontos:** Globális változók NEM megengedettek a PyCo-ban. Minden modul szintű értékadás NAGYBETŰS kell legyen, és konstansként kezelődik. Ha kisbetűs globális változót próbálsz létrehozni, a fordító hibát jelez.

## Utasítások

A PyCo-ban egy sorban pontosan egy utasítás szerepelhet.

### Kommentek

A `#` karaktertől a sor végéig minden kommentnek számít, a fordító figyelmen kívül hagyja.

```python
def example():
    # Ez egy teljes soros komment
    x: int = 42  # Ez egy sor végi komment
```

**Megjegyzés:** Csak egysoros kommentek léteznek. A Pythonban használt többsoros string komment (`"""..."""`) itt nem működik, mert a PyCo nem támogat többsoros stringeket.

### Többsoros utasítások

Hosszú utasítások a sor végén `\` karakterrel törhetők több sorba:

```python
def example():
    result: int

    result = very_long_function_name(param1, param2) \
        + another_function(param3)
```

**Szabályok:**
- A `\` után nem lehet semmi (komment sem), csak újsor
- Stringek belsejében nem lehet sortörés
- Egymás melletti string literálok automatikusan összefűződnek:

```python
def example():
    s: string = "első sor\n" \
        "második sor\n" \
        "harmadik sor"

    # Ugyanaz mint:
    # s: string = "első sor\nmásodik sor\nharmadik sor"
```

Ez a string összefűzés fordítási időben történik, nincs futásidejű költség.

### Blokkok

A kettőspontra (`:`) végződő utasítások új blokkot nyitnak. A blokk tartalmát a következő sorokban 4 szóköz behúzással kell jelölni:

```python
def example():
    x: int = 10

    if x > 0:
        print("pozitív")
        x = x - 1
```

A blokk addig tart, amíg a behúzás megmarad. Üres blokkot a `pass` kulcsszóval jelölünk:

```python
def later():
    pass
```

### Elágazások

#### if

Feltételes végrehajtás:

```python
if feltétel:
    utasítások
```

#### if-else

Kétirányú elágazás:

```python
if feltétel:
    utasítások
else:
    utasítások
```

#### if-elif-else

Többirányú elágazás:

```python
if feltétel1:
    utasítások
elif feltétel2:
    utasítások
elif feltétel3:
    utasítások
else:
    utasítások
```

Az `elif` ágakból tetszőleges számú lehet. Az `else` ág opcionális.

### Ciklusok

#### while

Elöltesztelő ciklus - addig ismétel, amíg a feltétel igaz:

```python
while feltétel:
    utasítások
```

```python
def example():
    i: byte = 0

    while i < 10:
        print(i)
        i = i + 1
```

#### for

Számlálós ciklus egy tartományon:

```python
for változó in range(vég):
    utasítások

for változó in range(kezdet, vég):
    utasítások

for változó in range(kezdet, vég, lépés):
    utasítások
```

| Forma                       | Leírás                                       |
| --------------------------- | -------------------------------------------- |
| `range(vég)`                | 0-tól vég-1-ig iterál (lépés: 1)             |
| `range(kezdet, vég)`        | kezdettől vég-1-ig iterál (lépés: 1)         |
| `range(kezdet, vég, lépés)` | kezdettől vég-1-ig iterál egyedi lépésközzel |

```python
def example():
    i: byte

    # Egyszerű forma: 0-tól 9-ig
    for i in range(10):
        print(i)           # 0, 1, 2, ... 9

    # Kezdőértékkel: 5-től 9-ig
    for i in range(5, 10):
        print(i)           # 5, 6, 7, 8, 9

    # Lépésközzel: páros számok
    for i in range(0, 10, 2):
        print(i)           # 0, 2, 4, 6, 8

    # Visszafelé iterálás
    for i in range(10, 0, -1):
        print(i)           # 10, 9, 8, ... 1
```

**Szabályok:**
- A `range()` a végértéket már nem tartalmazza (félig nyílt intervallum)
- A `lépés` nem lehet 0
- Visszafelé iteráláshoz negatív lépés kell, és `kezdet > vég`
- Ha `lépés > 0` és `kezdet >= vég`, a ciklus nem fut le egyszer sem
- Ha `lépés < 0` és `kezdet <= vég`, a ciklus nem fut le egyszer sem

**Fontos:** A ciklusváltozót előre deklarálni kell! A PyCo-ban a változók függvény szinten élnek (nem blokk szinten), és minden változót a függvény elején kell deklarálni.

#### break és continue

A `break` kilép a ciklusból:

```python
def example():
    done: bool

    while True:
        if done:
            break
```

A `continue` a ciklus következő iterációjára ugrik:

```python
def example():
    i: byte

    for i in range(0, 10):
        if i == 5:
            continue       # 5-öt kihagyja
        print(i)
```

## Kifejezések

A kifejezés olyan kódrészlet, ami értéket ad vissza. Kifejezések lehetnek:

| Típus               | Példa                   |
| ------------------- | ----------------------- |
| Literál             | `42`, `"hello"`, `True` |
| Változó hivatkozás  | `x`, `my_var`           |
| Aritmetikai művelet | `a + b`, `x * 2`        |
| Összehasonlítás     | `x > 0`, `a == b`       |
| Logikai művelet     | `a and b`, `not x`      |
| Függvényhívás       | `foo()`, `len(s)`       |
| Attribútum elérés   | `obj.x`, `self.score`   |

A kifejezések utasítások részeként szerepelnek, például értékadás jobb oldalán vagy függvény argumentumaként.

### Literálok

A literálok fix értékek, amelyeket közvetlenül a forráskódban adunk meg.

#### Szám literálok

A számokat háromféle formátumban írhatjuk:

| Formátum      | Prefix | Példa                        | Decimális érték |
| ------------- | ------ | ---------------------------- | --------------- |
| Decimális     | -      | `42`, `1000`                 | 42, 1000        |
| Hexadecimális | `0x`   | `0x2A`, `0xFF`, `0xD020`     | 42, 255, 53280  |
| Bináris       | `0b`   | `0b00101010`, `0b11110000`   | 42, 240         |

```python
def example():
    border: byte[0xD020]      # VIC border regiszter (hex cím)
    mask: byte = 0b11110000   # felső 4 bit beállítva
    count: int = 100          # decimális érték

    border = 0                # fekete (decimális)
    border = 0x0E             # világoskék (hex)

    mask = mask & 0b00001111  # alsó 4 bit megtartása
```

**Mikor melyiket használjuk:**

| Formátum      | Tipikus használat                                    |
| ------------- | ---------------------------------------------------- |
| Decimális     | Általános értékek, számlálók, matematikai műveletek  |
| Hexadecimális | Memóriacímek, színkódok, hardver regiszterek         |
| Bináris       | Bitműveletek, bitmaszkok, flag-ek                    |

**Megjegyzés:** A prefix betűmérete nem számít: `0x`, `0X`, `0b`, `0B` egyaránt érvényes.

#### Egyéb literálok

| Típus     | Szintaxis        | Példa                         |
| --------- | ---------------- | ----------------------------- |
| Boolean   | `True`, `False`  | `done: bool = False`          |
| Karakter  | 1 karakter       | `c: char = "A"`               |
| String    | Idézőjel között  | `s: string = "Hello"`         |
| Float     | Tizedesponttal   | `f: float = 3.14`, `1.0e-5`   |

### Operátorok

#### Aritmetikai operátorok

| Operátor | Leírás    | Példa   |
| -------- | --------- | ------- |
| `+`      | Összeadás | `a + b` |
| `-`      | Kivonás   | `a - b` |
| `*`      | Szorzás   | `a * b` |
| `/`      | Osztás    | `a / b` |
| `%`      | Maradék   | `a % b` |

> **Fontos:** A művelet típusa az **operandusok típusától** függ, nem az eredmény változójától!
> `byte + byte` mindig 8-bites művelet, még ha `word` változóba kerül is az eredmény.
> Ha 16-bites műveletre van szükség, használj explicit konverziót: `word(a) + word(b)`.
> Lásd: [Típuskeverés műveletekben](#típuskeverés-műveletekben---nincs-automatikus-bővítés)

#### Összehasonlító operátorok

| Operátor | Leírás               | Példa    |
| -------- | -------------------- | -------- |
| `==`     | Egyenlő              | `a == b` |
| `!=`     | Nem egyenlő          | `a != b` |
| `<`      | Kisebb               | `a < b`  |
| `>`      | Nagyobb              | `a > b`  |
| `<=`     | Kisebb vagy egyenlő  | `a <= b` |
| `>=`     | Nagyobb vagy egyenlő | `a >= b` |

#### Logikai operátorok

| Operátor | Leírás       | Példa     |
| -------- | ------------ | --------- |
| `and`    | Logikai ÉS   | `a and b` |
| `or`     | Logikai VAGY | `a or b`  |
| `not`    | Logikai NEM  | `not a`   |

#### Bitműveleti operátorok

| Operátor | Leírás          | Példa    |
| -------- | --------------- | -------- |
| `&`      | Bitenkénti ÉS   | `a & b`  |
| `\|`     | Bitenkénti VAGY | `a \| b` |
| `^`      | Bitenkénti XOR  | `a ^ b`  |
| `~`      | Bitenkénti NEM  | `~a`     |
| `<<`     | Balra léptetés  | `a << 2` |
| `>>`     | Jobbra léptetés | `a >> 2` |

```python
def example():
    x: byte = 0b11001010

    x = x & 0x0F          # alsó 4 bit: 0b00001010
    x = x | 0x80          # legfelső bit beállítása
    x = x ^ 0xFF          # összes bit invertálása
    x = x << 1            # balra léptetés (szorzás 2-vel)
    x = x >> 1            # jobbra léptetés (osztás 2-vel)
```

#### Értékadó operátorok

| Operátor | Leírás                       | Egyenértékű  |
| -------- | ---------------------------- | ------------ |
| `=`      | Értékadás                    | `a = b`      |
| `+=`     | Összeadás és értékadás       | `a = a + b`  |
| `-=`     | Kivonás és értékadás         | `a = a - b`  |
| `*=`     | Szorzás és értékadás         | `a = a * b`  |
| `/=`     | Osztás és értékadás          | `a = a / b`  |
| `%=`     | Maradék és értékadás         | `a = a % b`  |
| `&=`     | Bitenkénti ÉS és értékadás   | `a = a & b`  |
| `\|=`    | Bitenkénti VAGY és értékadás | `a = a \| b` |
| `^=`     | Bitenkénti XOR és értékadás  | `a = a ^ b`  |
| `<<=`    | Balra léptetés és értékadás  | `a = a << b` |
| `>>=`    | Jobbra léptetés és értékadás | `a = a >> b` |

**Optimalizáció:** A `+= 1` és `-= 1` műveletek optimalizált gépi kódot generálnak:

| Változó típus      | `+= 1` kód                     | Sebesség   |
| ------------------ | ------------------------------ | ---------- |
| Memory-mapped byte | `inc $addr` (1 utasítás)       | ~6 ciklus  |
| Stack byte         | `lda/clc/adc/sta` (5 utasítás) | ~15 ciklus |
| Stack word/int     | 16-bit inkrement (10 utasítás) | ~25 ciklus |

Ezért érdemes a `i += 1` formát használni a `i = i + 1` helyett - a fordító felismeri és optimalizálja.

#### Operátor precedencia

A precedencia Python-t követi. Magasabb precedencia = előbb értékelődik ki.

| Precedencia         | Operátorok                       | Leírás                   |
| ------------------- | -------------------------------- | ------------------------ |
| 1 (legmagasabb)     | `()`                             | Zárójelezés              |
| 2                   | `**`                             | Hatványozás              |
| 3                   | `~`, `+x`, `-x`                  | Unáris operátorok        |
| 4                   | `*`, `/`, `%`                    | Szorzás, osztás, maradék |
| 5                   | `+`, `-`                         | Összeadás, kivonás       |
| 6                   | `<<`, `>>`                       | Bit léptetés             |
| 7                   | `&`                              | Bitenkénti ÉS            |
| 8                   | `^`                              | Bitenkénti XOR           |
| 9                   | `\|`                             | Bitenkénti VAGY          |
| 10                  | `==`, `!=`, `<`, `>`, `<=`, `>=` | Összehasonlítás          |
| 11                  | `not`                            | Logikai NEM              |
| 12                  | `and`                            | Logikai ÉS               |
| 13                  | `or`                             | Logikai VAGY             |
| 14 (legalacsonyabb) | `=`, `+=`, `-=`, stb.            | Értékadás                |

**Tipp:** Ha bizonytalan vagy, használj zárójelet!

## Típusok

> **„A memória az igazság, a típus csak szemüveg."**
>
> A PyCo-ban a típusok nem varázslatosan működnek - egyszerűen megmondják, hogyan értelmezzük a nyers bájtokat a memóriában. Ugyanaz a 4 byte lehet `Int32`, `UInt32`, `Word[2]` vagy `Byte[4]` - attól függ, milyen "szemüvegen" keresztül nézzük.

| Típus  | Leírás                               | Példa értékek              | Tartomány                                    |
| ------ | ------------------------------------ | -------------------------- | -------------------------------------------- |
| bool   | Logikai típus                        | True, False                | False = 0, True = minden más érték           |
| char   | Egyetlen karakter                    | 'a', 'b', 'c'              |                                              |
| string | Szöveg                               | "Hello world"              | maximum 255 karakter hosszú (+ 1 byte hossz) |
| byte   | 8 bites egész típus                  | 0, 127, 255                | 0..255                                       |
| sbyte  | Előjeles, 8 bites egész típus        | -128, 0, 127               | -128..127                                    |
| word   | Előjel nélküli, 16 bites egész típus | 0, 1024, 65535             | 0..65535                                     |
| int    | Előjeles, 16 bites egész típus       | -32768, 0, 32767           | -32768..32767                                |
| f16    | 8.8 fixpontos (16 bit)               | 1.5, -127.5                | -128.0..+127.996 (pontosság: 1/256)          |
| f32    | 16.16 fixpontos (32 bit)             | 1.5, -32000.5              | -32768.0..+32767.99998 (pontosság: 1/65536)  |
| float  | Lebegőpontos 32 bites típus          | 1.23, -4.56, 1e10, 1.2e-10 |                                              |

### Char

A `char` 1 bájtot foglal, egyetlen karaktert tárol. Technikailag ugyanaz mint a `byte`, de karakterként értelmezzük.

```python
def example():
    c: char = 'A'         # karakter literál
    b: byte = 65          # ugyanaz, de számként

    c = b                 # OK - szabadon konvertálható
    b = c                 # OK
```

**Kódolás:** Platform-függő. C64-en PETSCII, más platformokon ASCII.

**Mikor használjuk:**
- `char` - ha szöveget, karaktereket kezelünk (olvashatóbb)
- `byte` - ha számokkal, memóriával dolgozunk

### Fixed-point típusok (f16, f32)

A fixpontos típusok a lebegőpontos (`float`) és az egész (`int`) típusok között helyezkednek el: tört számokat tárolnak, de sokkal gyorsabbak, mint a float.

**Mikor használd?**
- Sprite pozíciók szubpixel pontossággal (smooth mozgás)
- Fizikai szimulációk (sebesség, gyorsulás)
- Bármilyen tört szám, ahol a sebesség fontosabb a nagy tartománynál

#### f16 (8.8 formátum)

A `f16` 2 bájtot foglal:
- **8 bit** egész rész: -128..+127
- **8 bit** tört rész: 1/256 ≈ 0.004 pontosság

```python
def example():
    x: f16 = f16(10)       # explicit konverzió kötelező!
    y: f16 = f16(3)
    z: f16

    z = x + y              # z = 13.0 (összeadás ugyanolyan gyors mint int!)
    z = x * y              # z = 30.0 (szorzás: gyorsabb mint float, de lassabb mint int)
```

#### f32 (16.16 formátum)

A `f32` 4 bájtot foglal:
- **16 bit** egész rész: -32768..+32767
- **16 bit** tört rész: 1/65536 ≈ 0.00002 pontosság

```python
def example():
    pi: f32 = f32(3.14159)  # float literál compile-time konvertálódik!
    radius: f32 = f32(100)
    area: f32

    area = pi * radius * radius
```

#### Explicit konverzió kötelező!

**FONTOS:** A `f16` és `f32` típusoknál az `f16()` és `f32()` konverziós függvény használata **kötelező**:

```python
def main():
    # HELYES - explicit konverzió
    x: f16 = f16(5)         # egész → f16
    y: f16 = f16(1.5)       # tört → f16 (compile-time!)
    z: f16 = f16(-2.25)     # negatív tört → f16

    # HIBÁS - implicit konverzió tiltott!
    # x: f16 = 5            # HIBA: Use f16(5) instead
    # y: f16 = 1.5          # HIBA: Use f16(1.5) instead
```

**Miért van ez így?**
1. **Range ellenőrzés**: Fordításkor ellenőrizhetjük, hogy az érték belefér-e (f16: -128..+127)
2. **Tudatos döntés**: A programozó explicit választja a pontosságot
3. **Float literálok**: A `f16(1.5)` compile-time konvertálódik - nincs runtime overhead!

#### Túlcsordulás viselkedés

A fixed-point típusoknál **wraparound** történik, mint a többi egész típusnál - nincs runtime ellenőrzés:

| Típus | Egész rész tartomány | Túlcsordulás példa         |
| ----- | -------------------- | -------------------------- |
| `f16` | -128..+127           | `f16(200)` → -56.0         |
| `f32` | -32768..+32767       | `f32(40000)` → -25536.0    |

```python
def example():
    x: f16

    # Túlcsordulás - az érték "körbefordul"
    x = f16(200)          # 200 > 127 → -56.0 (200 - 256 = -56)
    x = f16(-200)         # -200 < -128 → 56.0 (-200 + 256 = 56)

    # Művelet közben is előfordulhat
    x = f16(100)
    x = x + f16(50)       # 150 > 127 → -106.0
```

**Ez a PyCo filozófiája:**
- Nincs runtime ellenőrzés → gyorsabb kód
- A programozó felelőssége a helyes értéktartomány
- Ugyanaz a viselkedés, mint C-ben vagy assembly-ben

**Tipp:** Ha bizonytalan vagy, használj `f32`-t - nagyobb tartomány, de lassabb szorzás/osztás.

#### Sebesség összehasonlítás

| Művelet  | int  | f16  | f32   | float |
| -------- | ---- | ---- | ----- | ----- |
| Add/Sub  | ~10  | ~10  | ~20   | ~200  |
| Multiply | ~100 | ~150 | ~500  | ~500  |
| Divide   | ~200 | ~300 | ~1000 | ~1000 |

*(Ciklusok becsült száma, 1 MHz-en)*

A f16 **összeadása/kivonása ugyanolyan gyors, mint az int** - csak a szorzás/osztás lassabb.

#### Konverzió float-ra

Ha a fixed-point tartományán kívül eső értékre, vagy float műveletekre van szükség, a fixed-point értékek konvertálhatók float-ra:

```python
def example():
    x: f16 = f16(1.5)
    y: f32 = f32(-3.25)
    f: float

    # Explicit konverzió
    f = float(x)             # 1.5
    f = float(y)             # -3.25

    # Implicit konverzió (mint az int-nél)
    f = x                    # 1.5 - automatikus konverzió!
    f = y                    # -3.25

    # Hasznos debug célokra
    print(float(x))          # kiírja a pontos értéket
```

**Megjegyzés:** A fixed-point → float konverzió lassú művelet, ne használd ciklusban! A konverzió főleg debug célokra vagy ritka számításokhoz hasznos.

### Float

A `float` 32 bites lebegőpontos típus.

**Figyelem:** A float műveletek lassúak régi hardveren! A float könyvtár csak akkor töltődik be, ha a program használ float típust.

```python
def example():
    x: float = 3.14159
    y: float = 2.0

    x = x * y             # lassú művelet!
```

#### Float és integer típusok keverése

A float típus **kivételt képez** az automatikus típusbővítés szabálya alól! Ha egy műveletben float és integer típus keveredik, az integer automatikusan float-tá konvertálódik:

```python
def example():
    f: float = 10.5
    i: int = 3
    result: float

    # Implicit konverzió - az integer automatikusan float-tá alakul
    result = f + i            # 10.5 + 3.0 = 13.5 ✓
    result = f * i            # 10.5 * 3.0 = 31.5 ✓
    result = f - i            # 10.5 - 3.0 = 7.5 ✓
    result = f / i            # 10.5 / 3.0 = 3.5 ✓

    # Értékadásnál is implicit konverzió
    f = 42                    # f = 42.0 ✓ (nem kell float(42))
    f = i                     # f = 3.0 ✓

    # Augmented assignment is működik
    f = 10.0
    f += 1                    # f = 11.0 ✓
    f -= 1                    # f = 10.0 ✓
```

**FONTOS - Integer osztás marad integer!**

Ha **mindkét** operandus integer típusú, akkor az osztás **egész osztás** marad, még ha az eredmény float változóba kerül is:

```python
def example():
    a: int = 7
    b: int = 2
    result: float

    # HIBÁS: egész osztás! 7 / 2 = 3 (nem 3.5!)
    result = a / b            # result = 3.0, nem 3.5!

    # HELYES: legalább az egyik operandust float-tá kell alakítani
    result = float(a) / b     # 7.0 / 2 = 3.5 ✓
    result = a / float(b)     # 7 / 2.0 = 3.5 ✓
    result = float(a) / float(b)  # 7.0 / 2.0 = 3.5 ✓

    # Vagy használj float literált
    result = a / 2.0          # 7 / 2.0 = 3.5 ✓
```

| Művelet          | Típus            | Eredmény      |
| ---------------- | ---------------- | ------------- |
| `float OP int`   | float művelet    | float         |
| `int OP float`   | float művelet    | float         |
| `int OP int`     | **int művelet!** | int (csonkol) |
| `float OP float` | float művelet    | float         |

**Összefoglalás:**
- Float változóba írhatsz integer értéket explicit `float()` nélkül
- Ha egy műveletben van legalább egy float, az egész művelet float lesz
- Ha mindkét operandus integer, az eredmény is integer (egész osztás!)
- Osztásnál mindig gondold át, kell-e float konverzió

**Alternatíva:** Ha nincs szükség törtre, használj fix-pontos aritmetikát:

```python
def example():
    # Százalék számítás fix-pontosan (2 tizedesjegy)
    price: int = 1000     # $10.00
    discount: int = 15    # 15%

    price = price * (100 - discount) / 100  # $8.50 = 850
```

### String

A string Pascal-típusú: az első byte a hosszat tartalmazza, utána következnek a karakterek.

```
[hossz][karakter1][karakter2]...[karakterN]
```

Maximum 255 karakter hosszú lehet (a hossz 1 byte-on tárolódik).

#### Deklaráció és méret

```python
# Szintaxis
név: string = "konstans"           # méret a konstansból (6 byte)
név: string[méret]                 # explicit méret (méret+1 byte)
név: string[méret] = "konstans"    # explicit méret, előre feltöltve
név: string[méret][cím]            # memory-mapped string
```

**Szabályok:**

| Eset                   | Méret megadása | Magyarázat                                         |
| ---------------------- | -------------- | -------------------------------------------------- |
| Konstans inicializálás | Opcionális     | Méret a konstansból kiszámítható                   |
| Nincs inicializálás    | **Kötelező**   | Különben nem tudjuk, mennyi helyet foglaljunk      |
| Memory-mapped          | **Kötelező**   | Fix címre mappelt buffer, méret ismert kell legyen |

```python
def example():
    # Konstansból - méret automatikus
    greeting: string = "Hello"           # 6 byte (1 hossz + 5 kar)

    # Explicit méret - dinamikus tartalomhoz
    buffer: string[80]                   # 81 byte lefoglalva
    line: string[40]                     # 41 byte lefoglalva

    # Explicit méret + konstans - előre feltöltve, de bővíthető
    msg: string[100] = "Score: "         # 101 byte, kezdetben "Score: "

    hossz: byte
    hossz = len(greeting)                # 5 - egyetlen byte olvasás, O(1)
```

**Miért hasznos az explicit méret?**
- `sprint()` híváshoz buffer kell, amibe írunk
- Dinamikusan épített stringekhez
- Bővíthető tartalom (pl. score kiírás, ami változik)

**Miért Pascal-típusú:**
- Gyors hossz lekérdezés (O(1), nem kell végigmenni a stringen)
- Biztonságosabb (a hossz mindig ismert)
- KERNAL kompatibilis (pl. SETNAM is hossz paramétert vár)

**Escape szekvenciák:**

| Escape | Jelentés                      |
| ------ | ----------------------------- |
| `\n`   | Újsor (PETSCII RETURN)        |
| `\\`   | Backslash                     |
| `\"`   | Idézőjel                      |
| `\0`   | Null karakter                 |
| `\xHH` | Karakter hexadecimális kóddal |

```python
def example():
    s: string = "Első sor\nMásodik sor"
    path: string = "C:\\folder\\file"
    special: string = "\x41\x42\x43"    # "ABC"
```

**String műveletek:**

| Művelet  | Leírás            | Példa                    |
| -------- | ----------------- | ------------------------ |
| `len(s)` | Hossz lekérdezése | `len("hello")` → 5       |
| `+`      | Összefűzés        | `"ab" + "cd"` → `"abcd"` |
| `*`      | Ismétlés          | `"ab" * 3` → `"ababab"`  |

```python
def example():
    a: string = "Hello"
    b: string = " World"
    c: string

    c = a + b             # "Hello World"
    c = a * 2             # "HelloHello"
```

**Numerikus kifejezések** - mindig fordításkor kiértékelődnek:

```python
VIC = 0xD000
BORDER = VIC + 0x20      # → 0xD020 (fordításkor kiszámolva)
FLAGS = 0x80 | 0x01      # → 0x81 (fordításkor kiszámolva)
OFFSET = 40 * 8          # → 320 (fordításkor kiszámolva)
```

Ez automatikus, mert a numerikus értékeknek nincs memória overhead-je, és az assembly generáláshoz konkrét értékek kellenek.

**String ismétlés** - a user dönt a `const()` függvénnyel:

```python
# Futásidőben számolódik (NEM foglal helyet az adatszegmensben)
SEPARATOR = "-" * 40

# Fordításkor kiértékelve (beágyazva az adatszegmensbe)
SEPARATOR = const("-" * 40)    # 40 kötőjel tárolva
```

**Megjegyzés:** A `const()` egy preprocesszor direktíva a fordítási idejű kiértékeléshez. A `const()` belsejében csak konstans kifejezések használhatók (literálok, NAGYBETŰS konstansok, operátorok).

**Mikor használd a `const()`-ot?**

| Eset                         | Megoldás       | Miért                            |
| ---------------------------- | -------------- | -------------------------------- |
| Numerikus számítás           | Sima kifejezés | Automatikusan kiértékelődik      |
| Gyakran használt, fix string | `const()`      | Csak egyszer tárolódik, gyorsabb |
| Ritkán használt string       | Sima kifejezés | Nem foglal helyet, ha nem kell   |

**További string műveletek** (pl. substring, keresés, összehasonlítás) könyvtárból érhetők el, nem beépítettek.

**A string módosítható (mutable):**

A Pythonnal ellentétben a PyCo stringek indexelhetők és módosíthatók:

```python
def example():
    s: string = "hello"
    c: char

    c = s[0]             # 'h' - olvasás
    s[0] = 'H'           # "Hello" - írás
    s[4] = '!'           # "Hell!" - módosítás
```

**Negatív indexelés (Python-stílus):**

A PyCo támogatja a Python-stílusú negatív indexelést:

```python
def example():
    s: string = "hello"
    c: char
    i: sbyte

    c = s[-1]            # 'o' - utolsó karakter
    c = s[-2]            # 'l' - utolsó előtti
    c = s[-5]            # 'h' - első (ha 5 karakteres)

    # Változó indexszel is működik (sbyte vagy int)
    i = -1
    c = s[i]             # 'o'
```

**Megjegyzés:** A negatív index az `len + index` formulával számolódik. A `sbyte` -128..127 tartományú, tehát max 128 karaktert lehet visszafelé indexelni. Hosszabb stringekhez használj `int` típusú indexet.

**Figyelem:** Nincs index ellenőrzés! A határon túli indexelés és a túl hosszú string beírása nem definiált viselkedést okoz. A programozó felelőssége a helyes méretkezelés. Ez a tudatos tervezési döntés - nincs runtime overhead, cserébe teljes kontroll és gyorsaság.

#### Memory-mapped string

Fix memóriacímre mappelt string buffer:

```python
# Képernyő egy sorának szöveges kezelése
screen_line: string[40][0x0400]        # 41 byte a $0400 címtől

def example():
    screen_line = "Hello C64!"         # közvetlenül a képernyőre ír
```

**Megjegyzés:** Memory-mapped stringnél a méret megadása kötelező, mert a fordítónak tudnia kell, mekkora területet kezel.

**Ha 255 karakternél hosszabb szöveg kell:**

Használj `char` tömböt:

```python
def example():
    long_text: array[char, 1000]
```

### Tömbök (array)

Azonos típusú elemek fix méretű, **egydimenziós** sorozata.

```python
array[elem_típus, méret]
```

```python
def example():
    scores: array[int, 10]
    x: int
    i: int

    # Nullázás for ciklussal
    for i in range(10):
        scores[i] = 0

    scores[0] = 100     # első elem
    x = scores[9]       # utolsó elem
```

A tömb elemek értéke deklaráció után nem garantált (memória szemét). Az indexelés 0-tól kezdődik.

**Index típus:** A fordító automatikusan választ:

| Elemszám | Index típus | Magyarázat                |
| -------- | ----------- | ------------------------- |
| ≤ 256    | byte        | Gyorsabb indexelés        |
| > 256    | word        | Nagyobb tömbök támogatása |

**Tömb műveletek:**

| Művelet  | Leírás               | Példa              |
| -------- | -------------------- | ------------------ |
| `len(a)` | Elemszám lekérdezése | `len(scores)` → 10 |

```python
def example():
    data: array[byte, 100]
    n: byte

    n = len(data)         # 100
```

**Fill inicializálás:** A tömb kitölthető egy byte értékkel a deklarációnál:

```python
def example():
    zeros: array[byte, 100] = [0]       # 100 bájt nullázva
    ones: array[byte, 50] = [1]         # 50 bájt 1-essel
    pattern: array[byte, 256] = [0xaa]  # 256 bájt 0xAA-val
```

**Szabályok:**
- Csak egy elem a listában: `[érték]`
- Az érték byte literál kell legyen (0-255)
- Az egész memóriaterületet bájtonként tölti ki
- Word/int tömbökre is működik (mindkét bájtot azonos értékkel)

**Vagy for ciklussal:**

```python
def example():
    data: array[byte, 100]
    i: byte

    for i in range(100):
        data[i] = 0
```

**Figyelem:** Nincs index ellenőrzés! A határon túli indexelés nem definiált viselkedést okoz. A programozó felelőssége a helyes indexelés.

**Többdimenziós tömbök:** A nyelv csak egydimenziós tömböket támogat. Többdimenziós adatszerkezetekhez wrapper class használható:

```python
class Matrix:
    data: array[int, 50]  # 5 sor × 10 oszlop
    cols: int = 10

    def get(x: int, y: int) -> int:
        return data[y * cols + x]

    def set(x: int, y: int, value: int):
        data[y * cols + x] = value

def main():
    m: Matrix = Matrix()
    m.set(3, 2, 42)       # (3,2) pozícióba 42
    value: int = m.get(3, 2)
```

### Memory-mapped változók

Fix memóriacímhez kötött változók. A hardver regiszterek és memória közvetlen eléréséhez.

```python
név: típus[cím]
```

```python
border: byte[0xD020]        # VIC border color regiszter
bg: byte[0xD021]            # VIC background color
sprite0_x: byte[0xD000]     # Sprite 0 X koordináta
```

Használat:

```python
def example():
    x: byte

    border = 0              # STA $D020
    x = bg                  # LDA $D021
```

**Előny:** Gyorsabb, mert a fordító közvetlen memória műveleteket generál, nincs függvényhívás.

### Memory-mapped tömbök

Tömbök fix memóriacímre mappelve:

```python
név: array[típus, méret][cím]
```

```python
screen: array[byte, 1000][0x0400]   # Képernyő memória
colors: array[byte, 1000][0xD800]   # Szín memória
```

Ez gyakorlatilag pointer-szerű viselkedést ad:

```python
def example():
    i: byte = 0
    x: byte = 65

    screen[0] = 1           # $0400-ra ír
    screen[i] = x           # $0400 + i címre ír
```

### Alias (dinamikus referencia)

Az `alias` egy **típusos referencia**, ami futásidőben beállítható memóriacímre mutat. Úgy viselkedik, mintha az eredeti változó lenne - átlátszó elérést biztosít.

```python
alias[típus]
```

**Miben különbözik a memory-mapped változótól?**

| Tulajdonság      | Memory-mapped          | Alias                       |
| ---------------- | ---------------------- | --------------------------- |
| Cím megadása     | Fordítási időben (fix) | Futásidőben (dinamikus)     |
| Szintaxis        | `var: byte[0xD020]`    | `var: alias[byte]`          |
| Cím módosítható? | Nem                    | Igen, `alias()` függvénnyel |
| Használat        | Hardver regiszterek    | Dinamikus adatszerkezetek   |

#### Deklaráció és beállítás

```python
def example():
    # Eredeti változók
    enemy: Enemy
    score: int = 100
    buffer: array[byte, 100]

    # Alias deklarációk
    e: alias[Enemy]
    s: alias[int]
    b: alias[byte]

    # Alias beállítása az alias() függvénnyel
    # A második paraméter mindig egy cím (word típus)
    alias(e, addr(enemy))        # e most enemy-re mutat
    alias(s, addr(score))        # s most score-ra mutat
    alias(b, addr(buffer))       # b a buffer első elemére mutat

    # Fix címre is mutathat
    alias(s, 0xC000)             # s a $C000 címre mutat

    # Pointer aritmetika is lehetséges!
    alias(b, addr(buffer) + 10)  # b a 10. elemre mutat
```

#### Használat - átlátszó elérés

Az alias úgy viselkedik, **mintha az eredeti változó lenne**:

```python
def example():
    enemy: Enemy
    e: alias[Enemy]

    enemy.x = 10
    alias(e, addr(enemy))

    # Olvasás és írás - átlátszó!
    e.x = 50                     # = enemy.x = 50
    e.y = 100                    # = enemy.y = 100
    print(e.x)                   # = print(enemy.x)
    e.move(5, 5)                 # = enemy.move(5, 5)
```

**Primitív típusokra:**

```python
def example():
    score: int = 100
    s: alias[int]

    alias(s, addr(score))

    s = 200                      # = score = 200
    s += 50                      # = score += 50
    print(s)                     # = print(score) → 250
```

**Array elérés:**

```python
def example():
    buffer: array[byte, 100]
    b: alias[byte]

    alias(b, addr(buffer))       # Első elemre mutat

    b = 42                       # buffer[0] = 42
    b[5] = 99                    # buffer[5] = 99
    b[10] = b[5]                 # buffer[10] = buffer[5]
```

#### addr() - cím lekérdezése

Az `addr()` függvény visszaadja egy változó memóriacímét:

```python
def example():
    enemy: Enemy
    ptr: word

    ptr = addr(enemy)            # enemy memóriacíme
    print(ptr)                   # pl. 2048
```

Ez hasznos, ha a címet el akarod tárolni, átadni függvénynek, vagy pointer aritmetikát végezni:

```python
def example():
    enemies: array[Enemy, 10]
    e: alias[Enemy]
    i: byte

    # i. enemy elérése pointer aritmetikával
    i = 3
    alias(e, addr(enemies) + i * size(Enemy))
    e.x = 100                    # enemies[3].x = 100
```

#### Gyakorlati példa: újrahasznosítható lista kezelő

Az alias lehetővé teszi, hogy **ugyanazt a logikát különböző storage-okra** használjuk:

```python
class ByteList:
    data: alias[byte]            # Bármelyik byte array-re mutathat
    capacity: byte               # Maximum méret
    count: byte = 0              # Aktuális elemszám (belső!)

    def init(data_ptr: word, cap: byte):
        alias(data, data_ptr)
        capacity = cap
        count = 0

    def add(value: byte) -> bool:
        if count >= capacity:
            return False         # Tele van
        data[count] = value
        count += 1
        return True

    def get(index: byte) -> byte:
        return data[index]

    def pop() -> byte:
        count -= 1
        return data[count]

    def clear():
        count = 0

    def is_full() -> bool:
        return count >= capacity

    def is_empty() -> bool:
        return count == 0

def main():
    # Különböző storage-ok
    bullets: array[byte, 50]
    scores: array[byte, 10]

    # Ugyanaz a ByteList class, különböző buffer méretekkel
    # A len() fordítási időben ismert konstans!
    bullet_list: ByteList
    bullet_list.init(addr(bullets), len(bullets))
    bullet_list.add(42)
    bullet_list.add(99)

    score_list: ByteList
    score_list.init(addr(scores), len(scores))
    score_list.add(100)

    print(bullet_list.count)     # 2
    print(score_list.count)      # 1
```

**Figyelem:** Az alias nem ellenőrzi, hogy érvényes címre mutat-e! Inicializálatlan alias használata vagy rossz típusú adatra mutatás nem definiált viselkedést okoz. A programozó felelőssége a helyes használat.

#### Alias függvény paraméterként

**Szabály:** Összetett típusok (objektum, tömb, string) **csak alias-ként** adhatók át függvénynek!

Ez biztosítja, hogy mindig egyértelmű legyen: primitív típusok érték szerint mennek, összetett típusok referencia szerint.

```python
# ✅ HELYES - alias paraméter
def process_enemy(e: alias[Enemy]):
    e.x = 50                     # Módosítja az eredetit!
    e.health -= 10

def sum_array(arr: alias[array[byte, 10]]) -> word:
    total: word = 0
    i: byte
    for i in range(len(arr)):    # len() működik, mert méret a típusban!
        total += arr[i]
    return total

# ❌ HIBÁS - összetett típus közvetlenül
def bad_function(e: Enemy):      # FORDÍTÁSI HIBA!
    pass

def bad_array(arr: array[byte, 10]):  # FORDÍTÁSI HIBA!
    pass
```

**Híváskor a fordító automatikusan kezeli a címet:**

```python
def main():
    enemy: Enemy
    buffer: array[byte, 10]

    process_enemy(enemy)         # Automatikusan addr(enemy) lesz
    sum_array(buffer)            # Automatikusan addr(buffer) lesz
```

Nem kell `addr()`-ot írni - a fordító látja, hogy alias paramétert vár, és automatikusan a címet adja át.

**Méret a típusban vs méret nélkül:**

| Paraméter típus          | `len()` működik? | Használat                        |
| ------------------------ | ---------------- | -------------------------------- |
| `alias[array[byte, 10]]` | ✅ = 10           | Fix méretű tömbök                |
| `alias[array[byte]]`     | ❌ Fordítási hiba | Változó méret, count külön param |
| `alias[string[80]]`      | ✅ = 80           | Fix méretű buffer                |
| `alias[string]`          | ❌ Fordítási hiba | Változó méret                    |

```python
# Fix méretű - len() használható
def fill_buffer(buf: alias[array[byte, 100]]):
    i: byte
    for i in range(len(buf)):    # len(buf) = 100
        buf[i] = 0

# Változó méretű - count külön paraméter
def fill_any(buf: alias[array[byte]], count: byte):
    i: byte
    for i in range(count):       # count külön kapjuk
        buf[i] = 0
```

#### Alias visszatérési értékként

**Szabály:** Összetett típusok visszatérése **csak alias-ként** lehetséges!

```python
# ✅ HELYES - alias visszatérés
def create_enemy() -> alias[Enemy]:
    e: Enemy = Enemy()           # e: konkrét Enemy objektum a stack-en
    e.x = 100
    e.y = 50
    return e                     # return: e CÍMÉT adja vissza → alias!

# ❌ HIBÁS - összetett típus közvetlenül
def bad_create() -> Enemy:       # FORDÍTÁSI HIBA!
    pass
```

**A `return` működése alias visszatérésnél:**

Ha a függvény `alias[T]` típust ad vissza, a `return` **alias-szá alakítja** a lokális változót:

```python
def create_enemy() -> alias[Enemy]:
    e: Enemy = Enemy()     # e: konkrét Enemy objektum
    e.x = 42
    return e               # e alias-szá alakul a visszatéréskor!

def main():
    enemy: Enemy = create_enemy()  # Az alias MÁSOLÓDIK enemy-be
```

A `return e` tehát nem az `e` értékét adja vissza közvetlenül, hanem alias-szá alakítja - így a hívó hozzáférhet a függvényben létrehozott objektumhoz.

**Fontos:** Az alias visszatérési érték **csak az adott statement végéig érvényes!**

```python
def main():
    result: Enemy

    # OK - azonnal másolás
    result = create_enemy()      # result = a visszaadott objektum másolata

    # VESZÉLYES - az alias már nem érvényes!
    ptr: word = addr(create_enemy())  # ← Az alias élete a sor végén véget ér!
    # ptr most érvénytelen címre mutat!
```

Ez a "deferred cleanup" működési elve: az ideiglenes objektumok a statement végéig élnek a stack-en, utána automatikusan felszabadulnak.

**Helyes használat:**

```python
def main():
    # 1. Azonnali másolás változóba
    enemy: Enemy = create_enemy()

    # 2. Azonnali használat kifejezésben
    print(create_enemy().x)      # OK - még él a statement alatt

    # 3. Metódus hívás
    process_enemy(create_enemy()) # OK - az alias átadódik, majd felszabadul
```

#### Típuskategóriák összefoglalása

| Kategória     | Típusok                                                 | Paraméterként    | Visszatérésként         |
| ------------- | ------------------------------------------------------- | ---------------- | ----------------------- |
| **Primitív**  | `byte`, `sbyte`, `word`, `int`, `bool`, `char`, `float` | Érték szerint    | Érték (A reg / retval)  |
| **Összetett** | `array[T,N]`, `string[N]`, osztályok                    | ❌ TILOS          | ❌ TILOS                 |
| **Alias**     | `alias[T]`                                              | ✅ Pointer (auto) | ✅ Pointer (stmt végéig) |

#### Miért kötelező az alias?

**1. Explicit szemantika** - A kód olvasásakor azonnal látszik, mi történik:
```python
def modify(x: byte):           # Érték - az eredeti nem változik
    x = 100

def modify_ref(e: alias[Enemy]): # Referencia - az eredeti változik!
    e.health = 100
```

**2. Konzisztens `len()` viselkedés**:
```python
arr: array[byte, 10]
len(arr)                        # = 10, ismert

def fn(a: alias[array[byte, 10]]):
    len(a)                      # = 10, ismert a típusból

def fn2(a: alias[array[byte]]):
    len(a)                      # HIBA - nincs méret info
```

**3. Oktatási érték** - Megtanítja a pointer/referencia fogalmát, ami fontos a gépközeli programozásban.

**4. Gépi szintű átláthatóság** - Pontosan látszik, hogy 2 byte (pointer) megy át, nem az egész objektum.

## Típuskonverziók és overflow

### Implicit konverzió

A PyCo hardverközeli nyelv, ezért **minden numerikus típus szabadon konvertálható bármely másikba**. Nincs compile-time vagy runtime ellenőrzés - a programozó felelőssége a helyes típushasználat.

**Bővítés** (kisebb → nagyobb): az érték megmarad, felső byte-ok nullázódnak/előjel-kiterjesztés.

**Szűkítés** (nagyobb → kisebb): az alsó byte-ok másolódnak, a felső byte-ok elvesznek.

```python
def example():
    x: int = 1000         # 0x03E8
    b: byte
    w: word

    b = x                 # alsó byte: 0xE8 (232)
    w = x                 # 0x03E8 (1000) - elfér
    x = b                 # 0x00E8 (232) - bővítés
```

**Signed/unsigned konverzió:**

```python
def example():
    x: byte = 250         # 0xFA
    y: sbyte

    y = x                 # -6 (mert 0xFA előjelesen = -6)
```

Ez a 8-bites programozás egyik klasszikus "aha-élménye" - ugyanaz a bitminta más értéket jelent signed és unsigned értelmezésben.

### Bool

A `bool` 1 bájtot foglal, értéke bármilyen byte lehet:
- `0` = False
- bármi más = True

```python
def example():
    b: bool
    x: int = 256          # 0x0100 - alsó byte 0!

    b = x                 # alsó byte (0x00) tárolódik
    if b:                 # False, mert b = 0
        print("no")       # nem fut le

    if x:                 # True, mert x != 0 (int-ként vizsgálja)
        print("yes")      # lefut
```

**Feltételekben** a teljes érték vizsgálódik (nem csak az alsó byte). Nem primitív típusok (osztály példányok, tömbök) mindig True-nak számítanak feltételben.

### Típuskeverés műveletekben - NINCS automatikus bővítés!

**FONTOS:** A PyCo-ban **nincs automatikus típusbővítés** (type promotion)! A művelet az operandusok típusa szerint hajtódik végre, függetlenül attól, hova kerül az eredmény.

| Művelet       | Eredmény típus | Megjegyzés                      |
| ------------- | -------------- | ------------------------------- |
| `byte + byte` | `byte`         | 8-bites művelet, túlcsordulhat! |
| `word + word` | `word`         | 16-bites művelet                |
| `int + int`   | `int`          | 16-bites előjeles művelet       |

**Figyelem - gyakori hiba:**

```python
def example():
    a: byte = 200
    b: byte = 100
    result: word

    result = a + b       # HIBÁS: 8-bites összeadás! 200+100=44 (túlcsordulás)
    result = word(a) + word(b)   # HELYES: 16-bites összeadás = 300
```

**Miért van ez így?**

1. **Hatékonyság**: 8-bites művelet ~4 ciklus, 16-bites ~20 ciklus a 6502-n
2. **Átláthatóság**: A kód pontosan azt csinálja, amit leírsz
3. **Oktatási cél**: A programozónak értenie kell a gépi szintű működést

Lásd: [Típuskonverziós függvények](#típuskonverziós-függvények) a `word()`, `int()` stb. használatához.

### Overflow viselkedés

Túlcsorduláskor **wraparound** történik, mint C-ben:

| Típus   | Tartomány     | Overflow példa     |
| ------- | ------------- | ------------------ |
| `byte`  | 0..255        | 255 + 1 → 0        |
| `sbyte` | -128..127     | 127 + 1 → -128     |
| `word`  | 0..65535      | 65535 + 1 → 0      |
| `int`   | -32768..32767 | 32767 + 1 → -32768 |

**Nincs futásidejű ellenőrzés** - a PyCo a 6502 hardver természetes aritmetikáját követi. Nincs ellenőrzés, nincs lassulás, minden wraparound. Ez a retro hardver működésének tiszteletben tartása.

## Memória és értékadás

A PyCo-ban fontos megérteni, hogyan tárolódnak az adatok és hogyan adódnak át függvényeknek.

### Globális változók

**A PyCo-ban nincsenek globális változók.** Ez tudatos tervezési döntés:

- Egyszerűbb memóriakezelés - nincs szükség globális szimbólumtáblára futásidőben
- Átláthatóbb kód - minden adat vagy lokális, vagy paraméterként érkezik
- Biztonságosabb - nincs véletlen felülírás más modulból

**Alternatívák:**

| Cél                   | Megoldás                                     |
| --------------------- | -------------------------------------------- |
| Megosztott konstansok | NAGYBETŰS konstansok + `include()`           |
| Hardver elérés        | Memory-mapped változók (`var: byte[0xD020]`) |
| Állapot tárolás       | Osztály property-k                           |
| Közvetlen memória     | `alias[]` dinamikus címmel                   |

### Primitív és összetett típusok

| Kategória | Típusok                                                 | Tárolás           |
| --------- | ------------------------------------------------------- | ----------------- |
| Primitív  | `byte`, `sbyte`, `word`, `int`, `float`, `bool`, `char` | Érték közvetlenül |
| Összetett | `string`, `array`, class példányok                      | Memóriaterület    |

### Értékadás

**Primitív típusoknál** az érték másolódik:

```python
def example():
    # Deklarációk az elején
    a: int = 10
    b: int

    # Használat
    b = a        # b egy MÁSOLAT, értéke 10
    b = 20       # a még mindig 10
```

**Összetett típusoknál** szintén másolat készül:

```python
def example():
    # Deklarációk az elején
    pos1: Position = Position()   # OK - nincs konstruktor paraméter
    pos2: Position

    # Használat
    pos1.x = 10
    pos2 = pos1      # pos2 egy MÁSOLAT!
    pos2.x = 100

    # pos1.x = 10 (változatlan)
    # pos2.x = 100
```

**Fontos:** Ha a konstruktornak van paramétere, a deklaráció és a példányosítás külön sorban kell:

```python
def example():
    # Deklarációk az elején
    enemy: Enemy                  # csak deklaráció

    # Példányosítás a törzsben
    enemy = Enemy(100, 50)        # konstruktor hívás
```

### Paraméter átadás

**Primitív típusok érték szerint** adódnak át (másolat):

```python
def modify_int(x: int):
    x = 100      # lokális másolat módosul

def main():
    n: int = 10

    modify_int(n)
    # n még mindig 10 - az eredeti nem változott
```

**Összetett típusok referencia szerint** adódnak át (pointer):

```python
def modify_enemy(e: Enemy):
    e.x = 100        # az EREDETI objektum módosul!
    e.health = 50

def main():
    enemy: Enemy = Enemy()

    enemy.x = 10
    enemy.health = 100
    modify_enemy(enemy)
    # enemy.x = 100 - megváltozott!
    # enemy.health = 50 - megváltozott!
```

**Miért van ez így?**
- Hatékonyság: nagy objektumok másolása költséges lenne minden függvényhívásnál
- Nincs dinamikus memóriakezelés: nem kell garbage collector
- Ha nem akarod módosítani az eredetit, készíts előtte másolatot

### Visszatérési érték

**Primitív típusok** értékként térnek vissza:

```python
def add(a: int, b: int) -> int:
    return a + b

def main():
    result: int

    result = add(10, 20)    # result = 30
```

**Összetett típusok** pointerként térnek vissza, majd azonnal másolódnak:

```python
def create_enemy() -> Enemy:
    e: Enemy = Enemy()

    e.x = 50
    return e            # pointer tér vissza

def main():
    enemy: Enemy

    enemy = create_enemy()  # pointer azonnal átmásolódik enemy-be
```

**Property vagy paraméter visszaadása** (nem lokális változó):

```python
class Game:
    player: Enemy

    def get_player() -> Enemy:
        return self.player    # OK - self.player nem lokális

def process_enemy(e: Enemy) -> Enemy:
    e.health = 50
    return e                  # OK - paraméter, nem lokális
```

### Összefoglaló táblázat

| Típus     | Értékadás | Paraméter                    | Visszatérés       |
| --------- | --------- | ---------------------------- | ----------------- |
| Primitív  | másolat   | másolat (érték szerint)      | érték             |
| Összetett | másolat   | pointer (referencia szerint) | pointer → másolat |

### Ajánlott minták

**Objektum módosítása függvényben** (hatékony):

```python
def init_enemy(e: Enemy, x: int, y: int):
    e.x = x
    e.y = y
    e.health = 100

def main():
    enemy: Enemy = Enemy()

    init_enemy(enemy, 100, 50)
```

**Ha nem akarod módosítani az eredetit:**

```python
def process(e: Enemy):
    # e módosítása itt az eredetit is módosítja!
    e.health -= 10

def main():
    original: Enemy = Enemy()
    copy: Enemy

    original.health = 100
    copy = original       # másolat készül
    process(copy)         # csak a másolat módosul
    # original.health = 100 (változatlan)
    # copy.health = 90
```

## Nyelvi elemek

### Változók

A változók adatokat tárolnak a memóriában. A PyCo-ban minden változónak előre kell deklarálni a típusát. És a típustól függ, hogy mennyi memóriát foglal el.

```
név: típus = érték
```

Az érték megadása nem kötelező. De ha nincs megadva, akkor nem garantált az értéke, az lesz, ami épp az adott memória helyen van.

#### Változók élettartama

A PyCo-ban a változók **függvény szinten** élnek, nem blokk szinten. Ez azt jelenti:

- Minden változót a függvény elején kell deklarálni
- A változó a teljes függvényben látható és elérhető
- Nincs blokk-szintű scope (pl. egy `if` blokkban deklarált változó a blokkon kívül is él)

```python
def example():
    # Változók deklarálása az elején
    i: byte
    result: int = 0

    # Használat bárhol a függvényben
    for i in range(0, 10):
        result += i

    # Az 'i' és 'result' itt is elérhető
    print(result)
```

Ez a megközelítés egyszerűsíti a memóriakezelést és átláthatóbbá teszi, hogy egy függvény milyen változókat használ.

### Függvények

A függvényeket a `def` kulcsszóval kell deklarálni.

```
def név(paraméterek) -> típus:
    változó deklarációk
    törzs
    return érték
```

**A paraméterek típusát kötelező megadni:**

```python
def add(a: int, b: int) -> int:
    return a + b

def greet(name: string, times: byte):
    i: byte
    for i in range(0, times):
        print(name)
```

Ha nincs visszatérési érték, akkor nem szabad megadni visszatérési típust és a nyíl (`->`) sem kell. Továbbá a `return` kulcsszót sem szabad megadni.

**Fontos:** Beágyazott függvények nem megengedettek! Minden függvényt modul szinten kell definiálni. Ugyanígy az `import` és `include()` is csak modul szinten használható, nem függvényen belül.

```python
def foo() -> int:
    # Változók deklarálása a függvényben, kötelezően az elején
    i: int = 0
    w: word = 0

    # Törzs
    print(i)

    # Visszatérési érték
    return 0
```

#### Belépési pont: main()

A program végrehajtása a `main()` függvénynél kezdődik. Minden futtatható programnak tartalmaznia kell:

```python
def main():
    # A program itt indul
    print("Hello World!\n")
```

**Könyvtárak és main():**

A könyvtáraknak is lehet `main()` függvényük - ez teszt vagy demó kódot tartalmazhat:

```python
# mylib.pyco
def useful_function():
    # ...
    pass

def main():
    # Teszt kód - csak közvetlen futtatáskor fut le
    print("Testing mylib...\n")
    useful_function()
```

- **Közvetlen futtatás:** A `main()` lefut (teszteléshez, demóhoz)
- **Import-kor:** A `main()` nem töltődik be, nem foglal memóriát

#### Dekorátorok

A `main()` függvény speciális dekorátorokkal módosítható:

| Dekorátor     | Hatás                                                              |
| ------------- | ------------------------------------------------------------------ |
| `@lowercase`  | Kisbetűs karakterkészlet mód bekapcsolása                          |
| `@standalone` | BASIC ROM kikapcsolása (+8KB RAM), végtelen ciklus a program végén |

**`@lowercase`** - Kisbetűs mód

```python
@lowercase
def main():
    print("Hello World!")  # Kisbetűkkel jelenik meg
```

A C64 alapértelmezetten nagybetűs/grafikus módban indul. A `@lowercase` dekorátor átkapcsolja kisbetűs/nagybetűs módba, ahol a normál angol betűk jelennek meg.

**`@standalone`** - Önálló program (+8KB RAM)

```python
@standalone
@lowercase
def main():
    # Teljes gép, 8KB extra RAM a BASIC ROM helyén
    pass
```

A `@standalone` dekorátor:
- A program indulásakor kikapcsolja a BASIC ROM-ot ($A000-$BFFF) → +8KB RAM használható
- A program végén visszakapcsolja a BASIC ROM-ot és visszatér a promptba
- Ha végtelen ciklus kell (pl. játékoknál), használd: `while True: pass`

**Kombinálás:**

```python
@standalone
@lowercase
def main():
    # Mindkét dekorátor aktív
    pass
```

### Osztályok

Az osztályokat a `class` kulcsszóval kell deklarálni.

```
class név(szülő osztály):
    tulajdonság deklarációk
    metódusok
```

Nem kötelező megadni a szülő osztályt, abban az esetben a zárójelet sem szabad odatenni. PyCo-ban nem lehet több szülő osztályt megadni, egyszeres öröklődés van.

**Fontos:** Beágyazott osztályok nem megengedettek! Minden osztályt modul szinten kell definiálni. Osztályon belül sem lehet másik osztályt vagy `import`/`include()` utasítást használni.

```python
# Nincs szülő osztály
class Position:
    # Tulajdonságok deklarálása, kötelezően az elején
    x: int = 0
    y: int = 0

    # Metódusok
    def move(dx: int, dy: int): # `self`-et nem szabad kitenni!
        self.x += dx
        self.y += dy

# A `Hero` osztály a `Position` osztályból származik
class Hero(Position):
    score: int = 0

    def add_score(inc: int) -> int:
        self.score += inc
        return self.score
```

#### Konstruktor

Az `__init__` metódus a konstruktor, ami az objektum létrehozásakor fut le:

```python
class Enemy:
    x: int
    y: int
    health: byte = 100

    def __init__(start_x: int, start_y: int):
        self.x = start_x
        self.y = start_y
```

A tulajdonságok **mindig** inicializálódnak a deklarált alapértékekkel (ha van), majd ezután fut le a konstruktor. A fenti példában a `health` automatikusan 100 lesz, az `x` és `y` értékét pedig a konstruktor állítja be.

#### Példányosítás

Objektum létrehozása az osztály nevének meghívásával történik.

**Ha nincs konstruktor** (vagy nincs paramétere), a deklarációnál inicializálható:

```python
def example():
    pos: Position = Position()       # OK - nincs konstruktor
    hero: Hero = Hero()              # OK - nincs konstruktor
```

**Ha van konstruktor paraméterekkel**, a deklaráció és példányosítás külön sorban kell:

```python
def example():
    enemy: Enemy                     # csak deklaráció

    enemy = Enemy(100, 50)           # példányosítás a törzsben
```

**Miért?** A deklarációnál csak memória-inicializálás történhet. A konstruktor hívás függvényhívás, ami a törzs része kell legyen.

Használat:

```python
def main():
    hero: Hero = Hero()
    points: int

    hero.move(10, 5)
    points = hero.add_score(10)
```

### Metódusok

A metódusok valójában függvények, amik az osztályban deklarált változókra hivatkozhatnak.

Metódusokat a `def` kulcsszóval kell deklarálni.

```
def név(paraméterek) -> típus:
    változó deklarációk
    törzs
    return érték
```

**Megjegyzés:** A `self`-et nem szabad kitenni a metódus paraméterek között. Ennek oka, hogy minden paraméternek kötelező megadni a típusát, de a `self` típusa mindig az adott osztály - ezt a fordító tudja, így felesleges lenne kiírni. A metódus törzsében viszont a `self`-et használjuk a tulajdonságok és más metódusok eléréséhez.

## Beépített függvények

### print

Értékek kiírása a képernyőre. **Nem** tesz újsort a végére.

```python
print(érték)                      # egy érték kiírása
print(érték1, érték2, ...)        # több érték egymás után (szeparátor nélkül)
```

```python
def example():
    x: int = 10
    y: int = 20
    name: string = "Játékos"

    print("Hello\n")              # "Hello\n"
    print(x)                      # "10"
    print(x, y, "\n")             # "1020\n"
    print(name, x, "\n")          # "Játékos10\n"
    print(x, " ", y, "\n")        # "10 20\n" - explicit szóköz
```

**Megjegyzés:** A `print` egy speciális beépített függvény. A fordító fordításkor ismeri a paraméterek típusát, és automatikusan a megfelelő kiíró kódot generálja. A változó paraméterszám csak a beépített függvényeknél megengedett - saját függvényekben nem használható.

**Miért nincs alapértelmezett szeparátor?** A C64-en gyakori a vezérlő karakterek használata (cursor pozícionálás, színváltás), ahol a köztük lévő szóköz hibás működést okozna. A `+` operátor sem megoldás, mert az byte/int összeadást végez, nem string konkatenációt. Ha szóközzel elválasztott értékeket szeretnél, használd a `printsep(" ", ...)` függvényt.

### printsep

Értékek kiírása a képernyőre egyedi szeparátorral. **Nem** tesz újsort a végére.

```python
printsep(szeparátor, érték1, érték2, ...)
```

Az első paraméter a szeparátor string, ami az értékek **közé** kerül.

```python
def example():
    x: int = 10
    y: int = 20
    name: string = "Játékos"

    printsep(", ", x, y, "\n")    # "10, 20, \n"
    printsep("", x, y)            # "1020" - nincs szeparátor
    printsep(": ", name, x, "\n") # "Játékos: 10: \n"
```

### sprint

Értékek írása string bufferbe. Az első paraméter a cél string, a többi a `printsep`-hez hasonlóan működik (explicit szeparátorral).

```python
sprint(buffer, érték)                      # egy érték a bufferbe
sprint(buffer, szeparátor, érték1, érték2, ...)  # több érték szeparátorral
```

- **Két paraméter:** egyszerűen beírja az értéket a bufferbe
- **Három vagy több paraméter:** a második a szeparátor, a többi a beírandó érték

```python
def example():
    result: string[40]                  # 40 karakteres buffer
    score: int = 100
    name: string = "Játékos"

    sprint(result, score)               # result = "100"
    sprint(result, ": ", name, score)   # result = "Játékos: 100"
    sprint(result, ", ", 1, 2, 3)       # result = "1, 2, 3"
```

**Megjegyzés:** A `sprint` célbufferének elegendő méretűnek kell lennie. Nincs túlcsordulás-ellenőrzés!

### str

Érték stringgé alakítása. Bármilyen típusú értéket elfogad és stringet ad vissza.

```python
str(érték) -> string
```

```python
def example():
    s: string[20]
    x: int = 42
    f: float = 3.14
    b: bool = True

    s = str(x)           # "42"
    s = str(f)           # "3.14"
    s = str(b)           # "True"
    s = str("hello")     # "hello" (változatlan)
```

**Objektumok esetén:**

Ha az objektum osztályában van `__str__` metódus, azt hívja meg:

```python
class Player:
    name: string[20] = "Hero"
    score: int = 0

    def __str__() -> string:
        result: string[40]

        sprint(result, ": ", self.name, self.score)
        return result

def example():
    p: Player = Player()
    s: string[40]

    s = str(p)           # "Hero: 0"
```

Ha nincs `__str__` metódus, az osztály nevét adja vissza `<ClassName>` formátumban:

```python
class Enemy:
    x: int = 0
    y: int = 0

def example():
    e: Enemy = Enemy()
    s: string[20]

    s = str(e)           # "<Enemy>"
```

**Megjegyzés:** A `str` is speciális beépített függvény, mint a `print`. A fordító ismeri a paraméter típusát és a megfelelő konverziós kódot generálja.

### len

Hossz lekérdezése stringből vagy tömbből.

```python
len(s) -> byte           # string hossza
len(arr) -> byte/word    # tömb elemszáma
```

**String esetén** a Pascal-string hossz byte-ját olvassa - ez O(1) művelet, nincs végigiterálás.

**Tömb esetén** az elemszámot adja vissza. A visszatérési típus a tömb méretétől függ:

| Elemszám | Visszatérési típus |
| -------- | ------------------ |
| ≤ 256    | `byte`             |
| > 256    | `word`             |

Ez konzisztens a tömb indexelési típusával.

```python
def example():
    s: string = "Hello"
    arr: array[byte, 100]
    big: array[byte, 500]
    n: byte
    m: word

    n = len(s)           # 5 (byte)
    n = len(arr)         # 100 (byte, mert ≤256)
    m = len(big)         # 500 (word, mert >256)
```

### size

Lefoglalt memória méretének lekérdezése byte-okban. Mindig `word` típust ad vissza.

```python
size(érték) -> word
```

| Típus   | Visszaadott érték                             |
| ------- | --------------------------------------------- |
| string  | deklarált méret + 1 (hossz byte + karakterek) |
| array   | elemszám × elemméret                          |
| osztály | az összes property összmérete                 |

```python
def example():
    s: string[40]                    # 41 byte lefoglalva
    arr: array[int, 100]             # 200 byte (100 × 2)
    enemy: Enemy                     # osztály mérete
    sz: word

    sz = size(s)         # 41
    sz = size(arr)       # 200
    sz = size(enemy)     # az Enemy osztály property-jeinek összmérete
```

**Mikor használjuk:**
- Memória másolásnál a pontos méret ismeretéhez
- Debug célokra, memória használat ellenőrzéséhez
- Dinamikus memóriakezelésnél (ha könyvtárból elérhető)

### getkey

Billentyűzet olvasása (non-blocking). Azonnal visszatér a lenyomott billentyű kódjával, vagy 0-val ha nincs lenyomott billentyű.

```python
getkey() -> char
```

```python
def example():
    k: char

    k = getkey()             # 0 ha nincs gomb
    if k != 0:
        print("Gomb: ", k, "\n")
```

**Működés:** A KERNAL `GETIN` ($FFE4) rutint hívja, ami a billentyűzet bufferből olvas. Ha a buffer üres, 0-t ad vissza.

**Használat:**
- Játékokban folyamatos irányításhoz (nem akasztja meg a ciklust)
- Menükben, ahol más tevékenység is fut háttérben
- Amikor ellenőrizni akarod, volt-e billentyűleütés

### waitkey

Billentyűzet olvasása (blocking). Várakozik egy billentyű lenyomására, majd visszaadja annak kódját.

```python
waitkey() -> char
```

```python
def example():
    k: char

    print("Nyomj egy gombot...")
    k = waitkey()            # Vár a gombnyomásra
    print("Lenyomtad: ", k, "\n")
```

**Működés:** Ciklusban hívja a KERNAL `GETIN` ($FFE4) rutint, amíg billentyűt nem kap.

**Használat:**
- "Press any key to continue" típusú várakozáshoz
- Menüpontok kiválasztásához
- Egyszerű interakciókhoz, ahol a program megáll

**getkey vs waitkey:**

| Függvény    | Viselkedés        | Tipikus használat               |
| ----------- | ----------------- | ------------------------------- |
| `getkey()`  | Azonnal visszatér | Játék vezérlés, nem blokkoló    |
| `waitkey()` | Vár gombnyomásra  | "Press any key", menü választás |

### abs

Abszolút érték számítása. Előjeles típusoknál (`sbyte`, `int`) a negatív előjelet eltávolítja.

```python
abs(érték) -> byte/word
```

**Visszatérési típusok:**

| Bemenet | Kimenet | Indoklás                                        |
| ------- | ------- | ----------------------------------------------- |
| `sbyte` | `byte`  | `abs(-128) = 128`, ami nem fér el `sbyte`-ban   |
| `int`   | `word`  | `abs(-32768) = 32768`, ami nem fér el `int`-ben |
| `byte`  | `byte`  | Változatlan (már pozitív)                       |
| `word`  | `word`  | Változatlan (már pozitív)                       |

```python
def example():
    x: int = -42
    y: sbyte = -10
    a: word
    b: byte

    a = abs(x)           # 42
    b = abs(y)           # 10
    a = abs(-100)        # 100
```

**Megjegyzés:** Előjel nélküli típusoknál (`byte`, `word`) nincs hatása, az értéket változatlanul adja vissza.

### min

Két érték közül a kisebbet adja vissza.

```python
min(a, b) -> a és b típusa
```

```python
def example():
    x: int = 10
    y: int = 20
    m: int

    m = min(x, y)        # 10
    m = min(100, 50)     # 50
    m = min(-5, 5)       # -5
```

**Megjegyzés:** A két paraméternek azonos típusúnak kell lennie (vagy kompatibilisnek).

### max

Két érték közül a nagyobbat adja vissza.

```python
max(a, b) -> a és b típusa
```

```python
def example():
    x: int = 10
    y: int = 20
    m: int

    m = max(x, y)        # 20
    m = max(100, 50)     # 100
    m = max(-5, 5)       # 5
```

---

## Típuskonverziós függvények

A PyCo-ban **nincs automatikus típus-promóció** (implicit konverzió). Ha különböző típusú értékekkel szeretnél dolgozni, explicit konverziót kell használnod. Ez biztonságosabb és átláthatóbb kódot eredményez - nincs meglepetés, hogy egy művelet milyen típussal dolgozik.

### Miért kellenek?

A PyCo-ban a **műveletek a részt vevő típusok szerint** hajtódnak végre, nincs automatikus típusbővítés (type promotion). Ez azt jelenti, hogy `byte + byte` mindig 8-bites összeadás lesz, még akkor is, ha az eredményt 16-bites változóba tesszük!

```python
def example():
    b1: byte = 200
    b2: byte = 100
    w: word

    # FIGYELEM: Ez NEM azt csinálja, amit várnál!
    w = b1 + b2          # 200 + 100 = 300... DE 8-biten: 44! (túlcsordulás)

    # HELYESEN: Explicit konverzióval
    w = word(b1) + word(b2)   # 16-bites összeadás: 300
```

**Miért van ez így?**

1. **Hatékonyság**: A C64-en minden CPU ciklus számít. A 8-bites összeadás ~4 ciklus, a 16-bites ~20 ciklus. Ha automatikusan bővítenénk, sok felesleges művelet lenne.

2. **Oktatási cél**: A programozónak meg kell értenie, mi történik a memóriában. Ez tudatos döntést igényel, nem "mágikus" automatizmust.

3. **Átláthatóság**: A kód pontosan azt csinálja, amit leírsz. Nincs rejtett konverzió.

**Értékadásnál viszont NEM kell konvertálni** - a fordító kezeli:

```python
def example():
    b: byte = 200
    w: word
    i: int

    w = b                # OK: byte → word automatikus (csak másolás)
    i = b                # OK: byte → int automatikus

    # DE műveletnél továbbra is a forrás típus számít:
    w = b * 2            # 8-bites szorzás! Ha b=200, eredmény: 144 (túlcsordulás)
    w = word(b) * 2      # 16-bites szorzás: 400
```

### byte

Szűkítés 8-bites előjel nélküli értékké (0-255). Csak az alsó 8 bit marad meg.

```python
byte(érték) -> byte
```

```python
def example():
    score: int = 300
    offset: int

    # Műveletben használva - itt van értelme!
    offset = score - byte(score) * 256   # Maradék kiszámítása 256-tal

    # FELESLEGES értékadásnál - ez automatikus:
    # b: byte = score   # OK, a fordító kezeli (alsó 8 bit)
```

### sbyte

Értelmezés előjeles 8-bites értékként (-128 - 127).

```python
sbyte(érték) -> sbyte
```

```python
def example():
    delta: byte          # Előjel nélküli byte-ként jött (pl. joystick)
    position: int = 100

    delta = getkey()     # Tegyük fel, 0xFE jött (254 unsigned, -2 signed)

    # Műveletben használva - előjeles értelmezés!
    position = position + sbyte(delta)   # 100 + (-2) = 98
    # vs.
    position = position + delta          # 100 + 254 = 354 (nem ezt akartuk!)
```

**Használat:** Amikor egy byte értéket előjeles számként akarsz **értelmezni** műveletben (pl. relatív elmozdulás, delta érték, joystick input).

### word

Bővítés 16-bites előjel nélküli értékké (0-65535). A fő cél: **túlcsordulás elkerülése műveletekben**.

```python
word(érték) -> word
```

```python
def example():
    a: byte = 200
    b: byte = 100
    result: word

    # HIBÁS - 8-bites művelet, túlcsordul!
    result = a + b              # 200 + 100 = 44 (wraparound)

    # HELYES - 16-bites művelet
    result = word(a) + word(b)  # 200 + 100 = 300

    # Memóriacím számítás
    row: byte = 5
    screen: word = 0x0400 + word(row) * 40   # Nincs túlcsordulás
```

**Használat:** Amikor byte értékekkel számolsz, de az eredmény nem fér 8 bitbe.

### int

Bővítés 16-bites előjeles értékké (-32768 - 32767), vagy float érték csonkolása egésszé.

```python
int(érték) -> int
```

```python
def example():
    temp_raw: byte = 200     # Hőmérő nyers érték (pl. 200 = -56°C offset-tel)
    temperature: int

    # Előjeles számításhoz kell int
    temperature = int(temp_raw) - 256   # 200 - 256 = -56

    # Float érték csonkolása egésszé (törtrész eldobása)
    f: float = 5.7
    i: int = int(f)          # 5 (nem kerekít, csonkol!)

    f = -10.9
    i = int(f)               # -10
```

**Használat:**
- Előjeles aritmetikához byte értékekkel
- Float értékek egésszé alakításához (truncate - a törtrész eldobásra kerül)

### char

Értelmezés karakterként. Fizikailag azonos a `byte`-tal, de a `print` karakterként kezeli.

```python
char(érték) -> char
```

```python
def example():
    code: byte

    # Dinamikus karakter generálás - itt van értelme!
    for code in range(26):
        print(char(65 + code))   # A, B, C, ... Z

    # Számból karakter megjelenítés
    print("Kód: ", code, " = '", char(code), "'\n")
```

**Használat:**
- Számkódból karakter **megjelenítéséhez** print-ben
- Dinamikus karakterek generálásához
- String-hez való hozzáfűzéshez

### bool

A teljes érték vizsgálata logikai értékként. Nulla → `False`, bármi más → `True`.

```python
bool(érték) -> bool
```

```python
def example():
    value: int = 256         # Alsó byte = 0, felső byte = 1
    flag: bool

    # FIGYELEM: Közvetlen értékadásnál csak az alsó byte másolódik!
    flag = value             # flag = False! (mert alsó byte = 0)

    # bool() konverzióval a TELJES érték számít:
    flag = bool(value)       # flag = True! (mert 256 != 0)

    # if-ben viszont FELESLEGES - ott mindig a teljes érték vizsgálódik:
    if value:                # True (256 != 0)
        print("Nem nulla\n")
```

**Használat:** Amikor int/word értéket bool **változóba** teszel, és fontos, hogy a teljes érték számítson, ne csak az alsó byte.

### float

Egész vagy fixpontos érték konvertálása 32-bites lebegőpontos típussá.

```python
float(érték) -> float
```

```python
def example():
    i: int = 42
    f: float
    result: float

    # Egész érték lebegőpontossá alakítása
    f = float(i)             # 42.0

    # Műveletben - ha float aritmetikát akarsz
    result = float(100) / float(3)   # 33.333... (nem 33!)

    # byte-ból float
    b: byte = 200
    f = float(b)             # 200.0

    # Fixed-point értékek konvertálása float-ra
    x: f16 = f16(1.5)
    f = float(x)             # 1.5 (explicit konverzió)
    f = x                    # 1.5 (implicit konverzió is működik!)

    y: f32 = f32(-3.25)
    f = float(y)             # -3.25
    f = y                    # -3.25 (implicit is OK)
```

**Használat:**
- Egész értékek lebegőpontos műveletekhez való előkészítéséhez
- Pontosabb osztáshoz (pl. `float(a) / float(b)` törtet ad)
- Float típusú változóba való explicit konverzióhoz
- Fixed-point értékek float-ra konvertálásához (ha nagyobb tartomány vagy float művelet kell)

**Fixed-point → float konverzió:**
- `f16` → `float`: Az 8.8 formátumú érték valódi tört számmá alakul
- `f32` → `float`: A 16.16 formátumú érték valódi tört számmá alakul
- Mind explicit (`float(x)`), mind implicit (`f = x`) konverzió támogatott

**Megjegyzés:** A `float()` konverzió lassú művelet a 6502-n. Ha nem szükséges a tört rész, használj egész aritmetikát. A fixed-point → float konverzió is lassú, de hasznos lehet debug célokra vagy ha float műveletek kellenek.

### Típuskonverziók összefoglaló táblázata

| Függvény    | Eredmény | Mikor használd **műveletben**                                    |
| ----------- | -------- | ---------------------------------------------------------------- |
| `word(b)`   | word     | `word(a) + word(b)` - byte összeadás túlcsordulás nélkül         |
| `int(b)`    | int      | `int(a) - int(b)` - előjeles eredmény byte-okból                 |
| `sbyte(b)`  | sbyte    | `pos + sbyte(delta)` - byte előjeles értelmezése                 |
| `char(b)`   | char     | `print(char(65+i))` - byte megjelenítése karakterként            |
| `byte(w)`   | byte     | `byte(addr) * 256` - alsó 8 bit kivonása                         |
| `bool(w)`   | bool     | `flag = bool(value)` - teljes int/word vizsgálata bool változóba |
| `float(i)`  | float    | `float(a) / float(b)` - pontos osztás lebegőpontosan             |
| `float(fx)` | float    | `float(f16_val)` - fixed-point → float konverzió                 |

**Emlékeztető:** Értékadásnál (`w = b`) NEM kell konverzió - az automatikus! Ez igaz a fixed-point → float konverzióra is: `f: float = f16_val` működik.

---

## Opcionális nyelvi elemek

Ez a szekció olyan nyelvi elemeket tartalmaz, amelyeket nem minden PyCo fordító implementál. Ezek platformfüggő vagy speciális célú funkciók.

### Inline assembly (__asm__)

Az `__asm__` lehetővé teszi nyers assembly kód beillesztését közvetlenül a PyCo programba. Ez a legalacsonyabb szintű kontroll - teljes hozzáférés a CPU-hoz és a hardverhez.

```python
__asm__("""
    lda #$00
    sta $d020
""")
```

**Mikor használjuk:**
- Időkritikus ciklusok, ahol minden CPU ciklus számít
- Hardver-specifikus műveletek (VIC trükkök, SID programozás)
- Speciális CPU utasítások (SEI, CLI, BRK, NOP)
- Interrupt handlerek
- Olyan optimalizációk, amiket a fordító nem tud generálni

**Szintaxis:**

```python
__asm__("""
    assembly kód
    több soros is lehet
""")
```

A tripla idézőjel (`"""`) többsoros stringet jelöl. Az assembly kód változtatás nélkül beillesztésre kerül a generált kimenetbe.

**Szabályok:**

| Szabály                           | Magyarázat                                                           |
| --------------------------------- | -------------------------------------------------------------------- |
| Csak függvényben használható      | Statement-ként, a kód bármely pontján                                |
| Nincs változó behelyettesítés     | Nyers assembly kód, placeholder-ek nélkül                            |
| Stack frame elérhető              | FP (Frame Pointer) és SP (Stack Pointer) használható                 |
| Lokális változók elérése          | `lda (FP),y` típusú címzéssel, az Y regiszterben az offset           |
| Regiszter megőrzés                | A programozó felelőssége (A, X, Y, status regiszterek)               |
| Nincs syntax ellenőrzés           | A PyCo fordító nem validálja az assembly kódot                       |

**Példák:**

Képernyő keret szín váltása:

```python
def flash_border():
    __asm__("""
        inc $d020
    """)
```

Interrupt tiltása kritikus szekció alatt:

```python
def critical_section():
    __asm__("""
        sei
    """)

    # Kritikus műveletek itt...

    __asm__("""
        cli
    """)
```

Gyors várakozás (busy wait):

```python
def wait_rasterline():
    __asm__("""
    .wait:
        lda $d012
        cmp #$80
        bne .wait
    """)
```

**Lokális változók elérése:**

A PyCo stack-alapú memóriakezelést használ. A lokális változók a Frame Pointer (FP) relatív címzéssel érhetők el:

```python
def add_to_var():
    x: byte = 10

    # Az 'x' változó FP+offset címen van
    # A pontos offset az adott fordítótól függ
    __asm__("""
        ldy #0          ; offset (függ a deklaráció sorrendjétől)
        lda (FP),y      ; x értéke
        clc
        adc #5
        sta (FP),y      ; x = x + 5
    """)
```

**Figyelmeztetések:**

- **Nincs type checking** - az assembly kód nem kerül validálásra PyCo szinten
- **Hibás assembly** - fordítási hibát okoz az assembler szintjén
- **Regiszter sérülés** - ha nem őrzöd meg a regisztereket, a PyCo kód hibásan működhet
- **Portabilitás** - az assembly kód platformfüggő (6502 specifikus)
- **Stack layout** - a lokális változók elrendezése fordító-függő lehet

**Tipp:** Az `__asm__` használata előtt próbáld meg a feladatot PyCo-ban megoldani. Az inline assembly csak végső eszköz legyen, amikor a teljesítmény kritikus és a PyCo nem elég gyors.
