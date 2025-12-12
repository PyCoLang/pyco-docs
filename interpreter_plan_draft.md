# PyCo Interpreter Mód - Tervezet (DRAFT)

> **FIGYELEM:** Ez egy tervezett funkció, amely lehet, hogy nem kerül megvalósításra. A dokumentum csak tervezési célokat szolgál.

## Áttekintés

Az interpreter mód egy alternatív futtatási módszer lenne a PyCo számára, ahol a kód közvetlenül értelmeződik fordítás nélkül.

## Név tárolási mechanizmus

A neveket az interpreter így tárolja, hogy hatékonyak legyenek:

A neveket a rendszer 1 bájtos, vagy 8 bájtos slotokban tárolja. Így az 1 betűs nevek kevesebb memóriát foglalnak el, mint a hosszú nevek és gyorsabban elérhetőek. Ha 8 karakternél hosszabb nevet adunk meg, akkor több slotot foglal el úgy, hogy az első slot utolsó bájtja egy `\0` karakterrel végződik. Innent tudja az interpreter, hogy a név folytatódik.

| Név         | Hossz  | Slotok száma | Magyarázat                                                                                                                    |
| ----------- | ------ | ------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `i`         | 1 bájt | Gyors slot   | Ez a gyors slotok egyikét foglalja el.                                                                                        |
| `count`     | 5 bájt | 1 slot       | Ez egy 8 bájtos slotot foglal el.                                                                                             |
| `abcdefgh`  | 8 bájt | 1 slot       | Ez pont elfér egy slotban, 8 bájt hosszú.                                                                                     |
| `abcdefghi` | 9 bájt | 2 slot       | Ez két slotot foglal el: az első slot utolsó bájtja egy `\0` karakterrel végződik, a második slot első bájtja a `h` karakter. |

Így tulajdonképpen lehet bármilyen hosszú nevet adni, de a rövid nevek gyorsabban elérhetőek.

## Státusz

- **Megvalósítás**: Nem tervezett a közeljövőben
- **Prioritás**: Alacsony
- **Függőségek**: Alapvető fordító infrastruktúra