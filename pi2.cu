/*
* ARQUITECTURA DE COMPUTADORES
* 2º Curso - Grado en Ingeniería Informática
* Curso 2016/17
*
* PRACTICA 07: "Memoria compartida dinámica"
* >> Utilizar la memoria compartida de la GPU de manera dinámica para calcular
pi mediante una nueva fórmula
*
* AUTOR: - GARCÍA MEDIAVILLA Marina - GARRIDO LABRADOR José Luis
* FECHA: 25/10/2016
*/
///////////////////////////////////////////////////////////////////////////
// includes
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <cuda_runtime.h>
#include <math.h>
///////////////////////////////////////////////////////////////////////////
// defines
#define BLOQUE 1
#define HILOS 512
///////////////////////////////////////////////////////////////////////////
// DEVICE: función llamada desde el device y ejecutada en el device
__device__ float calcularArea(float inicio, float final, float base){
  float medio = (inicio+final)/2;
  float altura = 4/(1+(medio)*(medio));
  return base*altura;
}
// GLOBAL: función llamada desde el host y ejecutada en el device (kernel)
__global__ void calcularPi(float *pi,int *precition){
  int hilosLanzados = *precition;
  int myID = threadIdx.x; //La posición global en el vector
  float inicio; //Punto inicial en X del rectángulo
  float final; //Punto final en X del rectángulo
  extern __shared__ float area[]; //Area del rectángulo
  float superVar = 1/(float)hilosLanzados; //Contiene la base de cada
  rectángulo
  //Calculamos el área
  inicio = myID * superVar;
  final = (myID + 1) * superVar;
  area[myID] = calcularArea(inicio,final,superVar);
  __syncthreads();
  //Reducción paralela
  if(hilosLanzados%2 != 0){
    if(myID == (hilosLanzados-1)){
      array[0] += array[myID];
    }
  }
  __syncthreads();
  int salto = hilosLanzados/2;
  // Realizamos log2(N) iteraciones
  while(salto)
  {
    // Solo trabajan la mitad de los hilos
    if(myID < salto)
    {
      area[myID] = area[myID] + area[myID+salto];
    }
    __syncthreads();
    if(salto % 2 != 0 && salto!=1){
      if(myID == salto-1){
        array[0] = array[0] + array[myID];
      }
    }
    __syncthreads();
    salto = salto/2;
  }
  __syncthreads();
  // El hilo no.'0' tiene el valor para calcular Pi
  if(myID==0)
  {
    *pi = area[myID];
  }
}
// HOST: función llamada desde el host y ejecutada en el host
/*
* Nombre: clean_stdin
* Descripción: borra el buffer de teclado
* Retorna 1 cuando termina
*/
__host__ int clean_stdin(void) {
  while (getchar() != '\n');
  return 1;
}
///////////////////////////////////////////////////////////////////////////
// MAIN: rutina principal ejecutada en el host
int main(int argc, char** argv) {
  float *dev_pi, *hst_pi;
  int *dev_precition;
  cudaSetDevice(0); //Elegimos la tarjeta 1º
  cudaEvent_t start,stop; //marcas de eventos
  int precition;
  char c;
  char linea[] =
  "---------------------------------------------------------------------";
  cudaDeviceProp features; //Propiedades de la tarjeta
  cudaGetDeviceProperties(&features, 0); //Obtenemos los datos de la
  tarjeta
  //Pedimos los datos
  do{
    printf("Seleccione la precisión con la que calcular Pi, como
    máximo %d: ",features.maxThreadsPerBlock);
    //
    if (scanf("%d%c", &precition, &c) != 2 || c != '\n') {
      printf("Valor no valido\n");
      clean_stdin();
    }
  } while (precition < 0 || precition > features.maxThreadsPerBlock);
  //Reservamos memoria
  hst_pi = (float *) malloc(sizeof(float));
  cudaMalloc((void**)&dev_pi,sizeof(float));
  cudaMalloc((void**)&dev_precition,sizeof(int));
  cudaMemcpy(dev_precition,&precition,sizeof(int),cudaMemcpyHostToDevice);
  //Creamos los eventos
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  //Inicializamos el inicio
  cudaEventRecord(start,0);
  //Llamamos a la función kernel para calcular pi
  calcularPi <<<BLOQUE,precition,precition*sizeof(float)>>> (dev_pi,
  dev_precition);
  cudaMemcpy(hst_pi,dev_pi,sizeof(float),cudaMemcpyDeviceToHost);
  //Inicializamos el final
  cudaEventRecord(stop,0);
  //Sincronizamos host y device
  cudaEventSynchronize(stop);
  //Calculamos el tiempo entre marcas
  float elapsedTime;
  cudaEventElapsedTime(&elapsedTime,start,stop);
  //Imprimimos los resultados
  printf("\n%s\nLa memoria compartida disponible
  %dKiB:\n",linea,features.sharedMemPerBlock/1024);
  printf("Los hilos disponibles son %d de los cuales se utilizaron
  %d\n",features.maxThreadsPerBlock,precition);
  printf("El valor de pi calculado es: %f\n",*hst_pi);
  printf("La ejecución se ha realizado sobre %f
  milisegundos\n",elapsedTime);
  printf("\npulsa INTRO para finalizar...");
  getchar();
  return 0;
}
///////////////////////////////////////////////////////////////////////////