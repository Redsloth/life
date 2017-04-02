.msp430
.entry_point ENTRY_POINT

.include "msp430g2231.inc"

.define RAM_SIZE     0x0080
.define RAM_END      0x0280

.define FIELD_HEIGHT 8
.define FIELD_WIDTH  8
.define FIELD_BYTES  (FIELD_HEIGHT * FIELD_WIDTH) / 8
.define FIELD_WORDS  (FIELD_BYTES / 2)
.define FIELD_ADDR   RAM_END - FIELD_BYTES

.define FIELD_MASK   0xff80
.define CELL_MASK    0xfff8

.org 0xf800
ENTRY_POINT:
.func InitCpu
    mov.w   #WDTHOLD|WDTPW, &WDTCTL
    mov.w   #RAM_END, SP
.endf

.func InitField
    mov.w   #FIELD_WORDS, r15
next:
    push    #0xAAAA
    dec.w   r15
    jne     next
.endf

test:
    mov     #0, r15
    mov     #0, r14
    mov     #0, r13
    call    #GetCellState

    mov     #1, r14
    call    #GetCellState

.func WaitForInterrupt
    bis     #CPUOFF|GIE, sr
.endf

.func DecideFate
; in  r15 idx of current cell
; use r14 ofs of neighbor
; use r13 count of live neighbors / fate
    


.endf

.func GetCellState
    ; in  r15 idx of current cell
    ; in  r14 ofs of neighbor
    ; ref r13 incremented if alive
    ; use r12 address of cell block / value of cell block
    push    r12

    add     r15, r14            ; get idx of neighbor
    bic     #FIELD_MASK, r14    ; modulo size of field

    mov     r14, r12            ; get addr of neighbor's cell block
    rra     r12                 ; cell block addr = cell addr / 8
    rra     r12
    rra     r12
    add     #FIELD_ADDR, r12    ; derefernce cell block idx
    mov     @r12, r12           ; load cell block

    bic     #CELL_MASK, r14     ; get idx of cell within block (modulo 8)
    add     #bits_table, r14    ; dereference to bits table
    mov.b   @r14, r14           ; load bit mask from table

    push    r12                 ; save value of r12
    bic     r14, r12            ; kill the cell in question
    pop     r14                 ; restore original value
    cmp     r14, r12            ; was the cell dead?
    jeq     end                 ; yes, do nothing
    inc     r13                 ; no, increment r13

end:
    pop     r12
    ret

bits_table:
    .db     BIT0
    .db     BIT1
    .db     BIT2
    .db     BIT3
    .db     BIT4
    .db     BIT5
    .db     BIT6
    .db     BIT7

.endf 

; Vectors
.org 0xfffe
    dw     ENTRY_POINT 
