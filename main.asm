;
; Music.asm
; Music bell project
; 
;
;
; ATtiny 2313 @ 20 MHz
;
;            ____   ____
;           |___ \_/    |
;  RESET>---|RST     Ucc|---- +5V
;       ----|RXD     PB7|---- ON Power (SET)
;       ----|TXD     PB6|---- OFF Power (RESET)
;       ----|XTAL2   PB5|----
;  20MHz>---|XTAL1   PB4|----
;       ----|PD2     PB3|---- B-UP
;       ----|PD3     PB2|---- A-UP
;       ----|PD4     PB1|---- B-DOWN
;       ----|PD5     PB0|---- A-DOWN
;    GND----|GND     PD6|----
;           |___________|
;
;...Fuses(Crystall 3..8 MHz).......................
;	[V]CKSEL0		[ ]RSTDISBL		[ ]SELFPRG
;	[V]CKSEL1		[ ]BODLEVEL0
;	[V]CKSEL2		[ ]BODLEVEL1
;	[V]CKSEL3		[ ]BODLEVEL2
;	[ ]SUT0			[ ]WDTON
;	[ ]SUT1			[V]SPIEN
;	[ ]CKOUT		[ ]EESAVE
;	[ ]CKDIV		[ ]DWEN
;
 
;------------------------------------- Global Definitions
.def zero = r1
.def current_note0 = r2
.def current_note1 = r3
.def dlit_count0 = r4
.def dlit_count1 = r5
.def dlit_count2 = r6
.def dlit_count3 = r7

.def temp0 = r16
.def temp1 = r17
.def temp2 = r18
.def temp3 = r19
.def encoded_note = r20
.def encoded_dlit = r21
.def tone_count0 = r22
.def tone_count1 = r23
.def tone_count2 = r24
.def output_buf  = r25
;.undef XL
;.undef XH

;------------------------------------- Interrupt table
rjmp start
reti
reti
reti
reti
reti
reti
reti

reti
reti
reti
reti
reti
reti
reti
reti

reti
reti
reti
reti
reti
reti
reti
reti

reti
reti
reti
reti
reti
reti
reti
reti

;================================================================================
;================================================================== Power part
;================================================================================

; Start main program
start:
	cli
	; Setup all ports
	ldi temp0,0
	out PORTB,temp0
	ldi temp0,0xff
	out DDRB,temp0

	ldi temp0,0
	out PORTD,temp0
	out DDRD,temp0

	;Set zero
	clr zero

	;+++DEBUG
	; rjmp start_music_player
	;---DEBUG

	;Delay 45 ms (45 * 20000 / 5 = 180000)
	ldi temp0,0x20
	ldi temp1,0xBF
	ldi temp2,0x02
	start_delay:
		subi temp0,1
		sbci temp1,0
		sbci temp2,0
	brcc start_delay

	;------------------------------------------------------
	;Turn on SET POWER
	ldi temp0,0b10000000 ; bit7
	out PORTB,temp0

	;Delay 45 ms (45 * 20000 / 5 = 180000)
	ldi temp0,0x20
	ldi temp1,0xBF
	ldi temp2,0x02
	relay_delay1:
		subi temp0,1
		sbci temp1,0
		sbci temp2,0
	brcc relay_delay1

	;Turn off SET POWER
	ldi temp0,0b00000000 ; bit7
	out PORTB,temp0
	;------------------------------------------------------
	rjmp start_music_player
	/*
	;Delay 1 sec
	ldi temp0,0x00
	ldi temp1,0x09
	ldi temp2,0x3D
	temporary_delay:
		subi temp0,1
		sbci temp1,0
		sbci temp2,0
	brcc temporary_delay
	*/
	return_to_power_manage:
	;------------------------------------------------------
	;Turn on SET POWER
	ldi temp0,0b01000000 ; bit6
	out PORTB,temp0

	;Delay 45 ms (45 * 20000 / 5 = 180000)
	ldi temp0,0x20
	ldi temp1,0xBF
	ldi temp2,0x02
	relay_delay2:
		subi temp0,1
		sbci temp1,0
		sbci temp2,0
	brcc relay_delay2

	;Turn off SET POWER
	ldi temp0,0b00000000 ; bit6
	out PORTB,temp0
	;------------------------------------------------------

    stop_program:
    rjmp stop_program

