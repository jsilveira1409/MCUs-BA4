/*
 * TEST4.asm
 *
 *  Created: 30.04.2021 21:15:18
 *   Author: BG
 */

.include "libPerso/per_macro.asm"
.include "lib/definitions.asm"

.equ	bufferLen	= 40		;? modifier
.equ	SRAM_flag	= 0
.equ	EEPROM_flag	= 1

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

.org	0x30			;end of interrupt vector table ??

; =========interrupt service routine ==========
.org	0x31
overflow0:
		in		_sreg, SREG
		ori		a1, (1<<SRAM_flag)
		out		SREG, _sreg
		reti

; ================== init / reset ===============================

reset:
		LDSP		RAMEND						;load stack pointer (SP)
		OUTI		TIMSK, (1<<TOIE0)			;init du timer
		OUTI		ASSR,  (1<<AS0)
		OUTI		TCCR0,6						;p.189 5->overflow toutes les secondes
		OUTI		ADCSR,(1<<ADEN) + 6 ;init du ADC pour LDR
		OUTI		ADMUX, 0						;pin 0 -> LDR
		rcall		LCD_init
		rcall		encoder_init
		rcall		wire1_init
		
		ldi			a0, 0
		ldi			xl, low(0)			;init des pointeurs pour les bases de donn?es
		ldi			xh, high(0)
		ldi			yl, low(buffer)
		ldi			yh, high(buffer)	;yh !!
		rcall		LCD_clear
		sei									; set global interrupts
		rjmp			main

.include "lib/printf.asm"
.include "lib/lcd.asm"
.include "lib/menu.asm"	
.include "libPerso/per_eeprom.asm"



.include "libPerso/per_encoder.asm"
.include "libPerso/per_wire1.asm"		
.include "libPerso/per_sensors.asm"

main:	
		CYCLIC			a0,0,2
		PRINTF			LCD
.db		CR, CR,FHEX,a,0							;deux retours ? la ligne ? ->a indique l'adresse m?moire
		rcall			menui
.db		"Temperature |Humidity    |Light       ",0		;au d?but du programme ? strmenu : .db "Temperature ..."	
		WAIT_MS			1
		rcall			encoder
		brts			mesurements_choice
		//JB1			a1, SRAM_flag, store_SRAM
		sbrc		a1, SRAM_flag
		rcall		store_SRAM

		//JB1			a1, EEPROM_flag, store_EEPROM	
		sbrc		a1, EEPROM_flag
		rcall		store_EEPROM

		rjmp			main

mesurements_choice:				; switch case selon le choix du menu (-> a0) pour l'affichage de la mesure 
		rcall		LCD_clear
		cpi			a0,0x0000
		breq		getTemp

		cpi			a0,0x0001
		breq		getHum

		cpi			a0,0x0002
		breq		getLight

		rjmp		mesurements_choice ;boucle infinie si a0 != 0,1,2 


getTemp:
	rcall		temperature
	rcall		LCD_home
	PRINTF		LCD
.db	"temp  ",FFRAC2+FSIGN,b,4,$42," C",CR,0
	rcall		encoder
	brts		come_back
	rjmp		getTemp

getHum:
	rcall		humidity
	rcall		LCD_home
	PRINTF		LCD
.db	"hum   ",FFRAC2+FSIGN,b,4,$42," %",CR,0
	rcall		encoder
	brts		come_back
	rjmp		getHum

getLight:
	rcall		light
	rcall		LCD_home ;change
	PRINTF		LCD
.db	"light ",FFRAC2+FSIGN,b,4,$42," lm",CR,0
	rcall		encoder
	brts		come_back
	rjmp		getLight


come_back:
	rcall		LCD_clear
	rcall		LCD_home
	rjmp		main

store_SRAM:
		ldi		a3, 0xCA	;temp
		ldi		a2, 0xFE
		st		y+, a3		;store dans la SRAM
		st		y+, a2
		
		ldi		a3, 0xAB	;hum
		ldi		a2, 0xCD
		st		y+, a3
		st		y+, a2

		ldi		a3, 0xB1	;light
		ldi		a2, 0x7E
		st		y+, a3
		st		y+, a2

		ret

store_EEPROM:
		nop
		ret



overflowtest:
		in		_sreg, SREG

		ldi		a3, 0xCA	;temp
		ldi		a2, 0xFE
		st		y+, a3		;store dans la SRAM
		st		y, a2		;pas de +y
		clr		a2			;clear le registre pour contr?ler si la valeur est bien stock?e dans la SRAM
		clr		a3			;clear le registre pour contr?ler si la valeur est bien stock?e dans la SRAM

		subi	yl, 1		;revenir ? l'adresse du MSB dans la SRAM
		ld		_u, y+		;utiliser le scratch register pour les interruptions
		mov		b1, _u
		clr		_u			;clear
		ld		_u, y		
		mov		b0, _u
		clr		_u			;clear
		subi	yl, 1
		rcall	record

		ldi		a3, 0xAB	;hum
		ldi		a2, 0xCD
		//subi	yl, 1
		adiw	yl, bufferLen
		st		y+, a3
		st		y, a2		;pas de +y
		clr		a2			;clear le registre pour contr?ler si la valeur est bien stock?e dans la SRAM
		clr		a3			;clear le registre pour contr?ler si la valeur est bien stock?e dans la SRAM

		subi	yl, 1		;revenir ? l'adresse du MSB dans la SRAM
		//adiw	yl, bufferLen
		ld		_u, y+		;utiliser le scratch register pour les interruptions
		mov		b1, _u
		clr		_u			;clear
		ld		_u, y		
		mov		b0, _u
		clr		_u			;clear
		subi	yl, 1
		rcall	record

		//subi	yl, 1
		ldi		a3, 0xB1	;light
		ldi		a2, 0x7E
		adiw	yl, 2*bufferLen
		st		y+, a3
		st		y, a2		;pas de +y
		clr		a2			;clear le registre pour contr?ler si la valeur est bien stock?e dans la SRAM
		clr		a3			;clear le registre pour contr?ler si la valeur est bien stock?e dans la SRAM

		subi	yl, 1		;revenir ? l'adresse du MSB dans la SRAM
		//adiw	yl, 2*bufferLen
		ld		_u, y+		;utiliser le scratch register pour les interruptions
		mov		b1, _u
		clr		_u			;clear
		ld		_u, y+		
		mov		b0, _u
		clr		_u			;clear
		//subi	yl, 1
		rcall	record
		subi	yl, bufferLen
		subi	yl, bufferLen

		/*rcall	temperature		
		st		x+, a0
		st		x+, a1
		rcall	humidity	
		st		y+, a0
		st		y+, a1
		rcall	light
		st		z+, a0
		st		z+, a1*/

		/*pop b0
		pop	b1
		pop _u
		pop a2
		pop a3*/
		out		SREG, _sreg
		reti




