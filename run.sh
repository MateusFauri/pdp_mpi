#!/bin/bash

export PRTE_MCA_ras_slurm_use_entire_allocation=1
export PRTE_MCA_ras_base_launch_orted_on_hn=1

CODE_DIR=$(pwd)
JOBS_DIR="$CODE_DIR/pdp_mpi_jobs"
OUTPUT_DIR="$CODE_DIR/pdp_mpi_outs"

rm -rf "$JOBS_DIR"
mkdir -p "$JOBS_DIR" "$OUTPUT_DIR"

make clean
make all

declare -a MATRIX_SIZES=("1024" "2048" "4096" "8192")
declare -a PROCESS_TYPES=("coletiva" "p2p_bloqueante" "p2p_naobloqueante")
declare -a NUM_PROCS=(1 2 4 8 16 32 64 80 120 160)

calc_nodes_needed() {
    local tasks=$1
    echo $(( (tasks + 39) / 40 ))
}

echo "Running MPI sbatches to compare algorithm scaling:"
echo "MATRIX_SIZES: ${MATRIX_SIZES[@]}"
echo "NUM_PROCS: ${NUM_PROCS[@]}"
echo "PROCESS_TYPES: ${PROCESS_TYPES[@]}"
echo "----------------------------------------"

overall_start=$(date +%s.%N)

for process_type in "${PROCESS_TYPES[@]}"; do
  for matrix_size in "${MATRIX_SIZES[@]}"; do
    for num_procs in "${NUM_PROCS[@]}"; do

        nodes=$(calc_nodes_needed $num_procs)
        tasks_per_node=$(( (num_procs + nodes - 1) / nodes ))

        slurm_job_name="mpi_${process_type}_${matrix_size}_${num_procs}"
        slurm_time_limit="2:00:00"

        job_file="#!/bin/bash
#SBATCH --job-name=$slurm_job_name
#SBATCH --partition=hype
#SBATCH --nodes=$nodes
#SBATCH --ntasks=$num_procs
#SBATCH --ntasks-per-node=$tasks_per_node
#SBATCH --time=$slurm_time_limit
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

MACHINEFILE=\"nodes.\$SLURM_JOB_ID\"
srun -l hostname | sort -n | awk '{print \$2}' > \$MACHINEFILE

echo \"# ----------------------------------------\"
echo \"# job id: \$SLURM_JOB_ID\"
echo \"# job name: $slurm_job_name\"
echo \"# Running process type: $slurm_process_type\"
echo \"# Matrix size: $slurm_matrix_size\"
echo \"# Number of processes: $slurm_num_tasks\"
echo \"# Number of nodes: $nodes\"
echo \"# Tasks per node: $tasks_per_node\"
current_time=\$(date '+%d-%m-%Y %H:%M:%S.%M')
echo \"# Current time: \$current_time\"
echo \"# ----------------------------------------\"

echo \"# ----------------------------------------\" >&2
echo \"# job id: \$SLURM_JOB_ID\" >&2
echo \"# job name: $slurm_job_name\" >&2
echo \"# Running process type: $slurm_process_type\" >&2
echo \"# Matrix size: $slurm_matrix_size\" >&2
echo \"# Number of processes: $slurm_num_tasks\" >&2
echo \"# Number of nodes: $nodes\"
echo \"# Tasks per node: $tasks_per_node\"
current_time=\$(date '+%d-%m-%Y %H:%M:%S.%M') >&2
echo \"# Current time: \$current_time\" >&2
echo \"# ----------------------------------------\" >&2

mpirun -np \$SLURM_NTASKS \\
       -machinefile \$MACHINEFILE \\
       --mca btl ^openib \\
       --mca btl_tcp_if_include eno2 \\
       --bind-to none -np \$SLURM_NTASKS \\
       $CODE_DIR/mpi_$slurm_process_type $slurm_matrix_size
       
exit_code=\$?
if [ \$exit_code -ne 0 ]; then
    echo \"# Error: Process $slurm_process_type with matrix size $slurm_matrix_size and $slurm_num_tasks processes failed with exit code \$exit_code after \$job_lasted seconds\"
    echo \"# ----------------------------------------\"
    echo \"# Error: Process $slurm_process_type with matrix size $slurm_matrix_size and $slurm_num_tasks processes failed with exit code \$exit_code after \$job_lasted seconds\" >&2
    echo \"# ----------------------------------------\" >&2
    exit \$exit_code
fi


echo \"# Finished running $process_type with matrix size $matrix_size and $num_procs processes\"
echo \"# ----------------------------------------\"

echo \"# Finished running $process_type with matrix size $matrix_size and $num_procs processes\" >&2
echo \"# ----------------------------------------\" >&2
"

        temp_job_file="$JOBS_DIR/${slurm_job_name}.slurm"
        echo "$job_file" > "$temp_job_file"

        if [ "$1" == "--launch" ]; then
            cd "$OUTPUT_DIR"
            echo "Submitting job: $slurm_job_name"
            sbatch "../$temp_job_file"
            cd "$CODE_DIR"
        else
            echo "Dry run: Would submit job: $slurm_job_name"
        fi
    done
  done
done

elapsed=$(echo "$(date +%s.%N) - $overall_start" | bc)
echo "All tasks processed. Time elapsed: $elapsed seconds"
