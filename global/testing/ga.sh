#!/usr/bin/bash

exe=testc
stop=0
reboot=0
go=0
async=0
myasync=0
mck=0
mpitype=intel
disable_uti=1
use_hfi=0
nwchemver=6.8
nnodes=4
LASTNODE=8200

omp_num_threads=1
ppn=16
async_progress_pin=64,132,200,268,65,133,201,269,66,134,202,270,67,135,203,271
lpp=4 # logical-per-physical
ncpu_mt=256 # number of CPUs for main-thread

while getopts srga:n:mp:dN:P:L:M:ho:v:A: OPT
do
        case ${OPT} in
	    s) stop=1
		;;
            r) reboot=1
                ;;
            g) go=1
                ;;
	    a) async=$OPTARG
		;;
            m) mck=1
                ;;
	    p) async_progress_pin=$OPTARG
		;;
            d) disable_uti=1
                ;;
	    N) nnodes=$OPTARG
		;;
	    P) ppn=$OPTARG
		;;
	    L) LASTNODE=$OPTARG
		;;
	    M) mpitype=$OPTARG
		;;
	    h) use_hfi=1
		;;
	    o) omp_num_threads=$OPTARG
		;;
            v) nwchemver=$OPTARG
                ;;
	    A) myasync=$OPTARG
		;;
            *) echo "invalid option -${OPT}" >&2
                exit 1
        esac
done

if [ $mck -eq 1 ] && [ $async -eq 0 ] && [ $disable_uti -eq 0 ]; then
    echo "Turn off uti when async progress thread is not created."
fi

if [ "$nwchem_ver" == "6.6" ] || [ "$mpitype" != "intel" ]; then
    parallel=0
else
    parallel=2
fi

MYHOME=/work/gg10/e29005
GA_TOP=${MYHOME}/project/src/ga/ga-5.6.3/global/testing
if [ "$mpitype" == "intel" ]; then
    MPILIB=/home/opt/local/cores/intel/impi/2018.1.163/intel64
elif [ "$mpitype" == "openmpi" ]; then
    MPILIB=${MYHOME}/project/src/openmpi/install
elif [ "$mpitype" == "mpich" ]; then
    MPILIB=${MYHOME}/project/mpich/install
else
    echo "unknown mpitype: $mpitype"
    exit 1
fi
MCK=${MYHOME}/project/os/install

nprocs=$((ppn * nnodes))
nodes=`echo $(seq -s ",c" $(($LASTNODE + 1 - $nnodes)) $LASTNODE) | sed 's/^/c/'`
echo nprocs=$nprocs nnodes=$nnodes ppn=$ppn nodes=$nodes

PDSH_SSH_ARGS_APPEND="-tt -q" pdsh -t 2 -w $nodes bash -c \'if \[ \"\`cat /etc/mtab \| while read line\; do cut -d\" \" -f 2\; done \| grep /work\`\" == \"\" \]\; then sudo mount /work\; fi\'

if [ ${disable_uti} -eq 1 ]; then
    export DISABLE_UTI=1
else
    unset DISABLE_UTI
fi

if [ "$mpitype" == "intel" ] || [ "$mpitype" == "openmpi" ] || [ "$mpitype" == "mpich" ]; then
    if [ $disable_uti -eq 1 ] || [ $myasync -eq 1 ]; then
	uti_thread_rank=0 # disable clone count based uti
    else
	uti_thread_rank=2 # main thread, async progress thread, omp threads (N-1)
    fi
fi

if [ ${mck} -eq 1 ]; then
    MCEXEC="${MCK}/bin/mcexec"
    nmcexecthr=$((256 / ppn + 4))
    if [ "$mpitype" == "intel" ] || [ "$mpitype" == "openmpi" ] || [ "$mpitype" == "mpich" ]; then
	if [ "`$MCEXEC --help 2>&1 | grep '\-\-uti\-thread\-rank'`" != "" ]; then
	    mcexecopt="--uti-thread-rank=$uti_thread_rank"
	else
	    echo "WARNING: --uti-thread-rank not available"
	fi
    fi
    if [ ${use_hfi} -eq 1 ]; then
	mcexecopt="--enable-hfi1 $mcexecopt"
    fi
    if [ "`$MCEXEC --help 2>&1 | grep '\-\-uti\-use\-last\-cpu'`" != "" ]; then
	mcexecopt="--uti-use-last-cpu $mcexecopt"
    else
	echo "WARNING: --uti-use-last-cpu not available"
    fi
    mcexecopt="-n $ppn -t $nmcexecthr -m 1 $mcexecopt"
