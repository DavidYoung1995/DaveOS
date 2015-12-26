format binary as 'bin'
use16
org 0600h

entry_point:	
	mov [DRIVE_NUM], dl
	cli							;Clear interrupts so we don't die
	xor ax, ax 				    ;Zero everything
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov sp, 7C00h				;Set stack to 0x7C00h

	cld							;clear the direction flag for MBR copy
	.relocate_br:				;copy boot record to the start of non-bios memory
	mov di, 0600h
	mov si, 7C00h
	mov cx, 256
	rep movsw

	jmp 0:main
	
main:
	sti							;Bring interrupts back
	;; Int 13h calls
	.check_partitions:
	mov cx, 0004
	mov bx, p_entry1

	.bootflag:
	mov al, BYTE [bx]
	test al, 80h
	jnz short .loadsectors
	add bx, 10h
	dec cx
	jnz short .bootflag
	jmp short .error
	
	.loadsectors:
	add bx, 8h					;jump forward 8 bytes
	mov cx, 4					;Set loop to load 4 bytes
	mov ax, 0
	
		.loadLBA:				;partition entry unaligned
		mov dh, BYTE [bx]
		mov BYTE [DAP_LBA], dh
		inc bx
		dec cx
		inc ax
		jnz .loadLBA
	
	mov si, datapack
	mov ah, 42h
	mov dl, [DRIVE_NUM]
	int 13h
	jc short .error

	jmp 0:7C00h					;give control to the bootable partition
	
.error:
	mov bl, 0002h				;Background - 4 bits; foreground - 4 bits
	mov al, 03h				;Print string & advance cursor
	mov ah, 13h
	mov bh, 0h
	mov bl, 01h
	mov cx, 7					;7 character string
	mov dh, 0
	mov dl, 0
	mov bp, ERR_STR
	int 10h

.failsafe:
	jmp short .failsafe

	
ERR_STR db "BadBoot"

DRIVE_NUM db 80h
	
align 4
datapack:
	DAP_sz db 1
	DAP_NUL db 0
	DAP_TSEC dw 1
	DAP_BUFFOFF dw 7C00h
	DAP_BUFFSEG dw 0h
	DAP_LBA dd 0h
	DAP_LBA_UPPER dd 0h
	
	
padding:
	times 445 - ($ - $$) db 90h			;pad with nop sled -- MBR records begin at 0x1b4

MBRecord:
	struc BOOT_RECORD bootable, s_head, s_sect, s_cyl, sys_id, e_head, e_sect, e_cyl, start_lba, total_sec
	{
	.bootable db bootable
	.s_head db s_head
	.s_sect db s_sect
	.s_cyl db s_cyl
	.sys_id db sys_id
	.e_head db e_head
	.e_sect db e_sect
	.e_cyl db e_cyl
	.start_lba dd start_lba
	.total_sec dd total_sec
	}
	;; 4 boot partitions controlled and loaded by MBR

	DISK_ID db 80h				;Unique disk identifier -- written by partition program

	p_entry1 BOOT_RECORD 0,0,0,0,0,0,0,0,0,0
	p_entry2 BOOT_RECORD 0,0,0,0,0,0,0,0,0,0
	p_entry3 BOOT_RECORD 0,0,0,0,0,0,0,0,0,0
	p_entry4 BOOT_RECORD 0,0,0,0,0,0,0,0,0,0
	db 55h
	db 0AAh						;0xAA55 boot signature
