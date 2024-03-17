ASSM=avra
PROJ=lab7_2
OUTFN=lab7.hex
AOPTIONS=-o ${OUTFN}
INFN=lab7_2.asm
hex:
	$(ASSM) $(AOPTIONS) $(INFN) 
	rm -f $(PROJ).obj $(PROJ).eep.hex
	sudo avrdude -c avr109 -p m32u4 -P /dev/ttyACM0 -U flash:w:$(OUTFN)
