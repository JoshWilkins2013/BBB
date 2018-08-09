/*  This program toggles a pin
*   Author: Josh Wilkins
*/

#include <stdio.h>
#include <stdlib.h>
#include <prussdrv.h>
#include <pruss_intc_mapping.h>

#define PRU_NUM	0   // using PRU0 for the DAC capture

int main (void) {
	
	// Initialize structure used by prussdrv_pruintc_intc
	// PRUSS_INTC_INITDATA is found in pruss_intc_mapping.h
	tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

	prussdrv_init ();
	prussdrv_open (PRU_EVTOUT_0);

	prussdrv_pruintc_init(&pruss_intc_initdata);

	// Load and execute the PRU program on the PRU
	prussdrv_exec_program (PRU_NUM, "./Toggle.bin");
	printf("Program now running\n");

	// Wait for event completion from PRU, returns the PRU_EVTOUT_0 number
	int n = prussdrv_pru_wait_event (PRU_EVTOUT_0);
	printf("EBBADC PRU0 program completed, event number %d.\n", n);

	// Disable PRU and close memory mappings
	prussdrv_pru_disable(PRU_NUM);

	prussdrv_exit ();
	return EXIT_SUCCESS;
}