#!/bin/bash
#SBATCH --job-name=mpi_experimentos_m
#SBATCH --partition=hype
#SBATCH --nodes=4
#SBATCH --ntasks=160
#SBATCH --time=06:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

export PRTE_MCA_ras_slurm_use_entire_allocation=1
export PRTE_MCA_ras_base_launch_orted_on_hn=1
export OMPI_MCA_mtl=^ofi
export OMPI_MCA_pml=ob1
export OMPI_MCA_btl=tcp,self
export OMPI_MCA_btl_tcp_if_include=eno2



SCRATCH_DIR=$SCRATCH/pdp_mpi
rm -rf $SCRATCH_DIR
git clone --depth 1 https://github.com/MateusFauri/pdp_mpi.git $SCRATCH_DIR
cd $SCRATCH_DIR

make clean
make

OUTPUT_DIR="$SCRATCH_DIR/pdp_mpi_outs"
mkdir -p $OUTPUT_DIR

declare -a MATRIX_SIZES=("1024" "2048" "4096" "8192")
declare -a PROCESS_TYPES=("coletiva" "p2p_bloqueante" "p2p_naobloqueante")
MAX_PROCS=$SLURM_NTASKS
MAX_NODES=$SLURM_JOB_NUM_NODES
PROCESS_SETS=(1 2 4 8 20 40 80 120 160)


overall_start=$(date +%s.%N)

generate_machinefile() {
    local nodes=$1
    local procs=$2
    local file=$3
    srun -l hostname | sort -n | awk '{print $2}' | head -n $nodes | while read node; do
        for ((i=0;i<$procs;i++)); do
            echo $node
        done
    done > $file
}


for num_procs in "${PROCESS_SETS[@]}"; do
    nodes_used=$(( num_procs < MAX_NODES ? num_procs : MAX_NODES ))
    
    if [ $num_procs -eq 2 ]; then
        nodes_options=(1 2)
    else
        nodes_options=($nodes_used)
    fi

    for nodes_to_use in "${nodes_options[@]}"; do
        procs_per_node=$(( (num_procs + nodes_to_use -1)/nodes_to_use ))
        MACHINEFILE="nodes_${num_procs}procs_${nodes_to_use}nodes.$SLURM_JOB_ID"
        generate_machinefile $nodes_to_use $procs_per_node $MACHINEFILE

        for matrix_size in "${MATRIX_SIZES[@]}"; do
            for process_type in "${PROCESS_TYPES[@]}"; do
                echo "----------------------------------------"
                echo "Process type: $process_type"
                echo "Matrix size: $matrix_size"
                echo "Num processes: $num_procs on $nodes_to_use nodes"
                start_time=$(date +%s.%N)

                mpirun -np $num_procs \
                       -machinefile $MACHINEFILE \
                       --mca btl ^openib \
                       --mca btl_tcp_if_include eno2 \
                       --bind-to none \
                       $SCRATCH_DIR/mpi_$process_type $matrix_size

                exit_code=$?
                end_time=$(date +%s.%N)
                elapsed=$(echo "$end_time - $start_time" | bc)

                if [ $exit_code -ne 0 ]; then
                    echo "ERRO: $process_type com matriz $matrix_size e $num_procs processos falhou ($exit_code) após $elapsed s"
                    continue
                fi

                echo "Concluído: $process_type com matriz $matrix_size e $num_procs processos em $elapsed s"
                echo "----------------------------------------"
            done
        done
    done
done

overall_end=$(date +%s.%N)
total_elapsed=$(echo "$overall_end - $overall_start" | bc)
