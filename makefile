# Names: Raj Trivedi, Lisa Pathania

CFLAGS=

all: cudablur_p2 cudablur_p3

cudablur_p3: obj/cudablur_p3.o
	nvcc ${CFLAGS} obj/cudablur_p3.o -o cudablur_p3 -lm

cudablur_p2: obj/cudablur_p2.o
	nvcc $(CFLAGS) obj/cudablur_p2.o -o cudablur_p2 -lm

obj/cudablur_p3.o: cudablur_p3.cu
	nvcc -c ${CFLAGS} cudablur_p3.cu -o obj/cudablur_p3.o

obj/cudablur_p2.o: cudablur_p2.cu
	nvcc -c $(CFLAGS) cudablur_p2.cu -o obj/cudablur_p2.o 

clean:
	rm -f obj/* cudablur_p2 cudablur_p3 output.png
