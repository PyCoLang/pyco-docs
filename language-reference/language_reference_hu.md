# PyCo nyelvi referencia

A PyCo egy **Python-szerű nyelv** gépközeli programozáshoz, amely ötvözi több nyelv erősségeit és saját innovatív megoldásokat is tartalmaz.

## 1. Bevezetés

### Mi a PyCo?

**Inspiráció:**
- **Python:** olvasható szintaxis, behúzás alapú blokkok, osztályok
- **Pascal:** strict típusosság, előre deklarált változók, Pascal-típusú stringek
- **C:** alacsony szintű memóriakezelés, bitműveletek, gépközeli szemlélet

**Saját megoldások:**
- **Memory-mapped változók:** hardver regiszterek közvetlen elérése típusosan (`var: byte[0xD020]`)
- **Alias típus:** dinamikus, típusos referenciák futásidejű címbeállítással
- **Implicit self:** metódusokban nem kell kiírni a `self` paramétert

**Jellemzők:**
- Gyors és memória hatékony
- Egyszerű, könnyen tanulható
- Platform-független nyelv, különböző backend-ekkel fordítható
- Moduláris: csak a használt függvények töltődnek be

**Célplatformok:** 8/16/32 bites rendszerek, mikrovezérlők - a konkrét platform a fordító backend-jétől függ, nem a nyelvtől.
Az első referencia implementáció a C64-re készült.

### Nyelvi korlátozások

| Korlátozás                              | Indoklás                                 |
| --------------------------------------- | ---------------------------------------- |
| Nincsenek globális változók             | Csak NAGYBETŰS konstansok modul szinten  |
| Változók a függvény elején              | Pascal-stílus, egyszerűbb memóriakezelés |
| Egyszálú végrehajtás                    | Egyszerűség, könnyebb tanulhatóság       |
| Nincs dinamikus memóriakezelés          | De könyvtárból elérhető                  |
| Függvények/osztályok csak modul szinten | Nincs beágyazás                          |
| Import és include csak modul szinten    | Egyszerűbb fordítás                      |
| Definíciós sorrend kötelező             | Egymenetes fordítás, egyszerűbb fordító  |

### Példaprogram

```python
# Ez egy komment
from sys import clear_screen

class Position:
    # Minden property-t deklarálni kell
    x: int = 0
    y: int = 0

class Hero(Position):
    score: int = 0

    def move_right(inc: int):      # self-et NEM kell kitenni!
        self.score += inc          # De a törzsben igen

def main():
    # Változókat az elején kell deklarálni
    hero: Hero
    i: int

    hero()                         # Objektum inicializálása
    print("Hello world\n")
```

---

## 2. Alapok

### 2.1 Nevek és azonosítók

A nevek csak kis- és nagybetűket, számokat és aláhúzást tartalmazhatnak, de nem kezdődhetnek számmal. A kis- és nagybetűt a nyelv megkülönbözteti.

**Fenntartott nevek:** A `__` (dupla aláhúzás) prefixű nevek fenntartottak a rendszer számára. Felhasználói kód nem definiálhat ilyen nevű függvényt, metódust vagy változót. Kivételek a dokumentált speciális metódusok:
- `__init__` - konstruktor
- `__str__` - string reprezentáció

#### Ajánlott elnevezési konvenciók

| Elem     | Konvenció       | Példa                        |
| -------- | --------------- | ---------------------------- |
| Osztály  | PascalCase      | `MyClass`, `PlayerSprite`    |
| Függvény | snake_case      | `my_function`, `get_score`   |
| Változó  | snake_case      | `my_variable`, `player_x`    |
| Konstans | SCREAMING_SNAKE | `MAX_ENEMIES`, `SCREEN_ADDR` |

### 2.2 Kommentek

A kommentek a programozó számára írt megjegyzések, amelyeket a fordító figyelmen kívül hagy. Céljuk a kód magyarázata, dokumentálása, vagy ideiglenesen kódrészletek kikapcsolása.

#### Egysoros kommentek

A `#` karaktertől a sor végéig minden kommentnek számít:

```python
def example():
    # Ez egy teljes soros komment
    x: int = 42  # Ez egy sor végi komment
```

#### Docstringek

A PyCo támogatja a **docstringeket** hármas idézőjellel (`"""..."""`) függvények, metódusok és osztályok dokumentálásához. A docstringnek a függvény/metódus/osztály törzsének első utasításaként kell szerepelnie:

```python
def calculate_score(hits: byte, multiplier: byte) -> word:
    """
    Kiszámítja a játékos pontszámát a találatok és szorzó alapján.
    A kiszámított pontszámot word értékként adja vissza.
    """
    result: word
    result = word(hits) * word(multiplier) * 10
    return result

class Player:
    """
    A játékost reprezentálja a játékban.
    Kezeli a pozíciót, életerőt és pontszámot.
    """
    x: byte = 0
    y: byte = 0
    health: byte = 100

    def take_damage(amount: byte):
        """Csökkenti a játékos életerejét a megadott értékkel."""
        if self.health > amount:
            self.health = self.health - amount
        else:
            self.health = 0
```

**Fontos:** A docstringeket a fordító figyelmen kívül hagyja - nem generálnak kódot és nem foglalnak memóriát. Kizárólag dokumentációs célokat szolgálnak.

> **Megjegyzés:** Csak a hármas dupla idézőjel (`"""`) támogatott, az egyszeres (`'''`) nem.

### 2.3 Blokkok és behúzás

A kettőspontra (`:`) végződő utasítások új blokkot nyitnak. A blokk tartalmát **4 szóköz** behúzással kell jelölni:

```python
def example():
    x: int = 10

    if x > 0:
        print("pozitív\n")
        x = x - 1
```

A blokk addig tart, amíg a behúzás megmarad. Üres blokkot a `pass` kulcsszóval jelölünk:

```python
def later():
    pass
```

### 2.4 Többsoros utasítások

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
```

Ez a string összefűzés fordítási időben történik, nincs futásidejű költség.

### 2.5 Include

Fájlok szöveges beillesztése az `include()` függvénnyel történik. Ez egy preprocesszor művelet: a fordító beolvassa a megadott fájl tartalmát és beilleszti a hívás helyére.

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

> **FONTOS:** Az `include()` nem tölt be lefordított modult, csak szövegesen bemásolja a fájl tartalmát. Konstansok és definíciók megosztására való.

### 2.6 Import

Az `import` utasítás lefordított modulokból tölt be függvényeket és osztályokat. A PyCo-ban az import helye meghatározza a betöltés módját.

**Szintaxis:**

```python
from modul_név import név1, név2, név3
from modul_név import név as alias
```

**Alapszabályok:**

- **Kötelező felsorolás**: Minden használt nevet explicit fel kell sorolni
- **Nincs wildcard**: `from X import *` NEM támogatott
- **Prefix nélküli használat**: Az importált nevek közvetlenül használhatók

#### Két import mód

Az import helye meghatározza, hogyan töltődik be a modul:

| Import helye          | Mód       | Mikor töltődik be | Élettartam       |
| --------------------- | --------- | ----------------- | ---------------- |
| Fájl elején (top-level) | Statikus | Fordításkor       | Program futása   |
| Függvényben           | Dinamikus | Futáskor          | Scope vége       |

**Statikus import (top-level):**

```python
# Fájl elején - STATIKUSAN befordul a programba
from math import sin, cos

def main():
    x: float = sin(0.5)    # Közvetlenül használható
    y: float = cos(0.5)
```

A statikus import előnyei:
- Nincs futásidejű betöltés
- A fordító ellenőrzi a típusokat
- Tree-shaking: csak a használt függvények kerülnek a programba

**Dinamikus import (függvényen belül):**

```python
def game_screen():
    # Függvényben - DINAMIKUSAN töltődik be futáskor
    from game_utils import update, draw
    from music import play

    play()
    while not game_over:
        update()
        draw()
    # ← Függvény vége: a modulok memóriája FELSZABADUL!
```

A dinamikus import előnyei:
- Memória hatékony: csak az van memóriában, ami éppen kell
- Scope = Lifetime: automatikus felszabadítás
- Végtelen méretű program részletekben töltve

#### Alias (`as`) támogatás

Névütközés esetén vagy rövidítéshez használható:

```python
from math import sin as math_sin
from audio import sin as audio_sin

x: float = math_sin(0.5)
freq: float = audio_sin(440.0)
```

**Névütközés = fordítási hiba:**

```python
from math import sin
from audio import sin     # HIBA: 'sin' already imported from 'math'!

# Megoldás - használj alias-t:
from math import sin
from audio import sin as audio_sin   # OK
```

#### Export szabályok

A modulok Python-szerű export szabályokat követnek:

| Név formátum                   | Exportálva?              |
| ------------------------------ | ------------------------ |
| `name`                         | ✓ Igen (publikus)        |
| `_name`                        | ✗ Nem (privát)           |
| `from X import foo`            | ✓ Igen (re-export)       |
| `from X import foo as _foo`    | ✗ Nem (privát alias)     |

```python
# math.pyco modul
def sin(x: float) -> float:     # ✓ Exportálva (publikus)
    return _sin_impl(x)

def _sin_impl(x: float) -> float:   # ✗ NEM exportálva (privát)
    ...
```

#### Egyedi modul összeállítás

Több lib-ből összeválogathatod a szükséges függvényeket egy saját modulba:

```python
# my_game_utils.pyco - saját modul
from math import sin, cos           # Statikusan befordul
from physics import update_pos
from gfx import draw_sprite

def rotate(x: int, y: int, angle: float) -> int:
    return int(x * cos(angle) - y * sin(angle))
```

A fő programban dinamikusan betöltheted:

```python
def game_screen():
    from my_game_utils import sin, cos, rotate, draw_sprite
    # Minden egy modulban, egy betöltéssel
```

#### Include vs Import összehasonlítás

| Kulcsszó               | Mit csinál                       | Mikor használjuk                       |
| ---------------------- | -------------------------------- | -------------------------------------- |
| `include("név")`       | Szövegesen beilleszti a fájlt    | Konstansok, definíciók megosztása      |
| `from X import a, b`   | Lefordított modulból tölt be     | Függvények, osztályok használata       |

### 2.7 Konstansok

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
    border: byte[BORDER]                  # memory-mapped változónál
    enemies: array[Enemy, MAX_ENEMIES]    # tömb méreténél
    i: byte

    border = 0
    for i in range(0, MAX_ENEMIES):
        pass
```

> **FONTOS:** Globális változók NEM megengedettek a PyCo-ban. Minden modul szintű értékadás NAGYBETŰS kell legyen, és konstansként kezelődik. Ha kisbetűs globális változót próbálsz létrehozni, a fordító hibát jelez.

### 2.8 Változók

A változók a program futása során változó értékeket tárolnak. A PyCo-ban a változókat **típusannotációval** deklaráljuk, és csak **függvényeken vagy metódusokon belül** használhatók (globális változók nem megengedettek).

**Szintaxis:**

```python
név: típus                # deklaráció alapérték nélkül
név: típus = alapérték    # deklaráció alapértékkel
```

**Példák:**

```python
def main():
    x: int                    # int típusú változó, nincs alapérték
    y: int = 0                # int típusú változó, 0 alapértékkel
    name: string[20] = "Player"
    scores: array[byte, 10]   # 10 elemű byte tömb
```

**Pascal-stílusú deklaráció:**

A PyCo-ban a változókat a függvény **elején** kell deklarálni, a végrehajtható utasítások előtt:

```python
def calculate():
    # Először: összes változó deklaráció
    x: int = 0
    y: int = 0
    result: int

    # Utána: végrehajtható kód
    x = 10
    y = 20
    result = x + y
```

Ez a szabály segít a fordítónak a memória előre lefoglalásában, és átláthatóbbá teszi a kódot.

**Alapértékek szabályai:**

Az alapértékek csak **fordítási időben ismert konstans értékek** lehetnek:

| Megengedett                         | Nem megengedett               |
| ----------------------------------- | ----------------------------- |
| Literálok: `42`, `"szöveg"`, `True` | Függvényhívás: `get_value()`  |
| NAGYBETŰS konstansok: `MAX_ENEMIES` | Változó: `other_var`          |
| Konstans kifejezések: `10 + 5`      | Futásidejű kifejezés: `x + 1` |
|                                     | Paraméter: `param`            |

**Helytelen példa:**

```python
def bad_example(n: byte):
    x: int = get_initial_value()  # HIBA: függvényhívás
    y: int = n                    # HIBA: paraméter nem konstans
    z: int = x + 1                # HIBA: változó nem konstans
```

