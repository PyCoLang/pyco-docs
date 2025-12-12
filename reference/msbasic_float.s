; msbasic float.s - Microsoft BASIC floating point routines
; Source: https://github.com/mist64/msbasic (BSD License)
;
; This file contains the original Microsoft BASIC floating point routines
; for reference when porting to PyCo's KickAssembler format.
;
; Key routines for 32-bit (CONFIG_SMALL) float operations:
; - FMULT / FMULTT: Multiplication
; - FDIV / FDIVT: Division
; - FADD / FADDT: Addition
; - FSUB / FSUBT: Subtraction
; - NORMALIZE_FAC1/2: Normalization
; - ADD_EXPONENTS: Exponent handling for mul/div

.segment "CODE"

TEMP1X = TEMP1+(5-BYTES_FP)

; ----------------------------------------------------------------------------
; ADD 0.5 TO FAC
; ----------------------------------------------------------------------------
FADDH:
        lda     #<CON_HALF
        ldy     #>CON_HALF
        jmp     FADD

; ----------------------------------------------------------------------------
; FAC = (Y,A) - FAC
; ----------------------------------------------------------------------------
FSUB:
        jsr     LOAD_ARG_FROM_YA

; ----------------------------------------------------------------------------
; FAC = ARG - FAC
; ----------------------------------------------------------------------------
FSUBT:
        lda     FACSIGN
        eor     #$FF
        sta     FACSIGN
        eor     ARGSIGN
        sta     SGNCPR
        lda     FAC
        jmp     FADDT

; ----------------------------------------------------------------------------
; SHIFT SMALLER ARGUMENT MORE THAN 7 BITS
; ----------------------------------------------------------------------------
FADD1:
        jsr     SHIFT_RIGHT
        bcc     FADD3

; ----------------------------------------------------------------------------
; FAC = (Y,A) + FAC
; ----------------------------------------------------------------------------
FADD:
        jsr     LOAD_ARG_FROM_YA

; ----------------------------------------------------------------------------
; FAC = ARG + FAC
; ----------------------------------------------------------------------------
FADDT:
        bne     L365B
        jmp     COPY_ARG_TO_FAC
L365B:
        ldx     FACEXTENSION
        stx     ARGEXTENSION
        ldx     #ARG
        lda     ARG
FADD2:
        tay
        beq     RTS3
        sec
        sbc     FAC
        beq     FADD3
        bcc     L367F
        sty     FAC
        ldy     ARGSIGN
        sty     FACSIGN
        eor     #$FF
        adc     #$00
        ldy     #$00
        sty     ARGEXTENSION
        ldx     #FAC
        bne     L3683
L367F:
        ldy     #$00
        sty     FACEXTENSION
L3683:
        cmp     #$F9
        bmi     FADD1
        tay
        lda     FACEXTENSION
        lsr     1,x
        jsr     SHIFT_RIGHT4
FADD3:
        bit     SGNCPR
        bpl     FADD4
        ldy     #FAC
        cpx     #ARG
        beq     L369B
        ldy     #ARG
L369B:
        sec
        eor     #$FF
        adc     ARGEXTENSION
        sta     FACEXTENSION
.ifndef CONFIG_SMALL
        lda     4,y
        sbc     4,x
        sta     FAC+4
.endif
        lda     3,y
        sbc     3,x
        sta     FAC+3
        lda     2,y
        sbc     2,x
        sta     FAC+2
        lda     1,y
        sbc     1,x
        sta     FAC+1

; ----------------------------------------------------------------------------
; NORMALIZE VALUE IN FAC
; ----------------------------------------------------------------------------
NORMALIZE_FAC1:
        bcs     NORMALIZE_FAC2
        jsr     COMPLEMENT_FAC
NORMALIZE_FAC2:
        ldy     #$00
        tya
        clc
L36C7:
        ldx     FAC+1
        bne     NORMALIZE_FAC4
        ldx     FAC+2
        stx     FAC+1
        ldx     FAC+3
        stx     FAC+2
.ifdef CONFIG_SMALL
        ldx     FACEXTENSION
        stx     FAC+3
.else
        ldx     FAC+4
        stx     FAC+3
        ldx     FACEXTENSION
        stx     FAC+4
.endif
        sty     FACEXTENSION
        adc     #$08
