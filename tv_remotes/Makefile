
PROGRAMS= \
  remote_auria.hex \
  remote_charter.hex \
  remote_in_focus.hex \
  remote_lg.hex \
  remote_rc5.hex \
  remote_samsung.hex \
  remote_westinghouse.hex

INCLUDE=../../naken_asm/include/msp430

default: $(PROGRAMS)

%.hex: %.asm
	naken_asm -l -o $*.hex -I$(INCLUDE) $<

clean:
	@rm -f *.hex *.lst
	@echo "Clean!"

