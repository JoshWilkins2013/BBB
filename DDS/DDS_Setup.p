// Setup the registers for the AD9912 DDS via SPI
// Author: Josh Wilkins

/////////////////////////////////////////////////////////////////
//----------------------- Program Setup -----------------------//
/////////////////////////////////////////////////////////////////

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
	SENDBYTE 0x0000, 0x99 // Serial Config
	SENDBYTE 0x0010, 0x00 // Power Down & Enable
	SENDBYTE 0x0020, 0x03 // N-Divider
	SENDBYTE 0x0106, 0x00 // S-Divier

END:
	MOV	r31.b0, PRU0_R31_VEC_VALID | EVTOUT_0
	HALT