.ifdef CONFIG_2B
; bugfix?
; fix does not exist on AppleSoft 2
        cmp     #(MANTISSA_BYTES+1)*8
.else
        cmp     #MANTISSA_BYTES*8
.endif
        bne     L36C7

; ----------------------------------------------------------------------------
; SET FAC = 0
; (ONLY NECESSARY TO ZERO EXPONENT AND SIGN CELLS)
; ----------------------------------------------------------------------------
ZERO_FAC:
        lda     #$00
STA_IN_FAC_SIGN_AND_EXP:
        sta     FAC
STA_IN_FAC_SIGN:
        sta     FACSIGN
        rts

; ----------------------------------------------------------------------------
; ADD MANTISSAS OF FAC AND ARG INTO FAC
; ----------------------------------------------------------------------------
FADD4:
        adc     ARGEXTENSION
        sta     FACEXTENSION
.ifndef CONFIG_SMALL
        lda     FAC+4
        adc     ARG+4
        sta     FAC+4
.endif
        lda     FAC+3
        adc     ARG+3
        sta     FAC+3
        lda     FAC+2
        adc     ARG+2
        sta     FAC+2
        lda     FAC+1
        adc     ARG+1
        sta     FAC+1
        jmp     NORMALIZE_FAC5

; ----------------------------------------------------------------------------
; FINISH NORMALIZING FAC
; ----------------------------------------------------------------------------
NORMALIZE_FAC3:
        adc     #$01
        asl     FACEXTENSION
.ifndef CONFIG_SMALL
        rol     FAC+4
.endif
        rol     FAC+3
        rol     FAC+2
        rol     FAC+1
NORMALIZE_FAC4:
        bpl     NORMALIZE_FAC3
        sec
        sbc     FAC
        bcs     ZERO_FAC
        eor     #$FF
        adc     #$01
        sta     FAC
NORMALIZE_FAC5:
        bcc     L3764
NORMALIZE_FAC6:
        inc     FAC
        beq     OVERFLOW
.ifndef CONFIG_ROR_WORKAROUND
        ror     FAC+1
        ror     FAC+2
        ror     FAC+3
  .ifndef CONFIG_SMALL
        ror     FAC+4
  .endif
        ror     FACEXTENSION
.else
        ; ROR workaround for older 6502 chips
        lda     #$00
        bcc     L372E
        lda     #$80
L372E:
        lsr     FAC+1
        ora     FAC+1
        sta     FAC+1
        lda     #$00
        bcc     L373A
        lda     #$80
L373A:
        lsr     FAC+2
        ora     FAC+2
        sta     FAC+2
        lda     #$00
        bcc     L3746
        lda     #$80
L3746:
        lsr     FAC+3
        ora     FAC+3
        sta     FAC+3
        lda     #$00
        bcc     L3752
        lda     #$80
L3752:
        lsr     FAC+4
        ora     FAC+4
        sta     FAC+4
        lda     #$00
        bcc     L375E
        lda     #$80
L375E:
        lsr     FACEXTENSION
        ora     FACEXTENSION
        sta     FACEXTENSION
.endif
L3764:
RTS3:
        rts

; ----------------------------------------------------------------------------
; 2'S COMPLEMENT OF FAC
; ----------------------------------------------------------------------------
COMPLEMENT_FAC:
        lda     FACSIGN
        eor     #$FF
        sta     FACSIGN

; ----------------------------------------------------------------------------
; 2'S COMPLEMENT OF FAC MANTISSA ONLY
; ----------------------------------------------------------------------------
COMPLEMENT_FAC_MANTISSA:
        lda     FAC+1
        eor     #$FF
        sta     FAC+1
        lda     FAC+2
        eor     #$FF
        sta     FAC+2
        lda     FAC+3
        eor     #$FF
        sta     FAC+3
.ifndef CONFIG_SMALL
        lda     FAC+4
        eor     #$FF
        sta     FAC+4
.endif
        lda     FACEXTENSION
        eor     #$FF
        sta     FACEXTENSION
        inc     FACEXTENSION
        bne     RTS12

; ----------------------------------------------------------------------------
; INCREMENT FAC MANTISSA
; ----------------------------------------------------------------------------
INCREMENT_FAC_MANTISSA:
.ifndef CONFIG_SMALL
        inc     FAC+4
        bne     RTS12
