#include <iostream>
#include <SerialStream.h>
#include <cstdlib>
#include <string.h>

using namespace std;
using namespace LibSerial;

int main() {
	string portName = "/dev/ttyO1";
	cout << "Attempting to connect to port " << portName << endl;
	
	SerialStream port;
	port.Open(portName);
	
	// Set the baud rate of the serial port.
	port.SetBaudRate(SerialStreamBuf::BAUD_9600);
	port.SetCharSize(SerialStreamBuf::CHAR_SIZE_8);
	port.SetParity(SerialStreamBuf::PARITY_NONE);
	port.SetNumOfStopBits(1);
	port.SetFlowControl(SerialStreamBuf::FLOW_CONTROL_NONE);
    
	// Make sure port is good
	if (!port.good()) {
		cerr << "Connection to serial port failed" << endl;
		exit(1) ;
	}
    
	cout << "Successfully connected to port " << portName << endl;

	while (port.rdbuf()->in_avail() > 0) usleep(100); // not sure what this does

	char command[256];
	char newChar;

	port << '\n';  // Get weird command if this isn't here

	while (newChar != '}') {
		port.get(newChar);
		strncat(command, &newChar, 1);
	}

	cout << "Received '" << command << "' on port " << portName << endl;
}
