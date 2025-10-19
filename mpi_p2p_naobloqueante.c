#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>

void initialize_matrices(int n, double* A, double* B, double* C){
    for(int i=0;i<n*n;i++){
        A[i]=i%100;
        B[i]=(i%100)+1;
        C[i]=0.0;
    }
}

int main(int argc, char* argv[]){
    int rank, size, n=atoi(argv[1]);
    MPI_Init(&argc,&argv);
    MPI_Comm_rank(MPI_COMM_WORLD,&rank);
    MPI_Comm_size(MPI_COMM_WORLD,&size);

    double *A = (double*)malloc(n*n*sizeof(double));
    double *B = (double*)malloc(n*n*sizeof(double));
    double *C = (double*)malloc(n*n*sizeof(double));
    double *local_A = (double*)malloc((n*n/size)*sizeof(double));
    double *local_C = (double*)malloc((n*n/size)*sizeof(double));

    if(rank==0) initialize_matrices(n,A,B,C);

    double t_total_start=MPI_Wtime();
    double t_comm=0.0, t_comp=0.0, t1, t2;
    MPI_Request req;

    t1=MPI_Wtime();
    if(rank==0){
        for(int i=1;i<size;i++)
            MPI_Isend(A+i*(n*n/size), n*n/size, MPI_DOUBLE, i,0,MPI_COMM_WORLD,&req);
        for(int i=0;i<n*n/size;i++) local_A[i]=A[i];
    } else {
        MPI_Irecv(local_A, n*n/size, MPI_DOUBLE, 0,0,MPI_COMM_WORLD,&req);
        MPI_Wait(&req,MPI_STATUS_IGNORE);
    }
    MPI_Ibcast(B, n*n, MPI_DOUBLE,0,MPI_COMM_WORLD,&req);
    MPI_Wait(&req,MPI_STATUS_IGNORE);
    t2=MPI_Wtime(); t_comm += (t2-t1);

    t1=MPI_Wtime();
    for(int i=0;i<n/size;i++){
        for(int j=0;j<n;j++){
            double sum=0.0;
            for(int k=0;k<n;k++)
                sum += local_A[i*n+k]*B[k*n+j];
            local_C[i*n+j]=sum;
        }
    }
    t2=MPI_Wtime(); t_comp += (t2-t1);

    t1=MPI_Wtime();
    if(rank==0){
        for(int i=0;i<n*n/size;i++) C[i]=local_C[i];
        for(int i=1;i<size;i++){
            MPI_Irecv(C+i*(n*n/size), n*n/size, MPI_DOUBLE, i,1,MPI_COMM_WORLD,&req);
            MPI_Wait(&req,MPI_STATUS_IGNORE);
        }
    } else {
        MPI_Isend(local_C, n*n/size, MPI_DOUBLE,0,1,MPI_COMM_WORLD,&req);
        MPI_Wait(&req,MPI_STATUS_IGNORE);
    }
    t2=MPI_Wtime(); t_comm += (t2-t1);

    double t_total=MPI_Wtime()-t_total_start;
    if(rank==0)
        printf("mpi_p2p_naobloqueante,%d,%d,%d,%.6f,%.6f,%.6f\n", size,1,n,t_total,t_comm,t_comp);

    free(A); free(B); free(C); free(local_A); free(local_C);
    MPI_Finalize();
    return 0;
}
