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

mkdir -p $EXEC_DIR
cd $EXEC_DIR || { echo "Falha ao entrar em $EXEC_DIR"; exit 1; }

echo ">> Verificando MPI..."
if ! command -v mpicc &> /dev/null; then
    echo "mpicc não encontrado no PATH. Configure manualmente ou carregue o módulo MPI."
    exit 1
fi

echo ">> Clonando repositório..."
rm -rf pdp_run
git clone --depth 1 $REPO_URL pdp_run || { echo "Falha no git clone"; exit 1; }

cd pdp_run || exit 1

echo ">> Compilando programas MPI..."
make clean || true
make || { echo "Falha no make"; exit 1; }

RESULTS_FILE="resultados_mpi.csv"
MACHINEFILE="nodes.$SLURM_JOB_ID"
echo "versao,n_processos,n_maquinas,tamanho,tempo_total,tempo_comunicacao,tempo_computacao" > $RESULTS_FILE

srun -l hostname | sort -n | awk '{print $2}' > $MACHINEFILE
NODES=($(cat $MACHINEFILE))

VERSOES=("mpi_coletiva" "mpi_p2p_bloqueante" "mpi_p2p_naobloqueante")
MATRIZES=(512 1024 2048 4096)
PROCESS_SETS=(1 2 4 8 20 40 80 120 160)

gerar_machinefile_parcial() {
    local n_nodes=$1
    local filename="machinefile_${n_nodes}.txt"
    head -n $n_nodes $MACHINEFILE > $filename
    echo $filename
}

for versao in "${VERSOES[@]}"; do
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

            OUTPUT=$(mpirun -np $nproc \
                -machinefile $MACHINE_SUBSET \
                --bind-to none \
                ./$versao $size $n_maquinas)

            RESULT_LINE=$(echo "$OUTPUT" | grep "^$versao")
            if [ -n "$RESULT_LINE" ]; then
                echo "$RESULT_LINE" >> $RESULTS_FILE
            else
                echo "$versao,$nproc,$n_maquinas,$size,ERROR,ERROR,ERROR" >> $RESULTS_FILE
            fi
        done
    done
done

SAVE_NAME="mpi_exp_pesado_$(date +%Y%m%d_%H%M%S).tgz"
tar czf $SAVE_NAME --exclude=.git --exclude=*.tgz .
mv $SAVE_NAME $SAVE_DIR/
