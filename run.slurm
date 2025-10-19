#!/bin/bash
#SBATCH --job-name=mpi_experimentos_m
#SBATCH --partition=hype
#SBATCH --nodes=4
#SBATCH --ntasks=160
#SBATCH --time=04:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

SAVE_DIR=$HOME          
EXEC_DIR=$SCRATCH       
REPO_URL="https://github.com/MateusFauri/pdp_mpi.git"

echo ">> Diretório de execução: $EXEC_DIR"
cd $EXEC_DIR

module load mpi

rm -rf ./pdp_run
git clone --depth 1 $REPO_URL ./pdp_run
cd ./pdp_run

make clean && make

RESULTS_FILE="resultados_mpi.csv"
MACHINEFILE="nodes.$SLURM_JOB_ID"

srun -l hostname | sort -n | awk '{print $2}' > $MACHINEFILE
NODES=($(cat $MACHINEFILE))

echo "versao,n_processos,n_maquinas,tamanho,tempo_total,tempo_comunicacao,tempo_computacao" > $RESULTS_FILE

VERSOES=("mpi_coletiva" "mpi_p2p_bloqueante" "mpi_p2p_naobloqueante")
MATRIZES=(512 1024 2048)
PROCESS_SETS=(1 2 40 80 120 160)

function gerar_machinefile_parcial() {
    local n_nodes=$1
    local filename="machinefile_${n_nodes}.txt"
    head -n $n_nodes $MACHINEFILE > $filename
    echo $filename
}

for versao in "${VERSOES[@]}"; do
    echo "=============================="
    echo "Executando versão: $versao"
    echo "=============================="

    for nproc in "${PROCESS_SETS[@]}"; do
        for size in "${MATRIZES[@]}"; do

            if [ $nproc -le 40 ]; then
                n_maquinas=1
            elif [ $nproc -le 80 ]; then
                n_maquinas=2
            else
                n_maquinas=4
            fi

            MACHINE_SUBSET=$(gerar_machinefile_parcial $n_maquinas)
            echo ">>> ${versao} | N=${size} | np=${nproc} | máquinas=${n_maquinas}"

            OUTPUT=$(mpirun -np $nproc \
                -machinefile $MACHINE_SUBSET \
                --mca btl ^openib \
                --mca btl_tcp_if_include eno2 \
                --bind-to none \
                ./$versao $size)

            TEMPO_TOTAL=$(echo "$OUTPUT" | grep "Execution time" | awk '{print $3}')

            TEMPO_COMUNIC=$(echo "$OUTPUT" | grep "Tempo comunicacao" | awk '{print $4}')
            TEMPO_COMP=$(echo "$OUTPUT" | grep "Tempo computacao" | awk '{print $4}')

            echo "$versao,$nproc,$n_maquinas,$size,$TEMPO_TOTAL,$TEMPO_COMUNIC,$TEMPO_COMP" >> $RESULTS_FILE
        done
    done
done

SAVE_NAME="mpi_experimentos_$(date +%Y%m%d_%H%M%S).tgz"

tar czf $SAVE_NAME --exclude=.git --exclude=*.tgz .
mv $SAVE_NAME $SAVE_DIR/

echo " Job finalizado! Resultados em $RESULTS_FILE"
