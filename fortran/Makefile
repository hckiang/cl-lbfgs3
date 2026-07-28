FC      = gfortran
FFLAGS  = -O2 -fPIC
LDFLAGS = -lblas -llapack
SRC     = lbfgsb3.f linpack.f printing.f
LIB     = ../lib/liblbfgsb3.so

all: $(LIB)

$(LIB): *.f
	$(FC) $(FFLAGS) -shared $(LDFLAGS) -o $@ $(SRC)

clean:
	rm -f *.o $(LIB)
