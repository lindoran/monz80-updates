*
* MONZ80: A software debugger for the Z80 processor
*
* ?COPY.TXT 1996-2007 Dave Dunfield
*  -- see COPY.TXT --.
*
* Monitor data
* (modified for vz200 clone, Z8D)
MCODE	EQU	$0000		;Monitor CODE goes here (ROM)
MDATA	EQU	$7800		;Monitor DATA goes here (start of RAM)
UCODE	EQU	$7860		;User CODE address (same space as before)
USTACK	EQU	$FFFF		;User STACK address (top of RAM)
*
	ORG	MDATA
* User registers (saved while monitor active)
uAF	DS	2		;User AF register
uBC	DS	2		;User BC register
uDE	DS	2		;User DE register
uHL	DS	2		;User HL register
uIX	DS	2		;User IX register
uIY	DS	2		;User IY register
uPC	DS	2		;User PC register
uSP	DS	2		;User SP register
* I/O control byte:
*  7/80 = Output paused
*  6/40 = Echo input
*  5/20 = Convert to upper case
*  4/10 = Clear input stream first
IOCTL	DS	1		;I/O control byte
BRKTAB	DS	8*3		;Breakpoint table
TEMP	DS	2		;Temporary storage
TEMP1	DS	1		;Temporary storage
TEMP2	DS	1		;Temporary storage
BUFFER	DS	50		;Disassembler output buffer
MONSTK	EQU	*		;Some free space
*
* Monitor Code
*
	ORG	MCODE
*
	JP	BEGIN		;Start up monitor
	ORG	1*8		;RST 1
	JP	UCODE+(1*8)	;Execute user code
	ORG	2*8		;RST 2
	JP	UCODE+(2*8)	;Execute user code
	ORG	3*8		;RST 3
	JP	UCODE+(3*8)	;Execute user code
	ORG	4*8		;RST 4
	JP	UCODE+(4*8)	;Execute user code
	ORG	5*8		;RST 5
	JP	UCODE+(5*8)	;Execute user code
	ORG	6*8		;RST 6
	JP	UCODE+(6*8)	;Execute user code
	ORG	7*8		;RST 7 - Breakpoint
*
* Breakpoint encountered - save registers, replace breakpoints
*
BRKPT	LD	(uHL),HL	;Save HL
	POP	HL		;Get PC
	DEC	HL		;Backup to RST instruction
	LD	(uPC),HL	;Save PC
BRKP1	PUSH	AF		;Get AF
	POP	HL		;Copy
	LD	(uAF),HL	;Save AF
	LD	HL,0		;Get 0
	ADD	HL,SP		;Get SP
	LD	(uSP),HL	;Save SP
	EX	DE,HL		;Get DE
	LD	(uDE),HL	;Save DE
	LD	H,B		;Get B
	LD	L,C		;Get C
	LD	(uBC),HL	;Save BC
	LD	(uIX),IX	;Save IX
	LD	(uIY),IY	;Save IY
* Remove any active breakpoints
	LD	HL,BRKTAB	;Point to breakpoint table
	LD	B,8		;Total of 8 breakpoints
rembrk1	LD	E,(HL)		;Get LOW address
	INC	HL		;Skip to next
	LD	D,(HL)		;Get HIGH address
	INC	HL		;Skip to next
	LD	A,D		;Get HIGH
	OR	L		;Test with LOW
	JR	Z,rembrk2	;No breakpoint here
	LD	A,(HL)		;Get opcode
	LD	(DE),A		;Resave opcode value
rembrk2	INC	HL		;Skip to next
	DJNZ	rembrk1		;Remove them all
	CALL	RDUMP		;Display registers
	JR	ENTMON		;Enter monitor
* Cold start entry point
BEGIN	LD	SP,MONSTK	;Set initial stack
	CALL	IOINIT		;Initialize I/O
* Initialize monitor memory to zero
	LD	HL,MDATA	;Point to start of monitor RAM
	LD	DE,TEMP		;End of initialized area
begin1	LD	(HL),0		;Zero 1 byte
	CALL	CHLDE		;Perform compare
	INC	HL		;Advance
	JR	C,begin1	;Zero it all
* Output welcome message
	CALL	WRMSG		;Output message
	DB	$0A,$0D
	STR	'MONZ80 Version 1.0'
	DB	$0A,$0D,$0A
	STR	'?COPY.TXT 1996-2007 Dave Dunfield'
	DB	$0A,$0D
	STR	' -- see COPY.TXT --.'
	DB	$0A,0
* Set initial PC and SP
	LD	HL,UCODE	;Get default PC
	LD	(uPC),HL	;Set it
	LD	HL,USTACK	;Get default SP
	LD	(uSP),HL	;Set it
* Warm-start of monitor
ENTMON	LD	SP,MONSTK	;Reset SP
	LD	A,%01100000	;Echo, Ucase
	LD	(IOCTL),A	;Set I/O control
	CALL	WRMSG		;Output string
	DB	$0A,$0D,'>',0	;Prompt string
* Get command from console
	LD	C,0		;Clear first char
	LD	D,C		;Clear pending flag
cmd	LD	B,C		;Set first character
	CALL	GETC		;Get command character
	LD	C,A		;Set second character
* Search for command in command table
	LD	HL,CTABLE	;Point to command table
cmd1	LD	A,C		;Get LAST char
	CP	(HL)		;Match?
	INC	HL		;Skip to next
	JR	NZ,cmd2		;No, try next
	LD	A,B		;Get HIGH char
	CP	(HL)		;Match?
	JR	NZ,cmd2		;No, try next
* We found the command - execute handler
	INC	HL		;Skip second
	CALL	SPACE		;Separator
	LD	A,(HL)		;Get LOW address
	INC	HL		;Advance
	LD	H,(HL)		;Get HIGH address
	LD	L,A		;Set LOW address
	LD	BC,CMDRET	;Get return address
	PUSH	BC		;Save for return
	JP	(HL)		;Execute
* This command didn't match, check for part of two char sequence
cmd2	LD	A,C		;Get char
	CP	(HL)		;Does it match leading of 2char?
	JR	NZ,cmd3		;No, skip it
	INC	D		;Record possibility
* Advance to next table entry
cmd3	INC	HL		;Skip second
	INC	HL		;Skip address LOW
	INC	HL		;Skip address HIGH
	LD	A,(HL)		;Get character
	AND	A		;End of table
	JR	NZ,cmd1		;Check every entry
	OR	B		;First time through?
	JR	NZ,ERROR	;No, report error
	OR	D		;Possible 2 char?
	JR	NZ,CMD		;Try again
* An error has occured
ERROR	CALL	WRMSG		;Output message
	STRZ	' ?'		;Error message
CMDRET	LD	A,(IOCTL)	;Get I/O control
	AND	%00010000	;Clean input?
	JR	Z,entmon	;No, leave it
* Wait for serial data to clear
CLRSER	LD	BC,0		;Reset counter
clrse1	CALL	TESTC		;Wait for input
	AND	A		;Character ready?
	JR	NZ,CLRSER	;Yes, reset
	DEC	BC		;Reduce count
	LD	A,B		;Get high
	OR	C		;Test for zero
	JR	NZ,clrse1	;Wait for expiry
	JR	ENTMON		;Re-enter monitor
* Command handler table
CTABLE	DW	'DM',DUMP	;Dump memory
	DW	'DI',DISCMD	;Disassemble memory
	DW	'DR',RDUMP	;Dump registers
	DW	'DB',BDUMP	;Dump breakpoints
	DW	'BR',SETBRK	;Set breakpoint
	DW	'E',EDIT	;Edit memory
	DW	'F',FILL	;Fill memory
	DW	'I',INPORT	;Input from a port
	DW	'O',OUTPORT	;Output to a port
	DW	'G',GO		;Go (execute)
	DW	'T',STEP	;Single-step
	DW	'L',LOAD	;Load HEX file
* Register modification commands
	DW	'AF',CAF	;Change AF
	DW	'BC',CBC	;Change BC
	DW	'DE',CDE	;Change DE
	DW	'HL',CHL	;Change HL
	DW	'IX',CIX	;Change IX
	DW	'IY',CIY	;Change IY
	DW	'PC',CPC	;Change PC
	DW	'SP',CSP	;Change SP
	DW	'?',HELP	;Help output
	DB	0
