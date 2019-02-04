;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DEF_BRIDGE_OFFSET		EQU		$20

BIOS_HOOK				; Typical way of handling I/O can bd
						; LDA	#$FD
						; TFR	A,DP
						; and then use direct-page access.
						; But, it takes 4 bytes.
						; If I use U register, I can set #$FD00 to U in 3 bytes.

						LDU		#$FD00
						LDA		#$B7 
						; #$B7 will be written to RS232C command
						; in BIOS_CTBWRT and BIOS_CTBRED
						; In "Dig Dug" (COMPAC) loader, subsequent LOADM commands call
						; MOTOR OFF and then start reading without calling MOTOR ON.
						; Need to guarantee to enable RS232C Rx/Tx by writing #$B7 to 7,U.
						LDB		,X
						DECB
						BEQ		BIOS_MOTOR
						DECB
						BEQ		BIOS_CTBWRT
						DECB
						BEQ		BIOS_CTBRED
						ORCC	#1
						RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

						; If [2,X] is $FF, turn on motor, turn off otherwise.
						; When motor is turned off, reset RS232C so that it won't fire IRQ any more.
BIOS_MOTOR				LDA		2,X
						INCA
						BNE		BIOS_MOTOR_OFF

BIOS_MOTOR_ON			LEAX	RS232C_RESET_CMD,PCR
						; According to http://vorkosigan.cocolog-nifty.com/blog/2009/12/a-b085.html
						; Need to wait 8 clocks between writes.
MOTOR_RS232C_RESET_LOOP
						CLRA								; 2 clocks
						LDA		,X+							; 5 clocks
						STA		7,U ; IO_RS232C_COMMAND
						BPL		MOTOR_RS232C_RESET_LOOP	; Only last command is negative ; 3 clocks

						; CLRA clears carry flag.
						; LDA, STA, and BPL does not change.
						; Can take 10 clocks after each STA 7,U

						RTS

						; 8251A Data Sheet pp.12 'NOTE' paragraph
						; Regarding Internal Reset on Power-up.
RS232C_RESET_CMD		FCB		0,0,0,$40,$4E,$B7

						; Need to make sure RS232C does nothing after MOTOR OFF.
						; "Emergency" (COMPAC) cannot take key inputs unless
						; RS232C is set to do nothing.
BIOS_MOTOR_OFF			
						; Commonly known I/O map tells bit1 of $FD00 means
						;    1: Motor off
						;    0: Motor on
						; which is flipped from actual.  Actual FM-7 write 1 to bit1 of $FD00 to MOTOR-ON.

						; Also, F-BASIC "SAVE" command write $42 outside of BIOS.  Overriding the BIOS
						; does not stop F-BASIC from MOTOR-ON.  Therefore, after loading, it must be set
						; to OFF.  
						; To motor off, $40 needs to be written to $FD00.  Bit6 carries a printer strobe
						; I need that 1 bit to prevent printer confusion.
						; I don't want to do it, but it wastes another 4 bytes.
						LDA		#$40
						STA		,U

						CLR		2,U ; Re-clear IRQ
						CLR		7,U ; IO_RS232C_COMMAND
						RTS		; Previous CLR 7,U also clears carry


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


						; 8251A Data Sheet pp.16 "NOTES" #4
						; Recovery time between writes for asynchronous mode is 8 tCY
						; Probably it is recovery time between sends.
						; May not need wait after setting the status bits.
BIOS_CTBWRT				STA		7,U ; IO_RS232C_COMMAND
						; A=#$B7=WRITE_REQUEST
						BSR		RS232C_WRITE	; 7 clocks
						LDA		2,X
						BSR		RS232C_WRITE
						CLRA
						RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


BIOS_CTBRED				LEAY	READBUFFER,PCR
						LDB		-1,Y
						CMPB	#READBUFFER_SIZE
						BCS		BIOS_CTBRED_EXIT

						STA		7,U ; IO_RS232C_COMMAND
						INCA					; A=#$B7 -> #$B8
						; A=#$B8=READ8_REQUEST
						BSR		RS232C_WRITE	; 7 clocks

						CLRB
FILL_BUFFER_LOOP		BSR		RS232C_READ
						STA		B,Y
						INCB
						ANDB	#(READBUFFER_SIZE-1)
						BNE		FILL_BUFFER_LOOP

BIOS_CTBRED_EXIT		LDA		B,Y
						STA		2,X

						INCB
						STB		-1,Y

						CLRA
						RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


RS232C_READ				LDA		#2
						ANDA	7,U ; IO_RS232C_COMMAND
						BEQ		RS232C_READ
						LDA		6,U	; IO_RS232C_DATA
						RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


RS232C_WRITE			LDB		7,U ; IO_RS232C_COMMAND
						LSRB
						BCC		RS232C_WRITE
						STA		6,U ; IO_RS232C_DATA
						RTS

READBUFFER_SIZE			EQU		16
READBUFFER_USED			FCB		READBUFFER_SIZE
READBUFFER				RZB		READBUFFER_SIZE

BIOS_HOOK_END

END_OF_PROGRAM
