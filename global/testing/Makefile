CC=mpiicc
LD=mpiicc
CPPFLAGS=-I.. -I/work/gg10/e29005/project/src/ga/install/include
LDFLAGS=-L/work/gg10/e29005/project/src/ga/install/lib -L/work/gg10/e29005/project/src/armci-mpi/install/lib -lga -larmci -lmkl_scalapack_lp64 -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -lmkl_blacs_intelmpi_lp64 -liomp5 -lpthread -lifcore

testc: testc.o
	$(LD) -o $@ $^ $(LDFLAGS)

%.o :: %.c
	$(CC) $(CPPFLAGS) -c $<