*
* Help command
*
HELP	LD	HL,HTEXT	;Point to help text
help1	CALL	LFCR		;New line
	LD	B,25		;Margin for comments
help2	LD	A,(HL)		;Get data from table
	INC	HL		;Skip to next
	AND	A		;End of line?
	JR	Z,help4		;Yes, stop
	CP	'|'		;Special case?
	JR	Z,help3		;Yes, handle it
	CALL	PUTC		;Output character
	DEC	B		;Reduce count
	JR	help2		;Keep going
help3	CALL	SPACE		;Space over
	DJNZ	help3		;Do them all
	LD	A,'-'		;Separator
	CALL	PUTC		;output
	CALL	SPACE		;Space over
	JR	HELP2		;Keep outputing
help4	OR	(HL)		;More data?
	JR	NZ,help1	;Keep going
	RET
*
* Go (execute)
*
GO	LD	HL,(uPC)	;Get user PC
	LD	B,H		;Copy HIGH
	LD	C,L		;Copy LOW
	CALL	GETADRD		;Get address with default
	LD	(uPC),HL	;Save new user PC
	CALL	LFCR		;New line
	CALL	GOSTEP		;Step one instruction
* Implant breakpoints
	LD	HL,BRKTAB	;Point to breakpoint table
	LD	B,8		;Max number of breakpoints
imbrk1	LD	E,(HL)		;Get LOW address
	INC	HL		;Advance
	LD	D,(HL)		;Get HIGH address
	INC	HL		;Advance
	LD	A,D		;Get HIGH
	OR	L		;Test for breakpoint set
	JR	Z,imbrk2	;Not set
	LD	A,(DE)		;Get opcode
	LD	(HL),A		;Save in table
	LD	A,$FF		;Get breakpoint opcode (RST 7)
	LD	(DE),A		;Write to table
imbrk2	INC	HL		;Advance to next
	DJNZ	imbrk1		;Do them all
* Restore user registers and execute
	LD	IX,(uIX)	;Get IX
	LD	IY,(uIY)	;Get IY
	LD	HL,(uBC)	;Get BC
	LD	B,H		;Copy
	LD	C,L		;Copy
	LD	HL,(uDE)	;Get DE
	EX	DE,HL		;Copy
	LD	HL,(uAF)	;Get AF
	PUSH	HL		;Save
	POP	AF		;Copy
	LD	HL,(uSP)	;Get user SP
	LD	SP,HL		;Copy
	LD	HL,(uPC)	;Get user PC
	PUSH	HL		;Stack for return
	LD	HL,(uHL)	;Get user HL
	RET			;Jump to user program
*
* Dump memory in instruction format (disassembly)
*
DISCMD	CALL	GETRANG		;Get address
disc1	CALL	LFCR		;New line
	CALL	DISASM		;Perform disassembly
	CALL	CHLDE		;Are we at end?
	JR	C,disc1		;No, keep going
	JR	Z,disc1		;Do last address
	RET
*
* Dump memory in HEX format
*
DUMP	CALL	GETRANG		;Get address range
dump1	CALL	LFCR		;New line
	CALL	WRADDR		;Output address
	CALL	SPACE		;Space over
	LD	B,16		;Display 16 bytes
	PUSH	HL		;Save HL
dump2	CALL	SPACE		;Space over
	LD	A,(HL)		;Get data
	CALL	WRBYTE		;Display it
	INC	HL		;Advance
	LD	A,B		;Get copy
	DEC	A		;Adjust
	AND	%00000011	;At 4 byte interval?
	CALL	Z,SPACE		;Add extra space
	DEC	B		;Backup count
	JR	NZ,dump2	;Keep going
	POP	HL		;Restore register set
	CALL	SPACE		;Space over
	LD	B,16		;Display 16 bytes
dump3	LD	A,(HL)		;Get data
	CALL	WRPRINT		;Display if printable
	INC	HL		;Advance
	DEC	B		;Decrement count
	JR	NZ,dump3	;Do them all
	CALL	CHLDE		;Compre HL and DE
	JR	C,dump1		;Keep going
	JR	Z,dump1		;Do last address
	RET
* Compare HL and DE
CHLDE	LD	A,H		;Get HIGH HL
	CP	D		;Do compare
	RET	NZ		;Not same
	LD	A,L		;Get LOW HL
	CP	E		;Do compare
	RET
* Display character if printable
WRPRINT	CP	' '		;In range
	JR	C,wrpri1	;Too low
	CP	$7F		;In range?
	JP	C,PUTC		;Ok, write it
wrpri1	LD	A,'.'		;Translate to dot
	JP	PUTC		;Write character
*
* Input from a port
*
INPORT	CALL	GETHEX		;Get port number
	LD	C,A		;Copy to port select
	CALL	SPACE		;Space over
	IN	A,(C)		;Read port
	JP	WRBYTE		;Output
*
* Output to a port
*
OUTPORT	CALL	GETHEX		;Get port number
	LD	C,A		;Copy to port select
	CALL	SPACE		;Space over
	CALL	GETHEX		;Get data
	OUT	(C),A		;Write to port
	RET
*
* Single Step one instruction
*
STEP	LD	HL,(uPC)	;Get user PC
	LD	C,L		;Set C to copy of lower
	CALL	DISASM		;Display on console
	CALL	LFCR		;New line
	CALL	GOSTEP1		;Perform step
*
* Dump registers
*
RDUMP	LD	HL,RNTEXT	;Point to register text
	LD	DE,uAF		;Point to first register
rdump1	CALL	SPACE		;Space over
	CALL	WRSTR		;Write string
	LD	A,(DE)		;Get LOW value
	LD	C,A		;Save for later
	INC	DE		;Advance
	LD	A,(DE)		;Get HIGH value
	INC	DE		;Advance
	CALL	WRBYTE		;Write HIGH
	LD	A,C		;Get LOW
	CALL	WRBYTE		;Write LOW
	LD	A,(HL)		;Get flag byte
	AND	A		;At end?
	JR	NZ,rdump1	;Continue
	RET
* Text of register names (in order of register storage)
RNTEXT	STRZ	'AF='
	STRZ	'BC='
	STRZ	'DE='
	STRZ	'HL='
	STRZ	'IX='
	STRZ	'IY='
	STRZ	'PC='
	STRZ	'SP='
	DB	0		;End of list
CAF	LD	HL,uAF		;Point to register
	JR	CHREG		;Change it
CBC	LD	HL,uBC		;Point to register
	JR	CHREG		;Change it
CDE	LD	HL,uDE		;Point to register
	JR	CHREG		;Change it
CHL	LD	HL,uHL		;Point to register
	JR	CHREG		;Change it
CIX	LD	HL,uIX		;Point to register
	JR	CHREG		;Change it
CIY	LD	HL,uIY		;Point to register
	JR	CHREG		;Change it
CPC	LD	HL,uPC		;Point to register
	JR	CHREG		;Change it
CSP	LD	HL,uSP		;Point to register
*Change register pointed to by DE
CHREG	LD	D,H		;Copy HIGH
	LD	E,L		;Copy LOW
	LD	A,(HL)		;Get LOW
	INC	HL		;Advance
	LD	H,(HL)		;Get HIGH
	LD	L,A		;Copy LOW
	CALL	WRADDR		;Output contents
	LD	A,'-'		;Separator
	CALL	PUTC		;Write it
	CALL	GETADR		;Get address
	LD	A,L		;Get LOW
	LD	(DE),A		;Write it
	INC	DE		;Advance
	LD	A,H		;Get HIGH
	LD	(DE),A		;Write it
	RET
*
* Edit memory
*
EDIT	CALL	GETADR		;Get address (with default)
edit1	CALL	LFCR		;New line
	CALL	WRADDR		;Output address
edit2	CALL	SPACE		;Separator
	LD	A,(HL)		;Get address
	CALL	WRBYTE		;Output
	LD	A,'-'		;Get prompt
	CALL	PUTC		;Output
	CALL	GETHEXC		;Get HEX input
	JR	C,edit4		;Special case
	LD	(HL),A		;Write value
