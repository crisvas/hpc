#include<stdio.h>
#include <stdlib.h>
#include<malloc.h>
#include <time.h>
#include<cuda.h>

typedef char* string;

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


int main(int argc, char** argv){

	if (argc != 3) {
    printf("Must be called with the names of the files\n");
    return 1;
  }

  //-------------------------------CPU--------------------------------------

	time_t time_start, time_end;
	float *A, *B, *C;
	int rowsA, colsA, rowsB, colsB;
  double timeCPU, timeGPU;

  FILE *arc1, *arc2;
  arc1 = fopen(argv[1], "r");
  arc2 = fopen(argv[2], "r");

  fscanf(arc1, "%d", &rowsA);
  fscanf(arc1, "%d", &colsA);
  fscanf(arc2, "%d", &rowsB);
  fscanf(arc2, "%d", &colsB);

  //RESERVA MEMORIA EN CPU

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

	if (colsA != rowsB) return 1; // tiene que ser iguales filas M2 y col M1

	time_start = clock();
	multCPU(A, rowsA, colsA, B, rowsB, colsB, C);
	time_end = clock();

  // print(C, rowsA, colsB);

  timeCPU = difftime(time_end, time_start);
  printf ("Elasped time in CPU: %.2lf seconds.\n", timeCPU);

  // save(C, rowsA, colsB, "CPU.out");

	//-------------------------------GPU--------------------------------------
  cudaError_t error = cudaSuccess;
  float *d_A, *d_B, *d_C, *h_C;
	h_C = (float*)malloc(rowsA * colsB * sizeof(float));

	error = cudaMalloc((void**)&d_A, rowsA * colsA * sizeof(float));
  if (error != cudaSuccess) {
      printf("Error al asignar memoria a d_A");
      return 1;
  }

  error = cudaMalloc((void**)&d_B, rowsB * colsB * sizeof(float));
  if (error != cudaSuccess) {
      printf("Error al asignar memoria a d_B");
      return 1;
  }

  error = cudaMalloc((void**)&d_C, rowsA * colsB * sizeof(float));
  if (error != cudaSuccess) {
      printf("Error al asignar memoria a d_C");
      return 1;
  }

	cudaMemcpy(d_A, A, rowsA * colsA * sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpy(d_B, B, rowsB * colsB * sizeof(float), cudaMemcpyHostToDevice);

  int blockSize = 32;
	dim3 dimblock(blockSize, blockSize, 1);
  dim3 dimGrid(ceil((colsB) / float(blockSize)), ceil((rowsA) / float(blockSize)), 1);

  time_start = clock();
	multGPU<<<dimGrid,dimblock>>>(d_A, rowsA, colsA, d_B, rowsB, colsB, d_C);
	cudaDeviceSynchronize();
  time_end = clock();

  timeGPU = difftime(time_end, time_start);
  printf ("Tiempo trasncurrido en GPU: %.2lf seconds.\n", timeGPU);

	cudaMemcpy(h_C, d_C, rowsA * colsB * sizeof(float), cudaMemcpyDeviceToHost);

	// print(h_C, rowsA, colsB);

	if (!compare(h_C, C, rowsA, colsB)) {
    printf("Error al multiplicar\n");
  } else {
    printf("tiempo acelerado: %lf\n", timeCPU / timeGPU);
    // save(h_C, rowsA, colsB, "GPU.out");
  }

	free(A); free(B); free(C); free(h_C);
	cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
	return 0;
}
