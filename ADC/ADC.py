# Slow, couple of KHz

import time
import beaglebone_pru_adc as adc

numsamples = 5000
capture = adc.Capture()
capture.oscilloscope_init(adc.OFF_VALUES, numsamples)

start = time.time()

capture.start()
while not capture.oscilloscope_is_complete():
	pass

stop = time.time()

diff = stop-start
print str(diff/numsamples) + "Avg time per sample [sec]"
print str(numsamples/diff) + "Avg rate [samples/sec]"

capture.stop()
capture.wait()
capture.close()