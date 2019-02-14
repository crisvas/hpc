#include<stdio.h>
#include <stdlib.h>
#include<malloc.h>
#include <time.h>
#include<cuda.h>
#include <iostream>

typedef char* string;

#define HILOSXBLOCK 32 //¿máximo depende de la memorio compartida de la gpu?
//d_A, rowsA, colsA, d_B, rowsB, colsB, d_s_C
__global__
void multGPUSHARE(float* A,int filA,int colA,float* B,int filB,int colB,float* C){//filC=filA,colC=colB

	//Tamaño total de los elementos con que vamos a trabajar
	__shared__ float A_s[HILOSXBLOCK][HILOSXBLOCK];
	__shared__ float B_s[HILOSXBLOCK][HILOSXBLOCK];

	//Para saber en qué bloque y qué hilo estamos
	int bx = blockIdx.x;
  int by = blockIdx.y;
  int tx = threadIdx.x;
	int ty = threadIdx.y;
	int gx = gridDim.x;
	int gy = gridDim.y;

	//Para el resultado de C
	int row = by * HILOSXBLOCK + ty;
	int col = bx * HILOSXBLOCK + tx;

	float suma = 0;//para llevar la suma de las multiplicaciones

	int n = 0, m = 0;
  	while(m < gx && n < gy){
		/* De A queremos sacar las columnas, por eso:
		* col = ( ( m * HILOSXBLOCK ) + tx )
		* col = ( ( bx * HILOSXBLOCK ) + tx )
		* Hacemos la comparación entre ambas.
		* Vemos que m se mueve entre los bloques en el eje x (las columnas)
		*/
		if(( ( m * HILOSXBLOCK ) + tx ) < colA && row < filA) //Si no se pasa
			A_s[ty][tx] = A[ (row * colA) + ( ( m * HILOSXBLOCK ) + tx )];//(Row*colA + k), donde k-> 0..filB (filB = colA)
		else A_s[ty][tx] = 0;

		/* De B queremos sacar las filas, por eso:
		* row = ( ( m * HILOSXBLOCK ) + tx )
		* row = ( ( by * HILOSXBLOCK ) + tx )
		* Hacemos la comparación entre ambas.
		* Vemos que n se mueve entre los bloques en el eje y (las filas)
		*/
		if(( n * HILOSXBLOCK + ty) < filB && col < colB)
			B_s[ty][tx] = B[( ( n * HILOSXBLOCK + ty) * colB ) + col ];//(k*colB)+Col, donde k-> 0..filB
		else B_s[ty][tx] = 0;

		m++; n++;

		__syncthreads();//espera a todos los hilos

		for (int k=0; k < HILOSXBLOCK ; ++k) {
			suma += A_s[ty][k] * B_s[k][tx];
		}
		__syncthreads();
	}
	if(row < filA && col < colB)
		C[ (row * colB) + col] = suma; //C[filA][colB]
}


__global__
void multGPU(float* A, int rowsA, int colsA, float* B, int rowsB, int colsB, float* C){
  int row = blockIdx.y * blockDim.y + threadIdx.y;
  int col = blockIdx.x * blockDim.x + threadIdx.x;
  if((col < colsB)&&(row < rowsA)) {
    for(int M = 0; M < rowsB; M++) {
        C[row * colsB + col]+= A[row * colsA + M] * B[M * colsB + col];
    }
  }
}

__host__
void multCPU(float* A, int rowsA, int colsA, float* B, int rowsB, int colsB, float* C){
  int i, j;
  for(i = 0; i < rowsA; i++){
    for(j = 0; j< colsB; j++){
      for(int M = 0; M < rowsB; M++){
        C[i * colsB + j] += A[i * colsA + M] * B[ M * colsB + j];
      }
    }
  }
}

__host__
bool compare(float *A, float *B, int rows, int cols){
  int i, j;
	for(i = 0; i < rows; i++) {
		for(j = 0; j < cols; j++) {
			if (A[ i * cols + j] != B[i * cols + j]) return false;
		}
	}
	return true;
}

__host__
void load(float *M, FILE *stream, int rows, int cols) {
  int i, j;
  for(i = 0; i < rows; i++) {
    for(j = 0; j < cols; j++) {
      fscanf(stream, "%f,", &M[i * cols + j]);
    }
  }
  fclose(stream);
}