edit3	INC	HL		;Advance to next
	LD	A,L		;Get address
	AND	%00000111	;8 byte boundary?
	JR	Z,edit1		;New line
	JR	edit2		;Its OK
edit4	CP	' '		;Skip value
	JR	NZ,edit5	;No try next
	CALL	SPACE		;Align display
	JR	edit3		;And proceed
edit5	CP	$27		;Single quote?
	JR	NZ,edit7	;No, try next
edit6	CALL	TESTC		;Test for char
	AND	A		;Character ready?
	JR	Z,edit6		;No, wait
	LD	(HL),A		;Save it
	CALL	WRPRINT		;Echo it
	JR	edit3		;And advance
edit7	CP	$1B		;Exit?
	RET	Z		;Return
	CP	$0D		;Return?
	RET	Z		;Return
	CP	$08		;Backspace
	JP	NZ,ERROR	;Report error
	DEC	HL		;Backup
	JR	edit1		;re-prompt
*
* Fill memory
*
FILL	CALL	GETRANG		;Get range to fill
	CALL	SPACE		;Space over
	CALL	GETHEX		;Get value
	LD	C,A		;Save for later
fill1	LD	(HL),C		;Save value
	CALL	CHLDE		;Compare registers
	INC	HL		;Advance
	JR	C,fill1		;And continue
	RET
*
* Display breakpoints
*
BDUMP	LD	DE,BRKTAB	;Point to breakpoint table
	LD	C,0		;Max number of breakpoints
bdump1	CALL	WRMSG		;Output message
	STRZ	' B'		;Message
	LD	A,C		;Get number
	ADD	A,'0'		;Convert to ASCII
	CALL	PUTC		;Output
	LD	A,'='		;Separator
	CALL	PUTC		;Write it
	LD	A,(DE)		;Get LOW
	LD	L,A		;Save it
	INC	DE		;Advance
	LD	A,(DE)		;Get HIGH
	LD	H,A		;Save it
	INC	DE		;Skip
	INC	DE		;Skip opcode
	OR	L		;Set?
	JR	NZ,bdump2	;Yes, output value
	CALL	WRMSG		;Output message
	STRZ	'----'		;Message
	JR	bdump3
bdump2	CALL	WRADDR		;Output address
bdump3	INC	C		;Get address
	LD	A,C		;Get value
	CP	8		;In range
	JR	C,bdump1	; Do them all
	RET
*
* Set a breakpoint
*
SETBRK	CALL	GETC		;Get nibble
	SUB	'0'		;Convert from ASCII
	CP	8		;In range?
	JP	NC,ERROR	;No, abort
	LD	E,A		;Copy
	ADD	A,A		;x2
	ADD	A,E		;x3
	LD	D,=BRKTAB	;Get HIGH offset
	ADD	A,BRKTAB	;Offset to brktab
	LD	E,A		;Set LOW value
	JR	NC,setb1	;No carry
	INC	D		;Advance HIGH
setb1	CALL	SPACE		;Space over
	CALL	GETADR		;Get address
	EX	DE,HL		;Swap
	LD	(HL),E		;Set LOW
	INC	HL		;Advance
	LD	(HL),D		;Set HIGH
	RET
*
* Download from serial port
*
LOAD	LD	A,%00110000	;Upper case, clear stream
	LD	(IOCTL),A	;Set I/O control
load1	CALL	DLREC		;Load one record
	JP	NZ,ERROR	;Report errors
	JR	NC,load1	;Not end of file
	RET
*
* Download a record from the serial port
*
DLREC	CALL	GETC		;Read a character
	CP	':'		;Start of record?
	JR	Z,DLINT		;Download INTEL format
	CP	'S'		;Is it MOTOROLA?
	JR	NZ,DLREC	;No, keep looking
* Download a MOTOROLA HEX format record
DLMOT	CALL	GETC		;Get next character
	CP	'0'		;Header record?
	JR	Z,DLREC		;Yes, skip it
	CP	'9'		;End of file?
	JR	Z,DLEOF		;Yes, report EOF
	CP	'1'		;Type 1 (code) record
	JR	NZ,DLERR	;Report error
	CALL	GETHEX		;Get hex byte
	LD	C,A		;Start checksum
	SUB	3		;Convert for overhead
	LD	E,A		;Save data length
	CALL	GETHEX		;Get first byte of address
	LD	H,A		;Set HIGH address
	ADD	A,C		;Include in checksum
	LD	C,A		;And re-save
	CALL	GETHEX		;Get next byte of address
	LD	L,A		;Set LOW address
	ADD	A,C		;Include in checksum
	LD	C,A		;And re-save
DMOT1	CALL	GETHEX		;Get a byte of data
	LD	(HL),A		;Save in memory
	INC	HL		;Advance
	ADD	A,C		;Include in checksum
	LD	C,A		;And re-save
	DEC	E		;Reduce length
	JR	NZ,DMOT1	;Keep going
	CALL	GETHEX		;Get record checksum
	ADD	A,C		;Include calculated checksum
	INC	A		;Adjust for test
	AND	A		;Clear carry set Z if no error
	RET
* Download a record in INTEL hex format
DLINT	CALL	GETHEX		;Get length
	AND	A		;End of file?
	JR	Z,DLEOF		;Yes, handle it
	LD	C,A		;Begin Checksum
	LD	E,A		;Record length
	CALL	GETHEX		;Get HIGH address
	LD	H,A		;Set HIGH address
	ADD	A,C		;Include in checksum
	LD	C,A		;Re-save
	CALL	GETHEX		;Get LOW address
	LD	L,A		;Set LOW address
	ADD	A,C		;Include in checksum
	LD	C,A		;Re-save
	CALL	GETHEX		;Get type byte
	ADD	A,C		;Include in checksum
	LD	C,A		;Re-save
DLINT1	CALL	GETHEX		;Get data byte
	LD	(HL),A		;Save in memory
	INC	HL		;Advance to next
	ADD	A,C		;Include in checksum
	LD	C,A		;Resave checksum
	DEC	E		;Reduce count
	JR	NZ,DLINT1	;Do entire record
	CALL	GETHEX		;Get record checksum
	ADD	A,C		;Add to computed checksum
	AND	A		;Clear carry, set Z if no error
	RET
* End of file on download
DLEOF	SCF			;Set carry, EOF
	RET
* Invalid record type
DLERR	OR	$FF		;Clear C and Z
	RET
*
* Get byte into A
*
GETHEX	CALL	GETNIB		;Get nibble
	JP	C,ERROR		;Report error
geth1	RLCA			;Shift
	RLCA			;Over into
	RLCA			;High nibble
	RLCA			;Position
	LD	B,A		;Save for later
	CALL	GETNIB		;Get nibble
	JP	C,ERROR		;Report error
	OR	B		;Add in high
	RET
*
* Get a byte into A, allow different 1st char
*
GETHEXC	CALL	GETNIB		;Get nibble
	JR	NC,geth1	;All is OK
	RET
*
* Get nibble into A
*
GETNIB	CALL	GETC		;Get char
	CP	'0'		;In range
	RET	C		;Error
	SUB	'0'		;Convert number
	CP	$0A		;0-9?
	CCF			;Toggle 'C' state (1=error)
	RET	NC		;Yes, its OK
	SUB	7		;Convert alpha
	CP	$0A		;In range?
	RET	C		;Error
	CP	$10		;In range?
	CCF			;Toggle carry state
	RET
*
* Read character from the console
*
GETC	PUSH	BC		;Save for later
	LD	A,(IOCTL)	;Get I/O control byte
	LD	B,A		;Copy for later
getc1	CALL	TESTC		;Test for character
	AND	A		;Any data?
	JR	Z,getc1		;Keep trying
* Test for echo
	BIT	6,B		;Test bit flag
	JR	Z,getc2		;Do not echo
	CALL	PUTC		;Output
* Test for convert to upper case
getc2	BIT	5,B		;Test bit flags
	JR	Z,getc3		;Do not convert
	CP	'a'		;Need conversion?
	JR	C,getc3		;No, skip it
	AND	%01011111	;Convert to upper