.endif
        inc     FAC+3
        bne     RTS12
        inc     FAC+2
        bne     RTS12
        inc     FAC+1
RTS12:
        rts
OVERFLOW:
        ldx     #ERR_OVERFLOW
        jmp     ERROR

; ----------------------------------------------------------------------------
; SHIFT 1,X THRU 5,X RIGHT
; (A) = NEGATIVE OF SHIFT COUNT
; (X) = POINTER TO BYTES TO BE SHIFTED
;
; RETURN WITH (Y)=0, CARRY=0, EXTENSION BITS IN A-REG
; ----------------------------------------------------------------------------
SHIFT_RIGHT1:
        ldx     #RESULT-1
SHIFT_RIGHT2:
.ifdef CONFIG_SMALL
        ldy     3,x
.else
        ldy     4,x
.endif
        sty     FACEXTENSION
.ifndef CONFIG_SMALL
        ldy     3,x
        sty     4,x
.endif
        ldy     2,x
        sty     3,x
        ldy     1,x
        sty     2,x
        ldy     SHIFTSIGNEXT
        sty     1,x

; ----------------------------------------------------------------------------
; MAIN ENTRY TO RIGHT SHIFT SUBROUTINE
; ----------------------------------------------------------------------------
SHIFT_RIGHT:
        adc     #$08
        bmi     SHIFT_RIGHT2
        beq     SHIFT_RIGHT2
        sbc     #$08
        tay
        lda     FACEXTENSION
        bcs     SHIFT_RIGHT5
.ifndef CONFIG_ROR_WORKAROUND
LB588:
        asl     1,x
        bcc     LB58E
        inc     1,x
LB58E:
        ror     1,x
        ror     1,x

; ----------------------------------------------------------------------------
; ENTER HERE FOR SHORT SHIFTS WITH NO SIGN EXTENSION
; ----------------------------------------------------------------------------
SHIFT_RIGHT4:
        ror     2,x
        ror     3,x
  .ifndef CONFIG_SMALL
        ror     4,x
  .endif
        ror     a
        iny
        bne     LB588
.else
L37C4:
        pha
        lda     1,x
        and     #$80
        lsr     1,x
        ora     1,x
        sta     1,x
        .byte   $24
SHIFT_RIGHT4:
        pha
        lda     #$00
        bcc     L37D7
        lda     #$80
L37D7:
        lsr     2,x
        ora     2,x
        sta     2,x
        lda     #$00
        bcc     L37E3
        lda     #$80
L37E3:
        lsr     3,x
        ora     3,x
        sta     3,x
        lda     #$00
        bcc     L37EF
        lda     #$80
L37EF:
        lsr     4,x
        ora     4,x
        sta     4,x
        pla
        php
        lsr     a
        plp
        bcc     L37FD
        ora     #$80
L37FD:
        iny
        bne     L37C4
.endif
SHIFT_RIGHT5:
        clc
        rts

; ----------------------------------------------------------------------------
; Constants for CONFIG_SMALL (32-bit floats)
; ----------------------------------------------------------------------------
.ifdef CONFIG_SMALL
CON_ONE:
        .byte   $81,$00,$00,$00
POLY_LOG:
        .byte   $02
        .byte   $80,$19,$56,$62
        .byte   $80,$76,$22,$F3
        .byte   $82,$38,$AA,$40
CON_SQR_HALF:
        .byte   $80,$35,$04,$F3
CON_SQR_TWO:
        .byte   $81,$35,$04,$F3
CON_NEG_HALF:
        .byte   $80,$80,$00,$00
CON_LOG_TWO:
        .byte   $80,$31,$72,$18
.endif

; ----------------------------------------------------------------------------
; FAC = (Y,A) * FAC
; ----------------------------------------------------------------------------
FMULT:
        jsr     LOAD_ARG_FROM_YA

; ----------------------------------------------------------------------------
; FAC = ARG * FAC
; ----------------------------------------------------------------------------
FMULTT:
.ifndef CONFIG_11
        beq     L3903
.else
        jeq     L3903
.endif
        jsr     ADD_EXPONENTS
        lda     #$00
        sta     RESULT
        sta     RESULT+1
        sta     RESULT+2
.ifndef CONFIG_SMALL
        sta     RESULT+3
.endif
        lda     FACEXTENSION
        jsr     MULTIPLY1
