#!/bin/bash
#SBATCH --job-name=test_mpi
#SBATCH --partition=hype
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --time=00:05:00
#SBATCH --output=test_mpi_%j.out
#SBATCH --error=test_mpi_%j.err

echo "# ======= TESTE MPI ======="
echo "# Job ID: $SLURM_JOB_ID"
echo "# Host principal: $(hostname)"
echo "# Diretório de trabalho: $(pwd)"
echo "# =========================="

srun -l hostname

CODE_DIR=$PWD
cd "$CODE_DIR" || exit 1

make clean
make all

if [ ! -f "./mpi_coletiva" ]; then
    echo "Erro: executável ./mpi_coletiva não encontrado!" >&2
    exit 1
fi
chmod +x ./mpi_coletiva

echo "Rodando ./mpi_coletiva 1024 ..."

srun --mpi=pmix_v3 ./mpi_coletiva 1024

echo "# ======= FIM DO TESTE ======="
