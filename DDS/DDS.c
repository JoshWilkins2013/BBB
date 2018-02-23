/*  Setup DDS Registers via SPI communication with the DDS
*   Author: Josh Wilkins
*/

#include <stdio.h>
#include <stdlib.h>
#include <prussdrv.h>
#include <pruss_intc_mapping.h>
#include <stdbool.h>

#define DDS_PRU_NUM	0   // using PRU0 for the DDS capture
#define DDS	// Defines the pins for SPI communication in SPI.hp

double FTW;
double f_center;
double f_mod;
double PCW;
double output_power;
bool PLL1_State;
bool PLL2_State;

void atox(double value, int numBits, int *hexPairs) {
	char hexVals[12] = {0};
	int i = numBits-1;
	int j = 1;
	int k = 0;
	for(i; i>=0; i--) {
		double nextPow = pow(2, i);
		if (nextPow <= value) {
			value -= nextPow;
			if (j==1) {
				hexVals[k] += 8;
			} else if (j==2) {
				hexVals[k] += 4;
			} else if (j==3) {
				hexVals[k] += 2;
			} else {
				hexVals[k] += 1;
			}
		}
		j++;
		if (j==5) {
			j = 1;
			k++;
		}
	}

	j = 0;
	for(i=0; i<(numBits/4); i++) {
		if(i % 2){
			hexPairs[j] += hexVals[i];
			j++;
		} else {
			hexPairs[j] += 16 * hexVals[i];
		}
	}
}

void removeChar(char *str, char garbage) {
	char *src, *dst;
	for (src = dst = str; *src != '\0'; src++) {
		*dst = *src;
		if (*dst != garbage) dst++;
	}
	*dst = '\0';
}

void parse_c3(void) {
	const char *command[100];
	printf("--> ");
	scanf("%s", command);
	
	// Removing '{' & '}' characters
	char* commands = malloc(strlen(command)+1);
	strcpy(commands, command);
	removeChar(commands, '{');
	removeChar(commands, '}');
	
	// Splitting string by ','
	char *token;
	bool set = 0;
	token = strsep(&commands, ",");
	if (strcmp("Get", token) == 0) {
		printf("GET\n");// Return parameter value
	} else if (strcmp("Set", token) == 0) {
		printf("SET\n");
		set = 1;		// Set parameter value
	} else {
		printf("INVALID COMMAND\n");
		parse_c3();
	}
	
	// Possible parameters to get/set:
	// MicrowaveFreqMod, MicrowaveFreqCenter, MicrowaveFreqCenter,
	// OutputPower, LockStatePLL1, LockStatePLL2
	token = strsep(&commands, ",");
	if (strcmp("MicrowaveFreqCenter", token) == 0) {
		printf("MicrowaveFreqCenter\n");// Enter desired Frequency in MHz
		if (set==1) {
			token = strsep(&commands, ",");
			double x = atof(token);
			printf("%f\n", x);
			f_center = x;
		} else {
			// Read register for current FTW
			printf("TBD");
		}
	} else if (strcmp("MicrowaveFreqMod", token) == 0) {
		printf("MicrowaveFreqMod\n");	// Enter desired modulation rate in MHz
		if (set==1) {
			token = strsep(&commands, ",");
			double x = atof(token);
			printf("%f\n", x);
			f_mod = x;
		} else {
			// Read register for current f_mod
			printf("TBD");
		}
	} else if (strcmp("MicrowavePhase", token) == 0) {
		printf("Phase\n");	// Enter desired starting phase in degrees
		if (set==1) {
			token = strsep(&commands, ",");
			double x = atof(token);
			printf("%f\n", x);
			PCW = round( (x * pow(2,14)) / 360.0 );
		} else {
			// Read register for current PCW
			printf("TBD");
		}
	} else if (strcmp("OutputPower", token) == 0) {
		printf("OutputPower\n");		// Enter output power level in dBm
		if (set==1) {
			token = strsep(&commands, ",");
			double x = atof(token);
			printf("%f\n", x);
			output_power = x;
		} else {
			// Read register for current output_power
			printf("TBD");
		}
	} else if (strcmp("LockStatePLL1", token) == 0) {
		printf("LockStatePLL1\n");		// Returns 10 MHz PLL lock status
		if (set==1) {
			printf("INVALID COMMAND\n");// Invalid parameter entered, try again
			parse_c3();
		} else {
			// Read register for current PLL lock state
			printf("TBD");
		}
	} else if (strcmp("LockStatePLL2", token) == 0) {
		printf("LockStatePLL2\n");		// Returns 100 MHz PLL lock status
		if (set==1) {
			printf("INVALID COMMAND\n");// Invalid parameter entered, try again
			parse_c3();
		} else {
			// Read register for current 100 MHz PLL Lock State
			printf("TBD");
		}
	} else {
		printf("INVALID COMMAND\n");	// Invalid parameter entered, try again
		parse_c3();
	}
}

void main(void) {

	// Initialize structure used by prussdrv_pruintc_intc
	// PRUSS_INTC_INITDATA is found in pruss_intc_mapping.h
	tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;
	
	// Allocate and initialize memory
	prussdrv_init ();
	prussdrv_open (PRU_EVTOUT_0);
	
	// Map the PRU's interrupts
	prussdrv_pruintc_init(&pruss_intc_initdata);

	// Load and execute the PRU program on the PRU
	prussdrv_exec_program (DDS_PRU_NUM, "./DDS.bin");
	
	while(1) {
		parse_c3();	// Blocking code, waits for input
		
		FTW1 = round( pow(2,48) * ( (f_center + f_mod) / 1e3) );
		FTW2 = round( pow(2,48) * ( (f_center - f_mod) / 1e3) );
		
		int FTW1_Hex[6] = {0};
		atox(FTW1, 48, FTW1_Hex);
		int FTW2_Hex[6] = {0};
		atox(FTW2, 48, FTW2_Hex);
		int PCW_Hex[2] = {0};
		atox(PCW, 16, PCW_Hex);

		// Concatenate the two arrays
		int* hex_vals1 = malloc(8 * sizeof(int));
		memcpy(hex_vals1,     FTW1_Hex, 6*sizeof(int));
		memcpy(hex_vals1 + 6, PCW_Hex, 2*sizeof(int));

		// Concatenate the two arrays
		int* hex_vals2 = malloc(8 * sizeof(int));
		memcpy(hex_vals2,     FTW2_Hex, 6*sizeof(int));
		memcpy(hex_vals2 + 6, PCW_Hex, 2*sizeof(int));
		
		// Write the FTW and PCW into PRU0 Data RAM0
		prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, 0, (const unsigned int *)hex_vals1, 32);  // SPI code
		
		bool new_command = 0;
		bool command_read = 0;
		while (new_command != 1) {
			while (command_read != 1) {
				// command_read = read PRU 'read status' register
				// Read register to see if new command is available
			}
			command_read = 0;
			prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, 0, (const unsigned int *)hex_vals2, 32);  // SPI code
			while (command_read != 1) {
				// command_read = read PRU 'read status' register
				// new_command = Read register to see if new command is available
			}
			prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, 0, (const unsigned int *)hex_vals1, 32);  // SPI code
		}
	}
	
	// Should be able to remove following code:
	// Wait for event completion from PRU, returns the PRU_EVTOUT_0 number
	//int n = prussdrv_pru_wait_event(PRU_EVTOUT_0);

	// Disable PRU and close memory mappings
	//prussdrv_pru_disable(DDS_PRU_NUM);
	//prussdrv_exit ();
}