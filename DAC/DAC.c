/*  Example using the external DAC
*   Author: Josh Wilkins
*/

#include <stdio.h>
#include <stdlib.h>
#include <prussdrv.h>
#include <pruss_intc_mapping.h>

#define DAC_PRU_NUM	1   // using PRU1 for the DAC capture

/*
** ------------------------------
** | 	BBB		 ||		DAC		|
** |-------------||-------------|
** | FUNC | PIN# ||	FUNC | PIN#	|
** |------|------||------|------|
** |  CS  | 8_27 ||	 CS  |  6	|
** | MISO | 8_28 ||	MISO |  5	|
** | MOSI | 8_29 || MOSI |  7	|
** | CLK  | 8_30 ||	SCK  |  4	|
** | DGND | 9_01 || GND  |  3	|
** |  5V  | 9_07 ||	 V+  |  1	|
** ------------------------------
*/

int main(int argc, char *argv[]) {

	// Initialize structure used by prussdrv_pruintc_intc
	// PRUSS_INTC_INITDATA is found in pruss_intc_mapping.h
	tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

	float Vout = strtof(argv[1], NULL);	// Desired output voltage in V
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
	
	// Wait for event completion from PRU, returns the PRU_EVTOUT_0 number
	int n = prussdrv_pru_wait_event (PRU_EVTOUT_0);
	printf("Program completed, event number %d.\n", n);

	// Disable PRU and close memory mappings 
	prussdrv_pru_disable(DAC_PRU_NUM);
	
	prussdrv_exit ();
	return EXIT_SUCCESS;
}