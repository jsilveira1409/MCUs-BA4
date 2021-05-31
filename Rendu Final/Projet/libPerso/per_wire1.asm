; === definitions ===
.equ	DQ_port	= PORTD
.equ	DQ_pin	= DQ

.equ	DS18B20		= 0x28

.equ	readROM		= 0x33
.equ	matchROM	= 0x55
.equ	skipROM		= 0xcc
.equ	searchROM	= 0xf0
.equ	alarmSearch	= 0xec

.equ	writeScratchpad	= 0x4e
.equ	readScratchpad	= 0xbe
.equ	copyScratchpad	= 0x48
.equ	convertT	= 0x44
.equ	recallE2	= 0xb8
.equ	readPowerSupply	= 0xb4

; === routines ===

.macro	WIRE1				; t0,t1,t2
	sbi	DQ_port-1,DQ_pin	; pull DQ low (DDR=1 output)
	ldi	w,(@0+1)/2	
	rcall	wire1_wait		; wait low time (t0)
	cbi	DQ_port-1,DQ_pin	; release DQ (DDR=0 input)
	ldi	w,(@1+1)/2	
	rcall	wire1_wait		; wait high time (t1)
	in	w,DQ_port-2			; sample line (PINx=PORTx-2)
	bst	w,DQ_pin			; store result in T
	ldi	w,(@2+1)/2	
	rcall	wire1_wait		; wait separation time (t2)
	ret
	.endmacro	

wire1_wait:
	dec	w					; loop time 2usec
	nop
	nop
	nop
	nop
	nop
	brne	wire1_wait
	ret

wire1_init:
	cbi		DQ_port,  DQ_pin	; PORT=0 low (for pull-down)
	cbi		DQ_port-1,DQ_pin	; DDR=0 (input hi Z)
	ret
	
wire1_reset:	WIRE1	480,70,410
wire1_write0:	WIRE1	56,4,1
wire1_write1:	WIRE1	1,59,1
wire1_read1:	WIRE1	1,14,45
	
wire1_write:
	push	b1
	ldi		b1,8
	ror		b0

	brcc	PC+3				; if C=1 then wire1, else wire0
	rcall	wire1_write1
	rjmp	PC+2
	rcall	wire1_write0

	DJNZ	b1,wire1_write+2	; dec and jump if not zero
	pop		b1	
	ret

wire1_read:
	push	b1
	ldi		b1,8
	ror		b0
	rcall	wire1_read1			; returns result in T
	bld		b0,7				; move T to MSB
	DJNZ	b1,wire1_read+2		; dec and jump if not zero
	pop		b1	
	ret
	
wire1_crc:
	ldi		w,0b00011001
	ldi		b2,8
crc1:		ror	b0
	brcc	PC+2
	eor		b1,w
	bst		b1,0
	ror		b1
	bld		b1,7
	DJNZ	b2,crc1
	ret