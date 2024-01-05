org 0x7c00
bits 16

%define ENDL 0x0d, 0x0a ; \r\n


start:
    jmp main


; params:
; - ds:si points to string
puts:
    push si
    push ax

    mov ah, 0x0e
    mov bh, 0

.loop:
    lodsb           ; mov al, [sp:si] (inc ip)
    or al, al       ; zero-flag will be 1 when al == 0
    jz .done

    int 0x10
    jmp .loop

.done:
    pop ax
    pop si
    ret


main:
    mov ax, 0
    mov ss, ax
    mov sp, 0x7c00

    mov si, hello_str
    call puts

    hlt


hello_str: db ENDL, "Hello Jas0xf, Hardy, Xunhaoz!!!", ENDL, 0

.halt:
    jmp .halt

times 510-($-$$) db 0
dw 0xaa55
