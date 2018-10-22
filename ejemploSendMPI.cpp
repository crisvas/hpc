#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <mpi.h>

using namespace std;

/* Programa 'hola mundo' donde cada procesador requerido se identifica,
basado en ejemplos orginales de Tim Kaiser (http://www.sdsc.edu/~tkaiser),
del San Diego Supercomputer Center, en California */

int main(int argc, char **argv)
{
    // Find out rank, size
    MPI_Init(&argc,&argv);
    int world_rank;

    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
    int world_size, stop;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);
    printf("world_rank %i", world_rank);
    
    int number;
    if (world_rank == 0) {
        number = -1;
        scanf("%d", &stop);
        MPI_Send(&number, 1, MPI_INT, 1, 0, MPI_COMM_WORLD);
    } else if (world_rank == 1) {
        MPI_Recv(&number, 1, MPI_INT, 0, 0, MPI_COMM_WORLD,
                MPI_STATUS_IGNORE);
        printf("Process 1 received number %d from process 0\n",
            number);
    }
}
