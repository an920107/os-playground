org 0x7c00
bits 16

%define ENDL 0x0d, 0x0a ; \r\n


; FAT 12 Header
jmp short start
nop
dbd_oem:                    db "MSWIN4.1"
dbd_bytes_per_sector:       dw 512
dbd_sectors_per_cluster:    db 1
dbd_reserved_sectors:       dw 1
dbd_fat_count:              db 2
dbd_dir_entries:            dw 0xe0
dbd_sectors:                dw 2880 ; 1440 KB / 512 B
dbd_media_type:             db 0xf0 ; 3.5-inch floppy
dbd_sectors_per_fat:        dw 9
dbd_sectors_per_track:      dw 18
dbd_heads:                  dw 2
dbd_hidden_sectors:         dd 0
dbd_large_sectors:          dd 0

; Extended Boot Record
ebr_drive_number:           db 0    ; 0x00: floppy, 0x80: hard disks
ebr_windows_flag:           db 0    ; reserved
ebr_signature:              db 0x29
ebr_volume_id:              dd 0    ; serial number
ebr_volume_label:           db "SQUIIIOS   "
ebr_system_id:              db "FAT12   "


; Entry
start:
    jmp main


; Convet LBA addr to CHS addr
;
; params:
; - ax: LBA addr
; returns:
; - cx [0-5 bits]: sector
; - cx [6-15 bits]: cylinder
; - dh: head
lba_to_chs:
    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [dbd_sectors_per_track]    ; ax = LBA / sectors per track
                                        ; dx = LBA % sectors per track

    inc dx                              ; dx = LBA % sectors per track + 1 -> sector
    mov cx, dx                          ; cx = sector


    xor dx, dx                          ; dx = 0
    div word [dbd_heads]                ; ax = LBA / sectors per track / heads -> cylinder
                                        ; dx = LBA / sectors per track % heads -> head

    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder to cl

    pop ax
    mov dl, al                          ; restore dl
    pop ax
    ret


; Read sectors from disk
;
; params:
; - ax: lba addr
; - cl: number of sectors to read (up to 128)
; - dl: drive number
; - es:bx: ram addr to store data
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax

    mov ah, 0x02
    mov di, 3

.retry:
    pusha
    stc
    int 0x13
    jnc .done ; carry flag will be clear if success

    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    jmp disk_error

.done:
    popa
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret


; Reset disk controller
; params:
; - dl: drive number
disk_reset:
    pusha
    mov ah, 0
    stc
    int 0x13
    jc disk_error
    popa
    ret


; Print a string to screen
;
; params:
; - si: points to string
puts:
    push si
    push ax

    mov ah, 0x0e
    mov bh, 0

.foreach:
    lodsb           ; mov al, [si] (inc ip)
    or al, al       ; zero-flag will be 1 when al == 0
    jz .done

    int 0x10
    jmp .foreach

.done:
    pop ax
    pop si
    ret


;
; Main
;
main:
    mov ax, 0
    mov es, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00

    mov si, hello_str
    call puts

    mov [ebr_drive_number], dl
    mov ax, 1
    mov cl, 1
    mov bx, 0x7e00
    call disk_read

    mov si, 0x7e00
    call puts

    cli
    hlt


disk_error:
    mov si, disk_error_str
    call puts
    jmp wait_key_and_reboot


wait_key_and_reboot:
    mov ah, 0
    int 0x16
    jmp 0xffff:0


.halt:
    cli
    hlt

hello_str: db "Hello Jas0xf, Hardy, Xunhaoz!!!", ENDL, 0
disk_error_str: db "Disk error!", ENDL, 0

times 510-($-$$) db 0
dw 0xaa55
