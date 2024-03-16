.def mpr = r16
.def gpr1 = r17
.def gpr2 = r18
.def gpr3 = r19
.include "m32U4def.inc"

.org $0000
rjmp INIT
.org $0002
;cycle r/p/s
rcall CYCLE
reti
.org $0008
;submit/start
rcall SUBMIT
reti
.org $0028
;timer overflow
rcall TC1OF
reti

.org $0032 ;recieve usart
rcall USARTREC
reti
INIT:
	;setup sp
	ldi gpr1, low(RAMEND)
	out SPL, gpr1
	ldi gpr1, high(RAMEND)
	out SPH, gpr1
	;setup interrupts
	ldi gpr1, $09 ;enable individaul interrupts for pd4 and pd7
	out EIMSK, gpr1
	ldi gpr1, 0b10000010 ;set them to detect falling edge
	sts EICRA, gpr1
	;setup t/c 1
	;use normal mode
	ldi gpr1, 0b00000000
	sts TCCR1A, gpr1
	ldi gpr1, 0b00000001
	sts TCCR1B, gpr1
	;setup usart
	;databits = 8, stopbits = 2, parity = disabled, operation = async, baud = 2400 bps, double data rate
	ldi gpr1, 0b00000010
	sts UCSR1A, gpr1
	ldi gpr1, 0b11111000
	sts UCSR1B, gpr1
	ldi gpr1, 0b00001110
	sts UCSR1C, gpr1
	;setup io regs
	ldi gpr1, $00 ;setup all of port d as input
	out DDRD, gpr1
	ldi gpr1, $FF
	out PORTD, gpr1
	;setup port b as an output
	ldi gpr1, $FF
	out DDRB, gpr1
	ldi gpr1, $00
	out PORTB, gpr1
	
	;write default value to data memory
	ldi XL, low(CURRSTATE)
	ldi XH, high(CURRSTATE)
	ldi gpr1, 0
	st X, gpr1
	ldi XL, low(CURRCHOICE)
	ldi XH, high(CURRCHOICE)
	ldi gpr1, 'r'
	st X, gpr1
	ldi XL, low(OPPREADY)
	ldi XH, high(OPPREADY)
	ldi gpr1, 0
	st X, gpr1
	ldi XL, low(COUNTDOWN)
	ldi XH, high(COUNTDOWN)
	ldi gpr1, 0 ;number of times the counter can overflow before the game ends
	st X, gpr1
	rcall LCDInit
	sei ;global int enable
	
MAIN:
	;check current state
	ldi XL, low(CURRSTATE)
	ldi XH, high(CURRSTATE)
	ld gpr1, X
	cpi gpr1, 0 ;branch depending on current state
	breq S0JMP
	cpi gpr1, 1
	breq S1JMP
	cpi gpr1, 2
	breq S2JMP
	cpi gpr1, 3
	breq S3JMP
	cpi gpr1, 4
	breq S4JMP
	rjmp MAIN ;infinite loop
S0JMP: ;"jump table", nessecary because breq has a pretty limited range for k (its only 7 bits and signed so half the value is reserved for negative values)
	jmp STATE0
S1JMP:
	jmp STATE1
S2JMP:
	jmp STATE2
S3JMP:
	jmp STATE3
S4JMP:
	jmp STATE4

TC1OF:
	;save state
	push gpr1
	push gpr2
	push gpr3
	;load overflows from data memory
	ldi XL, low(OVERFLOWS)
	ldi XH, high(OVERFLOWS)
	ld gpr1, X
	;if out of overlows, reset and decrement COUNTDOWN
	dec gpr1
	brne ENDTC1OF
	;if COUNTDOWN is 0 change state
	;load COUNTDOWN
	ldi XL, low(COUNTDOWN)
	ldi XH, high(COUNTDOWN)
	ld gpr1, X
	dec gpr1
	brne ENDTC1OF
	;change state
	ldi XL, low(CURRSTATE)
	ldi XH, high(CURRSTATE)
	ld gpr1, X
	inc gpr1
	st X, gpr1

ENDTC1OF:
	ldi gpr1, $97
	sts TCNT1L, gpr1 ;reset timer
	ldi gpr1, $98
	sts TCNT1H, gpr1
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	ret

USARTREC:
	;save state
	push gpr1
	push gpr2
	push gpr3
	lds gpr1, UCSR1A ;get reciever data
	ldi XL, low(LASTREC)
	ldi XH, high(LASTREC)
	st X, gpr1 ;put it into data memory for later
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	reti


LPMLOOP:
	lpm gpr1, Z+ ;get the next byte from program memory 
	st X+, gpr1 ;put it in the lcd buffer
	dec gpr2 ;decrement loop counter
	brne LPMLOOP ;repeat loop if != 0
	rcall LCDWrite ;write the data to the lcd
	ret
CYCLE: ;change what the current choice is 
	;save state
	push gpr1
	push gpr2
	push gpr3
	;get state
	ldi XL, low(CURRSTATE)
	ldi XH, high(CURRSTATE)
	ld gpr1, X
	cpi gpr1, 2
	breq CYCLES2
CYCLES2: ;state 2 is the state where we are actually playing the game which is the only time we want to be able to toggle choices 
	;the state transitions are: rock -> paper -> scizzors -> rock = 'r' -> 'p' -> 's' -> 'r'
	;get the current move first
	ldi XL, low(CURRCHOICE)
	ldi XH, high(CURRCHOICE)
	ld gpr1, X
	;transition to next state 
	cpi gpr1, 'r' ;check which state encoding is in data memory
	breq ROCKTOPAP 
	cpi gpr1, 'p'
	breq PAPTOSCIZZ
	cpi gpr1, 's'
	breq SCIZZTOROCK
	rjmp CYCLEEND ;if for whatever reason none of the branches trigger jump to end to save time
