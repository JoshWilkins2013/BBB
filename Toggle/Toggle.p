// Test to toggle PRU pin:
//   P9_27	pru0_r30.t5
// Author: Josh Wilkins

.origin 0					// start of program in PRU memory
.entrypoint START			// program entry point (for a debugger)

#define DELAY	10000000
#define PIN	r30.t5

START:
	MOV r0, DELAY
	SET PIN
	
WAITHIGH:
	SUB r0, r0, 1
	QBNE WAITHIGH, r0, 0
	MOV r0, DELAY
	CLR PIN
	
WAITLOW:
	SUB r0, r0, 1
	QBNE WAITLOW, r0, 0
	MOV r0, DELAY
	SET PIN
	QBA WAITHIGH
	
END:
	HALT