;================================================================================
;================================================================== Player part
;================================================================================

start_music_player:
	ldi ZL, LOW(Music_start*2) ; Y
	ldi ZH,HIGH(Music_start*2) ; Y
	mov current_note0, ZL ; Y
	mov current_note1, ZH; Y

main_loop:
	;--- Get music data
	mov ZL,current_note0
	mov ZH,current_note1
	lpm encoded_note,Z+
	lpm encoded_dlit,Z+
	mov current_note0,ZL
	mov current_note1,ZH

	;--- Test for finish
	cpi encoded_dlit,0xff //Максимальная длительность - выход
	breq return_to_power_manage
	cpi encoded_dlit,0x00 //Нулевая длительность - выход
	breq return_to_power_manage

	;--- decode dlit
		clr dlit_count0
		clr dlit_count1
		clr dlit_count2
		clr dlit_count3
		;20000000=0x1312D00
		ldi temp0,0x00
		ldi temp1,0x2D
		ldi temp2,0x31
		ldi temp3,0x01

		mult_loop:
			sbrs encoded_dlit,7
			rjmp skip_adding
				add dlit_count0,temp0
				adc dlit_count1,temp1
				adc dlit_count2,temp2
				adc dlit_count3,temp3
			skip_adding:
			lsr temp3
			ror temp2
			ror temp1
			ror temp0		
			lsl encoded_dlit
		brne mult_loop

	;--- process pause :)
	cpi encoded_note, Pause
	brne skip_pause
		ldi temp0,6
		loop_pause:
			sub dlit_count0,temp0
			sbc dlit_count1,zero
			sbc dlit_count2,zero
			sbc dlit_count3,zero
		brcc loop_pause
		rjmp main_loop
	skip_pause:

	;--- small pause before tone
	ldi temp0,0xff
	small_delay:
		subi temp0,1
	brcc small_delay

	;--- decode tone
	ldi ZL,LOW(Note_freq*2)
	ldi ZH,HIGH(Note_freq*2)
	mov temp0,encoded_note
	andi temp0,0x0f
	lsl temp0
	lsl temp0
	add ZL,temp0
	adc ZH,zero
	lpm tone_count0,Z+
	lpm tone_count1,Z+
	lpm tone_count2,Z+

	;--- correct octave
	mov temp0,encoded_note
	andi temp0, 0xf0
	;breq skip_delitel_oct
	swap temp0
	subi temp0,251; add +5 ( must be +7, low freq)
	loop_delitel_oct:
		lsr tone_count2
		ror tone_count1
		ror tone_count0
		subi temp0,0x1
	brne loop_delitel_oct
	skip_delitel_oct:


		;--- Main part
		//ldi output_buf,0b00001001 ;!!!!
		//ldi output_buf,0b00010001 ;!counter!
		clr output_buf ;!counter!

		dlit_loop:
			wdr
			;--- delay
			mov temp0,tone_count0
			mov temp1,tone_count1
			mov temp2,tone_count2

			;--- correct 28 ticks in oct (!!!)
			subi temp0,28 + 6;corrected
			sbci temp1,0
			sbci temp2,0

			tone_loop:
				subi temp0,5
				sbci temp1,0
				sbci temp2,0
			brcc tone_loop;temp0 in 251..255

			subi temp0,251; = +5
			ldi	ZL,low(note_correction)
			ldi ZH,high(note_correction)
			sub ZL,temp0
			sbci ZH,0
			ijmp
				nop ; -4
				nop ; -3
				nop ; -2
				nop ; -1
			note_correction:

			;--- change_phase
			;lsl output_buf		;com output_buf
			;adc output_buf,zero
			inc output_buf
			andi output_buf,0x7f;128 times
			ldi temp0,0b0000;out PORTB, zero;Protect transistor

			cpi output_buf,32
			brne skip_plus
				ldi temp0,0b1001;Plus signal
			skip_plus:

			cpi output_buf,96
			brne skip_minus
				ldi temp0,0b0110;Minus signal
			skip_minus:

			out PORTB, temp0	;out PORTB, output_buf

		sub  dlit_count0,tone_count0
		sbc  dlit_count1,tone_count1
		sbc  dlit_count2,tone_count2
		sbc  dlit_count3,zero
		brcc dlit_loop
		;--- Off dynamic
		out PORTB, zero

	;--- End of main part

