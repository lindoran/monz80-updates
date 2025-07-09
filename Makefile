SRC      := monz80.z80
ROM      := monz80.rom
LABELS   := monz80.lbl
LISTING  := monz80.lst
HEXFILE  := monz80.hex

TEMP_DIR := build

ZASM      := zasm
ZFLAGSBIN := -uwyb
ZFLAGSHEX := -uwyx

all: $(ROM)

$(ROM): $(SRC)
	$(ZASM) $(ZFLAGSBIN) $<
	$(ZASM) $(ZFLAGSHEX) $<

clean:
	rm -f $(ROM) $(LABELS) $(LISTING) $(HEXFILE)
