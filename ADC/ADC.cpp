// Slow, couple of KHz

#include<iostream>
#include<fstream>
#include<string>
#include<sstream>
#include <chrono>
#include <ratio>
#include <thread>
using namespace std;

#define ADC_Path "/sys/bus/iio/devices/iio:device0/in_voltage"

int readAnalog(int number){
	stringstream ss;
	ss << ADC_Path << number << "_raw";
	fstream fs;
	fs.open(ss.str().c_str(), fstream::in);
	fs >> number;
	fs.close();
	return number;
}

void f()
{
	std::this_thread::sleep_for(std::chrono::seconds(1));
}

int main(int argc, char* argv[]){
	
	cout << "Starting the readLDR program" << endl;

	auto t1 = chrono::high_resolution_clock::now();
	int value = readAnalog(0);
	auto t2 = std::chrono::high_resolution_clock::now();

	chrono::duration<double, milli> fp_ms = t2 - t1;
	cout << "f() took " << fp_ms.count() << " ms" << endl;

	cout << "The LDR value was " << value << " out of 4095." << endl;
	return 0;
}