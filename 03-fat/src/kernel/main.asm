org 0x0
bits 16

%define ENDL 0x0d, 0x0a ; \r\n

start:
    jmp main


; params:
; - bs:si points to string
puts:
    push si
    push ax

    mov ah, 0x0e
    mov bh, 0

.foreach:
    lodsb           ; mov al, [bs:si] (inc ip)
    or al, al       ; zero-flag will be 1 when al == 0
    jz .done

    int 0x10
    jmp .foreach

.done:
    pop ax
    pop si
    ret


main:
    mov si, hello_str
    call puts

    mov si, zoe_str
    call puts

hang:
    jmp hang

hello_str: db ENDL, "Hello Jas0xf, Hardy, Xunhaoz!!!", ENDL, 0
zoe_str: db "Zoe is a cute bao bao~", ENDL, 0
