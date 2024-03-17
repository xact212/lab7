.def mpr = r16
.def gpr1 = r17
.def gpr2 = r23
.def gpr3 = r24
.equ line1Start = $0100
.equ line1End = $010F
.equ line2Start = $0110
.equ line2End = $011F
.equ CURRSTATE = $0300
.equ OPPREADY = $0301
.equ CURRCHOICE = $0302

.include "m32U4def.inc"
.cseg

.org $0000
	rjmp INIT
.org $0002
	rcall CYCLE
.org $0004
	rcall SUBMIT
	reti
.org $0032 
	rcall USARTREC
	reti

.org $0056

INIT:
	ldi gpr1, low(RAMEND) ;setup sp
	out SPL, gpr1
	ldi gpr1, high(RAMEND)
	out SPH, gpr1

	ldi gpr1, 0b00000011 ;setup interrupts
	out EIMSK, gpr1
	ldi gpr1, 0b00001010
	sts EICRA, gpr1

	ldi gpr1, $00 ;i/o setup 
	out DDRD, gpr1
	ldi gpr1, $FF
	out PORTD, gpr1
	ldi gpr1, $FF
	out DDRB, gpr1
	ldi gpr1, $00
	out PORTB, gpr1
	
	ldi gpr1, high(416) ;USART setup set baud 2400 double data rate
	sts UBRR1H, gpr1
	ldi gpr1, low(416)
	sts UBRR1L, gpr1
		
	ldi gpr1, 0b10000001
	sts UCSR1A, gpr1
	
	ldi gpr1, 0b10011000 ;enable reciever and transmitter
	sts UCSR1B, gpr1

	ldi gpr1, 0b00001110 ;frame format/stop bits/async
	sts UCSR1C, gpr1

	ldi XL, low(CURRSTATE) ;set default state
	ldi XH, high(CURRSTATE)
	ldi gpr1, 0
	st X, gpr1
	
	ldi XL, low(CURRCHOICE) ;set default choice
	ldi XH, high(CURRCHOICE)
	ldi gpr1, 'r'
	st X, gpr1

	ldi XL, low(OPPREADY) ;set opponent ready to not ready (0)
	ldi XH, high(OPPREADY)
	ldi gpr1, 0
	st X, gpr1

	rcall LCDInit ;setup lcd
	rcall LCDBackLightOn
	rcall LCDClr

	ldi ZL, low(STATE0STR<<1);load program memory into lcd buffer 
	ldi ZH, high(STATE0STR<<1)
	ldi YL, low(line1Start)
	ldi YH, high(line1Start)

	ldi gpr2, 32 ;loop counter
	
LPMLOOP:
	lpm gpr1, Z+ ;get the next byte from program memory 
	st Y+, gpr1 ;put it in the lcd buffer
	dec gpr2 ;decrement loop counter
	brne LPMLOOP ;repeat loop if != 0
	rcall LCDWrite
	sei

MAIN:
	ldi XL, low(CURRSTATE) ;get current state
	ldi XH, high(CURRSTATE)
	ld gpr1, X
	cpi gpr1, 1 ;swicth to the right state
	breq S1JMP
	cpi gpr1, 2
	breq S2JMP
	rjmp MAIN
S1JMP:
	rjmp STATE1
S2JMP:
	rjmp STATE2
USARTREC:
	push gpr1 ;save state
	push gpr2
	lds gpr1, UDR1 ;get transmission from other board
	;if transmission is #, save that opp is rady to data mem
	cpi gpr1, '#'
	brne NEWCHOICE 
	ldi XL, low(OPPREADY) ;save opp is ready
	ldi XH, high(OPPREADY)
	st X, gpr1
	rjmp USARTRECEND
NEWCHOICE:
	ldi XL, low(CURRCHOICE) ;store new choice in data memory
	ldi XH, high(CURRCHOICE)
	st X, gpr1 
	rjmp USARTRECEND
USARTRECEND:
	pop gpr2 ;restore state
	pop gpr1
	ret
;expect caller to have put transmisson in gpr2 already
USARTTRANS:
	push gpr1 ;save satte
	push gpr2
TRANSLOOP:
	lds gpr1, UCSR1A ;wait until transmitter is ready
	sbrs gpr1, UDRE1
	rjmp TRANSLOOP
	sts UDR1, gpr2 ;caller responsible for setting transmission
	pop gpr2
	pop gpr1 ;restore state
	ret

