#if HAVE_CONFIG_H
#   include "config.h"
#endif

#if HAVE_STDIO_H
#   include <stdio.h>
#endif
#if HAVE_MATH_H
#   include <math.h>
#endif

#include "ga.h"
#include "macdecls.h"
#include "mp3.h"

/* Override definitions in mp3.h to call MPI_Init_thread */
    static inline int _MPI_INIT_THREAD(int *argc, char ***argv) {
        int status;
        int provided;
        status = MPI_Init_thread(argc, argv, MPI_THREAD_MULTIPLE, &provided);
        return status;
    }
#       define _MP_INIT(argc,argv)   _MPI_INIT_THREAD(&(argc),&(argv))


#define N 2000            /* dimension of matrices */

static inline uint64_t rdtsc_light(void )
{
    uint64_t x;
    __asm__ __volatile__("rdtscp;" /* rdtscp don't jump over earlier instructions */
                         "shl $32, %%rdx;"
                         "or %%rdx, %%rax" :
                         "=a"(x) :
                         :    
                         "%rcx", "%rdx", "memory");
    return x;
}

int ranges[] = {
#include "ranges0"
#include "ranges1"
#include "ranges2"
#include "ranges3"
#include "ranges4"
#include "ranges5"
#include "ranges6"
#include "ranges7"
#include "ranges8"
#include "ranges9"

#include "ranges10"
#include "ranges11"
#include "ranges12"
#include "ranges13"
#include "ranges14"
#include "ranges15"
#include "ranges16"
#include "ranges17"
#include "ranges18"
#include "ranges19"

#include "ranges20"
#include "ranges21"
#include "ranges22"
#include "ranges23"
#include "ranges24"
#include "ranges25"
#include "ranges26"
#include "ranges27"
#include "ranges28"
#include "ranges29"

#include "ranges30"
#include "ranges31"
#include "ranges32"
#include "ranges33"
#include "ranges34"
#include "ranges35"
#include "ranges36"
#include "ranges37"
#include "ranges38"
#include "ranges39"

#include "ranges40"
#include "ranges41"
#include "ranges42"
#include "ranges43"
#include "ranges44"
#include "ranges45"
#include "ranges46"
#include "ranges47"
#include "ranges48"
#include "ranges49"

#include "ranges50"
#include "ranges51"
#include "ranges52"
#include "ranges53"
#include "ranges54"
#include "ranges55"
#include "ranges56"
#include "ranges57"
#include "ranges58"
#include "ranges59"

#include "ranges60"
#include "ranges61"
#include "ranges62"
#include "ranges63"
};

int lranges[] = {
#include "lranges"
};

