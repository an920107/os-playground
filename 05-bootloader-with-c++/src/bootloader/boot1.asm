org 0x500

start:
    [bits 16]
    jmp entry

%include "print.inc"

entry:
    [bits 16]
    mov ax, ds
    mov ss, ax
    mov sp, 0xfff0
    mov bp, sp

    ; hide tty cursor
    mov ah, 0x01
    mov cx, 0x0100
    int 0x10

    ; switch to protected mode
    ; 1. disable interrupts
    cli

    ; 2. enable A20 gate
    call enable_a20

    ; 3. load GDT
    call load_gdt

    ; 4. set protection enable flag in CR0
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; 5. far jump into protected mode (code segment is 2nd)
    jmp dword 0x08:.pmode

.pmode:
    [bits 32]
    ; 6. setup segment register (data segment is 3rd)
    mov ax, 0x10
    mov ds, ax
    mov ss, ax

    mov ah, 0xc0
    call protected_clear

    mov ah, 0xcf
    mov esi, hello_msg
    call protected_print

    jmp halt

    ; go back to real mode
    ; 1. far jump into 16-bit protected mode (code segment is 4th)
    jmp word 0x18:.pmode16

.pmode16:
    [bits 16]
    ; 2. disable protected mode bit
    mov eax, cr0
    and al, ~1
    mov cr0, eax

    ; 3. far jump into real mode
    jmp word 0x00:.rmode

.rmode:
    [bits 16]
    ; 4. setup segments
    mov ax, 0
    mov ds, ax
    mov ss, ax

    ; 5. enable interrupt
    sti

halt:
    jmp halt

;;;

; Reference: https://wiki.osdev.org/%228042%22_PS/2_Controller
KeyboardCtlDataPort         equ 0x60
KeyboardCtlStatusPort       equ 0x64
KeyboardCtlCommandPort      equ 0x64

DisableKeyboardCtl          equ 0xad
EnableKeyboardCtl           equ 0xae
KeyboardReadCtlOutput       equ 0xd0
KeyboardWriteCtlOutput      equ 0xd1

enable_a20:
    [bits 16]
    ; disable keyboard
    call a20_wait_input
    mov al, DisableKeyboardCtl
    out KeyboardCtlCommandPort, al

    ; read control output port
    call a20_wait_input
    mov al, KeyboardReadCtlOutput
    out KeyboardCtlCommandPort, al

    call a20_wait_output
    in al, KeyboardCtlDataPort
    push eax

    ; write control output port
    call a20_wait_input
    mov al, KeyboardWriteCtlOutput
    out KeyboardCtlCommandPort, al

    call a20_wait_input
    pop eax
    or al, 2 ; 0000_0010, which is A20 bit
    out KeyboardCtlDataPort, al

    ; enable keyboard
    call a20_wait_input
    mov al, EnableKeyboardCtl
    out KeyboardCtlCommandPort, al

    call a20_wait_input
    ret

a20_wait_input:
    [bits 16]
    ; wait until status bit 1 (input buffer) is 0
    in al, KeyboardCtlStatusPort
    test al, 2 ; 0000_0010
    jnz a20_wait_input
    ret

a20_wait_output:
    [bits 16]
    ; wait until status bit 0 (output buffer) is 1
    in al, KeyboardCtlStatusPort
    test al, 1 ; 0000_0001
    jz a20_wait_output
    ret

;;;

; Reference: https://wiki.osdev.org/Global_Descriptor_Table
gdt:
    ; null description
    dq 0

    ; 32-bit code segment
    dw 0xffff                   ; limit (bits 0-15) = 0xFFFFF for full 32-bit range
    dw 0                        ; base (bits 0-15) = 0x0
    db 0                        ; base (bits 16-23)
    db 10011010b                ; access (present, ring 0, code segment, executable, direction 0, readable)
    db 11001111b                ; granularity (4k pages, 32-bit pmode) + limit (bits 16-19)
    db 0                        ; base high

    ; 32-bit data segment
    dw 0xffff                   ; limit (bits 0-15) = 0xFFFFF for full 32-bit range
    dw 0                        ; base (bits 0-15) = 0x0
    db 0                        ; base (bits 16-23)
    db 10010010b                ; access (present, ring 0, data segment, executable, direction 0, writable)
    db 11001111b                ; granularity (4k pages, 32-bit pmode) + limit (bits 16-19)
    db 0                        ; base high

    ; 16-bit code segment
    dw 0xffff                   ; limit (bits 0-15) = 0xFFFFF
    dw 0                        ; base (bits 0-15) = 0x0
    db 0                        ; base (bits 16-23)
    db 10011010b                ; access (present, ring 0, code segment, executable, direction 0, readable)
    db 00001111b                ; granularity (1b pages, 16-bit pmode) + limit (bits 16-19)
    db 0                        ; base high

    ; 16-bit data segment
    dw 0xffff                   ; limit (bits 0-15) = 0xFFFFF
    dw 0                        ; base (bits 0-15) = 0x0
    db 0                        ; base (bits 16-23)
    db 10010010b                ; access (present, ring 0, data segment, executable, direction 0, writable)
    db 00001111b                ; granularity (1b pages, 16-bit pmode) + limit (bits 16-19)
    db 0                        ; base high

gdt_descriptor:
    dw $ - gdt - 1              ; limit = size of GDT
    dd gdt                      ; address of GDT

load_gdt:
    [bits 16]
    lgdt [gdt_descriptor]
    ret

;;;

hello_msg: db "Thanks a lot, Zoe! I love you forever.", 0
