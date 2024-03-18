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
.equ OVERFLOWS = $0303
.equ COUNTDOWN = $0304
.equ OPPCHOICE = $0305
.include "m32U4def.inc"
.cseg

.org $0000
	rjmp INIT
.org $0002
	rcall CYCLE
.org $0004
	rcall SUBMIT
	reti
.org $0028
	rcall TC1OF
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
	
	ldi XL, low(OPPCHOICE) ;set default choice
	ldi XH, high(OPPCHOICE)
	ldi gpr1, 'r'
	st X, gpr1
	
	ldi XL, low(OVERFLOWS) ;preset overflows
	ldi XH, high(OVERFLOWS)
	ldi gpr1, 30
	st X, gpr1

	ldi XL, low(COUNTDOWN) ;preset countdown
	ldi XH, high(COUNTDOWN)
	ldi gpr1, 4
	st X, gpr1

	ldi gpr1, 0b00000000;setup tc1
	sts TCCR1A, gpr1
	ldi gpr1, 0b00000011 ;use 1024 prescale
	sts TCCR1B, gpr1
	
	ldi XL, low(OPPREADY) ;set opponent ready to not ready (0)
	ldi XH, high(OPPREADY)
	ldi gpr1, 0
	st X, gpr1

	rcall LCDInit ;setup lcd
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
	brne NEWOPPCHOICE 
	ldi XL, low(OPPREADY) ;save opp is ready
	ldi XH, high(OPPREADY)
	st X, gpr1
	rjmp USARTRECEND
NEWOPPCHOICE:
	ldi XL, low(OPPCHOICE) ;store new choice in data memory
	ldi XH, high(OPPCHOICE)
	st X, gpr1
	;if we are receieving a choice from the opponent it means the game is over
	;display the opponents choice at the top and yours at the bottom
	ldi gpr2, 16
	ldi YL, low(line1Start)
	ldi YH, high(line1Start)
	cpi gpr1, 'r'
	breq OPPROCK
	cpi gpr1, 'p'
	breq OPPPAP
	cpi gpr1, 's'
	breq OPPSCIZZ
OPPROCK:
	ldi ZL, low(ROCKSTR<<1)
	ldi Zh, high(ROCKSTR<<1)
	rjmp LPMREC
OPPPAP:
	ldi ZL, low(PAPSTR<<1)
	ldi Zh, high(PAPSTR<<1)
	rjmp LPMREC
OPPSCIZZ:
	ldi ZL, low(SCIZZSTR<<1)
	ldi Zh, high(SCIZZSTR<<1)
	rjmp LPMREC

LPMREC:
	lpm gpr1, Z+
	st Y+, gpr1
	dec gpr2
	brne LPMREC
	rcall LCDWrite
	;reset timer
	ldi gpr1, $DF
	sts TCNT1H, gpr1
	ldi gpr1, $97
	sts TCNT1L, gpr1 

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
;expects caller to put COUNTDOWN in gpr1
UPDATELEDS:
	;save state
	push gpr1
	push gpr2
	;check what point in the countdown we are at
	cpi gpr1, 4
	breq LEDS4 
	cpi gpr1, 3
	breq LEDS3 
	cpi gpr1, 2
	breq LEDS2 
	cpi gpr1, 1
	breq LEDS1 
	cpi gpr1, 0
	breq LEDS0 
LEDS4: ;drive the correct leds high
	ldi gpr2, 0b11110000
	out PORTB, gpr2
	rjmp LEDEND
LEDS3:
	ldi gpr2, 0b01110000
	out PORTB, gpr2
	rjmp LEDEND
LEDS2:
	ldi gpr2, 0b00110000
	out PORTB, gpr2
	rjmp LEDEND
LEDS1:
	ldi gpr2, 0b00010000
	out PORTB, gpr2
	rjmp LEDEND
LEDS0:
	ldi gpr2, 0b00000000
	out PORTB, gpr2
	rjmp LEDEND

LEDEND:
	;restore state
	pop gpr2
	pop gpr1
	ret
TC1OF:
	cli
	;save state
	push gpr1
	push gpr2
	push gpr3
	push XL
	push XH
	push ZL
	push ZH
	;get number of overflows from data memory
	ldi XL, low(OVERFLOWS)
	ldi XH, high(OVERFLOWS)
	ld gpr1, X
	;if out of overlows, reset and decrement COUNTDOWN
	dec gpr1
	;save new overflows to data memory
	st X, gpr1
	cpi gpr1, 0
	breq RESETTC1SKIP
	rjmp RESTC1OF
RESETTC1SKIP:
	;reset overflows to 30
	ldi gpr1, 30
	st X, gpr1
	;if COUNTDOWN is 0 change state
	;load COUNTDOWN
	ldi XL, low(COUNTDOWN)
	ldi XH, high(COUNTDOWN)
	ld gpr1, X
	dec gpr1
	rcall UPDATELEDS ;update leds with new value
	;store new COUNTDOWN in data memory
	st X, gpr1
	cpi gpr1, 0
	breq RESETTC1SKIP2
	rjmp RESTC1OF
