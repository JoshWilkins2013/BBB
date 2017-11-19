// Setup the registers for the AD9912 DDS via SPI
// Author: Josh Wilkins

/////////////////////////////////////////////////////////////////
//----------------------- Program Setup -----------------------//
/////////////////////////////////////////////////////////////////

// Local registers given names (prefixed r) to keep track of them
#define rDDS_ADDR	r2	// DDS ADDR to read/write to
#define rMOSI_VAL	r3	// DDS addr and val combined
#define rNUM_REGS	r4	// Number of registers needed to store FTW and PCW
#define rNUM_BITS	r5	// Number of bit to be transferred to DDS
#define rMISO_VAL	r7	// Value returned by MISO
#define rREAD_FLAG	r7.t0	// Set to read instead of write from rDDS_ADDR
#define rDELAY		r8	// Time Delays (ie. SCK_DELAY)
#define rFTW1		r9	// MSB of FTW
#define rFTW2		r10	// LSB of FTW
#define rPCW		r11	// PCW

// PRU1 DDS Pin Configurations (prefixed p):
#define pSYNC	r31.t7	// P9.25
#define pCS		r30.t5	// P9.27
#define pMISO	r31.t3	// P9.28
#define pMOSI	r30.t1	// P9.29
#define pSCK	r30.t2	// P9.30
#define pUPDATE	r30.t0	// P9.31

.setcallreg  r29.w2		// set a non-default CALL/RET register
.origin 0				// start of program in PRU memory
.entrypoint START		// program entry point (for a debugger)

#define PRU0_R31_VEC_VALID 32	// Allows notification of program completion
#define EVTOUT_0	3	// The event number that is sent back

#define SCK_DELAY	1


////////////////////////////////////////////////////////////////
//-------------------- Writing Registers ---------------------//
////////////////////////////////////////////////////////////////

START:
	// Enable shared memory access with host (http://www.embedded-things.com/bbb/understanding-bbb-pru-shared-memory-access/)
	LBCO r0, C4, 4, 4	// Load SYSCFG reg into r0
	CLR  r0, r0, 4		// Clear bit 4 (STANDBY_INIT)
	SBCO r0, C4, 4, 4	// Store the modified r0 back at the load addr

UPDATE:
	MOV	r1, 0x00000000	// Load the base address into r1
	
	// PRU memory 0x00 stores the FTW and PCW
	LBBO rPCW, r1, 0, 4		// Load FTW MSB into r11
	LBBO rFTW1, r1, 4, 8	// Load FTW MSB into r10
	LBBO rFTW2, r1, 12, 4	// Load FTW MSB into r10
	
	CLR	pMOSI				// Clear the data out line - MOSI
	CLR rREAD_FLAG			// CLR read flag
	
	MOV	rNUM_REGS, 3		// Number of registers needed to store FTW and PCW
	
	QBA NEXTREG


////////////////////////////////////////////////////////////////
//------------------- Read/Verify Registers ------------------//
////////////////////////////////////////////////////////////////

//VERIFY:
//	SET rREAD_FLAG		// Set read flag
//	MOV	rNUM_REGS, 3	// Number of Setup Registers
//	QBA NEXTREG

END:
	MOV	r31.b0, PRU0_R31_VEC_VALID | EVTOUT_0
	HALT


////////////////////////////////////////////////////////////////
//-------------------- Register Selection --------------------//
////////////////////////////////////////////////////////////////

NEXTREG:
	QBEQ REG1, rNUM_REGS, 3	// PCW Address and Value
	QBEQ REG2, rNUM_REGS, 2	// MSB of FTW
	QBEQ REG3, rNUM_REGS, 1	// LSB of FTW
REG1:
	MOV rDDS_ADDR, 0x61A60000	 	// Stream Mode + PCW Address
	ADD rMOSI_VAL, rDDS_ADDR, rPCW	// Combine address and PVW together
	QBA SPISETUP
REG2:
	MOV rMOSI_VAL, rFTW1			// Send 32 MSB of FTW
	QBA SPISETUP
REG3:
	MOV rMOSI_VAL, rFTW2			// Send remaining 16 LSB of FTW now
	LSL rMOSI_VAL, rMOSI_VAL, 16	// Shift rMOSI_VAL left 16 bits to write 32 bits (Soo inefficient, only need to write 16 bits, change later)


////////////////////////////////////////////////////////////////
//--------------------- SPI Transaction ----------------------//
////////////////////////////////////////////////////////////////

SPISETUP:
	MOV	rNUM_BITS, 32		// Number of bits to read/write
	CLR pCS					// Prepare for data transfer by clearing chip select pin
	QBBS READ, rREAD_FLAG	// If read flag: set read bit
	QBA NEXTBIT

READ:
	SET rMOSI_VAL, rMOSI_VAL, 31	// If read flag: set read bit
	
NEXTBIT:
	CALL SPICLK
	
	SUB	rNUM_BITS, rNUM_BITS, 1		// Count down through the bits
	QBNE NEXTBIT, rNUM_BITS, 0		// Repeat for 24 bits
	SET pCS	// Here for debugging purposes, move to end of all registers

//	QBBS VALIDATE, rREAD_FLAG		// Validate MISO value if read bit set
	
	SUB	rNUM_REGS, rNUM_REGS, 1		// Count down through the registers
	QBNE NEXTREG, rNUM_REGS, 0		// Verify each register value after setup
	
//	QBBS END, rREAD_FLAG
//	QBA VERIFY
	QBA END	// Change to UPDATE to make inf loop (Only does about 400 cycles for some reason)

//VALIDATE:
//	LSR	rMISO_VAL, rMISO_VAL, 1		// SPICLK shifts left too many times left, shift right once
//	AND	rMISO_VAL, rMISO_VAL, 0x0000FF// This line needs to change
//	QBNE FAIL, rMISO_VAL, rMOSI_VAL	// Verify MISO data and written data are equal
//	QBA END

//FAIL:
//	// Need to do something here to alert user...
//	MOV	r31.b0, PRU0_R31_VEC_VALID | EVTOUT_0
//	HALT


/////////////////////////////////////////////////////////////////
//-------------------- One SPI Clock Cycle --------------------//
/////////////////////////////////////////////////////////////////

SPICLK:
	QBBC DATALOW, rMOSI_VAL.t31// The write state needs to be set right here -- bit 31 shifted left
	SET	pMOSI		// Set MOSI line high (Did not branch above if rMOSI_VAL.t31=LOW)
	QBA	DATACONTD	// Jump to DATACONTD

DATALOW:
	CLR	pMOSI

DATACONTD:			// Time after setting data, before setting SCK
	SET	pSCK		// Set the clock high
	CLR pMOSI		// Clear the Data Out Line (MOSI)
	MOV rDELAY, SCK_DELAY		// time for clock low -- assuming clock low before cycle

SCKHIGH:
	SUB rDELAY, rDELAY, 1		// decrement the counter by 1 and loop (next line)
	QBNE SCKHIGH, rDELAY, 0
	LSL	rMOSI_VAL, rMOSI_VAL, 1	// Bit shift rMOSI_VAL (MOSI data) one bit left
	CLR	pSCK					// Set the clock low
	
	QBBC SCKLOW, pMISO			// If data in is low, just shift rNUM_BITS
	OR rMISO_VAL, rMISO_VAL, 0x000001	// Otherwise, set the last bit of rNUM_BITS then shift

SCKLOW:
	LSL	rMISO_VAL, rMISO_VAL, 1	// Shift the data in register left to prepare for next bit read
	RET