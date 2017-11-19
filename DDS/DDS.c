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

	// User input data
	float fdds = 158;	// Desired Frequency in MHz
	float shift = 0;	// Desired phase shift in degrees
	
	// Data for the PRU
	double FTW = round( pow(2,48) * (fdds / 1e3) );
	double PCW = round( (shift * pow(2,14)) / 360.0 );
	
	printf("FTW and PCW: %f and %f \n", FTW, PCW);
	
	unsigned int spiData[3];
	spiData[0] = 0x3333;
	spiData[1] = 0x77773333;
	spiData[3] = 0x1111;
	printf("PCW and FTW: 0x%x and 0x%x \n", spiData[0], spiData[1]);

	// Allocate and initialize memory
	prussdrv_init ();
	prussdrv_open (PRU_EVTOUT_0);

	// Write the FTW and PCW into PRU0 Data RAM0
	prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, 0, spiData, 16);  // SPI code

	// Map the PRU's interrupts
	prussdrv_pruintc_init(&pruss_intc_initdata);

	// Load and execute the PRU program on the PRU
	prussdrv_exec_program (DDS_PRU_NUM, "./DDS.bin");
	printf("DDS Capture program now running\n");

	// Wait for event completion from PRU, returns the PRU_EVTOUT_0 number
	int n = prussdrv_pru_wait_event (PRU_EVTOUT_0);
	printf("Program completed, event number %d.\n", n);

	// Disable PRU and close memory mappings 
	prussdrv_pru_disable(DDS_PRU_NUM);
	prussdrv_exit ();
	
	return EXIT_SUCCESS;
}