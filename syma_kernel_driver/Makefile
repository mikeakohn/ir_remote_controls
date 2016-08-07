
PROGRAM=syma_joystick
INCLUDE=../../naken_asm/include/msp430

default:
	naken_asm -l -o $(PROGRAM).hex -I$(INCLUDE) $(PROGRAM).asm

test:
	gcc -o test_serial test_serial.c -Wall -O3

clean:
	@rm -f *.hex *.lst *.ndbg
	@rm -f test_serial
	@echo "Clean!"

