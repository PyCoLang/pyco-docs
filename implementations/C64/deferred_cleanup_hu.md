# Deferred Cleanup - "Szegényember GC"

## Probléma

A PyCo-ban az összetett típusok (string, array, object) visszatérése függvényből problémás:

```python
def create_enemy() -> alias[Enemy]:   # Kötelező alias visszatérés!
    e: Enemy = Enemy()
    e.x = 50
    return e    # e a stack frame-en van!

def main():
    enemy: Enemy = create_enemy()  # Hova másolódik?
```

A `return e` után a függvény stack frame-je felszabadul, de az `e` pointer még oda mutat → **dangling pointer**!

**Megjegyzés:** A nyelvi szabály szerint összetett típusok visszatérése **csak `alias[T]`** típusként lehetséges. Ez explicit módon jelzi, hogy referencia jön vissza.

## Megoldás: Deferred Cleanup

**Alapötlet:** Ne takarítsunk azonnal! A "garbage" maradjon a stack-en a statement végéig.

### Működés

```
Normál return:              Deferred cleanup:

[caller][called][SSP]       [caller][called][SSP]
         ↓                           ↓
[caller][SSP]               [caller][called_"garbage"][SSP] ← marad!
    (azonnal takarít)                ↓
                            Statement végén:
                            [caller][SSP] ← MOST takarít!
```

### Szabályok

1. **Primitív típus return** (`byte`, `int`, `bool`, stb.):
   - Normál stack cleanup a függvény végén
   - Érték A regiszterben (1 byte) vagy tmp0/tmp1-ben (2 byte)

2. **Alias return** (`alias[Enemy]`, `alias[array[byte,10]]`, stb.):
   - **NE** csökkentsd az SSP-t a függvény végén!
   - A lokálisok (beleértve a return értéket) ottmaradnak
   - `retval` pointer mutat rájuk → működik!
   - **Nyelvi szabály:** Összetett típusok visszatérése CSAK alias-ként lehetséges!

3. **Statement wrapper:**
   - Statement elején: SSP mentése **hardware stack-re (PHA)**
   - Statement végén: SSP visszaállítása **hardware stack-ről (PLA)** → minden temp eltűnik
   - Az alias élettartama pontosan a statement végéig tart!

### Nested hívások

```python
process(create_enemy(), create_item())
```

```
Állapot                                 SSP         Hardware Stack
────────────────────────────────────────────────────────────────────
Statement eleje                         X           [SSP_hi][SSP_lo]
create_enemy() hívás után               X + frame   [SSP_hi][SSP_lo]
create_item() hívás után                X + frame2  [SSP_hi][SSP_lo]
process() hívás után                    X + ...     [SSP_hi][SSP_lo]
Statement vége                          X           (visszaállítva!)
```

**Miért hardware stack?** A ZP regisztereket a for loop használja, és nested hívások felülírnák azokat. A hardware stack (256 byte, LIFO) természetesen kezeli a beágyazott hívásokat.

## Implementáció

### Függvény return generálás (KÉSZ)

**Fájl:** `src/pyco/compiler/codegen/generator.py` - `_gen_return()` metódus

```python
def _is_alias_return(self) -> bool:
    """Check if current function returns an alias type."""
    if self.current_function:
        func_sig = self.symbols.get_function(self.current_function)
        if func_sig and func_sig.return_type:
            return func_sig.return_type.startswith("alias[")
    return False

def _gen_return(self, node: ast.Return) -> None:
    if self._is_alias_return():
        if node.value is not None:
            # retval = address of return value on stack
            self.expr_gen._gen_address_of(node.value)  # → tmp0/tmp1 = &value
            self.emitter.emit("lda tmp0")
            self.emitter.emit("sta retval")
            self.emitter.emit("lda tmp1")
            self.emitter.emit("sta retval+1")

        # Alias return: csak FP visszaállítás, SSP marad!
        if self._frame_size > 0:
            self.emitter.emit("pla")
            self.emitter.emit("sta FP")
            self.emitter.emit("pla")
            self.emitter.emit("sta FP+1")
        self.emitter.emit("rts")
        return

    # Primitív típus - normál cleanup
    # ... eredeti implementáció ...
```

**Generált assembly alias return esetén:**

```asm
// [test_alias.pyco:9] return e
__SRC_test_alias_pyco_9:
    // Alias return: get address of value
    // addr(e) = FP + 0
    clc
    lda FP
    adc #0
    sta tmp0
    lda FP+1
    adc #0
    sta tmp1
    lda tmp0
    sta retval
    lda tmp1
    sta retval+1
    // Alias return: skip SSP cleanup, only restore FP
    pla
    sta FP
    pla
    sta FP+1
    rts
```

### Statement wrapper (KÉSZ)

**Fájl:** `src/pyco/compiler/codegen/generator.py` - `_generate_statement()` metódus

