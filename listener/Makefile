
PROGRAMS= listener.hex \

INCLUDE=../../naken_asm/include/msp430

default: $(PROGRAMS)

%.hex: %.asm
	naken_asm -l -o $*.hex -I$(INCLUDE) $<

clean:
	@rm -f *.hex *.lst
	@echo "Clean!"

