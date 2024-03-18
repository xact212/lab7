ASSM=avra
PROJ=Zach_Lehman_and_Brendan_Cahill_Lab7_sourcecode
OUTFN=Zach_Lehman_and_Brendan_Cahill_Lab7_sourcecode.hex
AOPTIONS=-o ${OUTFN}
INFN=Zach_Lehman_and_Brendan_Cahill_Lab7_sourcecode.asm
hex:
	$(ASSM) $(AOPTIONS) $(INFN) 
	rm -f $(PROJ).obj $(PROJ).eep.hex
	sudo avrdude -c avr109 -p m32u4 -P /dev/ttyACM0 -U flash:w:$(OUTFN)
