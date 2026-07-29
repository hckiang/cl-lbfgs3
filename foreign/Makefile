FC      = gfortran
CC      ?= cc

FFLAGS  = -O2 -fPIC -ffunction-sections -fdata-sections
CFLAGS  = -O2 -fPIC -Wall -Wextra -ffunction-sections -fdata-sections

FSRC    = lbfgsb3.f linpack.f printing.f
CSRC    = linking.c

FOBJ    = $(FSRC:.f=.o)
COBJ    = linking.o

LIBDIR  = ../lib
LIB     = $(LIBDIR)/liblbfgsb3.so
CLIB    = $(LIBDIR)/liblinking.so

# Netlib BLAS/Lapack should be thread safe
#-llapack
BLAS_LIBS ?= -lblas 

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),FreeBSD)
  FFLAGS  += -ftls-model=global-dynamic
  CFLAGS  += -ftls-model=global-dynamic
endif

ifeq ($(UNAME_S),Linux)
  LDFLAGS += -ldl
endif

LDFLAGS = -shared \
          -Wl,--gc-sections

EXTRA_LIBS = -lm -lpthread

.PHONY: all clean

all: $(LIB) $(CLIB)

$(LIB): $(FOBJ)
	@mkdir -p $(LIBDIR)
	$(FC) $(LDFLAGS) -o $@ $(FOBJ) $(BLAS_LIBS) $(EXTRA_LIBS)

$(CLIB): $(COBJ) $(LIB)
	$(CC) $(LDFLAGS) -o $@ $(COBJ) -L$(LIBDIR) $(EXTRA_LIBS)

# Fortran objects
%.o: %.f
	$(FC) $(FFLAGS) -c $< -o $@

# C object (library version – no TEST_MAIN)
$(COBJ): $(CSRC)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(FOBJ) $(COBJ) $(LIB) $(CLIB)
