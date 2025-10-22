#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>

void initialize_matrices(int n, double* A, double* B, double* C){
    for (int i = 0; i < n * n; i++) {
        A[i] = i % 100;
        B[i] = (i % 100) + 1;
        C[i] = 0.0;
    }
}

int main(int argc, char* argv[]) {
    int rank, size, n, n_machines = 1;

    if (argc < 2) {
        if (rank == 0) fprintf(stderr, "Uso: %s <tamanho> [n_maquinas]\n", argv[0]);
        return 1;
    }

    n = atoi(argv[1]);
    if (argc > 2) n_machines = atoi(argv[2]); 

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    double *A = (double*)malloc(n * n * sizeof(double));
    double *B = (double*)malloc(n * n * sizeof(double));
    double *C = (double*)malloc(n * n * sizeof(double));
    double *local_A = (double*)malloc((n * n / size) * sizeof(double));
    double *local_C = (double*)malloc((n * n / size) * sizeof(double));

    if (rank == 0)
        initialize_matrices(n, A, B, C);

    double t_total_start = MPI_Wtime();
    double t_comm = 0.0, t_comp = 0.0, t1, t2;

    t1 = MPI_Wtime();
    MPI_Scatter(A, n * n / size, MPI_DOUBLE, local_A, n * n / size, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    MPI_Bcast(B, n * n, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    t2 = MPI_Wtime();
    t_comm += (t2 - t1);

    t1 = MPI_Wtime();
    for (int i = 0; i < n / size; i++) {
        for (int j = 0; j < n; j++) {
            double sum = 0.0;
            for (int k = 0; k < n; k++)
                sum += local_A[i * n + k] * B[k * n + j];
            local_C[i * n + j] = sum;
        }
    }
    t2 = MPI_Wtime();
    t_comp += (t2 - t1);

    t1 = MPI_Wtime();
    MPI_Gather(local_C, n * n / size, MPI_DOUBLE, C, n * n / size, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    t2 = MPI_Wtime();
    t_comm += (t2 - t1);

    double t_total = MPI_Wtime() - t_total_start;

    if (rank == 0) {
        printf("mpi_coletiva,%d,%d,%d,%.6f,%.6f,%.6f\n",
               size, n_machines, n, t_total, t_comm, t_comp);
        fflush(stdout);
    }

    free(A); free(B); free(C); free(local_A); free(local_C);
    MPI_Finalize();
    return 0;
}
