
PROGRAM=syma_motor_control
INCLUDE=../../naken_asm/include/msp430

default:
	naken_asm -l -o $(PROGRAM).hex -I$(INCLUDE) $(PROGRAM).asm

clean:
	@rm -f *.hex *.lst *.ndbg
	@echo "Clean!"

