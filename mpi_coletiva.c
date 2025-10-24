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
    int rank, size, n = atoi(argv[1]);
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

    double exec_start_time, exec_end_time;
    if(rank == 0)
	    exec_start_time = MPI_Wtime();

    double comm_time = 0.0;
    double comm_start, comm_end;

    comm_start = MPI_Wtime();
    MPI_Scatter(A, n * n / size, MPI_DOUBLE, local_A, n * n / size, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    comm_end = MPI_Wtime();
    comm_time += (comm_end - comm_start);

    comm_start = MPI_Wtime();
    MPI_Bcast(B, n * n, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    comm_end = MPI_Wtime();
    comm_time += (comm_end - comm_start);

    for (int i = 0; i < n / size; i++) {
        for (int j = 0; j < n; j++) {
            local_C[i * n + j] = 0.0;
            for (int k = 0; k < n; k++) {
                local_C[i * n + j] += local_A[i * n + k] * B[k * n + j];
            }
        }
    }

    comm_start = MPI_Wtime();
    MPI_Gather(local_C, n * n / size, MPI_DOUBLE, C, n * n / size, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    comm_end = MPI_Wtime();
    comm_time += (comm_end - comm_start);

    if(rank == 0){
	    exec_end_time = MPI_Wtime();
	    printf("Execution time: %.6f\n", exec_end_time - exec_start_time);
    }

    printf("Rank %d - Communication time: %.6f seconds\n", rank, comm_time);

    free(A); free(B); free(C); free(local_A); free(local_C);
    MPI_Finalize();
    return 0;
}