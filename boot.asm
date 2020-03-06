; BasicOS Bootloader v1
; Created by Onelio
;

%include "fat16.asm"
[BITS 16]               ; 16bt Mode Processor
[ORG FAT.CodeSection] ; Jump FAT table data

; FUNCTION Main
; Main sector loader
; 
Main:
    mov     ax, 0x07C0  ; Set DS(0x07C0):XX
    mov     ds, ax      ; workaround inval op
    ; Stack register init
    xor     ax, ax
    mov     ss, ax
    mov     sp, 0x7C00  ; SS:SP 0x0000:0x7C00
    ; Save DriveId to mem
    mov     [DriveId], dl
    ; Print init messages
    call    VGA_Init
    mov     si, MG_INIT
    call    Print
    ; I13 Extension check
    call    I13EXT_Check
    jnc     EXTSupported
    mov     si, MG_ESPT
    call    Print
    call    Loop        ; Die if no supported

EXTSupported:
    ; Calculate Root values
    EVAL_RootSector word[RootLBA] ; Starting sector (LBA)
    EVAL_RootLength word[RootLen] ; Size in sectors

    ; Initialize DAP-Packet
    ;
    call    Disk_Reset
    mov     byte[FAT.DAP + DAP.Size], 0x10
    ; ES:BX
    mov     word[FAT.DAP + DAP.DestSegment], 0x07C0
    mov     word[FAT.DAP + DAP.DestOffset], FAT.DataArea
    ; LBA && Length
    mov     ax, word[RootLBA]
    mov     word[FAT.DAP + DAP.LBA], ax
    mov     ax, word[RootLen]
    mov     word[FAT.DAP + DAP.Len], ax
    ; Set DAP and Drive
    mov     si, FAT.DAP
    mov     dl, byte[DriveId]

    call    Read
    jc      OnReadFail
    mov     word[DESItem], FAT.DataArea
    ; Assuming kernel.bin IS present
    FIND_SystemFile KRNFILE, 6, DESItem
    ; TODO store cluster & size


    
    ; Calculate FAT first table
    EVAL_FATSSector word[FATSLBA]

    ; Modify DAP-Packet
    ;
    call    Disk_Reset
    ; LBA && Length
    mov     ax, word[FATSLBA]
    mov     word[FAT.DAP + DAP.LBA], ax
    mov     ax, word[FAT.SectorsPerFAT]
    mov     word[FAT.DAP + DAP.Len], ax
    ; Set DAP and Drive
    mov     si, FAT.DAP
    mov     dl, byte[DriveId]
    call    Read
    jc      OnReadFail


    mov     si, MG_KRNF 
    call    Print
    call    Loop

OnReadFail:
    mov     si, MG_ELDG
    call    Print
    mov     cx, 0x2D
    mov     dx, 0xC6C0
    call    Sleep
    call    Reboot

%include "io.asm"
; SYS VARS
DriveId     db 0x00
RootLBA     dw 0x0000
RootLen     dw 0x0000
DESItem     dw 0x0000
FATSLBA     dw 0x0000
; CST DATA
KRNFILE     db "KERNEL"
; MG LIST DATA [13(\r) 10(\n) 0(\0)]
MG_INIT     db "v BasicOS boot", 13, 10, 0
MG_ESPT     db "* Error.", 13, 10, 0
MG_ELDG     db "* Error. Rebooting", 13, 10, 0
MG_KRNF     db "- Kernel Found. Init", 13, 10, 0
; Fill bytes with 0x00 up to magic numb
; Magic Number for the BIOS check.
times (510 - 0x003E - ($ - $$)) db 0x00  
    dw 0xAA55