__host__
void save(float *M, int rows, int cols, string file_name) {
  FILE *stream;
  int i, j;
  stream = fopen(file_name, "w");
  fprintf(stream, "%d\n", rows);
  fprintf(stream, "%d\n", cols);
  for(i = 0; i < rows; i++) {
    for(j = 0; j < cols; j++) {
      if (j + 1 == cols) fprintf(stream, "%.2f", M[i * cols + j]);
      else fprintf(stream, "%.2f,", M[i * cols + j]);
    }
    fprintf(stream, "%s\n","");
  }
  fclose(stream);
}

__host__
void print(float* M, int rows, int cols){
  printf("---------------print matrix--------------\n");
  for(int i = 0; i < rows; i++) {
    for(int j = 0; j < cols; j++) {
      printf("%f ", M[i * cols + j]);
    }
    printf("\n");
  }
}

void guardar(float *resultado, int size, string file_name) {
  FILE *f = fopen(file_name, "w");
  fprintf(f, "%d\n", size);
  if (f == NULL) {
    printf("Error opening file!\n");
    exit(1);
  }
  int i;
  for (i = 0; i < size; i++) {
    printf("resultado de %d :%f\n",i,resultado[i] );
    if (i + 1 == size) {
      fprintf(f, "%f\n", resultado[i]);

    } else {
      fprintf(f, "%f\n", resultado[i]);
    }
  }
  fclose(f);
}
//asd
int main(int argc, char** argv){

	if (argc != 3) {
    printf("Must be called with the names of the files\n");
    return 1;
  }

	//--------config gpu-------------------///

	int numdiv;
	int iddiv;
	const int kb = 1024;
  const int mb = kb * kb;
	cudaGetDeviceCount(&numdiv);
	printf("%d  numero de GPUS\n",numdiv);


	for (int i = 0; i < numdiv; i++) {
		cudaDeviceProp propieties;
		cudaGetDeviceProperties(&propieties, i);
		printf("nombre %s\n",(char*)propieties.name);

		std::wcout<<"  Global memory:   " << propieties.totalGlobalMem / mb << "mb" << std::endl;
		std::wcout<<" Shared memory:   " << propieties.sharedMemPerBlock / kb << "kb" << std::endl;
		std::wcout<<" Constant memory: " << propieties.totalConstMem / kb << "kb" << std::endl;
		std::wcout<<" Block registers: " << propieties.regsPerBlock << std::endl;
		std::wcout<<" Warp size:         " << propieties.warpSize << std::endl;
		std::wcout<<" Threads per block: " << propieties.maxThreadsPerBlock << std::endl;
		std::wcout<<" Max block dimensions: [ " << propieties.maxThreadsDim[0] << ", " << propieties.maxThreadsDim[1]  << ", " << propieties.maxThreadsDim[2] << " ]" << std::endl;
		std::wcout<<" Max grid dimensions:  [ " << propieties.maxGridSize[0] << ", " << propieties.maxGridSize[1]  << ", " << propieties.maxGridSize[2] << " ]" << std::endl;
	}

	printf("selecione dispositivo");
	scanf("%d",&iddiv );
	cudaSetDevice(iddiv);

  //-------------------------------CPU--------------------------------------

	clock_t time_start_cpu, time_end_cpu,time_start_gpu_ing, time_end_gpu_ing,time_start_gpu, time_end_gpu;
	float *A, *B, *C, *times;
	int rowsA, colsA, rowsB, colsB;
  double timeCPU, timeGPU, timeGPUING;

  FILE *arc1, *arc2;
  arc1 = fopen(argv[1], "r");
  arc2 = fopen(argv[2], "r");

  fscanf(arc1, "%d", &rowsA);
  fscanf(arc1, "%d", &colsA);
  fscanf(arc2, "%d", &rowsB);
  fscanf(arc2, "%d", &colsB);

  //RESERVA MEMORIA EN CPU
	times =  (float*)malloc(10 * 3 * sizeof(float));
  A = (float*)malloc(rowsA * colsA * sizeof(float));
  B = (float*)malloc(rowsB * colsB * sizeof(float));
	C = (float*)malloc(rowsA * colsB * sizeof(float));

	load(A, arc1, rowsA, colsA);
   // printf("rowsA: %d\n", rowsA);
  // printf("colsA: %d\n", colsA);
  // print(A, rowsA, colsA);
  load(B, arc2, rowsB, colsB);
  // printf("rowsA: %d\n", rowsB);
  // printf("colsA: %d\n", colsB);
  // print(B, rowsB, colsB);
 // tiene que ser iguales filas M2 y col M1

  if(colsA==rowsB){
		for (int i = 0; i < 10; i++) {
			/* code */

  time_start_cpu = clock();
  multCPU(A, rowsA, colsA, B, rowsB, colsB, C);
  time_end_cpu = clock();
	timeCPU = ((double)(time_end_cpu-time_start_cpu))/CLOCKS_PER_SEC;
  printf ("El tiempo transcurrido en la CPU fue %lf segundos.\n", timeCPU);
	times[i]=timeCPU;
	}
    //imprime(C,filA,colB);
  }else{
    printf("Error, no se pueden multiplicar");
    return 0;
  }

  // print(C, rowsA, colsB);

  // save(C, rowsA, colsB, "CPU.out"); ----------------------------

	//-------------------------------GPU INGENUA--------------------------------------
  cudaError_t error = cudaSuccess;
  float *d_A, *d_B, *d_C, *h_C, *d_s_C;
	h_C = (float*)malloc(rowsA * colsB * sizeof(float));

	error = cudaMalloc((void**)&d_A,rowsA*colsA*sizeof(float));
  if (error != cudaSuccess) {
      printf("Error al asignar memoria a d_A");
      return 1;
  }

  error = cudaMalloc((void**)&d_B,rowsB*colsB*sizeof(float));
  if (error != cudaSuccess) {
      printf("Error al asignar memoria a d_B");
      return 1;
  }

  error = cudaMalloc((void**)&d_C,rowsA*colsB*sizeof(float));
  if (error != cudaSuccess) {
      printf("Error al asignar memoria a d_C");
      return 1;
  }

  error = cudaMalloc((void**)&d_s_C,rowsA*colsB*sizeof(float));
  if (error != cudaSuccess) {
      printf("Error al asignar memoria a d_s_C");
      return 1;
  }

	cudaMemcpy(d_A, A, rowsA * colsA * sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpy(d_B, B, rowsB * colsB * sizeof(float), cudaMemcpyHostToDevice); //se copia de origen b a destico d_b

  int blockSize = 32;
	dim3 dimblock(blockSize, blockSize, 1);
  dim3 dimGrid(blockSize, blockSize, 1);
  //dim3 dimGrid(ceil((colsB) / float(blockSize), ceil((rowsA) / float(blockSize)), 1);

	for(int i=10;i<20;i++){
	  time_start_gpu_ing = clock();
		multGPU<<<dimGrid,dimblock>>>(d_A, rowsA, colsA, d_B, rowsB, colsB, d_C);
		cudaDeviceSynchronize();
	  time_end_gpu_ing = clock();

	  timeGPUING = ((double)(time_end_gpu_ing-time_start_gpu_ing))/CLOCKS_PER_SEC;
		times[i]=timeGPUING;
	  printf ("Tiempo trasncurrido en GPU Algoritmo INGENUO: %lf seconds.\n", timeGPUING);
	}
	cudaMemcpy(h_C, d_C, rowsA * colsB * sizeof(float), cudaMemcpyDeviceToHost);

	// print(h_C, rowsA, colsB);

	if (!compare(h_C, C, rowsA, colsB)) {
    printf("Error al multiplicar\n");
  } else {
    printf("tiempo acelerado: %lf\n", ((double)(timeCPU / timeGPUING)));
    // save(h_C, rowsA, colsB, "GPU.out");
  }

  //-----------------------GPU  SHARED --------------------------------------
	for(int i=20;i<30;i++){
	  time_start_gpu = clock();
		multGPUSHARE<<<dimGrid,dimblock>>>(d_A, rowsA, colsA, d_B, rowsB, colsB, d_s_C);
		cudaDeviceSynchronize();
	  time_end_gpu = clock();

	  timeGPU = ((double)(time_end_gpu-time_start_gpu))/CLOCKS_PER_SEC;
		times[i]=timeGPU;
	  printf ("Tiempo trasncurrido en GPU_SHEAR: %lf seconds.\n", timeGPU);

	}
  cudaMemcpy(h_C, d_C, rowsA * colsB * sizeof(float), cudaMemcpyDeviceToHost);

	guardar(times,30,"tiempos.csv");
  // print(h_C, rowsA, colsB);

  if (!compare(h_C, C, rowsA, colsB)) {
    printf("Error al multiplicar\n");
  } else {
    printf("tiempo acelerado en la cpu vs gpu_shared: %lf\n", (double)(timeCPU / timeGPU));
    // save(h_C, rowsA, colsB, "GPU.out");
  }

	free(A); free(B); free(C); free(h_C);
	cudaFree(d_A); cudaFree(d_B); cudaFree(d_C); cudaFree(d_s_C);
	return 0;
}
