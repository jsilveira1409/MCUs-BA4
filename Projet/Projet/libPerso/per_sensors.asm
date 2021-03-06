;	

; ==========================macros =====================================
	
; =======================subroutine=========================
temperature:		;PORT B
		rcall		wire1_reset							;reset pulse
		CA			wire1_write, skipROM				;skip ROM identification
		CA			wire1_write, convertT				;initaite temperature convertion
		WAIT_MS		10					
		rcall		wire1_reset
		CA			wire1_write, skipROM
		CA			wire1_write, readScratchpad
		rcall		wire1_read							;read temperature LSB
		mov			b2,b0
		rcall		wire1_read							;read temperature MSB
		mov			b1,b0
		mov			b0, b2
		ret

light:										;PORT F, pin 0, registre b1, b0
		OUTI		ADMUX, 0				;active le convertisseur sur le pin 0 
		sbi			ADCSR,ADSC
		WP1			ADCSR,ADSC
		in			b0,ADCL
		in			b1,ADCH
		WAIT_MS		100
		ret

humidity:									;PORT F, pin 1, registre b1, b0
		OUTI		ADMUX, 1				;active le convertisseur sur le pin 1
		sbi			ADCSR,ADSC
		WP1			ADCSR, ADSC
		in			b0,ADCL
		in			b1,ADCH
		WAIT_MS		100
		ret