rjmp main_loop

;================================================================================
;================================================================== Music part
;================================================================================

Note_freq: ; 20MHz
.dd 2745816 ; 2745816.18234674 -- 7.28380877372016 -- do
.dd 2591705 ; 2591705.36186281 -- 7.71692658212694 -- do_d
.dd 2446244 ; 2446244.11710171 -- 8.17579891564371 -- re
.dd 2308947 ; 2308946.98468102 -- 8.66195721802725 -- re_d
.dd 2179356 ; 2179355.74818426 -- 9.17702399741899 -- mi
.dd 2057038 ; 2057037.90890632 -- 9.72271824131503 -- fa
.dd 1941585 ; 1941585.24242914 -- 10.3008611535272 -- fa_d
.dd 1832612 ; 1832612.43621072 -- 10.9133822322814 -- sol
.dd 1729756 ; 1729755.80364032 -- 11.5623257097386 -- sol_d
.dd 1632672 ; 1632672.07026818 -- 12.2498573744297 -- la
.dd 1541037 ; 1541037.22815898 -- 12.9782717993733 -- la_d
.dd 1454545 ; 1454545.45454545 -- 13.75 -- si
.dd 1372908 ; 1372908.09117337 -- 14.5676175474403 -- protect
.dd 1295853 ; 1295852.6809314 -- 15.4338531642539 -- protect
.dd 1223122 ; 1223122.05855086 -- 16.3515978312874 -- protect
.dd 1154473 ; 1154473.49234051 -- 17.3239144360545 -- protect

;================== Tone
.equ Pause = 0xff
.equ do       = 0x00
.equ do_dies  = 0x01

.equ re_bemol = 0x01
.equ re       = 0x02
.equ re_dies  = 0x03

.equ mi_bemol = 0x03
.equ mi       = 0x04

.equ fa       = 0x05
.equ fa_dies  = 0x06

.equ sol_bemol= 0x06
.equ sol      = 0x07
.equ sol_dies = 0x08

.equ la_bemol = 0x08
.equ la       = 0x09
.equ la_dies  = 0x0A

.equ si_bemol = 0x0A
.equ si       = 0x0B
;================== Oktava
.equ Octava_c0 = 0x00
.equ Octava_c1 = 0x10
.equ Octava_c2 = 0x20
.equ Octava_c3 = 0x30
.equ Octava_c4 = 0x40 ; !
.equ Octava_c5 = 0x50 ; !
.equ Octava_c6 = 0x60 ; !
.equ Octava_c7 = 0x70
.equ Octava_c8 = 0x80
.equ Octava_c9 = 0x90
;================== dlit
.equ  dlit1 = 0x80
.equ  dlit2 = 0x40
.equ  dlit4 = 0x20
.equ  dlit8 = 0x10
.equ dlit16 = 0x08
.equ dlit32 = 0x04