```python
def _needs_deferred_cleanup(self, node: ast.stmt) -> bool:
    """Check if statement needs SSP save/restore for deferred cleanup.

    Returns True if the statement contains a call to a function
    that returns an alias type.
    """
    for child in ast.walk(node):
        if isinstance(child, ast.Call):
            if isinstance(child.func, ast.Name):
                func_name = child.func.id
                func_sig = self.symbols.get_function(func_name)
                if func_sig and func_sig.return_type:
                    if func_sig.return_type.startswith("alias["):
                        return True
            elif isinstance(child.func, ast.Attribute):
                # Method calls - check method return type
                # ... részletes implementáció a kódban ...
    return False

def _generate_statement(self, node: ast.stmt) -> None:
    needs_cleanup = self._needs_deferred_cleanup(node)

    if needs_cleanup:
        # SSP mentése hardware stack-re
        self.emitter.emit_comment("Deferred cleanup: save SSP")
        self.emitter.emit("lda SSP")
        self.emitter.emit("pha")
        self.emitter.emit("lda SSP+1")
        self.emitter.emit("pha")

    # Statement generálása
    self._emit_source_label(node)
    # ... dispatch to specific statement handlers ...

    if needs_cleanup:
        # SSP visszaállítása hardware stack-ről
        self.emitter.emit_comment("Deferred cleanup: restore SSP")
        self.emitter.emit("pla")
        self.emitter.emit("sta SSP+1")
        self.emitter.emit("pla")
        self.emitter.emit("sta SSP")
```

**Generált assembly alias hívás esetén:**

```asm
    // Deferred cleanup: save SSP
    lda SSP
    pha
    lda SSP+1
    pha

// [test_alias.pyco:13] enemy: Enemy = create_enemy()
__SRC_test_alias_pyco_13:
    jsr __F_create_enemy
    // Alias return: pointer in retval
    lda retval
    sta tmp0
    lda retval+1
    sta tmp1
    // Copy Enemy object (2 bytes)
    clc
    lda FP
    adc #0
    sta tmp2
    lda FP+1
    adc #0
    sta tmp3
    ldy #0
    !copy_loop:
    lda (tmp0),y
    sta (tmp2),y
    iny
    cpy #2
    bne !copy_loop-
    // Deferred cleanup: restore SSP
    pla
    sta SSP+1
    pla
    sta SSP
```

### Object másolás alias → konkrét típus (KÉSZ)

**Fájl:** `src/pyco/compiler/codegen/generator.py` - `_store_to_local()` metódus

Amikor egy alias visszatérési értéket konkrét típusú változóba másolunk:

```python
# Check if this is a class type that needs object copy
is_class_type = var.type_name in self.symbols.classes

if is_class_type:
    class_layout = self.symbols.classes[var.type_name]
    obj_size = class_layout.total_size

    # Source: tmp0/tmp1 (alias pointer from retval)
    # Dest: FP + var.offset
    self.emitter.emit_comment(f"Copy {var.type_name} object ({obj_size} bytes)")

    # Calculate destination address
    self.emitter.emit("clc")
    self.emitter.emit("lda FP")
    self.emitter.emit(f"adc #{var.offset}")
    self.emitter.emit("sta tmp2")
    self.emitter.emit("lda FP+1")
    self.emitter.emit("adc #0")
    self.emitter.emit("sta tmp3")

    # Inline memcpy
    self.emitter.emit("ldy #0")
    self.emitter.emit("!copy_loop:")
    self.emitter.emit("lda (tmp0),y")
    self.emitter.emit("sta (tmp2),y")
    self.emitter.emit("iny")
    self.emitter.emit(f"cpy #{obj_size}")
    self.emitter.emit("bne !copy_loop-")
```

## Trade-offs

### Előnyök

- **Egyszerű implementáció** - nincs bonyolult lifetime tracking
- **Nincs "return buffer" pre-allokáció** - a hívónak nem kell előre tudnia a méretet
- **Univerzális megoldás** - string, array, object mind ugyanígy működik
- **Zero-copy lehetőség** - ha azonnal használjuk, nincs felesleges másolás
- **Explicit szemantika** - az `alias[T]` típus egyértelműen jelzi, hogy referencia jön vissza
- **Hardware stack LIFO** - természetesen kezeli a nested hívásokat

### Hátrányok

- **Stack pazarlás** - de csak a statement végéig!
- **Mély láncok sok stack-et esznek** - `a(b(c(d(e()))))`
- **Hardware stack limit** - 256 byte, de ~40-60 nested szint elegendő
- **+12 ciklus overhead** - statement-enként ami cleanup-ot igényel

### Limitációk dokumentálása

> ⚠️ **Figyelem:** Az `alias[T]` visszatérési értékek stack-et fogyasztanak a statement végéig.
> Mély függvényláncoknál (5+ szint) figyelj a stack méretre!
>
> ```python
> # Kerülendő:
> result = a(b(c(d(e(f(g()))))))  # Sok stack! Minden alias él egyszerre.
>
> # Jobb:
> t1: Enemy = g()                  # Másolás, alias felszabadul
> t2: Item = f(t1)                 # Másolás, alias felszabadul
> t3: Weapon = e(t2)               # Másolás, alias felszabadul
> # ... stb.
> ```
>
> Az `alias[T]` típus a kódban jelzi: "ez egy referencia, ami csak ebben a statement-ben él!"

## Kapcsolódó témák

- Stack frame layout: `docs/code_generator_plan_hu.md`
- Típusok és memória: `docs/language_reference_hu.md` (Memória és értékadás szekció)

## Állapot

**Implementálva** - Alap funkciók működnek, tesztek megírva

