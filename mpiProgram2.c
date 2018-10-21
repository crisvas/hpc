#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "mpi.h"
#define MSGTAG   0

#define N 6
typedef struct NODE
{
	int sonId;
	int tam;
	int filaInicial;
	struct NODE *next;
}Node;

Node* insert(Node *head,int sonId,int filaInicial,int tam)
{
	Node *newN=NULL;
	newN=(Node *)malloc(sizeof(Node));
	newN->sonId=sonId;
	newN->tam=tam;
	newN->filaInicial=filaInicial;
	newN->next=head;
	return newN;
}

Node* pop(Node *head)
{
	Node *newHead=NULL;
	newHead=head->next;
	free(head);
	return newHead;
}

void show(int *M)
{	
	int i;
	for(i=0;i<N*N;i++,M++)
		if((i+1)%N!=0)
			printf("%d=>%p, ",*M,M);
		else
			printf("%d=>%p\n",*M,M);	
}

void initMatrix(int *matrix)
{
	int i,k=1;
	for(i=0;i<N*N;i++,matrix++)
	{
		*matrix=k;
		if((i+1)%N==0)
			k++;
	}
}

int main ( int argc, char* argv[] )
{
  int p_id;
  int p;

  //variables necesarias para la reparticion de carga entre los procesos
  int currNumRows=0;
  int numRows=0;
  int sonNode=0;
  int i,j,k,res;

  Node *head=NULL;

  int *matrixOp1=NULL;//Se debe declara aqui porque es usada por todos los procesos, matriz operando 1
  int *matrixOp2=NULL;//Se debe declara aqui porque es usada por todos los procesos, matriz operando 2
  int *matrixRes=NULL;//Se debe declara aqui porque es usada por todos los procesos, matriz de resultado reducido de cada procesos
  int *matrixResAux=NULL;//Se debe declara aqui porque es usada por todos los procesos, matriz de resultado de procesos hijos
  int *matrixResAux2=NULL;//Se debe declara aqui porque es usada por todos los procesos, matriz de resultado de procesos hijos

  matrixOp2=(int *)malloc(sizeof(int)*(N*N));//se reserva memoria para la matriz operando 2
  matrixOp2=(int *)memset(matrixOp2,0,N*N*4);//se definen los valores para la matriz operando 2, se hace aqui pues la matriz operando 2 no se reparte 

  MPI_Status status;
  MPI_Init ( &argc, &argv );
  MPI_Comm_rank ( MPI_COMM_WORLD, &p_id );
  MPI_Comm_size ( MPI_COMM_WORLD, &p );

  ////////////////////////////////Root Node///////////////////////////////////////////////////
  if(p_id==0)
  {
	matrixOp1=(int *)malloc(sizeof(int)*(N*N));//se reserva memoria para la matriz operando 1 para el nodo raiz
	matrixRes=(int *)malloc(sizeof(int)*(N*N));//se reserva memoria para la matriz resultado del nodo raiz
	
	initMatrix(matrixOp1);//se inicializa la matriz operando 1, solo se inicializa en el nodo raiz, los otros nodos reciben la informacion
	matrixRes=(int *)memset(matrixRes,1,N*N*4);//se inicializa la matriz de resultados, no es necesario pero se hace por visualizacion de cambios

	currNumRows=N;//se obtiene el numero actual de filas a procesar (para este caso, todas)
	////////////////Send a msg to each son node////////////////////////////////////////
  	for(i=0;i<ceil(log2(p));i++)
	{
		sonNode=(int)(pow(2,i)+p_id);//se determina el identificador del nodo hijo

		//solo se convocaran los procesos que tengan un identificador menor que el numero de procesos seleccionado y
		//en caso de que el proceso actual ya tenga solo una fila, éste no tendrá procesos hijos
		if(currNumRows>=1 && sonNode<p)
		{	
			numRows=currNumRows/2;//esto es necesario por la misma definicion de la funcion para enviarlo como parametro
			printf("el proceso %d envia al proceso %d %d filas iniciando en %d\n",p_id,sonNode,numRows,currNumRows-numRows);

			MPI_Send (&numRows, 1,MPI_INT, sonNode, MSGTAG, MPI_COMM_WORLD);//se envia el numero de filas que tendrá el proceso hijo
			MPI_Send (matrixOp1+(currNumRows-numRows), numRows*N,MPI_INT, sonNode, MSGTAG, MPI_COMM_WORLD);//se envia el paquete

			//se apilan los procesos hijos con los datos necesarios para recibirlos
			head=insert(head,sonNode,currNumRows-numRows,numRows);

			currNumRows=currNumRows-numRows;//se actualiza el numero de filas que le quedan a este nodo
		}
		else
			break;
	}
	////////////////Receives and processes the msg from each son node///////////////////
	while(head!=NULL)
	{
		matrixResAux=(int *)malloc(sizeof(int)*(head->tam*N));//se reserva memoria para la matriz resultado del proceso hijo(solo la necesaria)
		printf("el proceso %d recibe del proceso %d %d filas iniciando en %d\n",p_id,head->sonId,head->tam,head->filaInicial);
		MPI_Recv ( matrixResAux, (head->tam)*N, MPI_INT, head->sonId, MSGTAG, MPI_COMM_WORLD, &status );
		memcpy(matrixRes+(head->filaInicial*N),matrixResAux,head->tam*N*4);
		matrixResAux2=matrixResAux;
		for(i=0;i<head->tam;i++)
		{
			for(j=0;j<N;j++,matrixResAux2++)
				printf("%d,",*matrixResAux2);
			printf("\n");
		}
		free(matrixResAux);
		//head=head->next;
		head=pop(head);
	}
	//////////////////////Processing/////////////////////////////////////////////////////
	matrixResAux=matrixRes;
	for(i=0;i<currNumRows;i++)	
	{
		for(k=0;k<N;k++,matrixResAux++)
		{
			res=0;
			for(j=0;j<N;j++)
				res+=(*(matrixOp1+j))*(*(matrixOp2+(j*N)));
			*matrixResAux=res;	
			//printf("%d,",res);		
		}
		//printf("\n");
	}
	////////////////////////////////Shows the result/////////////////////////////////////
	show(matrixRes);
	}
  ////////////////////////////Intermediate Nodes/////////////////////////////////////////////
  else if((int)(floor(log2(p_id))+1)<(int)(ceil(log2(p))))
  {
	int fatherNode=(int)(p_id-pow(2,floor(log2(p_id))));
	//////////////////////Receives the msg from father node////////////////////////////
	MPI_Recv ( &numRows,1, MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD, &status );
	matrixOp1=(int *)malloc(sizeof(int)*numRows*N);//se reserva memoria para la matriz
	MPI_Recv ( matrixOp1, numRows*N, MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD, &status );
	currNumRows=numRows;
	matrixRes=(int *)malloc(sizeof(int)*(numRows*N));//se reserva memoria para la matriz
	//////////////////////////Send a msg to each son node//////////////////////////////
	for(i=floor(log2(p_id))+1 ;i<ceil(log2(p));i++)
	{
		sonNode=(int)(pow(2,i)+p_id);
		if(currNumRows>=1 && sonNode<p)
		{			
			numRows=currNumRows/2;
			printf("el proceso %d envia al proceso %d %d filas iniciando en %d\n",p_id,sonNode,numRows,currNumRows-(currNumRows/2));
			MPI_Send (&numRows, 1,MPI_INT, sonNode, MSGTAG, MPI_COMM_WORLD);
			MPI_Send (matrixOp1+(currNumRows-numRows), (currNumRows/2)*N,MPI_INT, sonNode, MSGTAG, MPI_COMM_WORLD);	
			head=insert(head,sonNode,currNumRows-(currNumRows/2),currNumRows/2);
			currNumRows=currNumRows-(currNumRows/2);
		}
		else
			break;
	}
	////////////////Receives and processes the msg from each son node///////////////////
	while(head!=NULL)
	{
		matrixResAux=(int *)malloc(sizeof(int)*(head->tam*N));//se reserva memoria para la matriz(solo la necesaria)
		printf("el proceso %d recibe del proceso %d %d filas iniciando en %d\n",p_id,head->sonId,head->tam,head->filaInicial);
		MPI_Recv ( matrixResAux, (head->tam)*N, MPI_INT, head->sonId, MSGTAG, MPI_COMM_WORLD, &status );
		memcpy(matrixRes+(head->filaInicial*N),matrixResAux,head->tam*N*4);
		matrixResAux2=matrixResAux;
		for(i=0;i<head->tam;i++)
		{
			for(j=0;j<N;j++,matrixResAux2++)
				printf("%d,",*matrixResAux2);
			printf("\n");
		}
		free(matrixResAux);
		//head=head->next;
		head=pop(head);
	}
	//////////////////////Processing/////////////////////////////////////////////////////
	for(i=0;i<currNumRows;i++)	
	{
		for(k=0;k<N;k++,matrixRes++)
		{
			res=0;
			for(j=0;j<N;j++)
				res+=(*(matrixOp1+j))*(*(matrixOp2+(j*N)));
			*matrixRes=res;	
			//printf("%d,",res);		
		}
		//printf("\n");
	}
	//////////////Send back the result to father node////////////////////////////////////	
	MPI_Send ( matrixRes, numRows*N,MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD);
  }
  /////////////////////////Leaf Nodes////////////////////////////////////////////////////////
  else
  {	
	int fatherNode=(int)(p_id-pow(2,floor(log2(p_id))));
	//////////////////////Receives and processes the msg from father node/////////////////
	MPI_Recv ( &numRows,1, MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD, &status );
	matrixOp1=(int *)malloc(sizeof(int)*numRows*N);//se reserva memoria para la matriz
	MPI_Recv ( matrixOp1, numRows*N, MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD, &status );
	matrixRes=(int *)malloc(sizeof(int)*(numRows*N));//se reserva memoria para la matriz
	//////////////////////Processing/////////////////////////////////////////////////////
	for(i=0;i<numRows;i++)	
	{
		for(k=0;k<N;k++,matrixRes++)
		{
			res=0;
			for(j=0;j<N;j++)
				res+=(*(matrixOp1+j))*(*(matrixOp2+(j*N)));
			*matrixRes=res;		
			printf("%d,",res);		
		}
		printf("\n");
	}
	//////////////Send back the result to father node////////////////////////////////////
	MPI_Send ( matrixRes, numRows*N,MPI_INT, fatherNode, MSGTAG, MPI_COMM_WORLD);
	}	
  MPI_Finalize ();
  return ( 0 );
}