.ifndef CONFIG_SMALL
        lda     FAC+4
        jsr     MULTIPLY1
.endif
        lda     FAC+3
        jsr     MULTIPLY1
        lda     FAC+2
        jsr     MULTIPLY1
        lda     FAC+1
        jsr     MULTIPLY2
        jmp     COPY_RESULT_INTO_FAC

; ----------------------------------------------------------------------------
; MULTIPLY ARG BY (A) INTO RESULT
; ----------------------------------------------------------------------------
MULTIPLY1:
        bne     MULTIPLY2
        jmp     SHIFT_RIGHT1
MULTIPLY2:
        lsr     a
        ora     #$80
L38A7:
        tay
        bcc     L38C3
        clc
.ifndef CONFIG_SMALL
        lda     RESULT+3
        adc     ARG+4
        sta     RESULT+3
.endif
        lda     RESULT+2
        adc     ARG+3
        sta     RESULT+2
        lda     RESULT+1
        adc     ARG+2
        sta     RESULT+1
        lda     RESULT
        adc     ARG+1
        sta     RESULT
L38C3:
.ifndef CONFIG_ROR_WORKAROUND
        ror     RESULT
        ror     RESULT+1
        ror     RESULT+2
.ifndef CONFIG_SMALL
        ror     RESULT+3
.endif
        ror     FACEXTENSION
.else
        ; ROR workaround
        lda     #$00
        bcc     L38C9
        lda     #$80
L38C9:
        lsr     RESULT
        ora     RESULT
        sta     RESULT
        lda     #$00
        bcc     L38D5
        lda     #$80
L38D5:
        lsr     RESULT+1
        ora     RESULT+1
        sta     RESULT+1
        lda     #$00
        bcc     L38E1
        lda     #$80
L38E1:
        lsr     RESULT+2
        ora     RESULT+2
        sta     RESULT+2
        lda     #$00
        bcc     L38ED
        lda     #$80
L38ED:
        lsr     RESULT+3
        ora     RESULT+3
        sta     RESULT+3
        lda     #$00
        bcc     L38F9
        lda     #$80
L38F9:
        lsr     FACEXTENSION
        ora     FACEXTENSION
        sta     FACEXTENSION
.endif
        tya
        lsr     a
        bne     L38A7
L3903:
        rts

; ----------------------------------------------------------------------------
; UNPACK NUMBER AT (Y,A) INTO ARG
; ----------------------------------------------------------------------------
LOAD_ARG_FROM_YA:
        sta     INDEX
        sty     INDEX+1
        ldy     #BYTES_FP-1
.ifndef CONFIG_SMALL
        lda     (INDEX),y
        sta     ARG+4
        dey
.endif
        lda     (INDEX),y
        sta     ARG+3
        dey
        lda     (INDEX),y
        sta     ARG+2
        dey
        lda     (INDEX),y
        sta     ARGSIGN
        eor     FACSIGN
        sta     SGNCPR
        lda     ARGSIGN
        ora     #$80
        sta     ARG+1
        dey
        lda     (INDEX),y
        sta     ARG
        lda     FAC
        rts

; ----------------------------------------------------------------------------
; ADD EXPONENTS OF ARG AND FAC
; (CALLED BY FMULT AND FDIV)
;
; ALSO CHECK FOR OVERFLOW, AND SET RESULT SIGN
; ----------------------------------------------------------------------------
ADD_EXPONENTS:
        lda     ARG
ADD_EXPONENTS1:
        beq     ZERO
        clc
        adc     FAC
        bcc     L393C
        bmi     JOV
        clc
        .byte   $2C
L393C:
        bpl     ZERO
        adc     #$80
        sta     FAC
        bne     L3947
        jmp     STA_IN_FAC_SIGN
L3947:
        lda     SGNCPR
        sta     FACSIGN
        rts

; ----------------------------------------------------------------------------
; IF (FAC) IS POSITIVE, GIVE "OVERFLOW" ERROR
; IF (FAC) IS NEGATIVE, SET FAC=0, POP ONE RETURN, AND RTS
; CALLED FROM "EXP" FUNCTION
; ----------------------------------------------------------------------------
OUTOFRNG:
        lda     FACSIGN
        eor     #$FF
        bmi     JOV

