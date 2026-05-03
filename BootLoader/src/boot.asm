[BITS 16]
[ORG 0x7C00]

start:
	cli ; Clear interrupts
	mov ax, 0x00 ; Clear the accumulator register.  Lower 16 bits of EAX
	mov ds, ax ; mov ax (0x00) to the Data Segment (clear it)
	mov es, ax ; clear Extra Segment
	mov ss, ax ; clear Stack Segment
	mov sp, 0x7C00 ; Set stack pointer to the appropriate memory location for our boot code.
	; Laptop won't print the H even though I'm confident I have it in the right place.  Chuck a junk char i n there
	mov ax, 0x0003	
	mov si, msg1; Move the information from our msg data area
	call print

	; Enable A20 line
	; An ancient backwards compatibility support that allows code access to memory past 1 MB
	; Has to be explicitly allowed
	in al, 0x92 ; Reads the hardware port 0x92 value into al register
	or al, 0x02 ; Bitwise OR against 0b0010
	out 0x92, al ; Writes back to the register, uses the "FAST A20 gate" that goes through the system control port
	; Load the GDT
	lgdt [gdt_descriptor] ; Load the data dereferences at this address
	
	; Write to the 0 bit of CR0 to enter Protected
	mov si, msg2
	call print 

	mov eax, cr0 ; Grab the current value so we don't overwrite it
	or eax, 0x1
	mov cr0, eax ; Restore the CR0 with the 0 bit written

	jmp CODE_SEGMENT:protected_mode

;******************************************************************************
;* Print in Real mode;
;******************************************************************************
print:
	lodsb ; load a single byte to the AL register,automatically increments Stack incrementer 
	cmp al, 0 ; Compare with null
	je done ; Then jump if found null
	mov ah, 0x0E ; Put the value b1110 into AH.  0xE is "Display Character" when we call Int 0x10
	int 0x10 ; interrupt number 0x10.   Video Display Functions!
	jmp print ; Unconditional jump to print.  Loops our characters

done:
	ret ; Pops the return address and then jumps back to the original calling instruction


;******************************************************************************
;* GDT
;******************************************************************************
; This is setting up NASM to interpret the byte locations in memory of the gdt sections
; This way if it adjusts within the binary it will find its new location itself.
gdt_start:  ; Start the Global Descriptors Table

gdt_null: ; Null description - Required
	dd 0x00000000 ; Always starts with null, dd Doubleword
	dd 0x00000000 ; Always starts with null, second set of DoubleWords to fill the entire expected Null area
; Access Flags:
; Validity
; DPL High
; DPL Low
; Code or System Segment
; Executable (code or system segment)
; Memory Direction
; Readable or Writeable (Code vs Data)
; Accessed by CPU flag
gdt_code:  ; Code segment.  
	dw 0b1111111111111111
	dw 0b0000000000000000
	db 0b00000000
	db 0b10011010
	db 0b11001111
	db 0b00000000
gdt_data: ; Data Segment
	dw 0b1111111111111111
	dw 0b0000000000000000
	db 0b00000000
	db 0b10010010
	db 0b11001111
	db 0b00000000
gdt_end:

; NASM technique to add up the binary byte size and location of the GDT instead of hard coding every change
gdt_descriptor:  
	dw gdt_end - gdt_start - 1 ; GDT size minus 1
	dd gdt_start ; GDT Address in boot binary

CODE_SEGMENT equ gdt_code - gdt_start ; define the CODE_SEGMENT constant
DATA_SEGMENT equ gdt_data - gdt_start


;******************************************************************************
;* Protected Mode Entry
;******************************************************************************

[BITS 32]
; Looks very similar to the beginning of REAL mode, but we're moving to 32 bits
; This time though, we put the DATA/Code flags into the  data section, extra, stack segments,
protected_mode:
	cld
	mov ax, DATA_SEGMENT 
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov fs, ax ; New register named.  No special name, just f comes after e
	mov gs, ax ;
	mov ebp, 0x90000
	mov esp, ebp

	; Clear the VGA Buffer
	mov edi, 0xB8000 ; Points to a specific position in member.  In this case, the VGA buffer
	mov ecx, 80 * 25 ; Put 80*25=2000 into the Counter Register, one of the 4 original general purpose registers
	mov ax, 0x0720 ; This is a color/background setting
	rep stosw ; This is tied directly to the edi register. It repeats, ecx number of times, decrementing it, then pushes whatever is in ax into the current position within edi.

	mov esi, msg3
	mov edi, 0xB8000 ; VGA text buffer
	mov ah,  0x0F    ; Set up the high bytes for white on black

.print:
	lodsb
	cmp al, 0 
	je .done
	; [edi] brackets write to the address that edi points to.  In this case, it's the VGA text buffer above
	mov [edi], ax ; Dereference the address
	add edi, 2 ; Increment a byte
	jmp .print

.done:
	cli
	hlt

msg1 db 'Loading Real Mode', 0xD, 0xA, 0 ; String followed by a CR/LF/Null (0xD, 0xA, NULL)
msg2 db 'Entering Protected Mode', 0xD, 0xA, 0 
msg3 db 'Protected Mode complete', 0xD, 0xA, 0

times 510 - ($ - $$) db 0 ; Fill the empty space to get to the 510 byte location.  $ is current address, $$ is next section

dw 0xAA55 ; Define word.  2 bytes.  Magic word at 510 bytes
