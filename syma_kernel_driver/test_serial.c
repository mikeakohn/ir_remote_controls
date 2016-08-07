#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

int main(int argc, char *argv[])
{
  struct termios oldtio;
  struct termios newtio;
  unsigned char buffer[5];
  unsigned char command[5];
  int fd;
  int n, l, ptr;

  if (argc != 2)
  {
    printf("Usage: test_serial <device>\n");
    exit(0);
  }

  printf("Opening %s\n", argv[1]);

  fd = open(argv[1], O_RDWR | O_NOCTTY);
  if (fd == -1)
  {
    printf("Couldn't open serial device.\n");
    exit(1);
  }

  tcgetattr(fd,&oldtio);

  memset(&newtio, 0, sizeof(struct termios));
  newtio.c_cflag = B9600|CS8|CLOCAL|CREAD;
  newtio.c_iflag = IGNPAR;
  newtio.c_oflag = 0;
  newtio.c_lflag = 0;
  newtio.c_cc[VTIME] = 0;
  newtio.c_cc[VMIN] = 1;

  tcflush(fd, TCIFLUSH);
  tcsetattr(fd, TCSANOW, &newtio);

  printf("Listening...\n");
  ptr = 0;

  while(1)
  {
    l = read(fd, buffer, 5);
    if (l < 0) break;

    for (n = 0; n < l; n++)
    {
      if (buffer[n] == 0xff) { ptr = 0; continue; }
      command[ptr++] = buffer[n];
      if (ptr == 4)
      {
        printf("yaw=%d pitch=%d (%c) throttle=%d corr=%d\n",
               command[0],
               command[1],
               command[2] & 128 ? 'B' : 'A',
               command[2] & 0x7f,
               command[3]);
      }
      //printf("%02x ", buffer[n]);
    }
    //printf("\n");
  }

  printf("Closing...\n");

  tcsetattr(fd, TCSANOW, &oldtio);

  return 0;
}


