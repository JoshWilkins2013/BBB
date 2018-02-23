/*  SPI communication to the DAC
*   Author: Josh Wilkins
*/

#include <stdio.h>
#include <stdlib.h>
#include <prussdrv.h>
#include <pruss_intc_mapping.h>

#define DAC_PRU_NUM	1   // using PRU1 for the DAC capture

int main(int argc, char *argv[]) {

	// Initialize structure used by prussdrv_pruintc_intc
	// PRUSS_INTC_INITDATA is found in pruss_intc_mapping.h
	tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

	float Vout = strtof(argv[1], NULL);	// Desired phase shift in degrees
	float k = (Vout * pow(2,16) ) / 5;
	
	// Allocate and initialize memory
	prussdrv_init ();
	prussdrv_open (PRU_EVTOUT_0);

	// Write the address and size into PRU1 Data RAM0
	prussdrv_pru_write_memory(PRUSS0_PRU1_DATARAM, 0, (const unsigned int)k, 4);
	
	// Map the PRU's interrupts
	prussdrv_pruintc_init(&pruss_intc_initdata);

	// Load and execute the PRU program on the PRU
	prussdrv_exec_program (DAC_PRU_NUM, "./DAC.bin");
	printf("DAC Capture program now running\n");
	
	
	/* // PI Loop Filter
	k1 = 1;		// Proportional Gain
	k2 = 1;		// Integral Gain
	ltmp = 0;	// Initialization value
	while(1){
		x = ;	// Read in latest DAC output
		tmp = x + k2*ltmp	// Intermediate step
		y = k1 * x + tmp;	// Output
		ltmp = tmp;
		// Write y to ADC
	} */
	
	// Wait for event completion from PRU, returns the PRU_EVTOUT_0 number
	int n = prussdrv_pru_wait_event (PRU_EVTOUT_0);
	printf("Program completed, event number %d.\n", n);

	// Disable PRU and close memory mappings 
	prussdrv_pru_disable(DAC_PRU_NUM);
	
	prussdrv_exit ();
	return EXIT_SUCCESS;
}