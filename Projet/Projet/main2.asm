/*
 * TEST4.asm
 *
 *  Created: 30.04.2021 21:15:18
 *   Author: BG
 */

.include "libPerso/per_macro.asm"
.include "lib/definitions.asm"

.equ	bufferLen		= 10			;? modifier
.equ	SRAM_flag		= 0

.equ	EEPROM_START	= 0	;0x0E0a pour tester si le pointeur revient au d?but ? modifier -> 0
.equ	eepromLen		= 0x0020
//.equ	EEPROM_flag	= 1

; ======================= memory management ======================================
.dseg
.org	SRAM_START
		buffer : .byte bufferLen

.cseg
; ========================interrupt vector tables =================================
.org 0
		jmp			reset

.org	OVF0addr
		jmp		overflow0

; =========interrupt service routine ==========
//.org	0x31
overflow0:
		in		_sreg, SREG
		ori		b3, (1<<SRAM_flag)
		out		SREG, _sreg
		reti

; ================== init / reset ===============================

reset:
		LDSP		RAMEND						;load stack pointer (SP)
		OUTI		TIMSK, (1<<TOIE0)			;init du timer
		OUTI		ASSR,  (1<<AS0)
		OUTI		TCCR0,	7					;p.189 6->overflow toutes les 2 secondes (5 -> toutes les secondes)
		OUTI		ADCSR,(1<<ADEN) + 6			;init du ADC pour LDR
		rcall		LCD_init
		rcall		encoder_init
		rcall		wire1_init
		ldi			b3, 0						;b3 register for SRAM_flag -> on pourrait utiliser a1 aussi ?
		ldi			a0, 0
		ldi			xl, low(EEPROM_START)					;init des pointeurs pour les bases de donn?es
		ldi			xh, high(EEPROM_START)
		ldi			yl, low(buffer)
		ldi			yh, high(buffer)

		OUTI	DDRE,0b00000010					; make Tx (PE1) an output
		sbi		PORTE,PE1						; set Tx to high	
		rcall		LCD_clear
		sei										; set global interrupts
		ldi			r17, 0x08
		mov			d0, r17
		rjmp		main

.include "lib/printf.asm"
.include "lib/lcd.asm"
.include "lib/menu.asm"	
.include "libPerso/per_eeprom.asm"

.include "libPerso/per_encoder.asm"
.include "libPerso/per_wire1.asm"		
.include "libPerso/per_sensors.asm"
.include "libPerso/per_uart.asm"

.macro	STVALSRAM		;store sensor value to SRAM
	st		y+, b1
	st		y+, b0
	.endmacro

main:
		
		rcall		putc
		CYCLIC			a0,0,2
		PRINTF			LCD
.db		CR, CR,FHEX,a,0							;deux retours ? la ligne ? ->a indique l'adresse m?moire
		rcall			menui
.db		"Temperature |Humidity    |Light       ",0		;au d?but du programme ? strmenu : .db "Temperature ..."	
		WAIT_MS			1
		rcall			encoder
		brts			mesurements_choice
		sbrc		b3, SRAM_flag
		rcall		store				;SRAM and EEPROm
		rjmp			main

mesurements_choice:				; switch case selon le choix du menu (-> a0) pour l'affichage de la mesure 
		rcall		LCD_clear
		cpi			a0,0x0000
		breq		getTemp

		cpi			a0,0x0001
		breq		getHum

		cpi			a0,0x0002
		breq		getLight
		
		//clr			a0					;sinon boucle infinie si a0 != 0,1,2 ?
		rjmp		mesurements_choice  


getTemp:
	rcall		temperature
	rcall		LCD_home
	PRINTF		LCD
.db	"temp  ",FFRAC2+FSIGN,b,4,$42," C",CR,0
	rcall		encoder
	brts		come_back

	sbrc		b3, SRAM_flag
	rcall		store							;SRAM and EEPROM
	rjmp		getTemp

getHum:
	rcall		humidity
	rcall		LCD_home
	PRINTF		LCD
.db	"hum   ",FFRAC2+FSIGN,b,4,$42," %",CR,0
	rcall		encoder
	brts		come_back

	sbrc		b3, SRAM_flag
	rcall		store							;SRAM and EEPROM
	rjmp		getHum

getLight:
	rcall		light
	rcall		LCD_home						;change
	PRINTF		LCD
.db	"light ",FFRAC2+FSIGN,b,4,$42," lm",CR,0
	rcall		encoder
	brts		come_back
	sbrc		b3, SRAM_flag
	rcall		store							;SRAM and EEPROM
	rjmp		getLight


come_back:
	rcall		LCD_clear
	rcall		LCD_home
	rjmp		main

store:
		rcall		temperature
		STVALSRAM							;store to SRAM
		rcall		humidity
		STVALSRAM							;store to SRAM
		rcall		light
		STVALSRAM							;store to SRAM
		andi		b3, ~(1<<SRAM_flag)		;clear bit SRAM_flag in b3 register
		cpi			yl, bufferLen			;if yl at the end of the buffer then
		brne		PC+3					
		ldi			yl, 0
		rcall		record					;store to EEPROM
		ldi			yl, 0
		ret

sendToCloud:
	/*ldi		zl, low(2*EEPROM_START);set pointer to start of eeprom
	ldi		zl, high(2*EEPROM_START);set pointer to start of eeprom
get:	
	lpm
	adiw	zl, 1
	tst		r0					; test end of file
	breq	end	
	mov		a0, r0				; move value to a0*/
	rcall	putc		        ; send value through uart to arduino
//end:
	ret				

	