getc3	POP	BC		;Restore
	RET
*
* Get address into H:L
*
GETADR	CALL	GETHEX		;Get HIGH
geta1	LD	H,A		;Save HIGH
	CALL	GETHEX		;Get LOW
	LD	L,A		;Save LOW
	RET
*
* Get range of address into HL:DE
*
GETRANG	LD	BC,0		;Get default
	CALL	GETADRD		;Get first
	EX	DE,HL		;Swap
	LD	A,','		;Separator
	CALL	PUTC		;Write it
	LD	BC,$FFFF	;Get default
	CALL	GETADRD		;Get address
	EX	DE,HL		;Swap
	RET
*
* Get address into H:L and allow extra char for default address
*
GETADRD	CALL	GETHEXC		;Get HIGH
	JR	NC,geta1	;Normal
	CP	' '		;Space?
	JP	NZ,ERROR	;Error
	LD	A,8		;Backspace
	CALL	PUTC		;Output
	LD	H,B		;Get HIGH
	LD	L,C		;Get LOW
*
* Write address (HL) to console in HEX
*
WRADDR	LD	A,H		;Get high
	CALL	WRBYTE		;Output
	LD	A,L		;Get LOW
*
* Write byte (A) to console in HEX
*
WRBYTE	PUSH	AF		;Save ACC
	RR	A		;Shift it
	RR	A		;Over one
	RR	A		;Nibble to
	RR	A		;High
	CALL	WRNIB		;Output high nibble
	POP	AF		;Restore ACC
*
* Write nibble (A) to console
*
WRNIB	PUSH	AF		;Save ACC
	AND	%00001111	;Mask high
	CP	$0A		;In range?
	JR	C,wrnib1	;Yes, its OK
	ADD	A,7		;Adjust
wrnib1	ADD	A,'0'		;Convert to printable
	CALL	PUTC		;Output
	POP	AF		;Restore
	RET
*
* Write Line-Feed, Carriage-Return to console
*
LFCR	CALL	TESTC		;Test for character
	CP	$1B		;Quit
	JP	Z,ENTMON	;Enter monitor
	CP	$0D		;Release output?
	JR	NZ,lfcr1	;No, try next
	LD	A,(IOCTL)	;Get I/O control byte
	AND	%01111111	;Clear pause bit
	LD	(IOCTL),A	;Resave
	JR	lfcr4		;Resume output
lfcr1	CP	' '		;Pause output
	JR	NZ,lfcr2	;No, try next
	LD	A,(IOCTL)	;Get I/O control byte
	XOR	%10000000	;Toggle pause bit
	JP	P,lfcr4		;Already set, allow 1 line
	LD	(IOCTL),A	;Resave control byte
lfcr2	LD	A,(IOCTL)	;Get I/O control bit
	AND	A		;Test pause bit
	JP	M,LFCR		;Paused - wait
lfcr4	LD	A,$0A		;Get LF
	CALL	PUTC		;Output it
	LD	A,$0D		;Get CR
	JP	PUTC		;Output & return
*
* Write a space to the console
*
SPACE	LD	A,' '		;Get space
	JP	PUTC		;Output
*
* Write message (PC) to the console
*
WRMSG	POP	HL		;Get pointer to message
	CALL	WRSTR		;Output the string
	JP	(HL)		;Execute at end
*
* Write string (HL) to the console
*
WRSTR	LD	A,(HL)		;Get character
	INC	HL		;Advance to next
	AND	A		;Last one?
	RET	Z		;Yes, quit
	CALL	PUTC		;Output
	JR	WRSTR		;Get next
*
* Disassemble instruction (HL) and display on screen
*
* Display address for disassembly
DISASM	LD	(TEMP),HL	;Save address
	CALL	WRADDR		;Output address
* Disassembly instruction into memory buffer
	PUSH	DE		;Save DE
	PUSH	BC		;Save BC
	CALL	disass		;Disassemble the code into buffer
* Display the instruction bytes in HEX
	EX	DE,HL		;DE = end address
	LD	HL,(TEMP)	;Get starting address
	LD	B,5		;Max spaces
dis1	CALL	SPACE		;Space over
	LD	A,(HL)		;Get data
	INC	HL		;Skip to next
	CALL	WRBYTE		;Output
	DEC	B		;Reduce count
	CALL	CHLDE		;Are we at end?
	JR	NZ,dis1		;No, keep going
dis2	CALL	SPACE		;Filler
	CALL	SPACE		;Filler
	CALL	SPACE		;Filler
	DJNZ	dis2		;Do them all
* Display instruction bytes as ASCII
	LD	HL,(TEMP)	;Get starting address
	LD	B,8		;Max spaces
dis3	LD	A,(HL)		;Get data
	INC	HL		;Advance to next
	CALL	WRPRINT		;Display
	DEC	B		;Reduce count
	CALL	CHLDE		;Are we at end?
	JR	NZ,dis3		;No, keep going
dis4	CALL	SPACE		;Filler
	DJNZ	dis4		;Do them all
* Display contents of disassembly buffer
	LD	IX,BUFFER	;Point to buffer
dis5	LD	A,(IX)		;Get data from memory
	AND	A		;End of list
	JR	Z,dis8		;Yes, stop
	INC	IX		;Advance
	CP	' '		;Special case?
	JR	Z,dis7		;Handle it
	CALL	PUTC		;Output
	INC	B		;Advance count
	JR	dis5		;And continue
dis7	CALL	SPACE		;Output space
	INC	B		;Advance count
	LD	A,B		;Get count
	AND	%00000111	;8 character tab
	JR	NZ,dis7		;Do all spaces
	JR	dis5		;Continue
dis8	POP	BC		;Restore BC
	POP	DE		;Restore DE
	RET
*
* Disassemble instruction (HL) and place in memory buffer (IX)
*
* Lookup opcode (HL) in table
disass	LD	A,(HL)		;Get opcode
	INC	HL		;Skip to next
	LD	DE,DTABCB	;Ready CB table
	CP	$CB		;CB prefix?
	JR	Z,disa1		;Yes
	LD	DE,DTABDD	;Ready DD table
	CP	$DD		;DD prefix?
	JR	Z,disa1		;Yes
	LD	DE,DTABED	;Ready ED table
	CP	$ED		;ED prefix?
	JR	Z,disa1		;Yes
	LD	DE,DTABFD	;Read FD prefix
	CP	$FD		;FD prefix?
	JR	Z,disa1		;Yes
	LD	DE,DTAB		;Switch to normal table
	DEC	HL		;Backup
disa1	LD	A,(HL)		;Get opcode
	INC	HL		;Advance to next
	LD	(TEMP1),A	;Save opcode for later
	LD	B,A		;Save opcode for later
* Lookup opcode (B) in table (DE)
	LD	A,(DE)		;Get mask
	INC	DE		;Advance to next
disa2	AND	B		;Get masked opcode
	LD	C,A		;Save for later
	LD	A,(DE)		;Get table opcode
	INC	DE		;Skip it
	CP	C		;Compare against masked opcode
	JR	Z,disa4		;We found it!
* This one isn't it, skip to the next one
disa3	LD	A,(DE)		;Get data from table
	INC	DE		;Skip to next
	AND	A		;End of entry?
	JR	NZ,disa3	;Keep looking
	LD	A,(DE)		;Get next mask
	INC	DE		;Skip it
	AND	A		;End of table?
	JR	NZ,disa2	;Keep looking
* We found opcode, handle it
disa4	LD	IX,BUFFER	;Point to output buffer
* Move data from disassembly table to output buffer with translations
disa5	LD	A,(DE)		;Get char from table
	AND	A		;End of table?
	JP	Z,disa900	;We are finished
	INC	DE		;Advance to next
	JP	M,disa100	;Special substuted symbol
* Test for 's' source register
	CP	's'		;Source register
	JR	NZ,disa7	;No, try next
	LD	A,(TEMP1)	;Get opcode back
disa6	AND	%00000111	;Allow only 8 entries
	LD	BC,REGTAB	;Point to table