> **Megjegyzés:** Típusokról részletesen a [3. Típusok](#3-típusok) szekcióban olvashatsz. Memory-mapped változókról (fix memóriacímen elhelyezett változók) a [4. Memory-mapped programozás](#4-memory-mapped-programozás) szekcióban.

### 2.9 Definíciós sorrend

A PyCo **egymenetes névfeloldást** használ. Ez azt jelenti, hogy egy név (típus, függvény, metódus) csak akkor hivatkozható, ha már definiálva van a forráskódban.

#### Miért fontos ez?

| Előny                    | Magyarázat                                                               |
| ------------------------ | ------------------------------------------------------------------------ |
| Egyszerűbb fordítás      | A fordító egyetlen menetben feldolgozhatja a kódot                       |
| Nincs "tükör a tükörben" | Önhivatkozó osztályok automatikusan kizárva (végtelen ciklus elkerülése) |
| Tiszta függőségek        | Mindig látható, mi mitől függ                                            |

#### Osztályok

Egy osztály csak **már definiált** osztályokra hivatkozhat property típusként:

```python
class Node:
    value: int = 0
    next: alias[Node]    # OK: önhivatkozás alias-szal (Node már ismert)

class Tree:
    root: alias[Node]    # OK: Node már definiálva van feljebb
```

**HIBÁS kód:**
```python
class Tree:
    root: alias[Node]    # HIBA: Node még nincs definiálva!

class Node:
    value: int = 0
```

**Hibaüzenet:**
```
example.pyco:2: Error: Property 'root': Type 'Node' is not yet defined.
    Classes can only reference previously defined classes.
    Move the 'Node' class definition before this line.
```

#### Önhivatkozás

Ha egy osztály önmagára hivatkozik, **kötelező az `alias`** használata:

```python
class Node:
    value: int = 0
    next: Node           # HIBA: végtelen memória lenne!
```

**Hibaüzenet:**
```
example.pyco:3: Error: Property 'next': Type 'Node' is the current class.
    Use 'alias[Node]' for self-references.
```

Az `alias` használatával a PyCo csak egy 2 bájtos pointert tárol a következő Node-ra, nem magát a Node-ot.

#### Öröklődés

A szülő osztálynak is definiáltnak kell lennie:

```python
class Parent:
    x: int = 0

class Child(Parent):     # OK: Parent már definiált
    y: int = 0
```

**HIBÁS kód:**
```python
class Child(Parent):     # HIBA: Parent még nincs definiálva!
    y: int = 0

class Parent:
    x: int = 0
```

#### Függvények és metódusok

Lásd: [8.5 Forward deklaráció (@forward)](#85-forward-deklaráció-forward).

---

## 3. Típusok

> **„A memória az igazság, a típus csak szemüveg."**
>
> A PyCo-ban a típusok nem varázslatosan működnek - egyszerűen megmondják, hogyan értelmezzük a nyers bájtokat a memóriában. Ugyanaz a 4 byte lehet `float`, `array[word, 2]` vagy `array[byte, 4]` - attól függ, milyen "szemüvegen" keresztül nézzük.

### 3.1 Primitív típusok

A primitív (vagy elemi) típusok az alapvető építőkövek - egyetlen, oszthatatlan értéket tárolnak. Ezekből épülnek fel az összetett típusok (tömbök, osztályok).

| Típus | Méret  | Tartomány     | Leírás                       |
| ----- | ------ | ------------- | ---------------------------- |
| bool  | 1 byte | True/False    | 0 = False, minden más = True |
| char  | 1 byte | 0..255        | Egyetlen karakter            |
| byte  | 1 byte | 0..255        | Előjel nélküli 8 bit         |
| sbyte | 1 byte | -128..127     | Előjeles 8 bit               |
| word  | 2 byte | 0..65535      | Előjel nélküli 16 bit        |
| int   | 2 byte | -32768..32767 | Előjeles 16 bit              |

#### Bool

A `bool` 1 bájtot foglal:
- `0` = False
- bármi más = True

```python
def example():
    b: bool
    x: int = 256          # 0x0100 - alsó byte 0!

    b = x                 # alsó byte (0x00) tárolódik
    if b:                 # False, mert b = 0
        print("no\n")     # nem fut le

    if x:                 # True, mert x != 0 (int-ként vizsgálja)
        print("yes\n")    # lefut
```

> **FIGYELEM:** Értékadásnál (`b = x`) csak az alsó byte másolódik! Ha a teljes érték számít, használd a `bool()` konverziót: `b = bool(x)`. Feltételekben viszont mindig a teljes érték vizsgálódik.

#### Char

A `char` 1 bájtot foglal, egyetlen karaktert tárol. Technikailag ugyanaz mint a `byte`, de karakterként értelmezzük.

A karakter literál egy **egybetűs string** dupla idézőjelek között:

```python
def example():
    c: char = "A"         # karakter literál (pontosan 1 karakter!)
    b: byte = 65          # ugyanaz, de számként

    c = b                 # OK - szabadon konvertálható
    b = c                 # OK

    if c == b:            # True - ugyanaz az érték
        print("same\n")
    if c == 65:           # True - char összehasonlítható számmal
        print("65\n")
    if b == "A":          # True - byte összehasonlítható karakterrel
        print("A\n")
```

**Kódolás:** Platform-függő. Commodore-on PETSCII, más platformokon ASCII.

**Miért hasznos a `char` típus?**

A `char` és `byte` a memóriában ugyanaz, de különböző kontextusokban másképp viselkednek:

```python
def example():
    c: char = "A"
    b: byte = 65
    s: string[20] = "Hello"

    # 1. print() másképp kezeli őket
    print(c)              # "A" - karakterként jelenik meg
    print(b)              # "65" - számként jelenik meg

    # 2. char hozzáfűzhető stringhez
    s = s + c             # "HelloA"
    s = "Hi" + "!"        # "Hi!"
```

**Mikor használjuk:**
- `char` - ha karaktert tárolunk, karakterként akarjuk megjeleníteni, vagy stringhez fűzni
- `byte` - ha számot tárolunk és számként akarjuk megjeleníteni
- `bool` - ha logikai értékeket kezelünk

### 3.2 Lebegőpontos típus (float)

A `float` 32 bites lebegőpontos típus (MBF formátum).

| Típus | Méret  | Tartomány | Pontosság |
| ----- | ------ | --------- | --------- |
| float | 4 byte | ±10^38    | ~7 jegy   |

```python
def example():
    x: float = 3.14159
    y: float = 2.0

    x = x * y             # lassú művelet!
```

> **FIGYELEM:** A float műveletek lassúak régi hardveren! A float könyvtár csak akkor töltődik be, ha a program használ float típust.

#### Float és integer keverése

A float típus **kivételt képez** az automatikus típusbővítés szabálya alól! Ha egy műveletben float és integer típus keveredik, az integer automatikusan float-tá konvertálódik:

```python
def example():
    f: float = 10.5
    i: int = 3
    result: float

    # Implicit konverzió - az integer automatikusan float-tá alakul
    result = f + i            # 10.5 + 3.0 = 13.5
    result = f * i            # 10.5 * 3.0 = 31.5

    # Értékadásnál is implicit konverzió
    f = 42                    # f = 42.0 (nem kell float(42))
    f = i                     # f = 3.0
```

> **FONTOS:** Ha **mindkét** operandus integer típusú, az osztás **egész osztás** marad!

```python
def example():
    a: int = 7
    b: int = 2
    result: float

    # HIBÁS: egész osztás! 7 / 2 = 3 (nem 3.5!)
    result = a / b            # result = 3.0, nem 3.5!

    # HELYES: legalább az egyik operandust float-tá kell alakítani
    result = float(a) / b     # 7.0 / 2 = 3.5
```

### 3.3 Fixpontos típusok (f16, f32)

A fixpontos típusok a lebegőpontos (`float`) és az egész (`int`) típusok között helyezkednek el: tört számokat tárolnak, de sokkal gyorsabbak, mint a float.

| Típus | Méret  | Formátum | Tartomány             | Pontosság |
| ----- | ------ | -------- | --------------------- | --------- |
| f16   | 2 byte | 8.8      | -128.0 .. +127.996    | 1/256     |
| f32   | 4 byte | 16.16    | -32768.0 .. +32767.99 | 1/65536   |

**Mikor használd?**
- Sprite pozíciók szubpixel pontossággal (smooth mozgás)
- Fizikai szimulációk (sebesség, gyorsulás)
- Bármilyen tört szám, ahol a sebesség fontosabb a nagy tartománynál

#### f16 (8.8 formátum)

```python
def example():
    x: f16 = f16(10)       # explicit konverzió kötelező!
    y: f16 = f16(3)
    z: f16

    z = x + y              # összeadás ugyanolyan gyors mint int!
    z = x * y              # szorzás: gyorsabb mint float
```

#### f32 (16.16 formátum)

```python
def example():
    pi: f32 = f32(3.14159)  # float literál compile-time konvertálódik!
    radius: f32 = f32(100)
    area: f32

    area = pi * radius * radius
```

> **FONTOS:** Számértékek helyes átkonvertálásához használd az `f16()` és `f32()` függvényeket!

```python
def main():
    # Explicit konverzió - a szám ÁTALAKUL f16 formátumba
    x: f16 = f16(5)         # → 0x0500 (5.0 f16-ként)
    y: f16 = f16(1.5)       # → 0x0180 (1.5 f16-ként, compile-time!)

    # Implicit értékadás - a bájtok BEMÁSOLÓDNAK ahogy vannak
    z: f16 = 5              # → 0x0005 (~0.02 f16-ként!)
    w: f16 = 0x0500         # → 0x0500 (5.0 - ha tudod mit csinálsz)
```

> **FIGYELEM:** Az implicit értékadásnál (`z: f16 = 5`) a szám bájtjai változtatás nélkül másolódnak! Az 5 nem 5.0 lesz f16-ként, hanem ~0.02. Ha valódi számkonverziót akarsz, használd az `f16()` függvényt!

**Mikor használjuk az explicit konverziót?**
- Ha egy számot **értékként** szeretnénk f16-ba rakni: `f16(5)` → 5.0
- Float literáloknál: `f16(1.5)` → compile-time konvertálódik, nincs runtime overhead

**Mikor használjuk az implicit értékadást?**
- Ha **nyers bájtokat** töltünk be (pl. file-ból, memóriából)
- Ha pontosan tudjuk, mit csinálunk a memóriaszinten

#### Túlcsordulás viselkedés

A fixed-point típusoknál **wraparound** történik:

| Típus | Túlcsordulás példa           |
| ----- | ---------------------------- |
| `f16` | `f16(200)` → -56.0 (200-256) |
| `f32` | `f32(40000)` → -25536.0      |

#### Sebesség összehasonlítás (ciklusok, ~1 MHz)

| Művelet  | int  | f16  | f32   | float |
| -------- | ---- | ---- | ----- | ----- |
| Add/Sub  | ~10  | ~10  | ~20   | ~200  |
| Multiply | ~100 | ~150 | ~500  | ~500  |
| Divide   | ~200 | ~300 | ~1000 | ~1000 |

A f16 **összeadása/kivonása ugyanolyan gyors, mint az int** - csak a szorzás/osztás lassabb.

### 3.4 String (Pascal-típusú)

A string Pascal-típusú: az első byte a hosszat tartalmazza, utána következnek a karakterek.

```
[hossz][karakter1][karakter2]...[karakterN]
```

Maximum 255 karakter hosszú lehet (a hossz 1 byte-on tárolódik).

#### Deklaráció és kapacitás

A stringnél meg kell különböztetni a **kapacitást** és a **hosszat**:

| Fogalom       | Mit jelent                         | Honnan tudjuk           |
| ------------- | ---------------------------------- | ----------------------- |
| **Kapacitás** | Maximum hány karakter fér bele     | Deklarációban adjuk meg |
| **Hossz**     | Aktuálisan hány karakter van benne | Az első byte tárolja    |

```
string[10] = "Hello"

Memória:  [5][H][e][l][l][o][?][?][?][?][?]
           ↑                 ↑
         hossz=5         kapacitás=10 (még 5 hely van)
```

```python
# Szintaxis
név: string = "konstans"           # kapacitás a konstansból (5 karakter)
név: string[kapacitás]             # explicit kapacitás (üres string)
név: string[kapacitás] = "kezdő"   # explicit kapacitás, előre feltöltve
```

> **Megjegyzés:** A memóriában a kapacitás+1 byte foglalódik le (az első byte a hossz).

**Szabályok:**

| Eset                   | Kapacitás megadása | Magyarázat                                    |
| ---------------------- | ------------------ | --------------------------------------------- |
| Konstans inicializálás | Opcionális         | Kapacitás a konstansból kiszámítható          |
| Nincs inicializálás    | **Kötelező**       | Különben nem tudjuk, mennyi helyet foglaljunk |

```python
def example():
    # Konstansból - kapacitás automatikus (5 karakter fér bele)
    greeting: string = "Hello"           # 6 byte (1 hossz + 5 kar)

    # Explicit kapacitás - dinamikus tartalomhoz
    buffer: string[80]                   # 81 byte, 0-80 karakter férhet bele
    line: string[40]                     # 41 byte, 0-40 karakter férhet bele

    # Explicit kapacitás + konstans - előre feltöltve, de bővíthető
    msg: string[100] = "Score: "         # 101 byte, most 7 kar, max 100

    hossz: byte
    hossz = len(greeting)                # 5 - aktuális hossz, O(1)
```

**Miért Pascal-típusú:**
- Gyors hossz lekérdezés (O(1), nem kell végigmenni a stringen)
- Biztonságosabb (a hossz mindig ismert)

#### Escape szekvenciák

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

#### String műveletek

| Művelet  | Leírás            | Példa                    |
| -------- | ----------------- | ------------------------ |
| `len(s)` | Hossz lekérdezése | `len("hello")` → 5       |
| `+`      | Összefűzés        | `"ab" + "cd"` → `"abcd"` |
| `*`      | Ismétlés          | `"ab" * 3` → `"ababab"`  |

**String ismétlés és const():**

```python
# Futásidőben számolódik
SEPARATOR = "-" * 40

# Fordításkor kiértékelve (beágyazva az adatszegmensbe)
SEPARATOR = const("-" * 40)    # 40 kötőjel tárolva
```

A `const()` egy preprocesszor direktíva a fordítási idejű kiértékeléshez.

#### String módosítása

A Pythonnal ellentétben a PyCo stringek **módosíthatók (mutable)**:

```python
def example():
    s: string = "hello"
    c: char

    c = s[0]             # "h" - olvasás
    s[0] = "H"           # "Hello" - írás
    s[4] = "!"           # "Hell!" - módosítás
```

**Negatív indexelés (Python-stílus):**

```python
def example():
    s: string = "hello"
    c: char

    c = s[-1]            # "o" - utolsó karakter
    c = s[-2]            # "l" - utolsó előtti
```

> **Megjegyzés:** Negatív konstans index esetén a fordító a méret alapján választ típust:
> - `-1..-128` → 8 bites `sbyte` indexelés (gyorsabb)
> - `-129..-255` → 16 bites `int` indexelés (lassabb, de szükséges)
>
> Pozitív konstans indexnél (`s[0]`, `s[5]`) mindig gyors 8 bites indexelés történik.

> **FIGYELEM:** Nincs index ellenőrzés! A határon túli indexelés nem definiált viselkedést okoz. A programozó felelőssége a helyes méretkezelés.

### 3.5 Tömbök (array)

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

**Index típus automatikus választás:**

| Elemszám | Index típus | Magyarázat                |
| -------- | ----------- | ------------------------- |
| ≤ 256    | byte        | Gyorsabb indexelés        |
| > 256    | word        | Nagyobb tömbök támogatása |

**Fill inicializálás (egyértékű kitöltés):**

```python
def example():
    zeros: array[byte, 100] = [0]       # 100 bájt nullázva
    ones: array[byte, 50] = [1]         # 50 bájt 1-essel
    pattern: array[byte, 256] = [0xaa]  # 256 bájt 0xAA-val
```

**Szabályok:**
- Csak egy elem a szögletes zárójelben: `[érték]`
- Az érték byte literál kell legyen (0-255)
- Az egész memóriaterületet bájtonként tölti ki

**Tuple inicializálás (több érték megadása):**

```python
def example():
    scores: array[byte, 5] = (10, 20, 30, 40, 50)  # 5 érték megadva
    partial: array[byte, 10] = (1, 2, 3)           # csak 3 érték, a maradék nincs inicializálva
    words: array[word, 3] = (1000, 2000, 3000)     # word értékek
```

**Szabályok:**
- Kerek zárójelben, vesszővel elválasztva: `(érték1, érték2, ...)`
- Minden érték konstans literál kell legyen (nem változó!)
- Kevesebb elemet is megadhatsz a tömb méreténél - nincs ellenőrzés!
- Az értékek a data szegmensből másolódnak be runtime-ban

**Osztály típusú tömbök (laposított byte értékek):**

Osztály típusú tömbök esetén a tuple a property értékeket byte-okként tartalmazza, laposított formában:

```python
class Position:
    x: byte = 0
    y: byte = 0

class Snake:
    # 3 Position objektum, mindegyikben x és y property
    # A tuple tartalmazza: x0, y0, x1, y1, x2, y2 (összesen 6 byte)
    body: array[Position, 3] = (18, 12, 19, 12, 20, 12)

def main():
    snake: Snake
    snake()                 # Inicializálás
    print(snake.body[0].x)  # 18
    print(snake.body[0].y)  # 12
    print(snake.body[1].x)  # 19
```

**Szabályok osztály típusú tömb tuple-ökhöz:**
- Minden tuple érték **byte** (0-255), nem osztály példány
- Az értékek property sorrendben követik egymást: először a 0. elem összes property-je, majd az 1. elemé, stb.
- Tuple értékek száma = elemszám × osztály mérete byte-ban
- Ez közvetlen memória layout kontrollt biztosít, hasznos sprite adatokhoz, játék objektumokhoz, stb.

**Összehasonlítás:**

| Szintaxis                     | Jelentés                       | Mikor használd?                |
| ----------------------------- | ------------------------------ | ------------------------------ |
| `[0]`                         | Kitöltés egyértékkel           | Nullázás, inicializálás        |
| `(1, 2, 3)`                   | Konkrét értékek megadása       | Lookup táblák, sprite adatok   |

> **FIGYELEM:** Nincs index ellenőrzés! A határon túli indexelés nem definiált viselkedést okoz.

**Többdimenziós tömbök:** A nyelv csak egydimenziós tömböket támogat. Többdimenziós adatszerkezetekhez wrapper class használható:

```python
class Matrix:
    data: array[int, 50]  # 5 sor × 10 oszlop
    cols: int = 10

    def get(x: int, y: int) -> int:
        return data[y * cols + x]

    def set(x: int, y: int, value: int):
        data[y * cols + x] = value
```

#### Karaktertömbök és string értékadás

A `char` elemű tömböknek (`array[char, N]`) string értéket is adhatunk. Ilyenkor a string **hossz byte nélkül** másolódik be - ez különösen hasznos képernyő memória kezelésnél:

```python
SCREEN = 0x0400

def example():
    # Képernyő első sora (40 karakter)
    row: array[char, 40][SCREEN]

    row = "Hello!"         # "Hello!" közvetlenül a képernyőre, hossz nélkül
```

> **FIGYELEM:** A compiler nem ellenőrzi, hogy a string belefér-e a tömbbe! Ha a string hosszabb mint a tömb mérete, a túlnyúló karakterek felülírják a memória következő bájtjait.

**Fordított irány: karaktertömb → string**

Karaktertömböt stringhez is rendelhetünk. Ilyenkor a másolás addig tart, amíg:
- `\0` (null) karaktert talál, VAGY
- eléri a `min(tömb mérete, string kapacitása)` limitet

```python
def example():
    chars: array[char, 40]
    s: string[50]

    # ... chars feltöltése ...
    s = chars              # \0-ig vagy min(40, 50) = 40 karakterig másol
```

Így mindkét világ támogatott: a null-terminált (C-stílusú) és a fix hosszú karaktertömbök egyaránt.

**Összehasonlítás:**

| Irány                    | Viselkedés                                            |
| ------------------------ | ----------------------------------------------------- |
| `string` → `array[char]` | Hossz byte nélkül másolja a karaktereket              |
| `array[char]` → `string` | `\0`-ig vagy `min(N, M)`-ig másol, beállítja a hosszt |

> **Megjegyzés:** Lokális változóknál mindkét buffer mérete ismert fordítási időben, így a `min(N, M)` limit automatikusan érvényesül. Függvényparaméternél (ha a méret nem ismert) a másolás a `\0` karakterig vagy maximum 255 byte-ig tart.

### 3.6 Tuple (csak olvasható adat és pointer változók)

A tuple hatékony hozzáférést biztosít fix adatsorozatokhoz. A PyCo **kétféle tuple változatot** támogat:

1. **Inicializált tuple** - Csak olvasható konstans adat a data szegmensben
2. **Tuple pointer változó** - Módosítható pointer, amely különböző tuple-kre mutathat

```python
tuple[elem_típus]
```

#### Inicializált Tuple (konstans adat)

Ha egy tuple változót tuple literállal inicializálunk, az **csak olvasható konstanssá** válik:

```python
def example():
    # Inicializált tuple - csak olvasható, data szegmensben tárolódik
    colors: tuple[byte] = (0, 2, 5, 7, 10, 14)

    # Indexelés működik
    x: byte = colors[2]    # x = 5

    # Írás TILOS - fordítási hiba!
    # colors[0] = 99       # HIBA: inicializált tuple csak olvasható
    # colors = other       # HIBA: nem lehet újra értéket adni
```

#### Tuple Pointer Változó

Ha egy tuple változót **inicializálás nélkül** deklarálunk, az **pointer változóvá** válik, amelynek később adhatunk értéket:

```python
def example():
    data1: tuple[byte] = (10, 20, 30)   # Inicializált (konstans)
    data2: tuple[byte] = (40, 50, 60)   # Inicializált (konstans)

    # Tuple pointer változó (nem inicializált)
    ptr: tuple[byte]

    # Kezdetben üres (len = 0)
    print(len(ptr))    # Kimenet: 0

    # Értéket adhatunk
    ptr = data1
    print(ptr[0])      # Kimenet: 10
    print(len(ptr))    # Kimenet: 3

    # Átírhatjuk
    ptr = data2
    print(ptr[0])      # Kimenet: 40
```

Ez hasznos:
- Különböző adathalmazok közötti futásidejű választáshoz
- Tuple-k függvényparaméterként való átadásához
- Osztály property-k, amelyek tuple adatra mutatnak

**Különbség az array-hoz képest:**

| Tulajdonság        | `array[T, N]`                    | `tuple[T]`                     |
| ------------------ | -------------------------------- | ------------------------------ |
| Méret megadása     | Kötelező: `array[byte, 10]`      | Automatikus a literálból       |
| Tárolás            | Stack (másolódik runtime-ban)    | Data szegmens (nincs másolás)  |
| Módosítható?       | ✅ Igen                          | ❌ Nem                         |
| Inicializálás      | `[v]` fill vagy `(v1,v2)` tuple  | Csak `(v1, v2, ...)` tuple     |
| Sebesség           | Lassabb (memória másolás)        | Gyorsabb (közvetlen elérés)    |
| Paraméterként      | `alias[array[T, N]]`             | `tuple[T]`                     |

**Mikor használd a tuple-t?**

- Konstans adatok (sprite patterns, font data, lookup tables)
- Nagy adatblokkok, amik nem változnak futás közben
- Sebesség-kritikus esetekben (nincs runtime másolás)

**Mikor használj array-t?**

- Módosítandó adatok
- Pufferek, változó tartalom

**Tuple mint osztály property:**

A tuple-k használhatók osztály property-ként ugyanazzal a kétféle viselkedéssel:

```python
class Level:
    # Inicializált tuple property - MINDEN instance által megosztva (konstans)
    default_colors: tuple[byte] = (0, 2, 5, 7, 10, 14)

    # Tuple pointer property - minden instance-nak más adatra mutathat
    current_data: tuple[byte]

def main():
    level: Level

    # Minden Level instance ugyanazt a default_colors-t látja (gyors!)
    x: byte = level.default_colors[0]

    # Minden instance más adatra mutathat
    level.current_data = level.default_colors
```

> **Megjegyzés:** Az inicializált tuple property-k (`= (...)`) egyszer tárolódnak a data szegmensben és minden instance megosztja őket. A tuple pointer property-k 2 byte-ot foglalnak instance-onként.

**Tuple konstans modul szinten:**

A tuple literálokat NAGYBETŰS konstansként definiálhatod modul szinten, és a preprocesszor behelyettesíti őket a használat helyén. Ez lehetővé teszi a sprite adatok külön fájlban történő tárolását:

```python
# sprites.pyinc - külön fájlban
SPRITE_ENEMY = (0xFF, 0xAA, 0x55, 0x00, ...)
SPRITE_PLAYER = (0x3C, 0x7E, 0xFF, ...)
```

```python
# main.pyco
include("sprites")

def main():
    # A konstans behelyettesítődik - mintha ide írtuk volna
    enemy_data: tuple[byte] = SPRITE_ENEMY
    player_data: tuple[byte] = SPRITE_PLAYER
```

```python
# Sprite mintázat - soha nem változik
SPRITE_DATA: tuple[byte] = (
    0x00, 0x7E, 0x00,
    0x03, 0xFF, 0xC0,
    0x07, 0xFF, 0xE0,
    # ... 21 sor × 3 byte
)

def main():
    # Gyors hozzáférés, nincs másolás
    first_row: byte = SPRITE_DATA[0]
```

**Tuple méret:** A tuple tartalmaz egy 2 byte-os méret előtagot (word), így a `len()` függvény runtime-ban is működik rá:

```python
def print_all(data: tuple[byte]):
    i: word

    for i in range(len(data)):  # len() a tuple méretét adja
        print(data[i])
```

**Array feltöltése tuple-ből:**

Egy array értékét egy tuple-ből másolhatjuk át. Ez **nyers memória másolás** (memcpy) a data szegmensből a stack-re - nincs típusellenőrzés!

```python
def main():
    # Konstans adat a data szegmensben
    default_values: tuple[byte] = (10, 20, 30, 40, 50)

    # Módosítható array a stack-en
    buffer: array[byte, 10]

    # Másolás tuple-ből array-be
    buffer = default_values

    # Most már módosítható!
    buffer[0] = 99
```

**Típusfüggetlen másolás:** Mivel ez nyers memcpy, különböző típusú tuple-t is másolhatsz byte array-be, hogy byte szinten hozzáférj az adatokhoz:

```python
def main():
    # Word adatok
    words: tuple[word] = (0x1234, 0x5678)

    # Byte-onként elérhető másolat
    bytes: array[byte, 10]
    bytes = words

    # Little-endian: bytes[0] = $34, bytes[1] = $12, bytes[2] = $78, bytes[3] = $56
    print(bytes[0])  # 52 ($34)
    print(bytes[1])  # 18 ($12)
```

Ez hasznos, ha van egy konstans adathalmaz (pl. default értékek), amit módosítani akarunk futás közben, vagy ha byte szinten akarunk hozzáférni nagyobb típusokhoz.

---

## 4. Memory-mapped programozás

A memory-mapped változók fix memóriacímhez kötött változók. A hardver regiszterek és memória közvetlen eléréséhez használjuk őket.

### 4.1 Memory-mapped változók

```python
név: típus[cím]
```

```python
border: byte[0xD020]        # VIC border color regiszter
bg: byte[0xD021]            # VIC background color
sprite0_x: byte[0xD000]     # Sprite 0 X koordináta
```

**Használat:**

```python
def example():
    border: byte[0xD020]
    bg: byte[0xD021]
    x: byte

    border = 0              # STA $D020
    x = bg                  # LDA $D021
```

**Előny:** Gyorsabb, mert a fordító közvetlen memória műveleteket generál, nincs függvényhívás (peek/poke).

### 4.2 Memory-mapped tömbök

```python
név: array[típus, méret][cím]
```

```python
def example():
    screen: array[byte, 1000][0x0400]   # Képernyő memória
    colors: array[byte, 1000][0xD800]   # Szín memória
    i: byte = 0
    x: byte = 65

    screen[0] = 1           # $0400-ra ír
    screen[i] = x           # $0400 + i címre ír
```

#### Memory-mapped karaktertömbök

Az `array[char, N]` típus különösen hasznos képernyő memória kezelésére, mert string értéket is kaphat - ilyenkor a Pascal hossz byte **nélkül** másolódik be:

```python
SCREEN = 0x0400
COLOR = 0xD800

def example():
    screen: array[char, 1000][SCREEN]
    color: array[byte, 1000][COLOR]

    screen = "Hello!"          # közvetlenül a képernyőre ír (hossz nélkül!)
    color[0] = 1               # első karakter fehér
```

> **Megjegyzés:** Ez csak egyszerűsített példa. A PETSCII/ASCII karakterkódok nem mindig egyeznek a képernyőkódokkal - egyes karakterek (pl. nagybetűk) esetén további konverzió szükséges a helyes megjelenítéshez.

### 4.3 Memory-mapped stringek

Fix memóriacímre mappelt Pascal-típusú string buffer:

```python
BUFFER_ADDR = 0xC000

def example():
    # Külső buffer (pl. kommunikációhoz)
    buffer: string[80][BUFFER_ADDR]    # 81 byte a $C000 címtől

    buffer = "Hello!"          # hossz byte + karakterek
    print(buffer)              # működik a print-tel
```

> **FIGYELEM:** A Pascal-típusú string első byte-ja a hossz! Képernyő memóriára NEM ajánlott, mert a hossz byte is megjelenik karakterként. Képernyő kezeléshez használj `array[char, N]` típust!

> **Megjegyzés:** Memory-mapped stringnél a kapacitás megadása kötelező a szintaxis egyértelműsége miatt - különben a fordító nem tudná megkülönböztetni a címet a kapacitástól.

### 4.4 Memory-mapped osztályok (hardver wrapperek)

Amikor egy osztály **összes** tulajdonsága memory-mapped (fix címre mutat), az osztály "mapped-only" osztállyá válik. Ez különösen hasznos hardver wrapperek készítéséhez:

```python
class VIC:
    border: byte[0xD020]
    bg0: byte[0xD021]
    bg1: byte[0xD022]
    bg2: byte[0xD023]
    sprite_enable: byte[0xD015]

    def flash_border(color: byte):
        self.border = color

    def reset():
        self.border = 14
        self.bg0 = 6
```

**Használat:**

```python
def main():
    vic: VIC

    vic.border = 0           # közvetlen: STA $D020
    vic.flash_border(1)      # metódushívás is működik
```

**A mapped-only osztályok előnyei:**

| Szempont              | Normál osztály            | Mapped-only osztály      |
| --------------------- | ------------------------- | ------------------------ |
| Memóriahasználat      | `total_size` byte/példány | 0 byte (nincs allokáció) |
| Metódushívás sebesség | Normál                    | ~2-3x gyorsabb           |

**Fontos szabályok:**

1. **Detektálás**: Egy osztály mapped-only, ha van legalább egy tulajdonsága ÉS `total_size == 0` (beleértve örökölt tulajdonságokat)
2. **Öröklődés**: Ha az ősosztálynak vannak normál (nem mapped) tulajdonságai, a leszármazott NEM mapped-only
3. **Több példány**: Létrehozhatsz több "példányt", de ezek mind ugyanarra a memóriára mutatnak

```python
class SpriteRegs:
    x: byte[0xD000]
    y: byte[0xD001]

def main():
    s1: SpriteRegs
    s2: SpriteRegs

    s1.x = 100     # $D000 = 100
    s2.x = 200     # $D000 = 200 (felülírja s1-et!)
    # s1.x és s2.x UGYANAZ a memóriacím!
```

> **Tipp:** Mapped-only osztályok ideálisak hardver regiszterek típusos eléréséhez. A metódusok segítségével komplex hardver műveleteket is áttekinthetően implementálhatsz.

### 4.5 IRQ-biztos változók (irq_safe)

Az `irq_safe` egy wrapper típus, ami **atomi hozzáférést** biztosít memory-mapped változókhoz. Ez kritikus fontosságú olyan változóknál, amelyeket mind a főprogram, mind az IRQ handler használ.

#### A probléma

A többbájtos típusok (word, int) olvasása és írása **több gépi utasítást** igényel. Ha egy megszakítás (IRQ) félbeszakítja a műveletet, "torn read/write" (szakadt olvasás/írás) történik - az IRQ handler félig frissített, inkonzisztens értéket lát.

```python
# VESZÉLYES - IRQ félbeszakíthatja!
SHARED_ADDR = 0x0080  # Platform-függő cím

@singleton
class State:
    counter: word[SHARED_ADDR]    # 2 bájt = 2 utasítás

def main():
    State.counter = 12345
    # ↑ Ha IRQ pont a két bájt írása között szakítja meg,
    #   az IRQ handler hibás értéket olvashat!
```

#### Megoldás: irq_safe wrapper

Az `irq_safe` wrapper automatikusan letiltja az IRQ-t a művelet idejére:

```python
irq_safe[típus[cím]]
```

```python
SHARED_ADDR = 0x0080

@singleton
class State:
    counter: irq_safe[word[SHARED_ADDR]]    # Atomi hozzáférés

def main():
    State.counter = 12345    # Védett: IRQ nem szakíthatja félbe
```

#### Működési elv

A fordító az `irq_safe` változók elérésekor:

1. **Elmenti** az aktuális interrupt flag állapotot
2. **Letiltja** az IRQ-t
3. **Végrehajtja** az olvasást vagy írást
4. **Visszaállítja** az eredeti interrupt flag állapotot

> **Miért nem egyszerű SEI/CLI?** Ha a felhasználó már korábban letiltotta az IRQ-t (`__sei__()`), a CLI véletlenül újra engedélyezné. Az eredeti állapot visszaállítása megőrzi a user szándékát.

#### Használat IRQ handlerben

Az IRQ handleren belül (`@irq`, `@irq_raw`) a védelem **automatikusan kimarad**, mivel:

1. A CPU automatikusan letiltja az IRQ-t amikor belép a handlerbe
2. További tiltás felesleges overhead lenne

```python
SHARED_ADDR = 0x0080

@singleton
class Game:
    score: irq_safe[word[SHARED_ADDR]]

@irq
def timer_irq():
    # Itt NEM generálódik védelem - már IRQ kontextusban vagyunk
    if Game.score > 0:
        Game.score = Game.score - 1

def main():
    # Itt generálódik a védelem
    print(Game.score)    # Atomi olvasás
```

#### Támogatott típusok

Az `irq_safe` wrapper az alábbi memory-mapped típusokkal használható:

| Típus  | Leírás                                       |
| ------ | -------------------------------------------- |
| byte   | 1 bájt (védelem konzisztencia miatt)         |
| sbyte  | 1 bájt előjeles                              |
| word   | 2 bájt - **kritikus**, 2 utasítás szükséges  |
| int    | 2 bájt előjeles - **kritikus**               |

> **Megjegyzés:** A `byte` típusnál a védelem technikailag nem szükséges (egyetlen utasítás), de a konzisztencia és jövőbiztonság érdekében a fordító mégis generálja.

#### Mikor használd?

| Helyzet                                           | Használj irq_safe-et? |
| ------------------------------------------------- | --------------------- |
| Változó csak főprogramban használt                | Nem szükséges         |
| Változó csak IRQ handlerben használt              | Nem szükséges         |
| Változó mindkét helyen használt (olvasás/írás)    | **Igen!**             |
| Többbájtos típus (word, int) megosztott használat | **Feltétlenül!**      |

#### Példa: Megosztott számláló

```python
# Platform-specifikus címek (lásd a compiler referenciát)
COUNTER_ADDR = 0x0080

@singleton
class SharedState:
    counter: irq_safe[word[COUNTER_ADDR]]
    flag: irq_safe[byte[COUNTER_ADDR + 2]]

@irq
def timer_handler():
    # IRQ kontextus - védelem nélkül
    SharedState.counter = SharedState.counter + 1

def main():
    SharedState.counter = 0
    SharedState.flag = 1

    # ... program logika ...

    # Biztonságos olvasás - atomi
    if SharedState.counter > 1000:
        SharedState.flag = 0
```

> **Platform-specifikus részletek:** A konkrét memóriacímek, IRQ vector beállítás és a generált assembly kód a target platformtól függ. Lásd az adott platform compiler referenciáját (pl. C64, Plus/4, stb.).

---

## 5. Alias és referenciák

Az `alias` egy **típusos referencia**, ami futásidőben beállítható memóriacímre mutat. Úgy viselkedik, mintha az eredeti változó lenne - átlátszó elérést biztosít.

```python
alias[típus]
```

Futásidőben döntheted el, melyik memóriaterületre mutasson.

> **C programozóknak:** Az alias hasonló a C nyelv pointereihez, de van néhány fontos különbség:
> - Nincs dereferálás szintaxis (`*ptr`) - az alias automatikusan "átlátszó", közvetlenül használható
> - Nincs null pointer - az alias mindig érvényes címre kell mutasson
> - Típusbiztos - az `alias[byte]` csak byte-ként kezeli a mutatott memóriát

### 5.1 Alias vs Memory-mapped összehasonlítás

| Tulajdonság      | Memory-mapped          | Alias                       |
| ---------------- | ---------------------- | --------------------------- |
| Cím megadása     | Fordítási időben (fix) | Futásidőben (dinamikus)     |
| Szintaxis        | `var: byte[0xD020]`    | `var: alias[byte]`          |
| Cím módosítható? | Nem                    | Igen, `alias()` függvénnyel |
| Használat        | Hardver regiszterek    | Dinamikus adatszerkezetek   |
| Overhead         | 0 (közvetlen cím)      | 2 byte (pointer tárolás)    |

### 5.2 Alias deklaráció és beállítás

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
    alias(e, addr(enemy))        # e most enemy-re mutat
    alias(s, addr(score))        # s most score-ra mutat
    alias(b, addr(buffer))       # b a buffer első elemére mutat

    # Fix címre is mutathat
    alias(s, 0xC000)             # s a $C000 címre mutat

    # Pointer aritmetika is lehetséges!
    alias(b, addr(buffer) + 10)  # b a 10. elemre mutat
```

### 5.3 Az addr() függvény

Az `addr()` függvény visszaadja egy változó, property vagy tömbelem memóriacímét:

```python
def example():
    enemy: Enemy
    ptr: word

    ptr = addr(enemy)            # enemy memóriacíme
    print(ptr)                   # pl. 2048
```

**addr() objektum property-kkel:**

Lekérdezheted egy objektum property-jének címét, akár láncolt hozzáféréssel:

```python
class Position:
    x: byte = 0
    y: byte = 0

class Enemy:
    pos: Position
    hp: byte = 0

    def __init__():
        self.pos()

def example():
    enemy: Enemy
    ptr: alias[byte]

    enemy()
    enemy.pos.x = 50

    alias(ptr, addr(enemy.pos.x))  # enemy.pos.x címe
    print(ptr)                      # 50

    # Bármilyen mélységű láncolás működik
    # addr(obj.a.b.c) érvényes
```

**addr() tömbelemekkel:**

```python
def example():
    arr: array[byte, 10] = [0]
    ptr: alias[byte]

    arr[5] = 42
    alias(ptr, addr(arr[5]))       # arr[5] címe
    print(ptr)                      # 42
```

**Pointer aritmetika:**

Ez hasznos pointer aritmetikához:

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

**addr() alias változóval:**

Ha az `addr()` függvényt alias változóval hívjuk meg, az **alias által mutatott címet** adja vissza - nem az alias változó tárolási címét:

```python
def example():
    x: byte = 42              # x a stack-en van
    a: alias[byte]            # a is a stack-en (2 byte pointer)
    ptr: word

    alias(a, 0xD020)          # a mostantól 0xD020-ra mutat

    ptr = addr(x)             # → x valódi memóriacíme a stack-en
    ptr = addr(a)             # → 0xD020 (az alias által mutatott cím!)
```

Ez a viselkedés összhangban van az alias átlátszó szemantikájával: minden művelet az alias-on keresztül a mutatott dologra vonatkozik.

**addr() függvény címe:**

Az `addr()` függvénnyel egy függvény címét is lekérdezhetjük. Ez különösen hasznos IRQ vektorok beállításához:

```python
@irq
def raster_handler():
    vic_irq: byte[0xD019]
    vic_irq = 0xFF               # IRQ nyugtázása

def main():
    irq_vector: word[0x0314]     # Kernal IRQ vektor

    __sei__()                    # Megszakítások tiltása
    irq_vector = addr(raster_handler)  # IRQ handler beállítása
    __cli__()                    # Megszakítások engedélyezése
```

> **Megjegyzés:** Ez a funkció elsősorban `@irq` dekorátorral jelölt függvényekkel használatos. Az IRQ kezelésről részletesebben lásd az [Interrupt kezelés](#13-interrupt-kezelés-c64) fejezetet.

### 5.4 Alias használata - átlátszó elérés

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

### 5.5 Alias paraméterként

> **SZABÁLY:** Összetett típusok (objektum, tömb, string) **csak alias-ként** adhatók át függvénynek!

```python
# HELYES - alias paraméter
def process_enemy(e: alias[Enemy]):
    e.x = 50                     # Módosítja az eredetit!
    e.health -= 10

def sum_array(arr: alias[array[byte, 10]]) -> word:
    total: word = 0
    i: byte
    for i in range(len(arr)):
        total += arr[i]
    return total

# HIBÁS - összetett típus közvetlenül
# def bad_function(e: Enemy):      # FORDÍTÁSI HIBA!
```

**Automatikus alias konverzió:**

Ha egy függvény `alias[T]` típusú paramétert vár, a fordító automatikusan alias-ként adja át a változót. A felhasználónak egyszerűen a változót kell átadnia - a fordító elvégzi a konverziót:

```python
def main():
    enemy: Enemy
    buffer: array[byte, 10]

    process_enemy(enemy)         # A fordító automatikusan alias-ként adja át
    sum_array(buffer)            # A fordító automatikusan alias-ként adja át
```

**Alias változó átadása:**

Ha már van egy alias változód, azt is átadhatod függvénynek. A fordító a tárolt pointer értékét adja át:

```python
def main():
    enemy: Enemy
    enemy()                      # Inicializálás
    e_alias: alias[Enemy]

    alias(e_alias, addr(enemy))  # e_alias → enemy címe
    process_enemy(e_alias)       # Az e_alias TARTALMÁT (enemy címét) adja át

    # Mindkét hívás ugyanazt eredményezi:
    process_enemy(enemy)         # Közvetlenül
    process_enemy(e_alias)       # Alias változón keresztül
```

**Alias primitívekre (pass-by-reference):**

Primitív típusok (byte, word, int stb.) alapértelmezetten érték szerint adódnak át. Ha módosítani szeretnéd az eredeti értéket, használj `alias[T]`-t:

```python
def increment(x: alias[byte]):
    x = x + 1                    # Az EREDETI változót módosítja!

def main():
    val: byte = 10
    increment(val)               # Automatikus alias konverzió
    print(val)                   # → 11
```

> **Megjegyzés:** Az `alias[alias[T]]` (beágyazott alias) **nem megengedett**! Egy pointer-re mutató pointer felesleges komplexitás lenne. Használj egyszerű `alias[T]`-t.

### 5.6 Alias visszatérési értékként

> **SZABÁLY:** Összetett típusok visszatérése **csak alias-ként** lehetséges!

```python
def create_enemy() -> alias[Enemy]:
    e: Enemy
    e()                          # Inicializálás
    e.x = 100
    e.y = 50
    return e                     # e alias-ként adódik vissza

def main():
    enemy: Enemy
    enemy = create_enemy()       # Az alias MÁSOLÓDIK enemy-be
```

> ⚠️ **FIGYELEM:** Az alias visszatérési érték **csak az adott statement végéig érvényes!**

**Miért?** Amikor egy függvény visszatér, a stack frame-je felszabadul. Az alias a függvény lokális változójára mutat, ami a stack-en volt. A statement végén ez a memóriaterület már "szabad" - a következő függvényhívás vagy változó deklaráció felülírhatja!

**Biztonságos használat - azonnali másolás:**

```python
def main():
    result: Enemy

    result = create_enemy()      # ✅ OK - azonnal másolódik result-ba
    # A create_enemy stack frame-je felszabadult, DE az adat már result-ban van
```

**Veszélyes használat - alias mentése:**

```python
def main():
    enemy_ptr: alias[Enemy]

    alias(enemy_ptr, addr(create_enemy()))  # ⚠️ VESZÉLYES!
    # A következő sorban enemy_ptr már "szemét" adatra mutathat!

    do_something()               # Ez a hívás felülírhatja a stack-et
    print(enemy_ptr.x)           # ← Memóriaszemét olvasása!
```

**A szabály egyszerű:** Ha alias-t kapsz vissza, **azonnal másold** egy rendes változóba, vagy használd fel ugyanabban a sorban.

### 5.7 Típuskategóriák összefoglalása

| Kategória     | Típusok                                   | Paraméterként     | Visszatérésként  |
| ------------- | ----------------------------------------- | ----------------- | ---------------- |
| **Primitív**  | byte, sbyte, word, int, bool, char, float | Érték szerint     | Érték            |
| **Összetett** | array, string, osztályok                  | Automatikus alias | `alias[T]` típus |

### 5.8 Gyakorlati példa: újrahasznosítható lista kezelő

```python
class ByteList:
    data: alias[byte]            # Bármelyik byte array-re mutathat
    capacity: byte
    count: byte = 0

    def init(data_ptr: word, cap: byte):
        alias(data, data_ptr)
        capacity = cap
        count = 0

    def add(value: byte) -> bool:
        if count >= capacity:
            return False
        data[count] = value
        count += 1
        return True

    def get(index: byte) -> byte:
        return data[index]

def main():
    # Deklarációk a függvény elején
    bullets: array[byte, 50]
    scores: array[byte, 10]
    bullet_list: ByteList
    score_list: ByteList

    # Inicializálás és használat
    bullet_list.init(addr(bullets), len(bullets))
    bullet_list.add(42)

    score_list.init(addr(scores), len(scores))
    score_list.add(100)
```

> **FIGYELEM:** Az alias nem ellenőrzi, hogy érvényes címre mutat-e! Inicializálatlan alias használata nem definiált viselkedést okoz.

---

## 6. Operátorok és kifejezések

### 6.1 Aritmetikai operátorok

| Operátor | Leírás    | Példa   |
| -------- | --------- | ------- |
| `+`      | Összeadás | `a + b` |
| `-`      | Kivonás   | `a - b` |
| `*`      | Szorzás   | `a * b` |
| `/`      | Osztás    | `a / b` |
| `%`      | Maradék   | `a % b` |

> **FONTOS:** A művelet típusa az **operandusok típusától** függ, nem az eredmény változójától! `byte + byte` mindig 8-bites művelet, még ha `word` változóba kerül is. Lásd: [Típuskonverziók](#10-típuskonverziók-és-típuskezelés)

### 6.2 Összehasonlító operátorok

| Operátor | Leírás               | Példa    |
| -------- | -------------------- | -------- |
| `==`     | Egyenlő              | `a == b` |
| `!=`     | Nem egyenlő          | `a != b` |
| `<`      | Kisebb               | `a < b`  |
| `>`      | Nagyobb              | `a > b`  |
| `<=`     | Kisebb vagy egyenlő  | `a <= b` |
| `>=`     | Nagyobb vagy egyenlő | `a >= b` |

### 6.3 Logikai operátorok

| Operátor | Leírás       | Példa     |
| -------- | ------------ | --------- |
| `and`    | Logikai ÉS   | `a and b` |
| `or`     | Logikai VAGY | `a or b`  |
| `not`    | Logikai NEM  | `not a`   |

### 6.4 Bitműveleti operátorok

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

### 6.5 Értékadó operátorok

| Operátor | Egyenértékű  |
| -------- | ------------ |
| `=`      | `a = b`      |
| `+=`     | `a = a + b`  |
| `-=`     | `a = a - b`  |
| `*=`     | `a = a * b`  |
| `/=`     | `a = a / b`  |
| `%=`     | `a = a % b`  |
| `&=`     | `a = a & b`  |
| `\|=`    | `a = a \| b` |
| `^=`     | `a = a ^ b`  |
| `<<=`    | `a = a << b` |
| `>>=`    | `a = a >> b` |

**Optimalizáció:** A `+= 1` és `-= 1` műveletek optimalizált gépi kódot generálhatnak (platform-függő). Például C64-en:

| Változó típus      | `+= 1` kód                     | Sebesség   |
| ------------------ | ------------------------------ | ---------- |
| Memory-mapped byte | `inc $addr` (1 utasítás)       | ~6 ciklus  |
| Stack byte         | `lda/clc/adc/sta` (5 utasítás) | ~15 ciklus |

### 6.6 Operátor precedencia

A precedencia Python-t követi. Magasabb precedencia = előbb értékelődik ki.

| Szint | Operátorok                       | Leírás                   |
| ----- | -------------------------------- | ------------------------ |
| 1     | `()`                             | Zárójelezés              |
| 2     | `**`                             | Hatványozás              |
| 3     | `~`, `+x`, `-x`                  | Unáris operátorok        |
| 4     | `*`, `/`, `%`                    | Szorzás, osztás, maradék |
| 5     | `+`, `-`                         | Összeadás, kivonás       |
| 6     | `<<`, `>>`                       | Bit léptetés             |
| 7     | `&`                              | Bitenkénti ÉS            |
| 8     | `^`                              | Bitenkénti XOR           |
| 9     | `\|`                             | Bitenkénti VAGY          |
| 10    | `==`, `!=`, `<`, `>`, `<=`, `>=` | Összehasonlítás          |
| 11    | `not`                            | Logikai NEM              |
| 12    | `and`                            | Logikai ÉS               |
| 13    | `or`                             | Logikai VAGY             |
| 14    | `=`, `+=`, `-=`, stb.            | Értékadás                |

> **Tipp:** Ha bizonytalan vagy, használj zárójelet!

---

## 7. Vezérlési szerkezetek

### 7.1 Elágazások

#### if

```python
if feltétel:
    utasítások
```

#### if-else

```python
if feltétel:
    utasítások
else:
    utasítások
```

#### if-elif-else

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

```python
def example():
    score: int = 85

    if score >= 90:
        print("Kiváló\n")
    elif score >= 70:
        print("Jó\n")
    elif score >= 50:
        print("Megfelelt\n")
    else:
        print("Elégtelen\n")
```

### 7.2 Ciklusok

#### while

Elöltesztelő ciklus - addig ismétel, amíg a feltétel igaz:

```python
def example():
    i: byte = 0

    while i < 10:
        print(i)
        i = i + 1
```

**Végtelen ciklus optimalizáció:** A `while True:` és `while 1:` ciklusokat a compiler optimalizálja - a felesleges feltételvizsgálat kimarad, így hatékonyabb kód generálódik. A ciklusból `break` utasítással lehet kilépni:

```python
def example():
    i: byte = 0

    while True:
        print(i)
        i += 1
        if i >= 10:  # Hátul tesztelő ciklus
            break
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

> **FONTOS:** A ciklusváltozót előre deklarálni kell! A PyCo-ban a változók függvény szinten élnek.

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

---

## 8. Függvények

### 8.1 Függvény definiálása

```python
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

Ha nincs visszatérési érték, akkor nem szabad megadni visszatérési típust, és a `return` kulcsszó sem használható.

> **FONTOS:** Függvényen belül nem definiálhatsz másik függvényt (Beágyazott függvények nem megengedettek) - minden függvényt modul szinten (a fájl "legkülső" szintjén) kell definiálni.

### 8.2 Paraméterek és visszatérési érték

**Primitív típusok érték szerint** adódnak át (másolat):

```python
def modify_int(x: int):
    x = 100      # lokális másolat módosul

def main():
    n: int = 10
    modify_int(n)
    # n még mindig 10 - az eredeti nem változott
```

**Összetett típusok referencia szerint** adódnak át - lásd [Alias paraméterként](#56-alias-paraméterként).

### 8.3 A main() belépési pont

Minden PyCo programnak **kötelezően** tartalmaznia kell egy `main()` függvényt. Ez a program belépési pontja - a végrehajtás itt kezdődik. A `main()` függvény nélkül a fordító hibát jelez.

```python
def main():
    print("Hello World!\n")
```

**Könyvtárak és main():**
A könyvtáraknak is lehet `main()` függvényük - ez teszt vagy demó kódot tartalmazhat:

```python
# mylib.pyco
def useful_function():
    pass

def main():
    # Teszt kód - csak közvetlen futtatáskor fut le
    print("Testing mylib...\n")
    useful_function()
```

- **Közvetlen futtatás:** A `main()` lefut
- **Import-kor:** A `main()` nem töltődik be

### 8.4 Dekorátorok

A függvények dekorátorokkal módosíthatók, amik platform- és fordító-specifikus viselkedést befolyásolnak. A jelenleg elérhető dekorátorok a `main()` függvényre vonatkoznak.

```python
@dekorátor_név
def main():
    pass
```

A dekorátorok a célplatformtól függenek. Például a C64 backend a következő dekorátorokat támogatja:

| Dekorátor        | Hatás                                                      |
| ---------------- | ---------------------------------------------------------- |
| `@lowercase`     | Kisbetűs karakterkészlet mód (csak main fv., C64)          |
| `@kernal`        | Kernal ROM engedélyezése (csak main fv., C64)              |
| `@noreturn`      | Cleanup kihagyása - program soha nem lép ki (main)         |
| `@irq`           | IRQ handler jelölés (rendszer IRQ-hoz láncolódik)          |
| `@irq_raw`       | Nyers IRQ handler (közvetlen rti)                          |
| `@irq_hook`      | Könnyűsúlyú Kernal IRQ hook (nincs prológ, rts return)     |
| `@forward`       | Forward deklaráció kölcsönös rekurzióhoz                   |
| `@mapped(cím)`   | Előre lefordított kód hívása fix címen                     |

> **Megjegyzés:** A platform-specifikus dekorátorok részletes leírását lásd a célplatform fordító referenciájában (pl. `c64_compiler_reference.md`).

### 8.5 Forward deklaráció (@forward)

A definíciós sorrend szabály függvényekre is érvényes - egy függvény csak már definiált függvényeket hívhat. Kölcsönös rekurzió esetén (két függvény hívja egymást) ez problémát okozna. A megoldás: **forward deklaráció**.

#### Szintaxis

```python
@forward
def függvény_név(paraméterek) -> visszatérési_típus: ...
```

A `...` (Ellipsis) jelzi, hogy ez csak deklaráció, nem implementáció. Ez a Pythonból ismert, kifejező forma egyértelműen mutatja: "itt még hiányzik valami".

#### Példa: Kölcsönös rekurzió

```python
@forward
def is_even(n: int) -> bool: ...    # Előre jelzés

def is_odd(n: int) -> bool:
    result: bool

    if n == 0:
        return False
    result = is_even(n - 1)         # OK: is_even forward-dal deklarálva
    return result

def is_even(n: int) -> bool:        # Teljes implementáció
    result: bool

    if n == 0:
        return True
    result = is_odd(n - 1)          # OK: is_odd már definiált
    return result
```

#### Szabályok

| Szabály                | Leírás                                                  |
| ---------------------- | ------------------------------------------------------- |
| Stub törzs             | A forward deklaráció törzse csak `...` (Ellipsis) lehet |
| Implementáció kötelező | Minden `@forward` függvényhez KELL teljes implementáció |
| Szignatúra egyezés     | Az implementáció szignatúrája pontosan egyezzen         |
| Ugyanabban a fájlban   | A forward és az implementáció egy modulban legyen       |

#### Hibaüzenetek

**Nem definiált függvény hívása:**
```
example.pyco:5: Error: Function 'helper' is not yet defined.
    Functions can only call previously defined functions.
    Hint: Add a forward declaration:
    @forward
    def helper(...) -> ...: ...
```

**Implementáció nélküli forward:**
```
example.pyco:2: Error: Forward declaration for 'calculate' has no implementation.
    Every @forward function must have a full implementation below.
```

**Eltérő szignatúra:**
```
example.pyco:10: Error: Function 'process' signature doesn't match its forward declaration.
    Forward: def process(x: int) -> bool
    Actual:  def process(x: int, y: int) -> bool
```

#### Metódusok

A `@forward` metódusokra is működik:

```python
class Calculator:
    @forward
    def multiply(a: int, b: int) -> int: ...

    def square(n: int) -> int:
        return self.multiply(n, n)    # OK: multiply forward-dal deklarálva

    def multiply(a: int, b: int) -> int:
        result: int = 0
        # ... implementáció
        return result
```

#### Mikor kell @forward?

| Helyzet                            | @forward kell? |
| ---------------------------------- | -------------- |
| Rekurzív függvény (önmagát hívja)  | Nem            |
| Kölcsönös rekurzió (A↔B)           | Igen           |
| Később definiált függvény hívása   | Igen           |
| Korábban definiált függvény hívása | Nem            |

### 8.6 Külső függvények (@mapped)

A `@mapped` dekorátor lehetővé teszi előre lefordított kód hívását fix memóriacímen anélkül, hogy inline assemblyt kellene használni. Ez hasznos külső rutinok (zenelejátszók, grafikus könyvtárak stb.) integrálásához, amelyek ismert címeken töltődnek be.

#### Szintaxis

```python
@mapped(cím)
def függvény_név(paraméterek) -> visszatérési_típus: ...
```

A függvény törzse `...` (Ellipsis) kell legyen, mivel a tényleges kód máshol található a memóriában.

#### Példa: Zenelejátszó integráció

```python
PLAYER_INIT = 0x1000   # Cím, ahová a lejátszó init rutinja töltődik
PLAYER_PLAY = 0x1003   # Cím, ahová a lejátszó play rutinja töltődik

@mapped(PLAYER_INIT)
def music_init(song: byte): ...

@mapped(PLAYER_PLAY)
def music_play(): ...

def main():
    music_init(0)        # Első szám inicializálása
    while True:
        music_play()     # Lejátszó hívása minden frame-ben
        wait_frame()
```

#### Osztály metódusok

A `@mapped` osztály metódusokkal is működik a logikus csoportosítás érdekében:

```python
class MusicPlayer:
    @mapped(0x1000)
    def init(song: byte): ...

    @mapped(0x1003)
    def play(): ...

def main():
    MusicPlayer.init(0)
    MusicPlayer.play()
```

> **Megjegyzés:** A mapped osztály metódusoknak nincs `self` paramétere - statikus metódusokként viselkednek.

#### Hívási konvenció

A fordító regiszter-alapú hívási konvenciót használ a mapped függvényekhez:

| Paraméter pozíció | Regiszter |
| ----------------- | --------- |
| 1. paraméter      | A         |
| 2. paraméter      | X         |
| 3. paraméter      | Y         |

A visszatérési értékek A-ban (`byte`) vagy A+X-ben (`word`, alacsony byte A-ban) kerülnek át.

> **Fontos:** Legfeljebb 3 byte méretű paraméter támogatott. Bonyolultabb paraméterátadáshoz használj globális változókat vagy inline assemblyt.

#### Szabályok

| Szabály               | Leírás                                                         |
| --------------------- | -------------------------------------------------------------- |
| Stub törzs            | A függvény törzse `...` (Ellipsis) kell legyen                 |
| Címtartomány          | A címnek érvényes memóriatartományban kell lennie (platformfüggő) |
| Nincs @irq kombináció | Nem kombinálható `@irq`, `@irq_raw` vagy `@irq_hook`-kal       |
| Egész szám cím        | A címnek egész szám konstansnak kell lennie (nem változó)      |

---

## 9. Osztályok

Az osztályok összetartozó adatokat (tulajdonságok) és a rajtuk végzett műveleteket (metódusok) fogják össze egyetlen egységbe. Ez áttekinthetőbbé teszi a kódot és segít az adatok logikus csoportosításában.

A PyCo az objektum-orientált programozás (OOP) egy **egyszerűsített változatát** támogatja - csak azokat a funkciókat, amik valódi előnyt jelentenek gépközeli programozásnál:

| Támogatott          | Nem támogatott                     |
| ------------------- | ---------------------------------- |
| Tulajdonságok       | Többszörös öröklődés               |
| Metódusok           | Interfészek, absztrakt osztályok   |
| Egyszeres öröklődés | Polimorfizmus, virtuális metódusok |
| Konstruktor         | Destruktor, garbage collection     |

Ez a megközelítés a kód szervezését segíti anélkül, hogy runtime overhead-et okozna.

### 9.1 Osztály definiálása

```python
class név:
    tulajdonság deklarációk
    metódusok
```

vagy öröklődéssel:

```python
class név(szülő_osztály):
    tulajdonság deklarációk
    metódusok
```

> **FONTOS:** Beágyazott osztályok nem megengedettek! Minden osztályt modul szinten kell definiálni (tehát nem egy másik osztályon vagy függvényen belül).

### 9.2 Tulajdonságok (properties)

Minden tulajdonságot előre deklarálni kell, [típussal](#3-típusok) és opcionális alapértékkel. Az alapértékekre ugyanazok a szabályok vonatkoznak, mint a [változóknál](#28-változók):

```python
class Position:
    x: int = 0
    y: int = 0

class Hero(Position):
    score: int = 0
    name: string[20] = "Player"
```

**Memory-mapped tulajdonságok:**

Egy tulajdonság fix memóriacímre is mappelható, hasonlóan a [memory-mapped változókhoz](#41-memory-mapped-változók):

```python
class VIC:
    border: byte[0xD020]    # Fix cím: $D020
    bg: byte[0xD021]        # Fix cím: $D021
```

Ha az osztály **összes** tulajdonsága memory-mapped, az osztály "mapped-only" lesz, és a fordító extra optimalizációkat alkalmazhat (közvetlen címzés). Lásd: [4.4 Memory-mapped osztályok](#44-memory-mapped-osztályok-hardver-wrapperek)

### 9.3 Inicializáló (__init__)

Az `__init__` metódus az objektum inicializálásakor fut le. A PyCo-ban az objektumok **közvetlenül a stack-en** tárolódnak (mint a C struktúrák), nem heap-en allokált referenciákként. Ez azt jelenti:

- **Deklaráció** (`pos: Position`) csak memóriát foglal - NEM inicializál!
- **Inicializálás** (`pos()` vagy `pos(args)`) beállítja az alapértékeket és futtatja az `__init__`-et

```python
class Enemy:
    x: int = 0
    y: int = 0
    health: byte = 100

    def __init__(start_x: int, start_y: int):
        self.x = start_x
        self.y = start_y
```

**Az inicializálás sorrendje `pos()` hívásakor:**
1. Az osztály-szintű alapértékek beállítódnak (pl. `health = 100`)
2. Az `__init__` metódus lefut (ha létezik és ha van argumentum)

**Fontos:** Az inicializáló hívás (`pos()`) **NEM kifejezés** - nem szerepelhet értékadás jobb oldalán vagy függvényargumentumként. Ez egy utasítás, ami egy már deklarált objektumon művel.

### 9.4 Metódusok

A metódusok valójában függvények, amik az osztály tulajdonságaira hivatkozhatnak.

> **FONTOS:** A `self`-et **NEM** szabad kitenni a metódus paraméterek között (ellentétben a Pythonnal)! A metódus törzsében viszont a `self`-et használjuk a tulajdonságok eléréséhez. Ez az egyszerűsítés azért lehetséges, mert a PyCo nem dinamikus nyelv - a `self` mindig az aktuális objektumra mutat, nem lehet mást behelyettesíteni.

```python
class Hero:
    x: int = 0
    score: int = 0

    def move(dx: int, dy: int):      # self NINCS a paraméterlistában!
        self.x += dx                 # De a törzsben kell!
        self.y += dy

    def add_score(points: int) -> int:
        self.score += points
        return self.score
```

### 9.5 Öröklődés

Az öröklődés lehetővé teszi, hogy egy osztály átvegye egy másik osztály tulajdonságait és metódusait. A gyermek osztály (leszármazott) örökli a szülő osztály (ősosztály) minden tulajdonságát és metódusát, és újakat is definiálhat.

PyCo-ban **egyszeres öröklődés** van - egy osztálynak csak egy szülője lehet:

```python
class Position:
    x: int = 0
    y: int = 0

class Player(Position):    # Player örökli Position-t
    score: int = 100

    def move_right(inc: int):
        self.x += inc      # x a Position-ból örökölt
```

**Tulajdonságok öröklése:**

A gyermek osztály megkapja a szülő összes tulajdonságát, és saját új tulajdonságokat is definiálhat:

```python
class Position:
    x: int = 0
    y: int = 0

class Player(Position):
    score: int = 0         # Saját tulajdonság

def main():
    p: Player
    p()                    # Inicializálás
    p.x = 10               # Örökölt tulajdonság
    p.score = 100          # Saját tulajdonság
```

**Tulajdonság elfedés (shadowing):**

Ha a gyermek osztály ugyanolyan nevű tulajdonságot deklarál, mint a szülő, az egy **új, különálló tulajdonság** lesz (elfedés). A szülő tulajdonsága megmarad a memóriában (a szülő metódusai számára), de a gyermek nem éri el név szerint:

```python
class Parent:
    x: byte = 10

    def get_x() -> byte:
        return self.x      # Mindig Parent x-ét használja (offset 0)

class Child(Parent):
    x: byte = 20           # ÚJ tulajdonság - elfedi a szülő x-ét

    def get_child_x() -> byte:
        return self.x      # Child x-ét használja (más offset)

def main():
    c: Child
    c()
    print(c.x)             # 20 - Child x-e
    print(c.get_child_x()) # 20 - Child x-e
    print(c.get_x())       # 10 - Parent metódusa Parent x-ét látja!
```

Fontos tudnivalók a tulajdonság elfedésről:
- A gyermek **más típust** is használhat az elfedett tulajdonsághoz
- Mindkét tulajdonság inicializálódik az alapértelmezett értékével
- A szülő metódusai mindig a szülő verzióját látják
- A szülő tulajdonságának eléréséhez használj getter metódust a szülő osztályban

**Metódusok öröklése:**

A gyermek osztály örökli a szülő metódusait is:

```python
class Animal:
    def describe():
        print("I am an animal\n")

class Dog(Animal):
    def speak():
        print("Woof!\n")

def main():
    d: Dog
    d()                    # Inicializálás
    d.describe()           # Örökölt metódus - "I am an animal"
    d.speak()              # Saját metódus - "Woof!"
```

**Metódus felülírás (override):**

A gyermek osztály felülírhatja a szülő metódusait ugyanazzal a névvel:

```python
class Animal:
    def speak():
        print("...\n")

class Dog(Animal):
    def speak():           # Felülírja az Animal.speak()-et
        print("Woof!\n")

def main():
    a: Animal
    d: Dog
    a()                    # Inicializálás
    d()                    # Inicializálás

    a.speak()              # "..."
    d.speak()              # "Woof!"
```

**Szülő metódus meghívása (super):**

Ha felülírunk egy metódust, de szeretnénk meghívni a szülő eredeti implementációját is, a `super` kulcsszót használhatjuk:

```python
class Animal:
    def speak():
        print("*hang*\n")

class Dog(Animal):
    def speak():
        print("Vau! ")
        super.speak()          # Meghívja Animal.speak()-et

def main():
    d: Dog
    d()                        # Inicializálás
    d.speak()                  # "Vau! *hang*"
```

A `super` használatának tipikus esete az **inicializáló láncolás**, ahol a gyermek inicializálója meghívja a szülő inicializálóját:

```python
class Position:
    x: int = 0
    y: int = 0

    def __init__(px: int, py: int):
        self.x = px
        self.y = py

class Player(Position):
    score: int = 0

    def __init__(px: int, py: int, initial_score: int):
        super.__init__(px, py)     # Szülő inicializáló hívása
        self.score = initial_score

def main():
    p: Player
    p(10, 20, 100)                     # Inicializálás argumentumokkal
    print(p.x, " ", p.y, " ", p.score)  # "10 20 100"
```

**Fontos szabályok:**
- A `super` csak metódusokon belül használható
- A `super` csak olyan osztályokban érvényes, amelyeknek van szülő osztálya
- A `super.metodus()` a szülő (vagy ős) osztály metódusát hívja közvetlenül
- A `super.property` NEM támogatott - csak metódushívásokhoz használható

> **Megjegyzés:** A PyCo-ban nincs polimorfizmus - a metódushívás fordítási időben dől el a változó típusa alapján, nem futásidőben az objektum tényleges típusa alapján. Ez egyszerűbb és gyorsabb kódot eredményez.

### 9.6 Deklaráció és inicializálás

A PyCo-ban az objektumok **közvetlenül a stack-en** tárolódnak (mint a C struktúrák), nem heap-en allokált referenciákként. Ez alapvetően különbözik a Pythontól, és fontos következményei vannak.

> **Megjegyzés:** Ha nagyobb vagy dinamikus méretű memóriaterületre van szükség, a [memory-mapped programozással](#4-memory-mapped-programozás) tetszőleges memóriaterületet kijelölhetsz és kezelhetsz.
>
> **Miért nem heap?** A C64 BASIC stringkezelése heap-et használ, és emiatt időnként "garbage collection" fut, ami másodpercekig lefagyaszthatja a gépet míg a memóriát tömöríti. A PyCo stack-alapú megoldása ezt teljesen elkerüli.

#### Deklaráció vs inicializálás

| Osztály típusa | Szintaxis | Mi történik |
|----------------|-----------|-------------|
| **Nincs `__init__`** | `pos: Position` | Memória foglalás + **automatikus inicializálás** |
| **Van `__init__`** | `enemy: Enemy` | Memória foglalás - az objektum UNDEFINED |
| **Explicit init** | `enemy()` vagy `enemy(100, 50)` | Alapértékek beállítása + `__init__` meghívása |

**Fő szabály:** Az `__init__` metódus megléte határozza meg, hogy kell-e explicit inicializálás:

```python
class Position:        # Nincs __init__ - AUTOMATIKUSAN inicializálódik
    x: byte = 0
    y: byte = 0

class Enemy:           # Van __init__ - EXPLICIT inicializálás kell
    x: byte = 0
    health: byte = 100

    def __init__(start_x: byte):
        self.x = start_x

def example():
    pos: Position       # Automatikusan inicializálva! x=0, y=0 azonnal használható
    print(pos.x)        # OK - kiírja: 0

    enemy: Enemy        # NINCS inicializálva (Enemy-nek van __init__-je)
    enemy(50)           # Explicit inicializálás szükséges
```

#### Inicializálás sorrendje

Amikor `pos()`-t hívod:

1. Az osztály-definícióban megadott **alapértékek** beállítódnak
2. Az **`__init__` metódus** lefut (ha létezik)

```python
class Enemy:
    x: int = 0          # Alapérték
    y: int = 0          # Alapérték
    health: byte = 100  # Alapérték

    def __init__(start_x: int, start_y: int):
        self.x = start_x
        self.y = start_y

def main():
    e: Enemy            # 1. lépés: Memória foglalás (definiálatlan értékek)
    e(50, 75)           # 2. lépés: alapértékek alkalmazása (x=0, y=0, health=100)
                        # 3. lépés: __init__ lefut (x=50, y=75, health marad 100)
```

#### Újrainicializálás

Az objektumok bármikor újrainicializálhatók az inicializáló újbóli meghívásával:

```python
class Counter:
    value: int = 0

def main():
    c: Counter
    c()                 # Első inicializálás: value = 0
    c.value = 100

    # ... c használata ...

    c()                 # Újrainicializálás: value visszaáll 0-ra
```

Ha az `__init__`-nek vannak paraméterei, azokat újrainicializáláskor is meg kell adni:

```python
def main():
    pos: Position
    pos(10, 20)         # Első inicializálás

    # ... pos használata ...

    pos(0, 0)           # Újrainicializálás új értékekkel
```

#### Automatikus inicializálás (osztályok `__init__` nélkül)

Az `__init__` metódus nélküli osztályok **automatikusan inicializálódnak** deklarációkor. Ez csökkenti a boilerplate kódot egyszerű adat-osztályoknál:

```python
class Point:
    x: byte = 10
    y: byte = 20
    # Nincs __init__ - automatikusan inicializálódik

def main():
    p: Point            # Automatikusan inicializálva! x=10, y=20
    print(p.x, p.y)     # OK - kiírja: "10 20"

    p.x = 50            # Értékek módosítása
    p()                 # Újrainicializálás: visszaáll x=10, y=20-ra
```

Ez **rekurzívan** működik a beágyazott osztály-property-knél is:

```python
class Position:
    x: byte = 0
    y: byte = 0
    # Nincs __init__

class Entity:
    pos: Position       # Automatikusan inicializálódik (Position-nek nincs __init__-je)
    id: byte = 1
    # Nincs __init__

def main():
    e: Entity           # Automatikusan inicializálva, a beágyazott pos-sal együtt!
    print(e.pos.x)      # OK - kiírja: 0
```

**Vegyes eset:** Ha a konténer osztálynak van `__init__`-je, de a beágyazott property-knek nincs:

```python
class Point:           # Nincs __init__ - automatikus init
    x: byte = 0
    y: byte = 0

class Game:            # Van __init__ - explicit hívás kell
    pos: Point         # Automatikusan inicializálódik amikor Game()-et hívjuk
    score: word = 0

    def __init__():
        # A pos már inicializálva van ezen a ponton!
        self.score = 100

def main():
    g: Game            # NINCS inicializálva (Game-nek van __init__-je)
    g()                # Inicializálás - pos auto-init, majd __init__ lefut
```

> **Tipp:** Ha bizonytalan vagy, nyugodtan hívd meg explicit az inicializálót - biztonságos kétszer inicializálni (csak redundáns).

#### Fontos: Az inicializáló NEM kifejezés

Az inicializáló hívás (`pos()`) egy **utasítás**, nem kifejezés. Nem használható:

```python
# ❌ TILOS - az inicializáló nem kifejezés
x = pos()               # HIBA - nincs visszatérési érték!
foo(enemy())            # HIBA - nem használható argumentumként!
return hero()           # HIBA - nem returnölhető!

# ✅ HELYES - külön deklaráció és inicializálás
pos: Position
pos()
```

Ez a tervezés egyértelművé teszi, hogy a `pos()` egy **meglévő objektumon művel**, nem pedig létrehoz egyet.

#### Teljes példa

```python
class Hero:
    x: int = 0
    y: int = 0
    score: int = 0

    def __init__(start_x: int, start_y: int):
        self.x = start_x
        self.y = start_y

    def move(dx: int, dy: int):
        self.x += dx
        self.y += dy

def main():
    hero: Hero          # Deklaráció
    points: int

    hero(10, 5)         # Inicializálás
    hero.move(5, 3)     # Metódus hívás
    points = hero.score
```

### 9.7 Singleton osztályok

A `@singleton` dekorátor olyan osztályt hoz létre, amelyből **pontosan egy példány** létezik a program teljes futása alatt. Ideális hardver wrapperekhez (VIC, SID, Screen) és globális állapot objektumokhoz.

```python
@singleton
class Screen:
    border: byte[0xD020]
    bg: byte[0xD021]

    def set_colors(b: byte, c: byte):
        self.border = b
        self.bg = c

    def clear():
        # ... képernyő törlés logika ...
```

#### Használat

A singleton osztályok kétféleképpen érhetők el:

**1. Közvetlen osztály hívás (ajánlott hardver wrapperekhez):**
```python
def main():
    Screen.set_colors(1, 0)   # Közvetlen hívás az osztály nevével
    Screen.clear()
```

**2. Lokális alias (mint a normál osztályoknál):**
```python
def main():
    scr: Screen               # Alias létrehozása a singletonhoz
    scr.set_colors(1, 0)      # Hozzáférés az aliason keresztül
```

Mindkét módszer **ugyanazt a példányt** éri el - az egyiken keresztül végzett változtatások a másikon keresztül is láthatók.

#### Viselkedés

| Szempont              | Singleton viselkedés                                      |
| --------------------- | --------------------------------------------------------- |
| Példányszám           | Pontosan egy, a `main()` előtt létrehozva                 |
| Property alapértékek  | Automatikusan alkalmazva program induláskor               |
| `__init__` metódus    | NEM hívódik automatikusan - explicit hívás szükséges      |
| Memória hely          | `__program_end` után (mapped-only: nincs extra memória)   |
| Lokális deklaráció    | `scr: Screen` alias-t hoz létre, nem új példányt          |

#### Mikor használjunk `@singleton`-t

✅ **Jó felhasználási esetek:**
- Hardver wrapperek (VIC, SID, CIA regiszterek)
- Globális játék állapot (pontszám, szint, életek)
- Erőforrás kezelők (sprite pool, hangeffektusok)

❌ **Nem alkalmas:**
- Osztályok, ahol több példányra van szükség
- Adat konténerek, amiket át kell adni

#### Mapped-only singletonok

Ha a singleton **összes property-je** memória-mapped, nem foglalódik extra memória:

```python
@singleton
class VIC:
    border: byte[0xD020]      # Minden property mapped
    bg: byte[0xD021]
    # Nincs stack/BSS memória használat - csak metódus hozzáférés fix címekhez
```

---

## 10. Típuskonverziók és típuskezelés

### 10.1 Implicit vs explicit konverzió

A PyCo hardverközeli nyelv, ezért **nincs automatikus típus-promóció** (implicit bővítés műveletekben). A programozó felelőssége a helyes típushasználat.

**Értékadásnál** az implicit konverzió működik:

```python
def example():
    b: byte = 200
    w: word

    w = b                # OK: byte → word automatikus
```

**Műveletekben** viszont NEM:

```python
def example():
    a: byte = 200
    b: byte = 100
    result: word

    # HIBÁS: 8-bites művelet! 200+100=44 (túlcsordulás)
    result = a + b

    # HELYES: explicit konverzió
    result = word(a) + word(b)   # 16-bites művelet = 300
```

### 10.2 Típuskonverziós függvények

| Függvény   | Eredmény | Mikor használd                              |
| ---------- | -------- | ------------------------------------------- |
| `byte(x)`  | byte     | Alsó 8 bit kivonása                         |
| `sbyte(x)` | sbyte    | Byte előjeles értelmezése                   |
| `word(x)`  | word     | 16-bites művelethez túlcsordulás ellen      |
| `int(x)`   | int      | Előjeles aritmetikához, float csonkolásához |
| `char(x)`  | char     | Byte megjelenítése karakterként             |
| `bool(x)`  | bool     | Teljes érték vizsgálata bool változóba      |
| `float(x)` | float    | Lebegőpontos műveletekhez                   |
| `f16(x)`   | f16      | Fixpontos konverzió (8.8)                   |
| `f32(x)`   | f32      | Fixpontos konverzió (16.16)                 |

#### word() - Bővítés túlcsordulás ellen

```python
def example():
    a: byte = 200
    b: byte = 100
    result: word

    # HIBÁS - 8-bites művelet, túlcsordul!
    result = a + b              # 200 + 100 = 44 (wraparound)

    # HELYES - 16-bites művelet
    result = word(a) + word(b)  # 200 + 100 = 300
```

#### sbyte() - Előjeles értelmezés

```python
def example():
    delta: byte = 254           # Tegyük fel, joystick: -2 előjelesen
    position: int = 100

    # Előjeles értelmezés műveletben
    position = position + sbyte(delta)   # 100 + (-2) = 98
```

#### int() - Float csonkolása

```python
def example():
    f: float = 5.7
    i: int = int(f)          # 5 (nem kerekít, csonkol!)

    f = -10.9
    i = int(f)               # -10
```

#### bool() - Teljes érték vizsgálata

```python
def example():
    value: int = 256         # Alsó byte = 0!
    flag: bool

    # Közvetlen értékadásnál csak alsó byte
    flag = value             # flag = False! (mert alsó byte = 0)

    # bool() konverzióval a TELJES érték számít
    flag = bool(value)       # flag = True! (mert 256 != 0)
```

### 10.3 Típuskeverés műveletekben

| Művelet        | Eredmény típus | Megjegyzés                      |
| -------------- | -------------- | ------------------------------- |
| `byte + byte`  | `byte`         | 8-bites művelet, túlcsordulhat! |
| `word + word`  | `word`         | 16-bites művelet                |
| `int + int`    | `int`          | 16-bites előjeles művelet       |
| `int OP float` | `float`        | Integer auto-konvertálódik      |
| `float OP int` | `float`        | Integer auto-konvertálódik      |

> **FONTOS:** A float az egyetlen kivétel, ahol automatikus konverzió van műveletben!

### 10.4 Overflow viselkedés

Túlcsorduláskor **wraparound** történik:

| Típus   | Tartomány     | Overflow példa     |
| ------- | ------------- | ------------------ |
| `byte`  | 0..255        | 255 + 1 → 0        |
| `sbyte` | -128..127     | 127 + 1 → -128     |
| `word`  | 0..65535      | 65535 + 1 → 0      |
| `int`   | -32768..32767 | 32767 + 1 → -32768 |

**Nincs futásidejű ellenőrzés** - a túlcsordulás természetes wrap-around viselkedést követ.

### 10.5 Gyakori hibák és megoldások

#### 1. Byte túlcsordulás műveletben

```python
# ❌ HIBÁS
result: word = a + b          # (a, b: byte) - 8 bites művelet!

# ✅ HELYES
result: word = word(a) + word(b)
```

#### 2. Bool értékadás nagy számból

```python
# ❌ HIBÁS
flag: bool = value            # (value: int = 256) - flag = False!

# ✅ HELYES
flag: bool = bool(value)      # flag = True
```

#### 3. Integer osztás

```python
# ❌ HIBÁS
result: float = a / b         # (a, b: int) - egész osztás!

# ✅ HELYES
result: float = float(a) / float(b)
```

#### 4. Elfelejtett explicit f16/f32 konverzió

```python
# ❌ HIBÁS
x: f16 = 5                    # FORDÍTÁSI HIBA

# ✅ HELYES
x: f16 = f16(5)
```

### Típuskonverziós folyamatábra

```
                    Szűkítés (adatvesztés!)
              ◄────────────────────────────────

    byte ───► sbyte ───► word ───► int ───► float

              ────────────────────────────────►
                    Bővítés (biztonságos)

                          │
                    f16 ──┴── f32
                   (explicit konverzió kötelező!)
```

---

## 11. Memória és értékadás

### 11.1 Primitív vs összetett típusok

| Kategória | Típusok                                   | Tárolás           |
| --------- | ----------------------------------------- | ----------------- |
| Primitív  | byte, sbyte, word, int, float, bool, char | Érték közvetlenül |
| Összetett | string, array, class példányok            | Memóriaterület    |

### 11.2 Értékadás szemantika

**Primitív típusoknál** az érték másolódik:

```python
def example():
    a: int = 10
    b: int

    b = a        # b egy MÁSOLAT, értéke 10
    b = 20       # a még mindig 10
```

**Összetett típusoknál** (objektumok, tömbök) szintén másolat készül:

```python
def example():
    pos1: Position
    pos2: Position
    pos1()               # Inicializálás

    pos1.x = 10
    pos2 = pos1          # pos2 egy MÁSOLAT!
    pos2.x = 100

    # pos1.x = 10 (változatlan)
    # pos2.x = 100
```

> **FONTOS - Különbség a Pythonhoz képest!**
>
> Pythonban és más dinamikus nyelvekben az objektumok **referenciák** (mutatók) egy heap-en dinamikusan lefoglalt memóriaterületre. Ezért ott a `pos2 = pos1` után mindkét változó **ugyanarra** az objektumra mutat:
>
> ```python
> # Python viselkedés (NEM így működik PyCo-ban!)
> pos2 = pos1      # pos2 ugyanarra az objektumra mutat
> pos2.x = 100     # pos1.x is 100 lesz!
> ```
>
> A PyCo-ban az objektumok **közvetlenül a stack-en** foglalnak helyet, nem mutatók - hasonlóan a C nyelv `struct` típusához. Ezért az értékadás **teljes másolatot** készít - a két objektum teljesen független egymástól. Ha referencia-szerű viselkedésre van szükség, használj [alias](#5-alias-és-referenciák)-t.

### 11.3 Paraméter átadás

A függvényeknek átadott paraméterek viselkedése eltérő a primitív és az összetett típusoknál.

**Primitív típusok - érték szerinti átadás:**

A primitív típusú paraméterekről **másolat** készül. A függvényen belüli módosítás nem hat vissza az eredetire:

```python
def add_ten(x: int):
    x = x + 10       # Csak a helyi másolat módosul

def main():
    n: int = 5

    add_ten(n)
    # n még mindig 5 - nem változott!
```

**Összetett típusok - kötelező alias:**

Összetett típusokat (objektumok, tömbök, stringek) **csak alias-ként** lehet átadni. Ez nem opció, hanem nyelvi követelmény - a fordító hibát jelez, ha alias nélkül próbálsz összetett típust paraméterként használni.

```python
def modify_enemy(e: alias[Enemy]):    # alias KÖTELEZŐ!
    e.x = 100        # az EREDETI objektum módosul!

def main():
    enemy: Enemy
    enemy()              # Inicializálás
    enemy.x = 10

    modify_enemy(enemy)  # Automatikusan alias-ként adódik át
    # enemy.x = 100 - megváltozott!
```

**Miért kötelező az alias?** Egy nagy objektum (pl. 100 byte-os struktúra) lemásolása lassú és memóriapazarló lenne. Az alias csak 2 byte-ot (egy címet) ad át, és közvetlenül az eredeti objektummal dolgozik.

**Összefoglaló táblázat:**

| Típus     | Átadás             | Eredeti módosul? | Alias kötelező? |
| --------- | ------------------ | ---------------- | --------------- |
| Primitív  | Érték szerint      | Nem              | Nem             |
| Összetett | Referencia (alias) | Igen             | **Igen!**       |

> **Megjegyzés:** Nem kell előre alias változót létrehozni a híváshoz. Ha egy függvény `alias[Enemy]` paramétert vár, egyszerűen átadhatod az `enemy` változót közvetlenül - a fordító automatikusan alias-ként kezeli.
>
> Ha már van alias változód, azt is átadhatod - ilyenkor az alias által hivatkozott objektumra fog mutatni a paraméter, nem magára az alias változóra.

### 11.4 Stack frame

Amikor egy függvény meghívódik, a rendszer lefoglal neki egy memóriaterületet a **stack**-en (verem). Ezt nevezzük **stack frame**-nek (veremkeretnek). Itt tárolódnak a függvény lokális változói és paraméterei.

Minden függvényhívás egy új frame-et hoz létre, és a függvény visszatérésekor ez automatikusan felszabadul. Ezért "ingyenes" a memóriakezelés - nem kell manuálisan foglalni és felszabadítani. Ez teszi lehetővé a rekurziót is: minden hívásnak saját frame-je van a saját változóival.

> **Megjegyzés:** A stack frame pontos felépítése platform-függő. A C64-es implementáció részleteiért lásd a [C64 fordító referenciát](c64_compiler_reference_hu.md#stack-frame-felépítése).

---

## 12. Beépített függvények

A PyCo **nem támogatja a változó számú argumentumokat** (variadic arguments) a felhasználói függvényeknél - minden függvénynek fix számú paramétere van. Azonban néhány beépített függvény speciális: a fordító ismeri őket és tetszőleges számú argumentumot fogad el.

### print

Értékek kiírása a képernyőre.

```python
print(érték)                      # egy érték kiírása
print(érték1, érték2, ...)        # több érték egymás után
```

**Fontos különbségek a Pythonhoz képest:**

| Python                      | PyCo                                 |
| --------------------------- | ------------------------------------ |
| `print("Hi")` → `Hi\n`      | `print("Hi")` → `Hi` (nincs újsor!)  |
| `print(a, b)` → `a b\n`     | `print(a, b)` → `ab` (nincs szóköz!) |
| `print(a, sep="-", end="")` | Nem támogatott                       |

A PyCo nem támogatja a **keyword argumentumokat** (`sep=`, `end=`), ezért a Python-os `print` viselkedését nem lehet pontosan reprodukálni. Helyette az **explicit formázás** a megoldás:

```python
def example():
    x: int = 10
    name: string = "Játékos"

    print("Hello\n")              # Explicit újsor a végén
    print(x)                      # "10" - újsor nélkül
    print(name, " ", x, "\n")     # "Játékos 10\n" - explicit szóköz
    print(x, "-", y, "-", z)      # "10-20-30" - explicit szeparátor
```

> **Tipp:** Az explicit `\n` és szóközök használata átláthatóbbá teszi a kódot - azonnal látszik, mi fog megjelenni.

> **Megjegyzés:** A `print` speciális beépített függvény. A fordító fordítási időben ismeri a paraméterek típusát és mindegyikhez a megfelelő kiíró kódot generálja. Saját függvényben ez nem lehetséges.

### printsep

Értékek kiírása egyedi szeparátorral. **Nem** tesz újsort a végére.

```python
printsep(szeparátor, érték1, érték2, ...)
```

```python
def example():
    x: int = 10
    y: int = 20

    printsep(", ", x, y, "\n")    # "10, 20, \n"
    printsep("", x, y)            # "1020"
```

### sprint

Értékek írása string bufferbe. Működése megegyezik a `print()`-tel, csak képernyő helyett bufferbe ír.

```python
sprint(buffer, érték1, érték2, ...)
```

```python
def example():
    result: string[40]
    score: int = 100

    sprint(result, score)               # result = "100"
    sprint(result, "Score: ", score)    # result = "Score: 100"
```

> **FIGYELEM:** A célbuffernek elegendő méretűnek kell lennie. Nincs túlcsordulás-ellenőrzés!

### str

Érték stringgé alakítása.

```python
str(érték) -> string
```

**Objektumok esetén:** Ha van `__str__` metódus, azt hívja meg. Ha nincs, `<ClassName>` formátumot ad vissza.

```python
class Player:
    name: string[20] = "Hero"
    score: int = 0

    def __str__() -> string:
        result: string[40]
        sprint(result, self.name, ": ", self.score)
        return result

def example():
    p: Player
    p()                  # Inicializálás
    s: string[40]

    s = str(p)           # "Hero: 0"
```

### len

Hossz lekérdezése.

```python
len(s) -> byte           # string hossza
len(arr) -> byte/word    # tömb elemszáma
```

**String esetén** O(1) művelet (Pascal-string hossz byte-ja).

**Tömb esetén** az elemszámot adja vissza. Visszatérési típus:
- ≤ 256 elem: `byte`
- > 256 elem: `word`

### size

Memória méret bájtokban.

```python
size(érték) -> word
```

| Típus   | Visszaadott érték                  |
| ------- | ---------------------------------- |
| string  | deklarált méret + 1 (hossz + kar.) |
| array   | elemszám × elemméret               |
| osztály | összes property összmérete         |

### getkey

Billentyűzet olvasása (non-blocking). Azonnal visszatér.

```python
getkey() -> char    # 0 ha nincs lenyomott gomb
```

### waitkey

Billentyűzet olvasása (blocking). Várakozik gombnyomásra.

```python
waitkey() -> char
```

| Függvény    | Viselkedés        | Tipikus használat     |
| ----------- | ----------------- | --------------------- |
| `getkey()`  | Azonnal visszatér | Játék vezérlés        |
| `waitkey()` | Vár gombnyomásra  | "Press any key", menü |

### abs

Abszolút érték.

```python
abs(érték) -> byte/word
```

| Bemenet | Kimenet | Indoklás                             |
| ------- | ------- | ------------------------------------ |
| `sbyte` | `byte`  | `abs(-128) = 128` nem fér sbyte-ba   |
| `int`   | `word`  | `abs(-32768) = 32768` nem fér int-be |

### min, max

Két érték közül a kisebb/nagyobb.

```python
min(a, b) -> a és b típusa
max(a, b) -> a és b típusa
```

### blkcpy

Téglalap (block) memóriamásolás. Téglalap alakú régiót másol egyik tömbből a másikba.

**7 paraméteres szintaxis (közös stride):**

```python
blkcpy(src_arr, src_offset, dst_arr, dst_offset, width, height, stride)
```

**8 paraméteres szintaxis (külön stride-ok):**

```python
blkcpy(src_arr, src_offset, src_stride, dst_arr, dst_offset, dst_stride, width, height)
```

**Paraméterek:**

| Paraméter    | Típus | Leírás                                        |
| ------------ | ----- | --------------------------------------------- |
| `src_arr`    | array | Forrás tömb                                   |
| `src_offset` | word  | Kezdő offset a forrásban (byte)               |
| `src_stride` | byte  | Forrás sor szélessége (csak 8-param)          |
| `dst_arr`    | array | Cél tömb                                      |
| `dst_offset` | word  | Kezdő offset a célban (byte)                  |
| `dst_stride` | byte  | Cél sor szélessége (csak 8-param)             |
| `width`      | byte  | Téglalap szélessége (byte, max 255)           |
| `height`     | byte  | Téglalap magassága (sorok, max 255)           |
| `stride`     | byte  | Közös sor szélesség (csak 7-param)            |

**Felhasználási példák:**

```python
screen: array[byte, 1000][0x0400]
buffer: array[byte, 1000][0x8000]
tile: array[byte, 16][0xC000]  # 4x4 tile

# Scroll balra 1 karakterrel
blkcpy(screen, 1, screen, 0, 39, 25, 40)

# Scroll felfelé 1 sorral
blkcpy(screen, 40, screen, 0, 40, 24, 40)

# Double buffer - 20x10 régió másolása
blkcpy(buffer, 5*40+10, screen, 5*40+10, 20, 10, 40)

# Tile blit - 4x4 tile különböző stride-okkal
blkcpy(tile, 0, 4, screen, 5*40+10, 40, 4, 4)
```

**Automatikus irány-detektálás:**

Átfedő régiók esetén (azonos tömb) a fordító automatikusan kiválasztja a helyes másolási irányt:

| Eset                              | Irány    | Meghatározás   |
| --------------------------------- | -------- | -------------- |
| Különböző tömbök                  | Forward  | Fordítási idő  |
| Azonos tömb, mindkét offset fix   | Helyes   | Fordítási idő  |
| Azonos tömb, változó offset       | Helyes   | Futásidő       |

### memfill

Gyors memória kitöltés. Egy tömböt tölt ki a megadott értékkel.

**2 paraméteres szintaxis (teljes tömb kitöltése):**

```python
memfill(tömb, érték)
```

**3 paraméteres szintaxis (első N elem kitöltése):**

```python
memfill(tömb, érték, darabszám)
```

**Paraméterek:**

| Paraméter    | Típus       | Leírás                                              |
| ------------ | ----------- | --------------------------------------------------- |
| `tömb`       | array       | Kitöltendő tömb (változó vagy osztály property)     |
| `érték`      | elem típusa | A kitöltési érték (meg kell egyezzen az elem típussal) |
| `darabszám`  | word        | Kitöltendő elemek száma (opcionális)                |

**Működés:**
- **2 paraméteres verzió:** A TELJES tömböt kitölti - a méret a típusdeklarációból jön
- **3 paraméteres verzió:** Csak az első `darabszám` elemet tölti ki

**Példák:**

```python
screen: array[byte, 1000][0x0400]
colorram: array[byte, 1000][0xD800]

# Teljes képernyő kitöltése szóközzel (1000 byte)
memfill(screen, 32)

# Teljes szín RAM kitöltése fehérrel (1000 byte)
memfill(colorram, 1)

# Csak az első 40 byte kitöltése (egy sor)
memfill(screen, 0, 40)
```

**Osztály property támogatás:**

```python
class Display:
    buffer: array[byte, 40][0x0400]

    def clear():
        # Működik self.property-vel - teljes tömböt tölti ki
        memfill(self.buffer, 32)
```

**Támogatott elem típusok:**

| Típus   | Méret   | Megjegyzés                  |
| ------- | ------- | --------------------------- |
| `byte`  | 1 byte  | Közvetlen érték (0-255)     |
| `word`  | 2 byte  | Little-endian kitöltés      |
| `int`   | 2 byte  | Azonos a word-del           |
| `float` | 4 byte  | MBF32 formátum kitöltés     |

---

## 13. Speciális funkciók

### 13.1 Inline assembly (__asm__)

> **Megjegyzés:** Az inline assembly **opcionális funkció** - a fordítóknak nem kötelező implementálniuk. Ha egy fordító támogatja, akkor az itt leírt egységes szintaxist kell használnia. Például egy natív fordítóban, ahol nincs köztes assembly kód generálás, nehéz vagy lehetetlen lehet megvalósítani.

Az `__asm__` lehetővé teszi nyers assembly kód beillesztését.

```python
__asm__("""
    lda #$00
    sta $d020
""")
```

**Mikor használjuk:**
- Időkritikus ciklusok
- Hardver-specifikus műveletek (VIC trükkök, SID)
- Speciális CPU utasítások (SEI, CLI, BRK, NOP)

> **Megjegyzés:** Interrupt rutinokhoz a jövőben dedikált dekorátorok lesznek, így azokhoz nem lesz szükség inline assembly-re.

**Szabályok:**

| Szabály                       | Magyarázat                                 |
| ----------------------------- | ------------------------------------------ |
| Csak függvényben használható  | Statement-ként, a kód bármely pontján      |
| Nincs változó behelyettesítés | Nyers assembly kód                         |
| Regiszter megőrzés            | A programozó felelőssége (A, X, Y, status) |
| Nincs syntax ellenőrzés       | A PyCo fordító nem validálja az assembly-t |

**Példák:**

```python
def flash_border():
    __asm__("""
        inc $d020
    """)

def critical_section():
    __asm__("""
        sei
    """)
    # Kritikus műveletek...
    __asm__("""
        cli
    """)

def wait_rasterline():
    __asm__("""
    .wait:
        lda $d012
        cmp #$80
        bne .wait
    """)
```

> **Tipp:** Az `__asm__` használata előtt próbáld meg a feladatot PyCo-ban megoldani. Az inline assembly csak végső eszköz legyen.

---

## Függelék

### A. Típuskonverziós táblázat

| Forrás | byte  | sbyte | word  | int   | float | f16   | f32   |
| ------ | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| byte   | =     | cast  | ext   | ext   | conv  | f16() | f32() |
| sbyte  | cast  | =     | ext   | ext   | conv  | f16() | f32() |
| word   | trunc | trunc | =     | cast  | conv  | f16() | f32() |
| int    | trunc | trunc | cast  | =     | conv  | f16() | f32() |
| float  | int() | int() | int() | int() | =     | f16() | f32() |
| f16    | -     | -     | -     | -     | auto  | =     | f32() |
| f32    | -     | -     | -     | -     | auto  | f16() | =     |

Jelmagyarázat:
- `=` : azonos típus
- `ext` : bővítés (biztonságos)
- `trunc` : csonkolás (adatvesztés!)
- `cast` : újraértelmezés
- `conv` : konverzió
- `auto` : automatikus
- `f16()/f32()` : explicit kötelező

### B. Cheatsheet Python fejlesztőknek

Ez az összefoglaló a Python és PyCo közötti legfontosabb különbségeket tartalmazza.

#### Típusok és deklarációk

| Python                | PyCo                            | Megjegyzés                            |
| --------------------- | ------------------------------- | ------------------------------------- |
| `x = 10`              | `x: int = 10`                   | Típusannotáció **kötelező**           |
| Változó bárhol        | Változók a függvény **elején**  | Pascal-stílus                         |
| `x = get_value()`     | ❌ Nem megengedett deklarációnál | Csak konstans alapérték               |
| `global x`            | `X = 10` (NAGYBETŰS)            | Nincs globális változó, csak konstans |
| `list`, `dict`, `set` | `array[típus, méret]`           | Fix méretű, statikus                  |
| `[1, 2, 3]`           | `= (1, 2, 3)`                   | Tuple szintaxis array-hoz             |
| `tuple` (dinamikus)   | `tuple[típus]`                  | Fix, csak olvasható, data szegmens    |
| `str` (dinamikus)     | `string[méret]`                 | Fix méretű (Pascal-típusú)            |

#### Osztályok és objektumok

| Python                            | PyCo                        | Megjegyzés                              |
| --------------------------------- | --------------------------- | --------------------------------------- |
| `obj = Class()`                   | `obj: Class` majd `obj()`   | Deklaráció és inicializálás külön       |
| `def method(self, x):`            | `def method(x: int):`       | `self` **nem kell** a paraméterlistában |
| `obj2 = obj1` → mindkettő ugyanaz | `obj2 = obj1` → **másolat** | Stack-alapú, nem referencia             |
| Többszörös öröklődés              | Egyszeres öröklődés         | `class Child(Parent):`                  |
| `isinstance()`, polimorfizmus     | ❌ Nincs                     | Nincs dinamikus típuskezelés            |
| Garbage collection                | ❌ Nincs                     | Stack automatikusan felszabadul         |

#### Függvények

| Python          | PyCo                      | Megjegyzés                      |
| --------------- | ------------------------- | ------------------------------- |
| `def f(*args):` | ❌ Nincs variadic          | Fix paraméterszám               |
| `def f(x=10):`  | ❌ Nincs default érték     | Minden paramétert meg kell adni |
| `f(name="x")`   | ❌ Nincs keyword arg       | Csak pozícionális               |
| `return obj`    | `return obj` → `alias[T]` | Összetett típus csak alias-ként |
| `lambda x: x+1` | ❌ Nincs lambda            | Csak `def`                      |

#### Print és I/O

| Python                 | PyCo                 | Megjegyzés                           |
| ---------------------- | -------------------- | ------------------------------------ |
| `print("Hi")` → `Hi\n` | `print("Hi")` → `Hi` | **Nincs** automatikus újsor          |
| `print(a, b)` → `a b`  | `print(a, b)` → `ab` | **Nincs** automatikus szóköz         |
| `print(x, sep="-")`    | `printsep("-", x, y)` vagy `print(x, "-", y)` | Dedikált függvény vagy explicit |
| `s = f"x={x}"`         | `sprint(s, "x=", x)` | `sprint(buffer, ...)` bufferbe ír |

#### Vezérlési szerkezetek

| Python                | PyCo                    | Megjegyzés                        |
| --------------------- | ----------------------- | --------------------------------- |
| `for i in range(10):` | `for i in range(10):`   | ✅ Ugyanaz                         |
| `for item in list:`   | ❌ Nincs foreach         | Csak index-alapú iteráció         |
| `try/except`          | ❌ Nincs kivételkezelés  | Hibakezelés a programozó feladata |
| `with`                | ❌ Nincs context manager |                                   |

#### Nem támogatott Python funkciók

- ❌ `list`, `dict`, `set` (dinamikus kollekciók)
- ❌ List comprehension (`[x*2 for x in items]`)
- ❌ Generator, `yield`
- ❌ Decorator (kivéve beépített: `@lowercase`, `@kernal`, `@noreturn`, `@irq`, `@irq_raw`, `@irq_hook`, `@forward`, `@mapped`)
- ❌ `async`/`await`
- ❌ `import` (részlegesen támogatott)
- ❌ Többsoros string (`"""..."""`)
- ❌ f-string (`f"Hello {name}"`)
- ❌ `None` (használj `0`-t vagy üres stringet)
- ❌ `__slots__`, `@property`, `@classmethod`, `@staticmethod`

#### Gyors referencia

```python
# Python                          # PyCo

class Enemy:                      class Enemy:
    def __init__(self, hp):           hp: int = 100
        self.hp = hp                  def __init__(hp_val: int):
                                          self.hp = hp_val

def greet(name="World"):          def greet(name: alias[string]):
    print(f"Hello {name}!")           print("Hello ", name, "!\n")

def main():                       def main():
    e = Enemy(50)                     e: Enemy           # Deklaráció
                                      e(50)              # Inicializálás
    x = 10                            x: int = 10
    name = "hello"                    name: string = "hello"
    items = [0] * 100                 items: array[byte, 100] = [0]
    data = [1, 2, 3]                  data: array[byte, 3] = (1, 2, 3)
```
