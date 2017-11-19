/*  Setup DDS Registers via SPI communication with the DDS
*   Author: Josh Wilkins
*/

#include <stdio.h>
#include <stdlib.h>
#include <prussdrv.h>
#include <pruss_intc_mapping.h>

#define DDS_PRU_NUM	0   // using PRU0 for the DDS capture

int main (void) {

	if(getuid() != 0) {
		printf("You must run this program as root. Exiting.\n");
		exit(EXIT_FAILURE);
	}

	// Initialize structure used by prussdrv_pruintc_intc
	// PRUSS_INTC_INITDATA is found in pruss_intc_mapping.h
	tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

	// Allocate and initialize memory
	prussdrv_init ();
	prussdrv_open (PRU_EVTOUT_0);

	// Map the PRU's interrupts
	prussdrv_pruintc_init(&pruss_intc_initdata);

	// Load and execute the PRU program on the PRU
	prussdrv_exec_program (DDS_PRU_NUM, "./DDS_Setup.bin");
	printf("DDS setup program now running\n");

	// Wait for event completion from PRU, returns the PRU_EVTOUT_0 number
	int n = prussdrv_pru_wait_event (PRU_EVTOUT_0);
	printf("Program completed, event number %d.\n", n);

	// Disable PRU and close memory mappings 
	prussdrv_pru_disable(DDS_PRU_NUM);
	prussdrv_exit ();

	return EXIT_SUCCESS;
}