disa61	PUSH	HL		;Save HL
	LD	L,A		;Get ID number
	LD	H,0		;Zero high
	ADD	HL,HL		;x2
	ADD	HL,HL		;x4
	ADD	HL,BC		;Offset to table
	LD	C,4		;Max four chars
disa62	LD	A,(HL)		;Get char
	AND	A		;Premature end?
	JR	Z,disa63	;Exit
	INC	HL		;Advance
	LD	(IX),A		;Write to buffer
	INC	IX		;Advance buffer
	DEC	C		;Reduce count
	JR	NZ,disa62	;Do them all
disa63	POP	HL		;Restore HL
	JR	disa5		;Do next entry
* Test for 'd' destination register
disa7	CP	'd'		;Destination register?
	JR	NZ,disa8	;No, try next
	LD	A,(TEMP1)	;Get opcode back
	RRA			;Shift
	RRA			;Over into
	RRA			;Source position
	JR	disa6		;And output
* Test for 'p' register pair
disa8	CP	'p'		;Register pair
	JR	NZ,disa9	;No, try next
	LD	BC,RPTAB	;Point to table
disa81	LD	A,(TEMP1)	;Get opcode back
	RRA			;Shift
	RRA			;Over into
	RRA			;Low bits of
	RRA			;Acc
	AND	%00000011	;Mask off
	JR	disa61		;Output and proceed
* Test for 'b', byte operand
disa9	CP	'b'		;Byte operand?
	JR	NZ,disa10	;No, try next
	LD	A,(HL)		;Get data from memory
	INC	HL		;Advance
disa91	CALL	IXBYTE		;Write it
	JR	disa5		;And proceed
* Test for 'w', word operand
disa10	CP	'w'		;Word operand
	JR	NZ,disa11	;No, try next
	LD	B,(HL)		;Get low
	INC	HL		;Advanve
	LD	A,(HL)		;Get HIGH
	INC	HL		;Advanve
	CALL	IXBYTE		;output
	LD	A,B		;Get LOW
	CALL	IXBYTE		;Output
	JR	disa5		;And proceed
* Test for 'x' register pair IX=HL
disa11	CP	'x'		;IX pair?
	JR	NZ,disa12	;No, try next
	LD	BC,RPTABX	;Point to special table
	JR	disa81		;And process
* Test for 'y' register pair IY=HL
disa12	CP	'y'		;IY pair?
	JR	NZ,disa13	;No, try next
	LD	BC,RPTABY	;Point to special table
	JR	disa81		;And process
* Test for 'c' condition code specification
disa13	CP	'c'		;Condition code
	JR	NZ,disa14	;No, try next
	LD	A,(TEMP1)	;Get opcode
	RRA			;Shift
	RRA			;Over to
	RRA			;Zero base
	AND	%00000111	;Mask unused bit
	LD	BC,CCTAB	;Point to table
	JR	disa61		;And process
* Test for 'r' relative address
disa14	CP	'r'		;Relative address?
	JR	NZ,disa15	;No, try next
	LD	A,(HL)		;Get value
	INC	HL		;Skip operand
	LD	B,0		;Assume zero carry
	AND	A		;Test for negative
	JP	P,disa14a	;Assumption correct
	DEC	B		;Adjust to negative
disa14a	ADD	A,L		;Compute lower
	LD	C,A		;Save for later
	LD	A,H		;Get HIGH
	ADC	A,B		;Compute high
	CALL	IXBYTE		;Write it
	LD	A,C		;Get LOW
	CALL	IXBYTE		;Write it
	JP	disa5		;And proceed
* Test for 'z', special double prefix
disa15	CP	'z'		;Special mode?
	JR	NZ,disa16	;No, try next
	LD	A,(HL)		;Get operand 'd' byte
	LD	(TEMP2),A	;Save for later
	INC	HL		;Advance
	LD	A,(HL)		;Get post byte
	LD	(TEMP1),A	;Save for later
	LD	B,A		;Save for later
	LD	A,(DE)		;Get Mask
	AND	B		;Get masked opcode
	LD	C,A		;Save for later
	INC	DE		;Advance to opcode
	LD	A,(DE)		;Get required opcode
	INC	DE		;Skip to next
	CP	C		;Does it match?
	JR	Z,disa15a	;Yes, we have it
	DEC	HL		;No fix error
	LD	B,$CB		;Get opcode
	JP	disa3		;Keep going
disa15a	INC	HL		;Advance to next
	JP	disa5		;And proceed
* Test for 'v', special post d byte
disa16	CP	'v'		;Specal post dbyte
	JR	NZ,disa17	;No, try next
	LD	A,(TEMP2)	;Get postbyte
	JR	disa91		;Output & proceed
* Test for 'n' numeric value from opcode
disa17	CP	'n'		;Numeric value
	JR	NZ,disa18	;No, try next
	LD	A,(TEMP1)	;Get opcode back
	RRA
	RRA
	RRA
	AND	%00000111	;Save only number
	ADD	A,'0'		;Convert to ASCII
* No special operation
disa18	LD	(IX),A		;Copy to buffer
	INC	IX		;Advance
	JP	disa5		;And continue
* Write special opcode
disa100	AND	%01111111	;Clear high bit
	LD	BC,TABTAB	;Point to table
	JP	disa61		;Output and proceed
* End of disassembly
disa900	LD	(IX),0		;Zero terminate
	RET
*
* Write byte (A) to (IX)
*
IXBYTE	PUSH	AF		;Save ACC
	RR	A		;Shift it
	RR	A		;Over one
	RR	A		;Nibble to
	RR	A		;High
	CALL	IXNIB		;Output high nibble
	POP	AF		;Restore ACC
IXNIB	PUSH	AF		;Save ACC
	AND	%00001111	;Mask high
	CP	$0A		;In range?
	JR	C,ixnib1	;Yes, its OK
	ADD	A,7		;Adjust
ixnib1	ADD	A,'0'		;Convert to printable
	LD	(IX),A		;Write to string
	INC	IX		;Advance
	POP	AF		;Restore
	RET
*
*---------------------------------
* Single step one instruction (HL)
*---------------------------------
*
GOSTEP	LD	HL,(uPC)	;Get user PC
	PUSH	HL		;Save for later
	CALL	DISASS		;Disassemble (no display)
	POP	BC		;C = copy of lower
GOSTEP1	LD	A,L		;Get low address
	SUB	C		;Compute length
	LD	C,A		;Set LOW count value
	LD	B,0		;Zero high
* Copy code into buffer for execution (if necessary)
	LD	HL,(uPC)	;Point to code address
	LD	DE,BUFFER	;Point to buffer
	LDIR			;Copy instruction into buffer
	LD	(uPC),HL	;Update program counter
	EX	DE,HL		;Hl = buffer address
	LD	(HL),$C3	;Jump instruction
	INC	HL		;Advance
	LD	(HL),STEPRET	;Write low address
	INC	HL		;Advance
	LD	(HL),=STEPRET	;Write high address
* Test instruction to see if it affects program control
	LD	A,(BUFFER)	;Get opcode
	LD	C,A		;C = opcode
	LD	HL,EFTAB	;Point to execution flow table
	LD	B,(EFEND-EFTAB)/4;Get size of table
step1	LD	A,(HL)		;Get mask
	INC	HL		;Advance
	AND	C		;Get masked opcode
	CP	(HL)		;Compare against opcode
	INC	HL		;Skip to next
	JR	Z,step3		;Execute
	INC	HL		;Skip LOW address
	INC	HL		;Skip HIGH address
	DJNZ	step1		;Keep looking
* Restore user registers and execute instruction in buffer
step2	LD	HL,0		;Get zero
	ADD	HL,SP		;Get stack
	LD	(TEMP1),HL	;Save stack
	LD	IX,(uIX)	;Get IX
	LD	IY,(uIY)	;Get IY
	LD	HL,(uBC)	;Get BC
	LD	B,H		;Copy
	LD	C,L		;Copy
	LD	HL,(uDE)	;Get DE
	EX	DE,HL		;Copy
	LD	HL,(uAF)	;Get AF
	PUSH	HL		;Save
	POP	AF		;Copy
	LD	HL,(uSP)	;Get user SP
	LD	SP,HL		;Copy
	LD	HL,(uHL)	;Get user HL
	JP	BUFFER		;Execute user program
