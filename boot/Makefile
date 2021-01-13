.PHONY: clean build hd

clean:
	rm *.bin *.o

build: loader.s mbr.s
	nasm -I include/ -o loader.bin loader.s
	nasm -I include/ -o mbr.bin mbr.s

hd:	mbr.bin loader.bin
	dd if=mbr.bin of=hd60M.img bs=512 count=1 conv=notrunc
	dd if=loader.bin of=hd60M.img bs=512 count=4 seek=2 conv=notrunc

mbr.bin: mbr.s
	nasm -I include/ -o mbr.bin mbr.s

loader.bin: loader.s
	nasm -I include/ -o loader.bin loader.s