else
    MCEXEC=
    mcexecopt=
fi

if [ ${parallel} -eq 5 ]; then
    ilpopt="-ilp64"
else
    ilpopt=""
fi

if [ ${stop} -eq 1 ]; then
    if [ ${mck} -eq 1 ]; then
	PDSH_SSH_ARGS_APPEND="-tt -q" pdsh -t 2 -w $nodes \
	    /sbin/pidof mcexec \| xargs -r kill -9
	PDSH_SSH_ARGS_APPEND="-tt -q" pdsh -t 2 -w $nodes \
	    sudo ${MCK}/sbin/mcstop+release.sh
    else
	:
    fi
fi

if [ ${reboot} -eq 1 ]; then
    if [ ${mck} -eq 1 ]; then
	PDSH_SSH_ARGS_APPEND="-tt -q" pdsh -t 2 -w $nodes \
	    sudo ${MCK}/sbin/mcreboot.sh -c 2-17,70-85,138-153,206-221,20-35,88-103,156-171,224-239,36-51,104-119,172-187,240-255,52-67,120-135,188-203,256-271 -r 2-5,70-73,138-141,206-209:0+6-9,74-77,142-145,210-213:1+10-13,78-81,146-149,214-217:68+14-17,82-85,150-153,218-221:69+20-23,88-91,156-159,224-227:136+24-27,92-95,160-163,228-231:137+28-31,96-99,164-167,232-235:204+32-35,100-103,168-171,236-239:205+36-39,104-107,172-175,240-243:18+40-43,108-111,176-179,244-247:19+44-47,112-115,180-183,248-251:86+48-51,116-119,184-187,252-255:87+52-55,120-123,188-191,256-259:154+56-59,124-127,192-195,260-263:155+60-63,128-131,196-199,264-267:222+64-67,132-135,200-203,268-271:223 -m 32G@0,12G@1
    else
	:
    fi
fi

# Calculate CPU set of rank 
if [ $((omp_num_threads * lpp * ppn)) -le $ncpu_mt ]; then
    domain=$((omp_num_threads * lpp)) # Prefer physical but adjacent physicals share L1
else
    domain=$((ncpu_mt / ppn)) # Use logical as well
fi 