void do_work()
{
int ONE=1 ;   /* useful constants */
int g_a, g_b;
int n=N, type=MT_F_DBL;
int me=GA_Nodeid(), nproc=GA_Nnodes();
int i, row;
int dims[2]={N,N};
int lo[2], hi[2];

/* Note: on all current platforms DoublePrecision == double */
double buf[N], err, alpha, beta;

long start, end;
 int j, column;

     if(me==0)printf("Creating matrix A\n");
     g_a = NGA_Create(type, 2, dims, "A", NULL);
     if(!g_a) GA_Error("create failed: A",n); 
     if(me==0)printf("OK\n");

     if(me==0)printf("Creating matrix B\n");
     /* create matrix B  so that it has dims and distribution of A*/
     g_b = GA_Duplicate(g_a, "B");
     if(! g_b) GA_Error("duplicate failed",n); 
     if(me==0)printf("OK\n");

     GA_Zero(g_a);   /* zero the matrix */

     if(me==0)printf("Initializing matrix A\n");
     /* fill in matrix A with random values in range 0.. 1 */ 
     lo[1]=0; hi[1]=n-1;
     for(row=me; row<n; row+= nproc){
         /* each process works on a different row in MIMD style */
         lo[0]=hi[0]=row;   
         for(i=0; i<n; i++) buf[i]=sin((double)i + 0.1*(row+1));
         NGA_Put(g_a, lo, hi, buf, &n);
     }

#if 0
     if(me==0)printf("Symmetrizing matrix A\n");
     GA_Symmetrize(g_a);   /* symmetrize the matrix A = 0.5*(A+A') */
   

     /* check if A is symmetric */ 
     if(me==0)printf("Checking if matrix A is symmetric\n");
     GA_Transpose(g_a, g_b); /* B=A' */
     alpha=1.; beta=-1.;
     GA_Add(&alpha, g_a, &beta, g_b, g_b);  /* B= A - B */
     err= GA_Ddot(g_b, g_b);
     
     if(me==0)printf("Error=%f\n",(double)err);
     
     if(me==0)printf("\nChecking atomic accumulate \n");

     GA_Zero(g_a);   /* zero the matrix */
     for(i=0; i<n; i++) buf[i]=(double)i;

     /* everybody accumulates to the same location/row */
     alpha = 1.0;
     row = n/2;
     lo[0]=hi[0]=row;
     lo[1]=0; hi[1]=n-1;
	 //printf("NGA_Acc(%d-%d,%d-%d)\n", lo[0], hi[0], lo[1], hi[1]);
     NGA_Acc(g_a, lo, hi, buf, &ONE, &alpha );
     GA_Sync();

     if(me==0){ /* node 0 is checking the result */

        NGA_Get(g_a, lo, hi, buf,&ONE);
        for(i=0; i<n; i++) if(buf[i] != (double)nproc*i)
           GA_Error("failed: column=",i);
        printf("OK\n\n");

     }
#endif
     
	 /* Communication pattern of mo_trp_trf23K when the w2 data-set */
	 int off = 0;
	 for (i = 0; i < me; i++) {
		 off += lranges[i];
	 }
	 off *= 4;
	 if (me == 1 || me == 63) printf("[%d] off=%d\n", me, off);

	 int count = 0;
	 armci_init_async_thread_();
	 GA_Sync();
	 //MPI_Pcontrol(1, "ga_acc");
	 start = rdtsc_light();

	 for (i = 0; i < lranges[me]; i++) {
			 alpha = 1.0;
			 lo[0] = ranges[off + i * 4];
			 hi[0] = ranges[off + i * 4 + 1];
			 lo[1] = ranges[off + i * 4 + 2];
			 hi[1] = ranges[off + i * 4 + 3];
			 //if (me == 1 || me == 63) printf("NGA_Acc(%d-%d,%d-%d)\n", lo[0], hi[0], lo[1], hi[1]);
			 NGA_Acc(g_a, lo, hi, buf, &ONE, &alpha );
			 //GA_Sync();
			 count++;
	 }

	 //MPI_Pcontrol(-1, "ga_acc");
	end = rdtsc_light();
	armci_finalize_async_thread_();
	GA_Sync();
	printf("ga_acc: %.0f, count: %d\n", (double)(end - start) / count, count);

     GA_Destroy(g_a);
     GA_Destroy(g_b);
}
     


int main(argc, argv)
int argc;
char **argv;
{
int heap=20000, stack=20000;
int me, nproc;

    _MP_INIT(argc,argv);

    GA_INIT(argc,argv);                            /* initialize GA */
    me=GA_Nodeid(); 
    nproc=GA_Nnodes();
    if(me==0) {
       if(GA_Uses_fapi())GA_Error("Program runs with C array API only",1);
       printf("Using %ld processes\n",(long)nproc);
       fflush(stdout);
    }

    heap /= nproc;
    stack /= nproc;
    if(! MA_init(MT_F_DBL, stack, heap)) 
       GA_Error("MA_init failed",stack+heap);  /* initialize memory allocator*/ 
    
    do_work();

    if(me==0)printf("Terminating ..\n");
    GA_Terminate();

    MP_FINALIZE();

    return 0;
}

