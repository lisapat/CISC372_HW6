# Names: Raj Trivedi, Lisa Pathania

CFLAGS=

all: fastblur cudablur_Part2 cudablur_Part3

cudablur_Part3: obj/cudablur_Part3.o
	nvcc ${CFLAGS} obj/cudablur_Part3.o -o cudablur_Part3 -lm

cudablur_Part2: obj/cudablur_Part2.o
	nvcc $(CFLAGS) obj/cudablur_Part2.o -o cudablur_Part2 -lm

fastblur: obj/fastblur.o
	gcc ${CFLAGS} obj/fastblur.o -o fastblur -lm

obj/cudablur_Part3.o: cudablur_Part3.cu
	nvcc -c ${CFLAGS} cudablur_Part3.cu -o obj/cudablur_Part3.o

obj/cudablur_Part2.o: cudablur_Part2.cu
	nvcc -c $(CFLAGS) cudablur_Part2.cu -o obj/cudablur_Part2.o

obj/fastblur.o: fastblur.c
	gcc -c ${CFLAGS} fastblur.c -o obj/fastblur.o

clean:
	rm -f obj/* fastblur cudablur_Part2 cudablur_Part3 output.png