; ----------------------------------------------------------------------------
; POP RETURN ADDRESS AND SET FAC=0
; ----------------------------------------------------------------------------
ZERO:
        pla
        pla
        jmp     ZERO_FAC
JOV:
        jmp     OVERFLOW

; ----------------------------------------------------------------------------
; MULTIPLY FAC BY 10
; ----------------------------------------------------------------------------
MUL10:
        jsr     COPY_FAC_TO_ARG_ROUNDED
        tax
        beq     L3970
        clc
        adc     #$02
        bcs     JOV
LD9BF:
        ldx     #$00
        stx     SGNCPR
        jsr     FADD2
        inc     FAC
        beq     JOV
L3970:
        rts

; ----------------------------------------------------------------------------
CONTEN:
.ifdef CONFIG_SMALL
        .byte   $84,$20,$00,$00
.else
        .byte   $84,$20,$00,$00,$00
.endif

; ----------------------------------------------------------------------------
; DIVIDE FAC BY 10
; ----------------------------------------------------------------------------
DIV10:
        jsr     COPY_FAC_TO_ARG_ROUNDED
        lda     #<CONTEN
        ldy     #>CONTEN
        ldx     #$00

; ----------------------------------------------------------------------------
; FAC = ARG / (Y,A)
; ----------------------------------------------------------------------------
DIV:
        stx     SGNCPR
        jsr     LOAD_FAC_FROM_YA
        jmp     FDIVT

; ----------------------------------------------------------------------------
; FAC = (Y,A) / FAC
; ----------------------------------------------------------------------------
FDIV:
        jsr     LOAD_ARG_FROM_YA

; ----------------------------------------------------------------------------
; FAC = ARG / FAC
; ----------------------------------------------------------------------------
FDIVT:
        beq     L3A02
        jsr     ROUND_FAC
        lda     #$00
        sec
        sbc     FAC
        sta     FAC
        jsr     ADD_EXPONENTS
        inc     FAC
        beq     JOV
        ldx     #-MANTISSA_BYTES
        lda     #$01
L39A1:
        ldy     ARG+1
        cpy     FAC+1
        bne     L39B7
        ldy     ARG+2
        cpy     FAC+2
        bne     L39B7
        ldy     ARG+3
        cpy     FAC+3
.ifndef CONFIG_SMALL
        bne     L39B7
        ldy     ARG+4
        cpy     FAC+4
.endif
L39B7:
        php
        rol     a
        bcc     L39C4
        inx
        sta     RESULT_LAST-1,x
        beq     L39F2
        bpl     L39F6
        lda     #$01
L39C4:
        plp
        bcs     L39D5
L39C7:
        asl     ARG_LAST
.ifndef CONFIG_SMALL
        rol     ARG+3
.endif
        rol     ARG+2
        rol     ARG+1
        bcs     L39B7
        bmi     L39A1
        bpl     L39B7
L39D5:
        tay
.ifndef CONFIG_SMALL
        lda     ARG+4
        sbc     FAC+4
        sta     ARG+4
.endif
        lda     ARG+3
        sbc     FAC+3
        sta     ARG+3
        lda     ARG+2
        sbc     FAC+2
        sta     ARG+2
        lda     ARG+1
        sbc     FAC+1
        sta     ARG+1
        tya
        jmp     L39C7
L39F2:
        lda     #$40
        bne     L39C4
L39F6:
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        sta     FACEXTENSION
        plp
        jmp     COPY_RESULT_INTO_FAC
L3A02:
        ldx     #ERR_ZERODIV
        jmp     ERROR

; ----------------------------------------------------------------------------
; COPY RESULT INTO FAC MANTISSA, AND NORMALIZE
; ----------------------------------------------------------------------------
COPY_RESULT_INTO_FAC:
        lda     RESULT
        sta     FAC+1
        lda     RESULT+1
        sta     FAC+2
        lda     RESULT+2
        sta     FAC+3
.ifndef CONFIG_SMALL
        lda     RESULT+3
        sta     FAC+4
.endif
        jmp     NORMALIZE_FAC2

; ----------------------------------------------------------------------------
; UNPACK (Y,A) INTO FAC
; ----------------------------------------------------------------------------
LOAD_FAC_FROM_YA:
        sta     INDEX
        sty     INDEX+1
        ldy     #MANTISSA_BYTES