;================== Music Data
Music_start:
	;--------------------------------------- From Russia
	;fa-dies
	
	.db Octava_c5 | si		, dlit4			;From

	;--- Str 2

	.db Octava_c6 | mi		, dlit4			;Rus
	.db Octava_c6 | sol		, dlit2			;sia
	.db Octava_c6 | mi		, dlit4			;with

	.db Octava_c7 | do		, dlit2 | dlit4	;love
	.db Octava_c6 | si		, dlit4			;I

	.db Octava_c6 | la_dies , dlit2 | dlit4	;fly
	.db Octava_c6 | si		, dlit4			;to

	.db Octava_c6 | fa_dies , dlit2 | dlit4 ;you (!)
	.db Octava_c5 | si		, dlit4			;My

	.db Octava_c6 | mi		, dlit4			;wis
	.db Octava_c6 | sol		, dlit2			;er
	.db Octava_c6 | mi		, dlit4			;since

	.db Octava_c7 | re		, dlit2 | dlit4	;my
	.db Octava_c7 | do_dies , dlit4			;good

	;--- Str 3
	.db Octava_c7 | do		, dlit2 | dlit4	;bye
	.db Octava_c6 | si		, dlit4			;to

	.db Octava_c7 | re_dies	, dlit2 | dlit4	;you
	.db Octava_c6 | si		, dlit4			;I've

	.db Octava_c7 | mi		, dlit4			;tra
	.db Octava_c6 | si		, dlit2			;velled
	.db Octava_c6 | sol_dies, dlit4			;the

	.db Octava_c6 | mi		, dlit2 | dlit4	;world
	.db Octava_c7 | re		, dlit4			;to

	.db Octava_c7 | re		, dlit2 | dlit4	;learn
	.db Octava_c7 | do		, dlit4			;I

	.db Octava_c6 | la		, dlit2 | dlit4	;must
	.db Octava_c6 | fa_dies	, dlit4			;re

	;--- Str 4

	.db Octava_c7 | do		, dlit2 | dlit4	;turn
	.db Octava_c6 | si		, dlit4			;from

	.db Octava_c5 | si		, dlit4			;Rus
	.db Octava_c6 | re_dies	, dlit2			;sia
	.db Octava_c6 | fa_dies	, dlit4			;with

	.db Octava_c6 | mi		, dlit1|dlit4|dlit8 ; love (3+4)
	.db Pause				, dlit8
/*
	.db Octava_c6 | re_dies	, dlit4
	.db Octava_c6 | mi		, dlit4

	.db Octava_c7 | re		, dlit4
	.db Octava_c7 | do		, dlit2 | dlit4

	.db Octava_c7 | re		, dlit4
	.db Octava_c7 | do		, dlit2
	.db Octava_c6 | la		, dlit4

	.db Octava_c7 | do		, dlit4
	.db Octava_c6 | si		, dlit2
	.db Octava_c6 | la_dies	, dlit4

	;--- Str 5 (page2)

	.db Octava_c7 | do		, dlit4
	.db Octava_c6 | si		, dlit2
	.db Octava_c6 | sol		, dlit4

	.db Octava_c6 | la		, dlit1|dlit4 ; 2+3
	.db Octava_c6 | si		, dlit4
	.db Octava_c6 | la		, dlit2 / 3
	.db Octava_c6 | sol		, dlit2 / 3
	.db Octava_c6 | la		, dlit2 / 3

	.db Octava_c6 | si		, dlit1|dlit4|dlit8 ; 4+5
	.db Pause				, dlit8
	.db Octava_c6 | re_dies	, dlit4
	.db Octava_c6 | mi		, dlit4

	.db Octava_c7 | re		, dlit4
	.db Octava_c7 | do		, dlit2 | dlit4

	;--- Str 6

	.db Octava_c7 | re		, dlit4
	.db Octava_c7 | do		, dlit2
	.db Octava_c6 | la		, dlit4

	.db Octava_c7 | do		, dlit4
	.db Octava_c6 | si		, dlit2
	.db Octava_c6 | la		, dlit4

	.db Octava_c6 | sol		, dlit4
	.db Octava_c6 | fa_dies	, dlit2
	.db Octava_c6 | mi		, dlit4

	.db Octava_c6 | fa_dies	, dlit1 | dlit4 ; 4+5
	.db Octava_c6 | fa_dies	, dlit4
	.db Octava_c6 | fa_dies	, dlit4
	.db Octava_c6 | la		, dlit4
	.db Octava_c7 | do		, dlit4

;--- Str 7
	
	.db Octava_c6 | si		, dlit1|dlit4|dlit8 ; pr+1
	.db Pause				, dlit8 | dlit4
*/
	.db Pause, Pause; End of music

;================================================================================
;================================================================== End of file
;================================================================================
