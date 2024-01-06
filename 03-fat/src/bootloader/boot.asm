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
    ; set up data segment and stack
    mov ax, 0
    mov es, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00

    push es
    push word main
    retf

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
; - es:bx: memory addr to store data
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
; - bs:si: points to string
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


;;;;;;
; Main begin
;

main:
    ; BIOS should have set dl to drive number
    mov [ebr_drive_number], dl

    ; show loading message
    mov si, loading_str
    call puts

    ; read drive parameter
    ; - cl [0-5 bits]: last sector index per track (start from 1)
    ; - dh: last head index (start from 0)
    push es
    mov ah, 0x08
    int 0x13
    jc disk_error
    pop es
    and cx, 0x003f ; 0000_0000_0011_1111
    mov [dbd_sectors_per_track], cx
    inc dh
    mov [dbd_heads], dh

    ; compute for root directory size
    ; lba = sectors per fat * fat count + reserved sectors
    mov ax, [dbd_sectors_per_fat]
    mov bl, [dbd_fat_count]
    xor bh, bh
    mul bx
    add ax, [dbd_reserved_sectors]
    push ax
    ; root directory sectors count = 32 * dir entries / bytes per sector
    mov ax, [dbd_dir_entries]
    shl ax, 5 ; ax *= 32
    div word [dbd_bytes_per_sector]
    test dx, dx
    jz .skip
    inc ax

.skip:
    pop cx
    push ax
    add ax, cx
    mov [data_begin], ax
    pop ax
    push cx

    ; read root directory
    mov cl, al
    pop ax ; lba of root directory sector
    mov dl, [ebr_drive_number]
    mov bx, buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx ; searched entries count
    mov di, buffer

.find_kernel:
    mov si, file_kernel_bin
    mov cx, 11
    push di
    repe cmpsb
    pop di
    je .kernel_found

    ; move to next directory entry
    add di, 32
    inc bx
    cmp bx, [dbd_dir_entries]
    jl .find_kernel
    jmp kernel_not_found

.kernel_found:
    mov ax, [di + 26] ; di is the entry, offset of first cluster low is 26
    mov [kernel_cluster], ax

    ; read fat chain
    mov ax, [dbd_reserved_sectors]
    mov bx, buffer
    mov cl, [dbd_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    ; lba = data begin + (cluster - 2) * sectors per cluster
    mov ax, [kernel_cluster]
    sub ax, 2
    xor cx, cx
    mov cl, [dbd_sectors_per_cluster]
    mul cx
    add ax, [data_begin]
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    ; buffer += sectors per cluster * bytes per sector
    xor ax, ax
    mov al, [dbd_sectors_per_cluster]
    mul word [dbd_bytes_per_sector]
    add bx, ax

    ; compute for next cluster
    ; fat index = current cluster * 3 / 2
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    dec cx
    div cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]

    or dx, dx ; if (current cluster % 2 == 0)
    jz .even

.odd:
    shr ax, 4
    jmp .next

.even:
    and ax, 0x0fff

.next:
    cmp ax, 0x0ff8
    jae .read_finished

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finished:
    mov dl, [ebr_drive_number]
    mov ax, KERNEL_LOAD_SEGMENT
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    cli
    hlt

;
; Main end
;;;;;;

disk_error:
    mov si, disk_error_str
    call puts
    jmp wait_key_and_reboot

kernel_not_found:
    mov si, kernel_not_found_str
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 0x16
    jmp 0xffff:0


loading_str: db "Loading...", ENDL, 0
disk_error_str: db "Disk error", ENDL, 0
kernel_not_found_str: db "Kernel not found", ENDL, 0
file_kernel_bin: db "KERNEL  BIN"
data_begin: dw 0
kernel_cluster: dw 0

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET equ 0

times 510-($-$$) db 0
dw 0xaa55

buffer:
