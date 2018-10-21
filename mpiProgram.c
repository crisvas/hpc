#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "mpi.h"
#define MSGTAG   0

#define N 6
void initMatrix(int *matrix)
{
	int i;
	for(i=0;i<N*N;i++,matrix++)
		*matrix=i+1;
}

int main ( int argc, char* argv[] )
{
  int p_id;
  int p;
  int currNumRows;

  int *matrixOp1=NULL;//Se debe definie aqui para que la matrix solo se cree inicialmente en el nodo Root

  MPI_Status status;
  MPI_Init ( &argc, &argv );
  MPI_Comm_rank ( MPI_COMM_WORLD, &p_id );
  MPI_Comm_size ( MPI_COMM_WORLD, &p );

  ////////////////////////////////Root Node///////////////////////////////////////////////////
  if(p_id==0)
  {
	matrixOp1=(int *)malloc(sizeof(int)*(N*N));//se reserva memoria para la matriz
	initMatrix(matrixOp1);//se inicializa la matriz;
	currNumRows=N*N;
	int myNum=0;
	////////////////Send a msg to each son node////////////////////////////////////////
  	for(int i=0;i<ceil(log2(p));i++)
	{
		int sonNode=(int)(pow(2,i)+p_id);
		MPI_Send (currNumRows/2, 1,MPI_INT, sonNode, MSGTAG, MPI_COMM_WORLD);
		MPI_Send (matrixOp1, currNumRows/2,MPI_INT, sonNode, MSGTAG, MPI_COMM_WORLD);	
		currNumRows=currNumRows-(currNumRows/2);
		}
	////////////////Receives and processes the msg from each son node///////////////////
	for(int i=0 ;i<ceil(log2(p));i++)
	{
		int sonNode=(int)(pow(2,i)+p_id);	
		antLenMsg=LenMsg;
		if(lenMsg%2==0)
			lenMsg=lenMsg/2;
		else
			if(lenMsg>N)
				lenMsg=(((lenMsg/N)/2)+1)*7;
			else
				lenMsg=(lenMsg/2)+1;			
		MPI_Recv ( &myNum, 1, MPI_INT, sonNode, MSGTAG, MPI_COMM_WORLD, &status );
		
		}
	////////////////////////////////Shows the result/////////////////////////////////////
	printf("The result for num was %d\n",myNum);
	}
  ////////////////////////////Intermediate Nodes/////////////////////////////////////////////
  else if((int)(floor(log2(p_id))+1)<(int)(ceil(log2(p))))
  {
	int myNum=0;
	int fatherNode=(int)(p_id-pow(2,floor(log2(p_id))));
	lenMsg=(pow(2,floor(log2(p_id))))+N;//se calcula el tamaño del mensaje a recibir
	matrixOp1=(int *)malloc(sizeof(int)*lenMsg);//se reserva memoria para la matriz
	//////////////////////Receives the msg from father node////////////////////////////
	MPI_Recv ( matrixOp1, lenMsg, MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD, &status );
	//////////////////////////Send a msg to each son node//////////////////////////////
	for(int i=floor(log2(p_id))+1 ;i<ceil(log2(p));i++)
	{
		int sonNode=(int)(pow(2,i)+p_id);
		if(sonNode<p)
		{		
			MPI_Send ( matrixOp1, 36,MPI_INT,sonNode, MSGTAG, MPI_COMM_WORLD);			
		}	
	}
	////////////////Receives and processes the msg from each son node///////////////////
	for(int i=floor(log2(p_id))+1 ;i<ceil(log2(p));i++)
	{
	
		int sonNode=(int)(pow(2,i)+p_id);
		if(sonNode<p)
		{
			MPI_Recv ( &myNum, 1, MPI_INT, sonNode, MSGTAG, MPI_COMM_WORLD, &status );						
		}
	}
	//////////////Send back the result to father node////////////////////////////////////	
	MPI_Send ( &myNum, 1,MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD);

  }
  /////////////////////////Leaf Nodes////////////////////////////////////////////////////////
  else
  {	
	int fatherNode=(int)(p_id-pow(2,floor(log2(p_id))));
	int matrix[6][6]={{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0},{0,0,0,0,0,0}};
	//////////////////////Receives and processes the msg from father node/////////////////
	MPI_Recv ( matrix, 36, MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD, &status );
	int value=matrix[1][1];	
	//////////////Send back the result to father node////////////////////////////////////
	MPI_Send ( &value, 1,MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD);
	}	
  MPI_Finalize ();
  return ( 0 );
}
