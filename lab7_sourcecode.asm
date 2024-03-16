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
.org $0032 ;recieve usart
rcall USARTREC

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

	ldi gpr2, 16 ;loop counter
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

	ldi gpr2, 16 ;loop counter
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

STATE1END:
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	rjmp MAIN	
STATE2:
	jmp MAIN

STATE3:
	jmp MAIN

STATE4:
	jmp MAIN

;preset text
;opening 
STATE0STR:
.db "Welcome!        Please press PD7"
STATE1STR:
.db "Ready. Waiting  For the opponent"
STATE2STR:
.db "Game start"

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
