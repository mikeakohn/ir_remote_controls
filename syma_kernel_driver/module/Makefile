

obj-m += syma_s107.o

all:
	make -C /lib/modules/$(shell uname -r )/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r )/build M=$(PWD) clean

