; Reference: https://wiki.osdev.org/Memory_Map_(x86)
;            https://wiki.osdev.org/Printing_To_Screen
VideoBuffer equ 0xb8000

; Print string in protected mode
; params:
; - esi: string pointer
; - ah: color (background * 16 + foreground, i.e. 0x12 is green on blue)
protected_print:
    [bits 32]
    push edi
    push eax

    mov edi, VideoBuffer
    cld

.foreach:
    lodsb
    test al, al
    jz .done

    mov [edi], al
    inc edi
    mov [edi], ah
    inc edi

    jmp .foreach

.done:
    pop eax
    pop edi
    ret


; Clear screen in protected mode
; params:
; - ah: color (background * 16, i.e. 0x30 is cyan background)
protected_clear:
    [bits 32]
    push edi
    push ecx

    mov edi, VideoBuffer
    cld

    mov ecx, 25

.for_row:
    push ecx
    mov ecx, 80

    .for_col:
        mov [edi], byte ' '
        inc edi
        mov [edi], ah
        inc edi

        loop .for_col

    pop ecx
    loop .for_row

.done:
    pop ecx
    pop edi
    ret


; Color Table
; Color number  Color name
; 0             Black
; 1             Blue
; 2             Green
; 3             Cyan
; 4             Red
; 5             Purple
; 6             Brown
; 7             Gray
; 8             Dark Gray
; 9             Light Blue
; 10            Light Green
; 11            Light Cyan
; 12            Light Red
; 13            Light Purple
; 14            Yellow
; 15            White
