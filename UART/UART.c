#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define BAUDRATE B9600
#define MODEMDEVICE "/dev/ttyO1"
#define _POSIX_SOURCE 1 /* POSIX compliant source */

#define FALSE 0
#define TRUE 1

volatile int STOP=FALSE;

void main() {
	int fd, res;
	struct termios newtio;

	fd = open(MODEMDEVICE, O_RDWR | O_NOCTTY );
	if (fd <0) {perror(MODEMDEVICE); exit(-1); }

	bzero(&newtio, sizeof(newtio));
	newtio.c_cflag = BAUDRATE | CRTSCTS | CS8 | CLOCAL | CREAD;
	newtio.c_iflag = IGNPAR;
	newtio.c_oflag = 0;

	/* set input mode (non-canonical, no echo,...) */
	newtio.c_lflag = 0;

	newtio.c_cc[VTIME]    = 0;   /* inter-character timer unused */
	newtio.c_cc[VMIN]     = 1;   /* blocking read until 1 chars received */

	tcflush(fd, TCIFLUSH);
	tcsetattr(fd,TCSANOW,&newtio);

	char newCommand[255]="";
	char newChar[1]="";

	while (STOP==FALSE) {       /* loop for input */
			res = read(fd, newChar, 255);   /* returns after 1 chars have been input */
			newChar[res] = 0;

			strncat(newCommand, &newChar[0], 1);
			if (newChar[0]=='}') STOP=TRUE;
	}
	printf("%s\n", newCommand);
}