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
cd $CODE_DIR

make clean && make
chmod +x mpi_coletiva

echo "Rodando ./mpi_coletiva 1024 ..."
mpirun -np $SLURM_NTASKS \
       --mca btl ^openib \
       --mca btl_tcp_if_include eno2 \
       --bind-to none \
       ./mpi_coletiva 1024

echo "# ======= FIM DO TESTE ======="
