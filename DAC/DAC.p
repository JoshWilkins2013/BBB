// Communication with the LTC2601 DAC via SPI
// Author: Josh Wilkins

/////////////////////////////////////////////////////////////////
//----------------------- Program Setup -----------------------//
/////////////////////////////////////////////////////////////////

// Local registers given names (prefixed r) to keep track of them
#define rDAC_DATA	r2	// DAC ADDR to read/write to
#define rMOSI_VAL	r3	// DAC addr and val combined
#define rNUM_BITS	r4	// Number of bit to be transferred to DAC

// PRU1 DAC Pin Configurations (Tested on PRU0, assumed working on PRU1):
#define pCS		r30.t8	// P8.27
#define pMISO	r31.t10	// P8.28
#define pMOSI	r30.t9	// P8.29
#define pSCK	r30.t11	// P8.30

.setcallreg  r29.w2		// set a non-default CALL/RET register
.origin 0				// start of program in PRU memory
.entrypoint START		// program entry point (for a debugger)

#define PRU1_R31_VEC_VALID 32	// Allows notification of program completion
#define EVTOUT_0	3	// The event number that is sent back


////////////////////////////////////////////////////////////////
//---------------------- Memory Sharing ----------------------//
////////////////////////////////////////////////////////////////

START:
	// Enable shared memory access with host (http://www.embedded-things.com/bbb/understanding-bbb-pru-shared-memory-access/)
	LBCO r0, C4, 4, 4	// Load SYSCFG reg into r0
	CLR  r0, r0, 4		// Clear bit 4 (STANDBY_INIT)
	SBCO r0, C4, 4, 4	// Store the modified r0 back at the load addr

	// PRU memory 0x00 stores the SPI command - e.g., 0x30 0x80 0x00
	MOV	r1, 0x00000000	// Load the base address into r1
	
	CLR	pMOSI			// Clear the data out line - MOSI


////////////////////////////////////////////////////////////////
//-------------------- Writing Registers ---------------------//
////////////////////////////////////////////////////////////////

UPDATE:
	// Load the send value on each sample (Allows for sampling re-configuration)
	LBBO rDAC_DATA, r1, 0, 4			// The LTC2601 states are now stored in r2 -- need the 16 MSBs
	ADD rMOSI_VAL, rDAC_DATA, 0x300000	// Add command word to data (3 = Write & Update)
	CLR	pCS				// Set the CS line low (Active low)
	MOV	rNUM_BITS, 24	// Going to write/read 24 bits (3 bytes)

CLK_BIT:
	// Loop for each of the 24 bits
	SUB	rNUM_BITS, rNUM_BITS, 1	// Count down through the bits
	CALL SPICLK		// Repeat call SPICLK procedure until all 24-bits written/read
	QBNE CLK_BIT, rNUM_BITS, 0	// Repeat for 24 bits
	SET	pCS			// Pull the CS line high (End of sample)
//	QBA	UPDATE		// Uncomment to loop infinitely

END:
	MOV	r31.b0, PRU1_R31_VEC_VALID | PRU_EVTOUT_0
	HALT


/////////////////////////////////////////////////////////////////
//-------------------- One SPI Clock Cycle --------------------//
/////////////////////////////////////////////////////////////////

SPICLK:	
	QBBC DATALOW, rMOSI_VAL.t23// The write state needs to be set right here -- bit 23 shifted left
	SET	pMOSI		// Set MOSI line high (Did not branch above if r2.t23=low)
	QBA	DATACONTD	// Jump to DATACONTD

DATALOW:
	CLR	pMOSI

DATACONTD:
	SET	pSCK		// Set the clock high
	CLR pMOSI		// Clear the Data Out Line (MOSI)

CLKHIGH:
	LSL	rMOSI_VAL, rMOSI_VAL, 1	// Bit shift r2 (MOSI data) one bit left
	CLR	pSCK		// Set the clock low
	RET