STATE1: ;constantly poll to see if the opponent is ready
	push gpr1 ;save state
	push gpr2
	push XL
	push XH
	push ZL
	push ZH


	ldi YL, low(line1Start)
	ldi YH, high(line1Start)
	
	ldi XL, low(OPPREADY) ;get opponent state
	ldi XH, high(OPPREADY)
	ld gpr1, X
	;st Y, gpr1 
	rcall LCDWrite ;test to see i fthe opponent is ready
	;compare with # to see if opponent is ready
	cpi gpr1, '#'
	brne STATE1END
	;change to state 2 if opponent is ready
	ldi gpr1, 2
	ldi XL, low(CURRSTATE) ;get current state
	ldi XH, high(CURRSTATE)
	st X, gpr1 ;modify state
	
	rcall LCDClr ;load game start
	ldi ZL, low(STATE2STR<<1);load program memory into lcd buffer 
	ldi ZH, high(STATE2STR<<1)
	ldi YL, low(line1Start)
	ldi YH, high(line1Start)

	ldi gpr2, 32 ;loop counter
	
 LPMLOOPS1:
	lpm gpr1, Z+ ;get the next byte from program memory 
	st Y+, gpr1 ;put it in the lcd buffer
	dec gpr2 ;decrement loop counter
	brne LPMLOOPS1 ;repeat loop if != 0
	rcall LCDWrite

STATE1END:
	pop ZH ;restore state
	pop ZL
	pop XH
	pop XL
	pop gpr2
	pop gpr1
	rjmp MAIN

STATE2:
	push gpr1 ;save state
	push gpr2
	push XL
	push XH
STATE2END:
	pop XH
	pop XL
	pop gpr2
	pop gpr1
	rjmp MAIN

CYCLE:	;change what the current choice is 
	;save state
	push gpr1
	push gpr2
	push gpr3
	push XL
	push XH
	;get state
	ldi XL, low(CURRSTATE)
	ldi XH, high(CURRSTATE)
	ld gpr1, X
	cpi gpr1, 2
	brne CYCLEEND
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
	ldi ZL, low(PAPSTR<<1)
	ldi ZH, high(PAPSTR<<1)
	rjmp CYCLEEND
PAPTOSCIZZ:
	ldi gpr1, 's'
	ldi ZL, low(SCIZZSTR<<1)
	ldi ZH, high(SCIZZSTR<<1)
	rjmp CYCLEEND
SCIZZTOROCK:
	ldi gpr1, 'r'
	ldi ZL, low(ROCKSTR<<1)
	ldi ZH, high(ROCKSTR<<1)
	rjmp CYCLEEND
	
CYCLEEND:
	st X, gpr1 ;putting this at cycle end instead of each branch saves program memory
	ldi YL, low(line2Start)
	ldi YH, high(line2Start)

	ldi gpr2, 16 ;loop counter
	
LPMLOOPCYC:
	lpm gpr1, Z+ ;get the next byte from program memory 
	st Y+, gpr1 ;put it in the lcd buffer
	dec gpr2 ;decrement loop counter
	brne LPMLOOPCYC ;repeat loop if != 0
	rcall LCDWrite

	pop XH
	pop XL
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	ret

SUBMIT:	
	push gpr1 ;save state
	push gpr2
	push gpr3
	push XL
	push XH
	push YL 
	push YH

	;get curr state
	ldi XL, low(CURRSTATE)
	ldi XH, high(CURRSTATE)
	ld gpr1, X
	cpi gpr1, 0
	brne SUBMITEND

SUBMITS0:
	ldi gpr1, 1 ;set state to waiting for opponent
	st X, gpr1 ;write state new data memory
	rcall LCDClr
	ldi ZL, low(STATE1STR<<1);load program memory into lcd buffer 
	ldi ZH, high(STATE1STR<<1)
	ldi YL, low(line1Start)
	ldi YH, high(line1Start)

	ldi gpr2, 32 ;loop counter
	
LPMLOOPSUB:
	lpm gpr1, Z+ ;get the next byte from program memory 
	st Y+, gpr1 ;put it in the lcd buffer
	dec gpr2 ;decrement loop counter
	brne LPMLOOPSUB ;repeat loop if != 0
	rcall LCDWrite

	ldi gpr2, '#' ;USARTTRANS needs caller to put transmission in gpr2 to know what to transmit
	rcall USARTTRANS ;tell other board you are ready
	rjmp SUBMITEND

SUBMITEND:
	pop YH ;restore state
	pop YL
	pop XH
	pop XL
	pop gpr3
	pop gpr2
	pop gpr1
	ret

STATE0STR:
.db "Welcome!        Please press PD7"
STATE0STREND:
STATE1STR:
.db "Ready. Waiting  For the opponent"
STATE1STREND:
STATE2STR:
.db "Game Start      Rock            "
STATE2STREND:
ROCKSTR:
.db "Rock            "
ROCKSTREND:
PAPSTR:
.db "Paper           "
PAPSTREND:
SCIZZSTR:
.db "Scizzors        "
SCIZZSTREND:
.include "lcddriver.asm"


