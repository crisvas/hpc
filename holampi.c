#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>
 
/* Programa 'hola mundo' donde cada procesador requerido se identifica,
basado en ejemplos orginales de Tim Kaiser (http://www.sdsc.edu/~tkaiser),
del San Diego Supercomputer Center, en California */

int main(int argc, char **argv)
{
    int myid, numprocs;
    FILE *arch;
 
    MPI_Init(&argc,&argv);
    MPI_Comm_size( MPI_COMM_WORLD, &numprocs ); // devuelve el numero de procesos en este COMM_WORLD
    MPI_Comm_rank( MPI_COMM_WORLD, &myid );     // identificate por el myid asignado  
 
    printf("Soy el procesador %d de un total de %d\n",myid,numprocs);
    
    if(myid == 1) // solamente para el procesador 1
    {
       // ajusta la ruta del archivo si es necesario 
       arch=fopen("/home/pepe/archivo.txt","w");
       fprintf(arch,"Hola, soy el procesador 1\n");
       fclose(arch);
    }
	
    MPI_Finalize();
	
    return 0;
}