if [ ${go} -eq 1 ]; then
    cd ${GA_TOP}
    PDSH_SSH_ARGS_APPEND="-tt -q" pdsh -t 2 -w $nodes \
	ulimit -u 16384; 
    PDSH_SSH_ARGS_APPEND="-tt -q" pdsh -t 2 -w $nodes \
	ulimit -s unlimited
    PDSH_SSH_ARGS_APPEND="-tt -q" pdsh -t 2 -w $nodes \
	ulimit -c unlimited
    if [ "$mpitype" == "intel" ]; then

	export I_MPI_HYDRA_BOOTSTRAP_EXEC=/usr/bin/ssh
	export I_MPI_HYDRA_BOOTSTRAP=ssh

	export OMP_NUM_THREADS=$omp_num_threads
	#export OMP_STACKSIZE=64M
	export KMP_BLOCKTIME=1

        if [ ${mck} -eq 1 ]; then
	    export I_MPI_PIN=off
	else
	    export I_MPI_PIN=on
	    export I_MPI_PIN_DOMAIN=$domain
	    export I_MPI_PIN_ORDER=compact
	fi
	export HFI_NO_CPUAFFINITY=1
	export I_MPI_COLL_INTRANODE_SHM_THRESHOLD=4194304
	export I_MPI_FABRICS=shm:tmi
	export PSM2_RCVTHREAD=0
	export I_MPI_TMI_PROVIDER=psm2
	export I_MPI_FALLBACK=0
	export PSM2_MQ_RNDV_HFI_WINDOW=4194304
	export PSM2_MQ_EAGER_SDMA_SZ=65536
	export PSM2_MQ_RNDV_HFI_THRESH=200000

	export MCKERNEL_RLIMIT_STACK=32M,16G
	export KMP_STACKSIZE=64m
	export KMP_AFFINITY=granularity=thread,scatter
	#export KMP_HW_SUBSET=$((64 / ppn))c,1t

	export I_MPI_ASYNC_PROGRESS=$async
	if [ $async -eq 1 ] && [ "$async_progress_pin" != "" ] ; then
	    export I_MPI_ASYNC_PROGRESS_PIN=$async_progress_pin
	fi

	export MY_ASYNC_PROGRESS=$myasync
	if [ $myasync -eq 1 ]; then
	    export MY_ASYNC_PROGRESS_PIN=$async_progress_pin
	fi
	if [ $myasync -eq 1 ] && [ $mck -eq 1 ]; then
	    export MY_ASYNC_PROGRESS_MCK=on
	fi

	#export I_MPI_STATS=native:20,ipm
	export I_MPI_STATS=ipm
	export I_MPI_DEBUG=4
	export f77_dump_flag=TRUE

	. /home/opt/local/cores/intel/compilers_and_libraries_2018.1.163/linux/bin/compilervars.sh intel64
	mpiexec.hydra -l -n $nprocs -ppn $ppn -hosts $nodes $ilpopt bash -c '. /home/opt/local/cores/intel/compilers_and_libraries_2018.1.163/linux/bin/compilervars.sh intel64; '"$MCEXEC $mcexecopt ./$exe "
    elif [ "$mpitype" == "openmpi" ]; then

	export PATH=${MPILIB}/bin:$PATH
	export LD_LIBRARY_PATH=${MPILIB}/lib:/opt/intel/compilers_and_libraries_2018.1.163/linux/compiler/lib/intel64_lin/:/opt/intel/compilers_and_libraries_2018.1.163/linux/mkl/lib/intel64_lin/:$LD_LIBRARY_PATH

	export OMP_NUM_THREADS=$omp_num_threads
	export OMP_STACKSIZE=64M

	export PSM2_RCVTHREAD=0

	export MCKERNEL_RLIMIT_STACK=32M,16G

	export MPIR_CVAR_ASYNC_PROGRESS=$async
	if [ $async -eq 1 ] && [ "$async_progress_pin" != "" ] ; then
	    export I_MPI_ASYNC_PROGRESS_PIN=$async_progress_pin
	fi

	export f77_dump_flag=TRUE
    
	
	((for i in $(seq $(($LASTNODE + 1 - $nnodes)) $LASTNODE); do echo c$i; done) | sed 's/$/.ofp/') > ./hostfile

	${MPILIB}/bin/mpirun -n $nprocs --hostfile ./hostfile --map-by ppr:$ppn:node:pe=$((domain / lpp)) --report-bindings $ilpopt $MCEXEC $mcexecopt ./bin/LINUX64/nwchem $nwchemopt
	# Put $ppn ranks on each node, width of $domain PEs

    elif [ "$mpitype" == "mpich" ]; then

	export PATH=${MPILIB}/bin:$PATH
	export LD_LIBRARY_PATH=${MPILIB}/lib:/opt/intel/compilers_and_libraries_2018.1.163/linux/compiler/lib/intel64_lin/:/opt/intel/compilers_and_libraries_2018.1.163/linux/mkl/lib/intel64_lin/:$LD_LIBRARY_PATH

	export MPIR_CVAR_OFI_USE_PROVIDER=psm2
	export HYDRA_PROXY_RETRY_COUNT=30

	export OMP_NUM_THREADS=$omp_num_threads
	#export OMP_STACKSIZE=64M
	export KMP_BLOCKTIME=1

	export PSM2_RCVTHREAD=0

	export MCKERNEL_RLIMIT_STACK=32M,16G
	export KMP_STACKSIZE=64m
	export KMP_AFFINITY=granularity=thread,scatter

	export MPIR_CVAR_ASYNC_PROGRESS=$async
	if [ $async -eq 1 ] && [ "$async_progress_pin" != "" ] ; then
	    export I_MPI_ASYNC_PROGRESS_PIN=$async_progress_pin
	fi

	export MY_ASYNC_PROGRESS=$myasync
	if [ $myasync -eq 1 ]; then
	    export MY_ASYNC_PROGRESS_PIN=$async_progress_pin
	fi
	
	export f77_dump_flag=TRUE

	${MPILIB}/bin/mpiexec.hydra -l -n $nprocs -ppn $ppn -hosts $nodes -bind-to hwthread:$domain -map-by hwthread:$domain $MCEXEC $mcexecopt ./bin/LINUX64/nwchem $nwchemopt
    fi
fi