* Execute handler for special instructions requiring interpretation
step3	LD	A,(HL)		;Get LOW address
	INC	HL		;Skip to next
	LD	H,(HL)		;Get HIGH address
	LD	L,A		;Set LOW address
	JP	(HL)		;Execute handler
* Return from single step. Like breakpoint, but no PC
STEPRET	LD	(uHL),HL	;Save HL
	PUSH	AF		;Get AF
	POP	HL		;Copy
	LD	(uAF),HL	;Save AF
	LD	HL,0		;Get 0
	ADD	HL,SP		;Get SP
	LD	(uSP),HL	;Save SP
	EX	DE,HL		;Get DE
	LD	(uDE),HL	;Save DE
	LD	H,B		;Get B
	LD	L,C		;Get C
	LD	(uBC),HL	;Save BC
	LD	(uIX),IX	;Save IX
	LD	(uIY),IY	;Save IY
	LD	HL,(TEMP1)	;Get our stack
	LD	SP,HL		;Set out stack
	RET
*
* DD prefix's
*
EXDDP	LD	A,(BUFFER+1)	;Get opcode
	CP	$E9		;JP (IX)?
	JR	NZ,step2	;No, execute
	LD	HL,(uIX)	;Get user IX
	JR	GOHL		;And execute
*
* FD prefix's
*
EXFDP	LD	A,(BUFFER+1)	;Get opcode
	CP	$E9		;JP (IY)?
	JR	NZ,step2	;No, execute
	LD	HL,(uIY)	;Get user IY
	JR	GOHL		;And proceed
*
* Restart instruction
*
EXRST	LD	A,C		;Get opcode
	AND	%00111000	;Save number*8
	LD	L,A		;Set LOW
	LD	H,0		;Set high
	LD	(uPC),HL	;Set new address
	RET
*
* Jump indirect through HL
*
EXJPHL	LD	HL,(uHL);	;Get HL register
	JR	GOHL		;Set new address
*
* Conditional JR's
*
EXJRC	LD	C,%00011000	;Get 'C' condition
	JR	EXJPC		;Execute conditional
EXJRNC	LD	C,%00010000	;Get 'NC' condition
	JR	EXJPC		;Execute conditional
EXJRZ	LD	C,%00001000	;Get 'Z' conditional
	JR	EXJPC		;Execute conditional
EXJRNZ	LD	C,%00000000	;Get 'NZ' conditoinal
*
* Jump absolute conditional
*
EXJPC	CALL	TESTCC		;Test condition code
	JR	NZ,EXSKP	;Not taken
*
* JP instruction
*
EXJP	LD	HL,(BUFFER+1)	;Get operand
	JR	GOHL		;Execute
*
* DJNZ instruction
*
EXDJNZ	LD	A,(uBC+1)	;Get 'B' value
	DEC	A		;Adjust
	LD	(uBC+1),A	;Resave
	JR	Z,EXSKP		;Skip if zero
*
* JR instruction
*
EXJR	LD	A,(BUFFER+1)	;Get offset
	LD	C,A		;Save it
	LD	B,0		;Assume positive
	AND	A		;Is it negative
	JP	P,exjr1		;No, assumption correct
	DEC	B		;Sign extend
exjr1	LD	HL,(uPC)	;Get user PC
	ADD	HL,BC		;Adjust for offset
	JR	GOHL		;Set new address
*
* Conditional CALL
*
EXCALLC	CALL	TESTCC		;Test condition codes
	JR	NZ,EXSKP	;Not taken
*
* CALL instruction
*
EXCALL	LD	HL,(BUFFER+1)	;Get operand
* Stack PC and reset to HL
GOHLS	EX	DE,HL		;Free HL
	LD	HL,(uSP)	;Get user SP
	DEC	HL		;Backup stack
	LD	A,(uPC+1)	;Get HIGH pc
	LD	(HL),A		;Stack it
	DEC	HL		;Backup stack
	LD	A,(uPC)		;Get LOW pc
	LD	(HL),A		;Stack it
	LD	(uSP),HL	;set HL
	EX	DE,HL		;Get address back
GOHL	LD	(uPC),HL	;Set new address
EXSKP	RET
*
* Conditional return
*
EXRETC	CALL	TESTCC		;Test condition codes
	JR	NZ,EXSKP	;Not taken
*
* Return instruction
*
EXRET	LD	HL,(uSP)	;Get user SP
	LD	A,(HL)		;Get LOW address
	LD	(uPC),A		;Set it
	INC	HL		;Advance
	LD	A,(HL)		;Get HIGH address
	LD	(uPC+1),A	;Set it
	INC	HL		;Advance
	LD	(uSP),HL	;Save new SP
	RET
*
* Test condition code (Opcode in C)
*
TESTCC	LD	A,C		;Get opcode
	AND	%00111000	;Save only condition code
	OR	%11000010	;Convert into 'JP C'
	LD	(BUFFER+4),A	;Point to buffer
	LD	HL,BUFFER+8	;Skip INC
	LD	(BUFFER+5),HL	;Set offset
	LD	HL,$C93C	;'INC A' + 'RET'
	LD	(BUFFER+7),HL	;Set it
	LD	HL,(uAF)	;Get A and flags
	LD	H,0		;Zero 'A'
	PUSH	HL		;Stack it
	POP	AF		;Set A and F
	CALL	BUFFER+4	;Test code
	AND	A		;Zero means jump taken
	RET
*
* ---- Disassembly tables ----
*
* Register name tables
REGTAB	DB	'B',0,0,0
	DB	'C',0,0,0
	DB	'D',0,0,0
	DB	'E',0,0,0
	DB	'H',0,0,0
	DB	'L',0,0,0
	DB	'(','H','L',')'
	DB	'A',0,0,0
* Register pair name table
RPTAB	DB	'B','C',0,0
	DB	'D','E',0,0
	DB	'H','L',0,0
	DB	'S','P',0,0
RPTABX	DB	'B','C',0,0
	DB	'D','E',0,0
	DB	'I','X',0,0
	DB	'S','P',0,0
RPTABY	DB	'B','C',0,0
	DB	'D','E',0,0
	DB	'I','Y',0,0
	DB	'S','P',0,0
* Condition code table
CCTAB	DB	'N','Z',0,0
	DB	'Z',0,0,0
	DB	'N','C',0,0
	DB	'C',0,0,0
	DB	'P','O',0,0
	DB	'P','E',0,0
	DB	'P',0,0,0
	DB	'M',0,0,0
* Test abbreviations table
TABTAB	EQU	*
xLD	EQU	$80
	DB	'L','D',' ',0
xBC	EQU	$81
	DB	'B','C',0,0
xDE	EQU	$82
	DB	'D','E',0,0
xHL	EQU	$83
	DB	'H','L',0,0
xIX	EQU	$84
	DB	'I','X',0,0
xIY	EQU	$85
	DB	'I','Y',0,0
xBCI	EQU	$86
	DB	'(','B','C',')'
xDEI	EQU	$87
	DB	'(','D','E',')'
xHLI	EQU	$88
	DB	'(','H','L',')'
xIXI	EQU	$89
	DB	'(','I','X','+'
xIYI	EQU	$8A
	DB	'(','I','Y','+'
xACM	EQU	$8B
	DB	'A',',',0,0
xCMA	EQU	$8C
	DB	',','A',0,0
xSP	EQU	$8D
	DB	'S','P',0,0
xPUSH	EQU	$8E
	DB	'P','U','S','H'
xPOP	EQU	$8F
	DB	'P','O','P',' '
xAF	EQU	$90
	DB	'A','F',0,0
xEX	EQU	$91
	DB	'E','X',0,0
xLDx	EQU	$92
	DB	'L','D',0,0
xCP	EQU	$93
	DB	'C','P',0,0
xADD	EQU	$94
	DB	'A','D','D',' '
xADC	EQU	$95
	DB	'A','D','C',' '
xSUB	EQU	$96
	DB	'S','U','B',' '
