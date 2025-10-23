#!/bin/bash

export PRTE_MCA_ras_slurm_use_entire_allocation=1
export PRTE_MCA_ras_base_launch_orted_on_hn=1

JOBS_DIR="pdp_mpi_jobs"
rm -rf $JOBS_DIR
mkdir -p $JOBS_DIR

OUTPUT_DIR="pdp_mpi_outs"
mkdir -p $OUTPUT_DIR

CODE_DIR=$(pwd)
echo "Usando diretório do código: $CODE_DIR"
make clean && make

declare -a MATRIX_SIZES=("1024" "2048" "4096" "8192")
declare -a PROCESS_TYPES=("coletiva" "p2p_bloqueante" "p2p_naobloqueante")

declare -a NUM_PROCS=(1 2 4 8 16 32 64 80 120 160)

function calc_nodes_needed() {
    local tasks=$1
    echo $(( ($tasks + 39) / 40 ))
}

overall_start=$(date +%s.%N)

for process_type in "${PROCESS_TYPES[@]}"; do
  for matrix_size in "${MATRIX_SIZES[@]}"; do
    for num_procs in "${NUM_PROCS[@]}"; do

      if [[ "$num_procs" -eq 1 ]]; then
        configs=("1x1") 
      elif [[ "$num_procs" -eq 2 ]]; then
        configs=("2x1" "2x2") 
      else
        configs=("auto") 
      fi

      for cfg in "${configs[@]}"; do
        case $cfg in
          "1x1")
            nodes=1
            tasks_per_node=1
            ;;
          "2x1")
            nodes=1
            tasks_per_node=2
            ;;
          "2x2")
            nodes=2
            tasks_per_node=1
            ;;
          "auto")
            nodes=$(calc_nodes_needed $num_procs)
            tasks_per_node=$(( ($num_procs + $nodes - 1) / $nodes ))
            ;;
        esac

        slurm_job_name="mpi_${process_type}_${matrix_size}_${num_procs}_${cfg}"
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
echo \"# Job ID: \$SLURM_JOB_ID\"
echo \"# Job Name: $slurm_job_name\"
echo \"# Tipo: $process_type\"
echo \"# Tamanho da matriz: $matrix_size\"
echo \"# Num procs: $num_procs\"
echo \"# Nodes: $nodes\"
echo \"# Tasks/node: $tasks_per_node\"
echo \"# ----------------------------------------\"

mpirun -np \$SLURM_NTASKS \\
       -machinefile \$MACHINEFILE \\
       --mca btl ^openib \\
       --mca btl_tcp_if_include eno2 \\
       --bind-to none \\
       $CODE_DIR/mpi_$process_type $matrix_size

exit_code=\$?
if [ \$exit_code -ne 0 ]; then
  echo \"Erro no job \$SLURM_JOB_ID: código \$exit_code\" >&2
  exit \$exit_code
fi
"

        temp_job_file="./$JOBS_DIR/${slurm_job_name}.slurm"
        echo "$job_file" > "$temp_job_file"

        if [ "$1" == "--launch" ]; then
          cd $OUTPUT_DIR
          echo "Submetendo: $slurm_job_name"
          sbatch "../$temp_job_file"
          cd ..
        else
          echo "Dry run: $slurm_job_name"
        fi
      done
    done
  done
done

elapsed=$(echo "$(date +%s.%N) - $overall_start" | bc)
echo "Tempo total: $elapsed s"