.ifndef CONFIG_SMALL
        lda     (INDEX),y
        sta     FAC+4
        dey
.endif
        lda     (INDEX),y
        sta     FAC+3
        dey
        lda     (INDEX),y
        sta     FAC+2
        dey
        lda     (INDEX),y
        sta     FACSIGN
        ora     #$80
        sta     FAC+1
        dey
        lda     (INDEX),y
        sta     FAC
        sty     FACEXTENSION
        rts

; ----------------------------------------------------------------------------
; ROUND FAC, STORE IN TEMP2
; ----------------------------------------------------------------------------
STORE_FAC_IN_TEMP2_ROUNDED:
        ldx     #TEMP2
        .byte   $2C

; ----------------------------------------------------------------------------
; ROUND FAC, STORE IN TEMP1
; ----------------------------------------------------------------------------
STORE_FAC_IN_TEMP1_ROUNDED:
        ldx     #TEMP1X
        ldy     #$00
        beq     STORE_FAC_AT_YX_ROUNDED

; ----------------------------------------------------------------------------
; ROUND FAC, AND STORE WHERE FORPNT POINTS
; ----------------------------------------------------------------------------
SETFOR:
        ldx     FORPNT
        ldy     FORPNT+1

; ----------------------------------------------------------------------------
; ROUND FAC, AND STORE AT (Y,X)
; ----------------------------------------------------------------------------
STORE_FAC_AT_YX_ROUNDED:
        jsr     ROUND_FAC
        stx     INDEX
        sty     INDEX+1
        ldy     #MANTISSA_BYTES
.ifndef CONFIG_SMALL
        lda     FAC+4
        sta     (INDEX),y
        dey
.endif
        lda     FAC+3
        sta     (INDEX),y
        dey
        lda     FAC+2
        sta     (INDEX),y
        dey
        lda     FACSIGN
        ora     #$7F
        and     FAC+1
        sta     (INDEX),y
        dey
        lda     FAC
        sta     (INDEX),y
        sty     FACEXTENSION
        rts

; ----------------------------------------------------------------------------
; COPY ARG INTO FAC
; ----------------------------------------------------------------------------
COPY_ARG_TO_FAC:
        lda     ARGSIGN
MFA:
        sta     FACSIGN
        ldx     #BYTES_FP
L3A7A:
        lda     SHIFTSIGNEXT,x
        sta     EXPSGN,x
        dex
        bne     L3A7A
        stx     FACEXTENSION
        rts

; ----------------------------------------------------------------------------
; ROUND FAC AND COPY TO ARG
; ----------------------------------------------------------------------------
COPY_FAC_TO_ARG_ROUNDED:
        jsr     ROUND_FAC
MAF:
        ldx     #BYTES_FP+1
L3A89:
        lda     EXPSGN,x
        sta     SHIFTSIGNEXT,x
        dex
        bne     L3A89
        stx     FACEXTENSION
RTS14:
        rts

; ----------------------------------------------------------------------------
; ROUND FAC USING EXTENSION BYTE
; ----------------------------------------------------------------------------
ROUND_FAC:
        lda     FAC
        beq     RTS14
        asl     FACEXTENSION
        bcc     RTS14

; ----------------------------------------------------------------------------
; INCREMENT MANTISSA AND RE-NORMALIZE IF CARRY
; ----------------------------------------------------------------------------
INCREMENT_MANTISSA:
        jsr     INCREMENT_FAC_MANTISSA
        bne     RTS14
        jmp     NORMALIZE_FAC6

; ----------------------------------------------------------------------------
CON_HALF:
.ifdef CONFIG_SMALL
        .byte   $80,$00,$00,$00
.else
        .byte   $80,$00,$00,$00,$00
.endif

; ----------------------------------------------------------------------------
; POWERS OF 10 FROM 1E8 DOWN TO 1,
; AS 32-BIT INTEGERS, WITH ALTERNATING SIGNS
; ----------------------------------------------------------------------------
DECTBL:
.ifdef CONFIG_SMALL
        .byte   $FE,$79,$60 ; -100000
        .byte   $00,$27,$10 ; 10000
        .byte   $FF,$FC,$18 ; -1000
        .byte   $00,$00,$64 ; 100
        .byte   $FF,$FF,$F6 ; -10
        .byte   $00,$00,$01 ; 1
.endif
DECTBL_END:
