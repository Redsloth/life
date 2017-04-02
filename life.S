.msp430
.entry_point ENTRY_POINT

.include "msp430g2231.inc"

.define RAM_SIZE     0x0080
.define RAM_END      0x0280
.define RAM_START    0x0200

.define FIELD_HEIGHT 8
.define FIELD_WIDTH  8
.define FIELD_CELLS  (FIELD_HEIGHT * FIELD_WIDTH)
.define FIELD_BYTES  (FIELD_CELLS / 8)
.define FIELD_WORDS  (FIELD_BYTES / 2)
.define FIELD_ADDR   RAM_END - FIELD_BYTES
.define FIELD_MASK   0xffc0
.define CELL_MASK    0xfff8

.org 0xf800
ENTRY_POINT:
    mov.w   #WDTHOLD|WDTPW, &WDTCTL
    mov.w   #RAM_END, SP
    mov.b   #BIT0|BIT6, &P1DIR
    mov.b   #BIT0, &P1OUT
    
    mov.w   #RAM_START, r15
zero_ram:
    clr     @r15
    inc     r15
    cmp     #RAM_END, r15
    jne     zero_ram
    

;   call    #InitField

    push    #0xaaaa
    push    #0xaaaa
    push    #0xaaaa
    push    #0xaaaa

tick:
    xor.b   #BIT0, &P1OUT
    call    #Generate
    jmp     tick

.func InitField
    pop     r4
    mov.w   #FIELD_WORDS, r15
next:
    push    #0xfb8c
    dec.w   r15
    jne     next
    push    r4
    ret
.endf

.func Generate
    ; use r15 addr of lfield

    ; copy field to lfield
push_lfield:                     
    mov     #(FIELD_ADDR + FIELD_BYTES), r15
push_lfield_word:
    add     #-2, r15
    push    @r15
    cmp     #FIELD_ADDR, r15
    jne     push_lfield_word
    mov     SP, r15         ; addr of lfield in r15

    ; decide fates of cells
decide_fates:
    clr     r14
decide_fate:
    xor.b   #BIT6, &P1OUT
    call    #GetCellState
    push    r15
    mov     #FIELD_ADDR, r15
    call    #ApplyCellState
    pop     r15
fate_decided:
    inc     r14
    cmp     #FIELD_CELLS, r14
    jne     decide_fate

    ; remove lfield from stack
pop_lfield:
    mov     #FIELD_WORDS, r15
pop_lfield_word:
    pop     r14
    dec     r15
    jnz     pop_lfield_word

generate_end:
    ret
.endf

.func ApplyCellState
    ; in  r15 addr of field
    ; in  r14 idx  of cell
    ; in  r13 val  of cell state
    ; use r12 addr of cell block
    ; use r11 val  of cell mask

    call    #FindCellBlock
    call    #LoadCellMask

    rrc     r13
    jnc     dead
alive:
    cmp     #2, r13
    jeq     birth
    cmp     #3, r13
    jeq     birth
    jmp     death
dead:
    cmp     #3, r13
    jeq     birth
    jmp     death
birth:
    bis.b   r11, @r12
    ret
death:
    bic.b   r11, @r12
    ret
.endf

.func GetCellState
    ; in  r15 addr of field
    ; in  r14 idx  of cell
    ; out r13 cell state

    ; cell state is:
    ; (AliveNeighborCount * 2) + (Alive ? 1 : 0)
    
    .define X2A 1
    .define A2B (FIELD_WIDTH - 2)
    .define B2C 1
    .define C2D 1
    .define D2E (FIELD_HEIGHT * FIELD_WIDTH) - (FIELD_WIDTH * 2) - 2
    .define E2F 1
    .define F2G 1
    .define G2H (FIELD_WIDTH - 2)
    .define H2X 1

    clr     r13

    add     #X2A, r14
    call    #IncIfAlive
    add     #A2B, r14
    call    #IncIfAlive
    add     #B2C, r14
    call    #IncIfAlive
    add     #C2D, r14
    call    #IncIfAlive
    add     #D2E, r14
    call    #IncIfAlive
    add     #E2F, r14
    call    #IncIfAlive
    add     #F2G, r14
    call    #IncIfAlive
    add     #G2H, r14
    call    #IncIfAlive

    rla     r13
    
    add     #H2X, r14
    call    #IncIfAlive

    ret
.endf

.func IncIfAlive
    ; in  r15 addr of field
    ; in  r14 idx  of cell
    ; ref r13 incremented if alive
    ; use r12 address of cell block / value of cell block
    ; use r11 address of cell mask  / value of cell mask
    
    bic     #FIELD_MASK, r14    ; keep cell idx within field

    call    #FindCellBlock
    mov     @r12, r12           ; load cell block

    call    #LoadCellMask

    push    r12                 ; save value of r12
    bic     r11, r12            ; kill the cell in question
    pop     r11                 ; restore original value
    cmp     r11, r12            ; was the cell dead?
    jeq     end                 ; yes, do nothing
    inc     r13                 ; no, increment r13

end:
    ret
.endf

.func FindCellBlock
    ; in  r15 addr of field
    ; in  r14 idx  of cell
    ; out r12 addr of cell block
    mov     r14, r12            
    rra     r12                 ; cell block addr = cell addr / 8
    rra     r12
    rra     r12
    add     r15, r12            ; derefernce cell block idx to addr
    ret
.endf

.func LoadCellMask
    ; in  r14 idx of cell
    ; out r11 val of cell mask
    mov     r14, r11
    bic     #CELL_MASK, r11     ; get idx of cell within block (modulo 8)
    add     #bits_table, r11    ; dereference to bits table
    mov.b   @r11, r11           ; load bit mask from table
    ret
.endf

bits_table:
    .db     BIT0
    .db     BIT1
    .db     BIT2
    .db     BIT3
    .db     BIT4
    .db     BIT5
    .db     BIT6
    .db     BIT7

; Vectors
.org 0xfffe
    dw     ENTRY_POINT 
