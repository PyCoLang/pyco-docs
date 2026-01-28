# Future Optimization Opportunities

This document describes potential compiler optimizations that could improve generated code quality. These are not currently implemented but represent low-hanging fruit for future development.

## 1. Direct ADC/SBC with Global Variables

**Current behavior:**
```asm
; a = counter + increment
lda increment    ; 4 cycles, 3 bytes
sta tmp0         ; 3 cycles, 2 bytes
clc
lda counter      ; 4 cycles, 3 bytes
adc tmp0         ; 3 cycles, 2 bytes
sta counter      ; 4 cycles, 3 bytes
                 ; Total: 18 cycles, 13 bytes
```

**Optimized:**
```asm
; a = counter + increment
clc
lda counter      ; 4 cycles, 3 bytes
adc increment    ; 4 cycles, 3 bytes  <- direct!
sta counter      ; 4 cycles, 3 bytes
                 ; Total: 12 cycles, 9 bytes
```

**Savings:** 6 cycles, 4 bytes per operation

**Implementation notes:**
- Peephole optimization pattern
- Only applicable for simple two-operand expressions with global variables
- JAM markers already support ADC abs ($C2) and SBC abs ($D2) for module relocation

## 2. Direct AND/ORA/EOR with Global Variables

Same pattern as ADC/SBC:

**Current:**
```asm
lda mask         ; 4 cycles, 3 bytes
sta tmp0         ; 3 cycles, 2 bytes
lda value        ; 4 cycles, 3 bytes
and tmp0         ; 3 cycles, 2 bytes
sta result       ; 4 cycles, 3 bytes
```

**Optimized:**
```asm
lda value        ; 4 cycles, 3 bytes
and mask         ; 4 cycles, 3 bytes
sta result       ; 4 cycles, 3 bytes
```

**Savings:** 6 cycles, 4 bytes per operation

**Implementation notes:**
- JAM markers support AND abs ($E2) and ORA abs ($F2)
- EOR abs would need a new marker if needed

## 3. Strength Reduction for Multiplication

**Current (partially implemented):**
- `x * 2` → `x << 1` (shift left)
- `x * 4` → `x << 2`
- `x * 8` → `x << 3`

**Additional opportunities:**
- `x * 3` → `(x << 1) + x`
- `x * 5` → `(x << 2) + x`
- `x * 6` → `(x << 2) + (x << 1)`
- `x * 7` → `(x << 3) - x`
- `x * 9` → `(x << 3) + x`
- `x * 10` → `(x << 3) + (x << 1)`

**Implementation notes:**
- Trade-off between code size and speed
- For small multipliers (2-10), shifts are always faster than MUL routine
- Consider inlining threshold

## 4. Loop Unrolling

**Current:**
```asm
    ldx #0
loop:
    lda source,x
    sta dest,x
    inx
    cpx #8
    bne loop
```

**Unrolled (for small counts):**
```asm
    lda source+0
    sta dest+0
    lda source+1
    sta dest+1
    ; ... etc
```

**Implementation notes:**
- Only beneficial for small, known-at-compile-time counts
- Increases code size
- Consider as opt-in optimization flag

## 5. Dead Store Elimination

Remove stores that are immediately overwritten:

```python
x = 5      # Dead store
x = 10     # Only this matters
```

**Implementation notes:**
- Requires data flow analysis
- Must be careful with memory-mapped variables (stores may have side effects)

## 6. Common Subexpression Elimination

**Current:**
```python
a = x + y
b = x + y  # Recalculated
```

**Optimized:**
```python
tmp = x + y
a = tmp
b = tmp
```

**Implementation notes:**
- Requires expression tracking across statements
- Must consider aliasing

## 7. Register Allocation for Locals

**Current:** All locals are on stack (FP-relative addressing)

**Opportunity:** Keep frequently-used byte locals in A/X/Y registers

**Implementation notes:**
- Significant complexity increase
- Requires liveness analysis
- Only beneficial for leaf functions with few locals

## 8. Tail Call Optimization

**Current:**
```asm
    jsr other_function
    rts
```

**Optimized:**
```asm
    jmp other_function  ; Tail call
```

**Implementation notes:**
- Only when caller and callee have compatible stack frames
- Requires tracking return paths

## Priority Recommendations

1. **High impact, low effort:**
   - Direct ADC/SBC/AND/ORA (peephole optimization)
   - Extended strength reduction

2. **Medium impact, medium effort:**
   - Loop unrolling for small counts
   - Dead store elimination

3. **High impact, high effort:**
   - Common subexpression elimination
   - Register allocation

## JAM Marker Reference

For module relocation, the following JAM markers are available:

| Marker | Original | Instruction |
|--------|----------|-------------|
| $42    | $4C      | JMP abs     |
| $52    | $20      | JSR abs     |
| $22    | $AD      | LDA abs     |
| $12    | $BD      | LDA abs,X   |
| $32    | $B9      | LDA abs,Y   |
| $62    | $8D      | STA abs     |
| $72    | $9D      | STA abs,X   |
| $82    | $99      | STA abs,Y   |
| $92    | $EE      | INC abs     |
| $B2    | $CE      | DEC abs     |
| $C2    | $6D      | ADC abs     |
| $D2    | $ED      | SBC abs     |
| $E2    | $2D      | AND abs     |
| $F2    | $0D      | ORA abs     |

**Note:** $A2 is NOT usable as a JAM marker - it's the legal `LDX #imm` opcode!
