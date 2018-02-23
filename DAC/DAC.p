// Communication with the LTC2601 DAC via SPI
// Author: Josh Wilkins

/////////////////////////////////////////////////////////////////
//----------------------- Program Setup -----------------------//
/////////////////////////////////////////////////////////////////

#define rDAC		r10		// DAC ADDR/VAL

.setcallreg  r29.w2		// set a non-default CALL/RET register
.origin 0				// start of program in PRU memory
.entrypoint START		// program entry point (for a debugger)

#include "../SPI.hp"

#define PRU1_R31_VEC_VALID 32	// Allows notification of program completion
#define PRU_EVTOUT_0	3	// The event number that is sent back


////////////////////////////////////////////////////////////////
//---------------------- Memory Sharing ----------------------//
////////////////////////////////////////////////////////////////

START:
	LBCO r0, C4, 4, 4	// Load SYSCFG reg into r0
	CLR  r0, r0, 4		// Clear bit 4 (STANDBY_INIT)
	SBCO r0, C4, 4, 4	// Store the modified r0 back at the load addr
	MOV	r1, 0x00000000	// Load the base address into r1


////////////////////////////////////////////////////////////////
//-------------------- Writing Registers ---------------------//
////////////////////////////////////////////////////////////////

UPDATE:
	LBBO rDAC, r1, 0, 4	// The LTC2601 states are now stored in r2 -- need the 16 MSBs
	SENDVAL 0x30		// Send command word to DAC (3 = Write & Update)
	SENDADDR rDAC		// This actually sends two bytes of data
	SET	pCS				// Pull the CS line high (End of sample)

END:
	MOV	r31.b0, PRU1_R31_VEC_VALID | PRU_EVTOUT_0
	HALT