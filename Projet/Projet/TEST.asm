.include "lib/macros.asm"
.include "lib/definitions.asm"

; ==========================macros =====================================
.macro RECORD
	mov			w,a0					; garder la valeur a0 avant de la perdre dans eeprom_store
	rcall		eeprom_store			; stockage du LSB de la temperature
	adiw		xl,1					; incrementation de l'adresse de la eeprom
	mov			a0, a1					; transfer pour que eeprom_store prenne le MSB de la temperature
	rcall		eeprom_store			; stockage du MSB de la temperature
	adiw		xl,1					; incrementation de l'adresse de la eeprom
	WAIT_MS		200 ;POSE PROBLEME DANS LA IRS???????????
	mov		a0, w					; restitution de la valeur de a0
.endmacro

.macro TEMPERATURE_RECORD
	rcall		wire1_reset							;reset pulse
	CA			wire1_write, skipROM				;skip ROM identification
	CA			wire1_write, convertT				;initaite temperature convertion							
	WAIT_MS		750		
	rcall		lcd_home							
	rcall		wire1_reset
	CA			wire1_write, skipROM
	CA			wire1_write, readScratchpad
	rcall		wire1_read							;read temperature LSB
	mov			c0,a0
	rcall		wire1_read							;read temperature MSB
	mov			a1, a0
	mov			a0, c0
	RECORD
.endmacro	

; ========================interrupt vector tables =================================
.org 0
		jmp			reset

.org	OVF0addr
		rjmp		overflow0

; =========interrupt service routine ==========
	
overflow0:
		in			_sreg, SREG
		inc			b1
		out			PORTA, b1
		//TEMPERATURE_RECORD
		out			SREG, _sreg
		reti
		

; ==========reset / initialization================
reset:
		LDSP		RAMEND
		ldi			xl, low(0)				;memoire eeprom adresse init
		ldi			xh, high(0)
		OUTI		TIMSK, (1<<TOIE0)		; timer
		OUTI		ASSR,  (1<<AS0)
		OUTI		TCCR0, 3
		sei
		rcall		wire1_init
		;rcall		lcd_init
		ldi			r16, 0xff
		out			DDRA, r16				;port A en output
		ldi			b1, 0
		rjmp		main

.include "lib/lcd.asm"
.include "lib/wire1.asm"	
.include "lib/printf.asm"
.include "lib/eeprom.asm"

; ======================main ==============================
main:
	
	rjmp		main
	
; =======================subroutine=========================	