ROCKTOPAP: ;each transition is the same. change the value of gpr1 for later to the new state
	ldi gpr1, 'p'
	rjmp CYCLEEND
PAPTOSCIZZ:
	ldi gpr1, 's'
	rjmp CYCLEEND
SCIZZTOROCK:
	ldi gpr1, 'r'
	rjmp CYCLEEND
	
CYCLEEND:
	st X, gpr1 ;putting this at cycle end instead of each branch saves program memory
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	rjmp MAIN

SUBMIT:
	;save state
	push gpr1
	push gpr2
	push gpr3

	;get curr state
	ldi XL, low(CURRSTATE)
	ldi XH, high(CURRSTATE)
	ld gpr1, X
	cpi gpr1, 0
	breq SUBMITS0

SUBMITS0: ;always go to state 1 if we are in state 0
	inc gpr1
	st X, gpr1
	;send transmission to other device that you are ready
	rjmp SUBMITEND

SUBMITEND:
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	ret

STATE0: ;display opening message 
	;save state
	push gpr1
	push gpr2
	push gpr3
	;load program memory into lcd buffer 
	ldi ZL, low(STATE0STR)
	ldi ZH, high(STATE0STR)
	rol ZL ;need to shift left because program memory only has 2^15 accessible words and the last bit is to select the byte in the word
	rol ZH
	ldi XL, low(lcd_buffer_addr)
	ldi XH, high(lcd_buffer_addr)

	ldi gpr2, 32 ;loop counter
	rcall LPMLOOP

STATE0END:
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	rjmp MAIN	

STATE1:
	;save state
	push gpr1
	push gpr2
	push gpr3
	;load program memory into lcd buffer 
	ldi ZL, low(STATE1STR)
	ldi ZH, high(STATE1STR)
	rol ZL ;need to shift left because program memory only has 2^15 accessible words and the last bit is to select the byte in the word
	rol ZH
	ldi XL, low(lcd_buffer_addr)
	ldi XH, high(lcd_buffer_addr)

	ldi gpr2, 32 ;loop counter
	rcall LPMLOOP
	;check opponent status
	ldi XL, low(OPPREADY)
	ldi XH, high(OPPREADY)
	ld gpr1, X
	cpi gpr1, '#'
	brne STATE1END ;only go to next state if opponent ready is # (code for "yes opponent is ready")
	ldi XL, low(CURRSTATE) ;go to next state by incrementing state from program memory and writing it back
	ldi XH, high(CURRSTATE)
	ld gpr1, X
	inc gpr1
	st X, gpr1
	;start the countdown now! (value for ~0.05 seconds = $9897)
	ldi gpr1, $97
	sts TCNT1L, gpr1
	ldi gpr1, $98
	sts TCNT1H, gpr1
	;set countdown appropriately 
	ldi XL, low(COUNTDOWN)
	ldi XH, high(COUNTDOWN)
	ldi gpr1, 4
	st X, gpr1
	;set overflows properly
	ldi XL, low(OVERFLOWS)
	ldi XH, high(OVERFLOWS)
	ldi gpr1, 30
	st X, gpr1

STATE1END:
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	rjmp MAIN	
STATE2:
	;save state
	push gpr1
	push gpr2
	push gpr3
	;load program memory into lcd buffer (print "GAME START"
	ldi ZL, low(STATE2STR)
	ldi ZH, high(STATE2STR)
	rol ZL ;need to shift left because program memory only has 2^15 accessible words and the last bit is to select the byte in the word
	rol ZH
	ldi XL, low(lcd_buffer_addr)
	ldi XH, high(lcd_buffer_addr)

	ldi gpr2, 16 ;loop counter
	rcall LPMLOOP
	;get current move from data memory
	ldi YL, low(CURRCHOICE)
	ldi YH, high(CURRCHOICE)
	ld gpr1, Y
	;write a different string into the last 16 bytes of the lcd buffer corresponding to the correct choice
	cpi gpr1, 'r' ;conditional branching
	breq PRINTROCK
	cpi gpr2, 'p'
	breq PRINTPAPER
	cpi gpr3, 's'
	breq PRINTSCIZZ
PRINTROCK: ;load different string based on data memory value
	ldi ZL, low(ROCKSTR)
	ldi ZH, high(ROCKSTR)
	rjmp STATE2END
PRINTPAPER:
	ldi ZL, low(PAPERSTR)
	ldi ZH, high(PAPERSTR)
	rjmp STATE2END
PRINTSCIZZ:
	ldi ZL, low(SCIZZSTR)
	ldi ZH, high(SCIZZSTR)
	rjmp STATE2END

STATE2END:
	ldi gpr2, 16 ;write that string to the lcd buffer's last line. 
	;we can do this without loading a different value into Z because LPMLOOP doesn't restore the state on purpose 
	;so that we can write to the next line easily
	rcall LPMLOOP
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	rjmp MAIN	

STATE3:
	rjmp MAIN

STATE4:
	rjmp MAIN

;preset text
;opening 
STATE0STR:
.db "Welcome!        Please press PD7"
STATE1STR:
.db "Ready. Waiting  For the opponent"
STATE2STR:
.db "Game start	     "
ROCKSTR:
.db "Rock	     "
PAPERSTR:
.db "Paper	     "
SCIZZSTR:
.db "Scizzors	     "
.include "lcddriver.asm"

.dseg 

CURRSTATE:
.byte 1
CURRCHOICE:
.byte 1
OPPREADY:
.byte 1
LASTREC:
.byte 1
COUNTDOWN: ;tracks with leds, how many more 5 sec increments until out of time
.byte 1
OVERFLOWS: ;tracks tc1 overflows since last countdown reached 0
.byte 1
