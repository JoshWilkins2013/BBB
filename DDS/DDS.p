// Control output FTW and PCW of the AD9912 DDS
// Author: Josh Wilkins

/////////////////////////////////////////////////////////////////
//----------------------- Program Setup -----------------------//
/////////////////////////////////////////////////////////////////

#define rFTW1		r11
#define rFTW2		r12
#define rFTW3		r13
#define rFTW4		r14
#define rFTW5		r15
#define rFTW6		r16

#define rPCW1		r17
#define rPCW2		r18

.setcallreg  r29.w2		// set a non-default CALL/RET register
.origin 0				// start of program in PRU memory
.entrypoint START		// program entry point (for a debugger)

#include "../SPI.hp"

#define PRU0_R31_VEC_VALID 32	// Allows notification of program completion
#define EVTOUT_0	3	// The event number that is sent back


////////////////////////////////////////////////////////////////
//-------------------- Writing Registers ---------------------//
////////////////////////////////////////////////////////////////

START:
	LBCO r0, C4, 4, 4
	CLR r0, r0, 4
	SBCO r0, C4, 4, 4

GETFTW:
	MOV r1, 0x00000000
	LBBO rFTW1, r1, 0, 2
	LBBO rFTW2, r1, 4, 2
	LBBO rFTW3, r1, 8, 2
	LBBO rFTW4, r1, 12, 2
	LBBO rFTW5, r1, 16, 2
	LBBO rFTW6, r1, 20, 2

GETPCW:
	LBBO rPCW1, r1, 24, 2
	LBBO rPCW2, r1, 28, 2
	// Set PRU Read bit (command_read = 1)

SENDVALS:	
	SENDBYTE 0x61AD, rPCW1
	SENDVAL rPCW2

	SENDVAL rFTW1
	SENDVAL rFTW2
	SENDVAL rFTW3
	SENDVAL rFTW4
	SENDVAL rFTW5
	SENDVAL rFTW6
	SET pCS

	UPDATEREG
	// Add check/wait for new data
	JMP GETFTW	// Get new params from A8 Main

END:	// Should never reach this, possibly remove it
	MOV	r31.b0, PRU0_R31_VEC_VALID | EVTOUT_0
	HALT