xSBC	EQU	$97
	DB	'S','B','C',' '
xAND	EQU	$98
	DB	'A','N','D',' '
xOR	EQU	$99
	DB	'O','R',' ',0
xXOR	EQU	$9A
	DB	'X','O','R',' '
xINC	EQU	$9B
	DB	'I','N','C',' '
xDEC	EQU	$9C
	DB	'D','E','C',' '
xRL	EQU	$9D
	DB	'R','L',0,0
xRR	EQU	$9E
	DB	'R','R',0,0
xJP	EQU	$9F
	DB	'J','P',' ',0
xJR	EQU	$A0
	DB	'J','R',' ',0
xCALL	EQU	$A1
	DB	'C','A','L','L'
xRET	EQU	$A2
	DB	'R','E','T',0
xIN	EQU	$A3
	DB	'I','N',0,0
xOUT	EQU	$A4
	DB	'O','U','T',0
xBIT	EQU	$A5
	DB	'B','I','T',' '
xSET	EQU	$A6
	DB	'S','E','T',' '
xRES	EQU	$A7
	DB	'R','E','S',' '
*
* ---- Opcode Disassembly table ----
* d = reg from bits 00111000 of opcode
* s = reg from bits 00000111 of opcode
* p = reg pair1 from bits 00110000 of opcode
* x = reg pair2 with IX instead of HL
* y = reg pair3 with IY instead of HL
* b = byte value from next memory location
* w = word value from next memory location
* c = conditional code from bite 00111000 of opcode
* r = relative address from next memory location
* n = numeric value from bite 00111000 of opcode
* z = special double prefix opcode
* v = special 'd' value saved from 'z'
*
DTAB	DB	$FF,$76,'H','A','L','T',0
	DB	$C0,$40,xLD,'d',',','s',0
	DB	$C7,$06,xLD,'d',',','b',0
	DB	$FF,$0A,xLD,xACM,xBCI,0
	DB	$FF,$1A,xLD,xACM,xDEI,0
	DB	$FF,$3A,xLD,xACM,'(','w',')',0
	DB	$FF,$02,xLD,xBCI,xCMA,0
	DB	$FF,$12,xLD,xDEI,xCMA,0
	DB	$CF,$01,xLD,'p',',','w',0
	DB	$FF,$32,xLD,'(','w',')',xCMA,0
	DB	$FF,$2A,xLD,xHL,',','(','w',')',0
	DB	$FF,$22,xLD,'(','w',')',',',xHL,0
	DB	$FF,$F9,xLD,xSP,',',xHL,0
	DB	$FF,$F5,xPUSH,' ',xAF,0
	DB	$CF,$C5,xPUSH,' ','p',0
	DB	$FF,$F1,xPOP,xAF,0
	DB	$CF,$C1,xPOP,'p',0
	DB	$FF,$EB,xEX,' ',xDE,',',xHL,0
	DB	$FF,$08,xEX,' ',xAF,',',xAF,$27,0
	DB	$FF,$D9,xEX,'X',0
	DB	$FF,$E3,xEX,' ','(',xSP,')',',',xHL,0
	DB	$F8,$80,xADD,xACM,'s',0
	DB	$FF,$C6,xADD,xACM,'b',0
	DB	$F8,$88,xADC,xACM,'s',0
	DB	$FF,$CE,xADC,xACM,'b',0
	DB	$F8,$90,xSUB,xACM,'s',0
	DB	$FF,$D6,xSUB,xACM,'b',0
	DB	$F8,$98,xSBC,xACM,'s',0
	DB	$FF,$DE,xSBC,xACM,'b',0
	DB	$F8,$A0,xAND,xACM,'s',0
	DB	$FF,$E6,xAND,xACM,'b',0
	DB	$F8,$A8,xXOR,xACM,'s',0
	DB	$FF,$EE,xXOR,xACM,'b',0
	DB	$F8,$B0,xOR,xACM,'s',0
	DB	$FF,$F6,xOR,xACM,'b',0
	DB	$F8,$B8,xCP,' ',xACM,'s',0
	DB	$FF,$FE,xCP,' ',xACM,'b',0
	DB	$C7,$04,xINC,'d',0
	DB	$C7,$05,xDEC,'d',0
	DB	$CF,$09,xADD,xHL,',','p',0
	DB	$FF,$27,'D','A','A',0
	DB	$FF,$2F,xCP,'L',0
	DB	$FF,$3F,'C','C','F',0
	DB	$FF,$37,'S','C','F',0
	DB	$FF,$00,'N','O','P',0
	DB	$FF,$F3,'D','I',0
	DB	$FF,$FB,'E','I',0
	DB	$CF,$03,xINC,'p',0
	DB	$CF,$0B,xDEC,'p',0
	DB	$FF,$07,xRL,'C','A',0
	DB	$FF,$17,xRL,'A',0
	DB	$FF,$0F,xRR,'C','A',0
	DB	$FF,$1F,xRR,'A',0
	DB	$FF,$C3,xJP,'w',0
	DB	$C7,$C2,xJP,'c',',','w',0
	DB	$FF,$18,xJR,'r',0
	DB	$FF,$38,xJR,'C',',','r',0
	DB	$FF,$30,xJR,'N','C',',','r',0
	DB	$FF,$28,xJR,'Z',',','r',0
	DB	$FF,$20,xJR,'N','Z',',','r',0
	DB	$FF,$E9,xJP,xHLI,0
	DB	$FF,$10,'D','J','N','Z',' ','r',0
	DB	$FF,$CD,xCALL,' ','w',0
	DB	$C7,$C4,xCALL,' ','c',',','w',0
	DB	$FF,$C9,xRET,0
	DB	$C7,$C0,xRET,' ','c',0
	DB	$C7,$C7,'R','S','T',' ','n',0
	DB	$FF,$DB,xIN,' ',xACM,'(','b',')',0
	DB	$FF,$D3,xOUT,' ','(','b',')',xCMA,0
	DB	0,'?',0
* -- CB prefix opcode table
DTABCB	DB	$F8,$00,xRL,'C',' ','s',0
	DB	$F8,$10,xRL,' ','s',0
	DB	$F8,$08,xRR,'C',' ','s',0
	DB	$F8,$18,xRR,' ','s',0
	DB	$F8,$20,'S','L','A',' ','s',0
	DB	$F8,$28,'S','R','A',' ','s',0
	DB	$F8,$38,'S','R','L',' ','s',0
	DB	$C0,$40,xBIT,'n',',','s',0
	DB	$C0,$C0,xSET,'n',',','s',0
	DB	$C0,$80,xRES,'n',',','s',0
	DB	0,'?',0
* -- DD prefix opcode table
DTABDD	DB	$C7,$46,xLD,'d',',',xIXI,'b',')',0
	DB	$F8,$70,xLD,xIXI,'b',')',',','s',0
	DB	$FF,$36,xLD,xIXI,'b',')',',','b',0
	DB	$FF,$21,xLD,xIX,',','w',0
	DB	$FF,$2A,xLD,xIX,',','(','w',')',0
	DB	$FF,$22,xLD,'(','w',')',',',xIX,0
	DB	$FF,$F9,xLD,xSP,',',xIX,0
	DB	$FF,$E5,xPUSH,' ',xIX,0
	DB	$FF,$E1,xPOP,xIX,0
	DB	$FF,$E3,xEX,' ','(',xSP,')',',',xIX,0
	DB	$FF,$86,xADD,xACM,xIXI,'b',')',0
	DB	$FF,$8E,xADC,xACM,xIXI,'b',')',0
	DB	$FF,$96,xSUB,xACM,xIXI,'b',')',0
	DB	$FF,$9E,xSBC,xACM,xIXI,'b',')',0
	DB	$FF,$A6,xAND,xACM,xIXI,'b',')',0
	DB	$FF,$AE,xXOR,xACM,xIXI,'b',')',0
	DB	$FF,$B6,xOR,xACM,xIXI,'b',')',0
	DB	$FF,$BE,xCP,' ',xACM,xIXI,'b',')',0
	DB	$FF,$34,xINC,xIXI,'b',')',0
	DB	$FF,$35,xDEC,xIXI,'b',')',0
	DB	$CF,$09,xADD,xIX,',','x',0
	DB	$FF,$23,xINC,xIX,0
	DB	$FF,$2B,xDEC,xIX,0
	DB	$FF,$E9,xJP,xIXI,0
	DB	$FF,$CB,'z',$FF,$06,xRL,'C',' ',xIXI,'v',')',0
	DB	$FF,$CB,'z',$FF,$16,xRR,'C',' ',xIXI,'v',')',0
	DB	$FF,$CB,'z',$C7,$46,xBIT,'n',',',xIXI,'v',')',0
	DB	$FF,$CB,'z',$C7,$C6,xSET,'n',',',xIXI,'v',')',0
	DB	$FF,$CB,'z',$C7,$86,xRES,'n',',',xIXI,'v',')',0
	DB	0,'?',0