RESETTC1SKIP2:
	;reset COUNTDOWN in case player wants to play again
	ldi gpr1, 4
	st X, gpr1
	;check state
	ldi XL, low(CURRSTATE)
	ldi XH, high(CURRSTATE)
	ld gpr1, X
	;branch based on state
	cpi gpr1, 2
	breq OFS2RESP
	cpi gpr1, 3
	breq OFS3RESP
	cpi gpr1, 4
	breq OFS4RESP
OFS2RESP:
	ldi gpr1, 3 ;switch to state3 if in state 2 and countdwon is over
	st X, gpr1
	;tell other board what your choice was
	;get you choice 
	ldi XL, low(CURRCHOICE)
	ldi XH, high(CURRCHOICE)
	ld gpr2, X
	;transmit it
	rcall USARTTRANS 
	;reset to four leds on
	ldi gpr1, 4
	rcall UPDATELEDS
	;only reset the timer when we have receieved a response (reset in interrupt when recieving)
	rjmp ENDTC1OF 
OFS3RESP:
	ldi gpr1, 4 ;switch to state 4 displays winner/loser
	st X, gpr1
	;figure out who won/lost
	ldi XL, low(CURRCHOICE) ;get the current choice
	ldi XH, high(CURRCHOICE)
	ld gpr1, X
	ldi XL, low(OPPCHOICE) ;get opponent choice
	ldi XH, high(OPPCHOICE)
	ld gpr2, X
	ldi YL, low(line1Start)	;load lcd address
	ldi YH, high(line1Start)	
	ldi gpr3, 16
	cpi gpr1, 'r' ;branch based on the current choice
	breq PLCHOSEROCK
	cpi gpr1, 'p' 
	breq PLCHOSEPAP
	cpi gpr1, 's' 
	breq PLCHOSESCIZZ
PLCHOSEROCK:
	cpi gpr2, 'r' ;branch based on the opp choice
	breq DRAW
	cpi gpr2, 'p' 
	breq LOST
	cpi gpr2, 's' 
	breq WON
PLCHOSEPAP:
	cpi gpr2, 'r' ;branch based on the opp choice
	breq WON 
	cpi gpr2, 'p' 
	breq DRAW
	cpi gpr2, 's' 
	breq LOST
PLCHOSESCIZZ:
	cpi gpr2, 'r' ;branch based on the opp choice
	breq LOST
	cpi gpr2, 'p' 
	breq WON
	cpi gpr2, 's' 
	breq DRAW

WON:
	ldi ZL, low(WINSTR<<1)
	ldi ZH, high(WINSTR<<1)
	rjmp DISPRES
LOST:
	ldi ZL, low(LOSESTR<<1)
	ldi ZH, high(LOSESTR<<1)
	rjmp DISPRES
DRAW:
	ldi ZL, low(DRAWSTR<<1)
	ldi ZH, high(DRAWSTR<<1)
DISPRES:
	lpm gpr1, Z+ ;replace first line with result
	st Y+, gpr1
	dec gpr3
	brne DISPRES
	rcall LCDWrite
	rjmp RESTC1OF
OFS4RESP:
	;watchdog reset
	ldi gpr1, (1<<WDCE) | (1<<WDE)
	sts WDTCSR, gpr1
	ldi gpr1, (1<<WDE) | (1<<WDP0) | (1<<WDP1)
	sts WDTCSR, gpr1
WDWAIT:
	rjmp WDWAIT
RESTC1OF:
	ldi gpr1, $DF
	sts TCNT1H, gpr1
	ldi gpr1, $97
	sts TCNT1L, gpr1 ;reset timer
ENDTC1OF:
	pop ZH
	pop ZL
	pop XH
	pop XL
	pop gpr3 ;restore state
	pop gpr2
	pop gpr1
	sei
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
	
	ldi gpr1, 4 ;set leds in inital condition
	rcall UPDATELEDS

	ldi gpr1, 0b00000001 ;enable overflow interrupt
	sts TIMSK1, gpr1
	ldi gpr1, $DF
	sts TCNT1H, gpr1
	ldi gpr1, $97 ;set the timer to start counting down!
	sts TCNT1L, gpr1 
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
	rjmp LPMCYCLE
PAPTOSCIZZ:
	ldi gpr1, 's'
	ldi ZL, low(SCIZZSTR<<1)
	ldi ZH, high(SCIZZSTR<<1)
	rjmp LPMCYCLE
SCIZZTOROCK:
	ldi gpr1, 'r'
	ldi ZL, low(ROCKSTR<<1)
	ldi ZH, high(ROCKSTR<<1)
	rjmp LPMCYCLE

LPMCYCLE:
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
CYCLEEND:
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
WINSTR:
.db "You Won!        "
WINSTREND:
LOSESTR:
.db "You Lost        "
LOSESTREND:
DRAWSTR:
.db "Draw            "
DRAWSTREND:
.include "lcddriver.asm"


