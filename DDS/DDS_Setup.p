// Setup the registers for the AD9912 DDS via SPI
// Author: Josh Wilkins

/////////////////////////////////////////////////////////////////
//----------------------- Program Setup -----------------------//
/////////////////////////////////////////////////////////////////

// Local registers given names (prefixed r) to keep track of them
#define rDDS_ADDR	r2	// DDS ADDR to read/write to
#define rDDS_VAL	r3	// DDS Value to write
#define rMOSI_VAL	r4	// DDS addr and val combined
#define rNUM_REGS	r5	// Number of DDS Registers to setup
#define rNUM_BITS	r6	// Number of bit to be transferred to DDS
#define rMISO_VAL	r7	// Value returned by MISO
#define rREAD_FLAG	r8.t0	// Set to read instead of write from DDS_ADDR
#define rDELAY		r9	// Time Delays (ie. SCK_DELAY)

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
	CLR	pMOSI			// Clear the data out line - MOSI
	CLR rREAD_FLAG		// CLR read flag
	MOV	rNUM_REGS, 4	// Number of Setup Registers
	QBA NEXTREG


////////////////////////////////////////////////////////////////
//------------------- Read/Verify Registers ------------------//
////////////////////////////////////////////////////////////////

VERIFY:
	SET rREAD_FLAG		// Set read flag
	MOV	rNUM_REGS, 4	// Number of Setup Registers
	QBA NEXTREG

END:
	MOV	r31.b0, PRU0_R31_VEC_VALID | EVTOUT_0
	HALT


////////////////////////////////////////////////////////////////
//-------------------- Register Selection --------------------//
////////////////////////////////////////////////////////////////

NEXTREG:
	QBEQ REG1, rNUM_REGS, 4	// Serial Config Register
	QBEQ REG2, rNUM_REGS, 3	// Power Down & Enable Register
	QBEQ REG3, rNUM_REGS, 2	// N-Divider Register
	QBEQ REG4, rNUM_REGS, 1	// S-Divider Register

REG1:
	MOV rDDS_ADDR, 0x0000	// Serial Config Register Address
	MOV rDDS_VAL, 0x99		// Enable 4-Wire SPI
	QBA SPISETUP

REG2:
	MOV rDDS_ADDR, 0x0100	// Power Down & Enable Register
	MOV rDDS_VAL, 0x00		// Addr: 0x0010 -- Disable CMOS, Enable HSTL (0x00)
	QBA SPISETUP

REG3:
	MOV rDDS_ADDR, 0x0020	// N-Divider Register
	MOV rDDS_VAL, 0x05		// Sets Reference Multiplier Value of 10
	QBA SPISETUP

REG4:
	MOV rDDS_ADDR, 0x0106	// S-Divider Register
	MOV rDDS_VAL, 0x00		// Disables /2 Prescaler for CMOS Output (Could probably remove)


////////////////////////////////////////////////////////////////
//--------------------- SPI Transaction ----------------------//
////////////////////////////////////////////////////////////////

SPISETUP:
	LSL rDDS_ADDR, rDDS_ADDR, 8			// Left shift address to make room for data
	ADD rMOSI_VAL, rDDS_ADDR, rDDS_VAL	// Combine address and value together
	MOV	rNUM_BITS, 24		// Number of Bits to transfer (Reg Addr (16) + Reg Val (8))
	CLR pCS					// Prepare for data transfer by clearing chip select pin
	QBBS READ, rREAD_FLAG	// If read flag: set read bit
	QBA NEXTBIT

READ:
	SET rMOSI_VAL, rMOSI_VAL, 23	// If read flag: set read bit
	
NEXTBIT:
	CALL SPICLK
	
	SUB	rNUM_BITS, rNUM_BITS, 1	// Count down through the bits
	QBNE NEXTBIT, rNUM_BITS, 0	// Repeat for 24 bits
	SET pCS

	QBBS VALIDATE, rREAD_FLAG	// Validate MISO value if read bit set
	
	SUB	rNUM_REGS, rNUM_REGS, 1	// Count down through the registers
	QBNE NEXTREG, rNUM_REGS, 0	// Verify each register value after setup
	
	QBBS END, rREAD_FLAG
	QBA VERIFY

VALIDATE:
	LSR	rMISO_VAL, rMISO_VAL, 1		// SPICLK shifts left too many times left, shift right once
	AND	rMISO_VAL, rMISO_VAL, 0x0000FF	// AND the data with mask to give only the 8 LSBs (DATA)
	QBNE FAIL, rMISO_VAL, rMOSI_VAL	// Verify MISO data and written data are equal
	QBA END

FAIL:
	// Need to do something here to alert user...
	MOV	r31.b0, PRU0_R31_VEC_VALID | EVTOUT_0
	HALT

/////////////////////////////////////////////////////////////////
//-------------------- One SPI Clock Cycle --------------------//
/////////////////////////////////////////////////////////////////

SPICLK:
	QBBC DATALOW, rMOSI_VAL.t23// The write state needs to be set right here -- bit 23 shifted left
	SET	pMOSI		// Set MOSI line high (Did not branch above if rMOSI_VAL.t23=LOW)
	QBA	DATACONTD	// Jump to DATACONTD

DATALOW:
	CLR	pMOSI

DATACONTD:			// Time after setting data, before setting sck
	SET	pSCK		// Set the clock high
	CLR pMOSI		// Clear the Data Out Line (MOSI)
	MOV rDELAY, SCK_DELAY		// time for clock low -- assuming clock low before cycle

SCKHIGH:
	SUB rDELAY, rDELAY, 1		// decrement the counter by 1 and loop (next line)
	QBNE SCKHIGH, rDELAY, 0
	LSL	rMOSI_VAL, rMOSI_VAL, 1	// Bit shift MOSI_VAL (MOSI data) one bit left
	CLR	pSCK		// Set the clock low
	
	QBBC SCKLOW, pMISO	// If data in is low, just shift rNUM_BITS
	OR rMISO_VAL, rMISO_VAL, 0x000001	// Otherwise, set the last bit of rNUM_BITS then shift

SCKLOW:
	LSL	rMISO_VAL, rMISO_VAL, 1		// Shift the data in register left to prepare for next bit read
	RET