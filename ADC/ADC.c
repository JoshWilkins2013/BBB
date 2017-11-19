/*  ADC Speed Test Program
*	See http://users.freebasic-portal.de/tjf/Projekte/libpruio/doc/html/_cha_preparation.html
*	800ish KHz? Datasheet gives 200KHz max sample rate -- How to slow down?
*   Author: Josh Wilkins
*/

#define _GNU_SOURCE 1
#include <sys/time.h>
#include "stdio.h"
#include <termios.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/time.h>
#include "../c_wrapper/pruio.h"

void main() {
    pruIo *io = pruio_new(PRUIO_ACT_ADC, 0, 0, 0); //! create new driver structure
    pruio_config(io, 1, 1 << 2, 0, 4);

    if (io->Errr) {
        printf("initialisation failed (%s)\n", io->Errr);}

    if (pruio_config(io, 1, 0x1FE, 0, 4)) {
        printf("config failed (%s)\n", io->Errr);
    }

    struct timeval t1, t2;
    float elapsedTime;
    double x;
    float totalTime = 0;
    int i = 0;

    while(1) {
        i = i + 1;
        gettimeofday(&t1, NULL);
        x = io->Adc->Value[1];
        gettimeofday(&t2, NULL);

        elapsedTime = (t2.tv_sec - t1.tv_sec)*1000000;
        elapsedTime += (t2.tv_usec - t1.tv_usec);
        totalTime += elapsedTime/1000000;

        if (i%10 == 0) {
            printf("\r%4f", i/totalTime);
            //printf("\r%4f", x);
            fflush(STDIN_FILENO);
        }
    }
}