* -- FD prefix opcode table
DTABFD	DB	$C7,$46,xLD,'d',',',xIYI,'b',')',0
	DB	$F8,$70,xLD,xIYI,'b',')',',','s',0
	DB	$FF,$36,xLD,xIYI,'b',')',',','b',0
	DB	$FF,$21,xLD,xIY,',','w',0
	DB	$FF,$2A,xLD,xIY,',','(','w',')',0
	DB	$FF,$22,xLD,'(','w',')',',',xIY,0
	DB	$FF,$F9,xLD,xSP,',',xIY,0
	DB	$FF,$E5,xPUSH,' ',xIY,0
	DB	$FF,$E1,xPOP,xIY,0
	DB	$FF,$E3,xEX,' ','(',xSP,')',',',xIY,0
	DB	$FF,$86,xADD,xACM,xIYI,'b',')',0
	DB	$FF,$8E,xADC,xACM,xIYI,'b',')',0
	DB	$FF,$96,xSUB,xACM,xIYI,'b',')',0
	DB	$FF,$9E,xSBC,xACM,xIYI,'b',')',0
	DB	$FF,$A6,xAND,xACM,xIYI,'b',')',0
	DB	$FF,$AE,xXOR,xACM,xIYI,'b',')',0
	DB	$FF,$B6,xOR,xACM,xIYI,'b',')',0
	DB	$FF,$BE,xCP,' ',xACM,xIYI,'b',')',0
	DB	$FF,$34,xINC,xIYI,'b',')',0
	DB	$FF,$35,xDEC,xIYI,'b',')',0
	DB	$CF,$09,xADD,xIY,',','y',0
	DB	$FF,$23,xINC,xIY,0
	DB	$FF,$2B,xDEC,xIY,0
	DB	$FF,$E9,xJP,xIYI,0
	DB	$FF,$CB,'z',$FF,$06,xRL,'C',' ',xIYI,'v',')',0
	DB	$FF,$CB,'z',$FF,$16,xRR,'C',' ',xIYI,'v',')',0
	DB	$FF,$CB,'z',$C7,$46,xBIT,'n',',',xIYI,'v',')',0
	DB	$FF,$CB,'z',$C7,$C6,xSET,'n',',',xIYI,'v',')',0
	DB	$FF,$CB,'z',$C7,$86,xRES,'n',',',xIYI,'v',')',0
	DB	0,'?',0
* -- ED prefix opcode table
DTABED	DB	$FF,$57,xLD,xACM,'I',0
	DB	$FF,$5F,xLD,xACM,'R',0
	DB	$FF,$47,xLD,'I',xCMA,0
	DB	$FF,$4F,xLD,'R',xCMA,0
	DB	$CF,$4B,xLD,'p','(','w',')',0
	DB	$FF,$A0,xLDx,'I',0
	DB	$FF,$B0,xLDx,'I','R',0
	DB	$FF,$A8,xLDx,'D',0
	DB	$FF,$B8,xLDx,'D','R',0
	DB	$FF,$A1,xCP,'I',0
	DB	$FF,$B1,xCP,'I','R',0
	DB	$FF,$A9,xCP,'D',0
	DB	$FF,$B9,xCP,'D','R',0
	DB	$FF,$44,'N','E','G',0
	DB	$FF,$46,'I','M',' ','0',0
	DB	$FF,$56,'I','M',' ','1',0
	DB	$FF,$5E,'I','M',' ','2',0
	DB	$CF,$4A,xADC,xHL,',','p',0
	DB	$CF,$42,xSBC,xHL,',','p',0
	DB	$FF,$6F,xRL,'D',0
	DB	$FF,$67,xRR,'D',0
	DB	$FF,$4D,xRET,'I',0
	DB	$FF,$45,xRET,'N',0
	DB	$C7,$40,xIN,' ','d',',','(','C',')',0
	DB	$FF,$A2,xIN,'I',0
	DB	$FF,$B2,xIN,'I','R',0
	DB	$FF,$AA,xIN,'D',0
	DB	$FF,$BA,xIN,'D','R',0
	DB	$C7,$41,xOUT,' ','(','C',')',',','d',0
	DB	$FF,$A3,xOUT,'I',0
	DB	$FF,$B3,'O','T','I','R',0
	DB	$FF,$AB,xOUT,'D',0
	DB	$FF,$BB,'O','T','D','R',0
	DB	0,'?',0
*
* Table of execution flow affecting opcodes and handlers
*
EFTAB	DW	$C3FF,EXJP	;JP
	DW	$C2C7,EXJPC	;JP C
	DW	$18FF,EXJR	;JR
	DW	$E9FF,EXJPHL	;JP (HL)
	DW	$CDFF,EXCALL	;CALL
	DW	$C4C7,EXCALLC	;CALL C
	DW	$C9FF,EXRET	;RET
	DW	$C0C7,EXRETC	;RET C
	DW	$10FF,EXDJNZ	;DJNZ
	DW	$38FF,EXJRC	;JR C
	DW	$30FF,EXJRNC	;JR NC
	DW	$28FF,EXJRZ	;JR Z
	DW	$20FF,EXJRNZ	;JR NZ
	DW	$C7C7,EXRST	;RST
	DW	$DDFF,EXDDP	;DD prefix: JP (IX)
	DW	$FEFF,EXFDP	;FD prefix: JP (IY)
EFEND	EQU	*
*
* Help text
*
HTEXT	STR	'MONZ80 Commands:'
	DB	$0A,0
	STRZ	'BR 0-7 addr|Set breakpoint (0000 clears)'
	STRZ	'DB|Display breakpoints'
	STRZ	'DI from,[to]|Disassemble memory'
	STRZ	'DM from,[to]|Dump memory (HEX/ASCII)'
	STRZ	'DR|Display Z80 registers'
	STRZ	'E addr|Edit memory'
	STRZ	'F from,to value|Fill memory'
	STRZ	'G [addr]|Go (execute)'
	STRZ	'I port|Read/Display I/O port'
	STRZ	'L|Load .HEX file'
	STRZ	'O port value|Write I/O port'
	STRZ	'T|Trace (single-step)'
	STRZ	'AF,BC,DE,HL'
	STRZ	'IX,IY,SP,PC value|Set register value'
	DB	0
*
*------------ LOW LEVEL I/O FUNCTIONS -----------
* Modified for 68B50 UART at I/O port 80h (status/control) and 81h (data)
*
* Initialize I/O subsystem
* 
IOINIT	LD	A,3		; Insure not setup mode
    OUT	(80h),A		; Write once
    OUT (80h),A		; write twice 
    LD  A,%01110111	; Setup mode
    OUT (80h),A		; write it
    LD	A,$15		; 8 data, 1 stop, no parity, /16 clock, RTS high, ints off
    OUT	(80h),A		; Write it
    RET
*
* Test for character from the console
*
TESTC	IN	A,(80h)	;Get status
    AND	1		;RX ready  
    RET	Z		;No, return zero
    IN	A,(81h)		;Read data
    RET
*
* Write character to console
*
PUTC	PUSH	AF		;Save PSW
putc1	IN	A,(80h)		;Read status
    AND 2		;TX ready
    JR	Z,putc1		;Not ready
    POP	AF		;Restore
    OUT	(81h),A		;Write to data port
    RET