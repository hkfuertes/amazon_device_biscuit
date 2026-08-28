#include <errno.h>
#include <fcntl.h>
#include <linux/i2c-dev.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main(int argc, char** argv) {
    if (argc != 4) {
        fprintf(stderr, "usage: %s addr reg value\n", argv[0]);
        return 2;
    }
    int addr = strtol(argv[1], NULL, 0);
    int reg = strtol(argv[2], NULL, 0);
    int val = strtol(argv[3], NULL, 0);
    int fd = open("/dev/i2c-0", O_RDWR);
    if (fd < 0) { perror("open"); return 1; }
    if (ioctl(fd, I2C_SLAVE, addr) < 0) { perror("ioctl"); return 1; }
    unsigned char buf[2] = { (unsigned char)reg, (unsigned char)val };
    if (write(fd, buf, 2) != 2) { perror("write"); return 1; }
    close(fd);
    return 0;
}
