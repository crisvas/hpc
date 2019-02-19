#include <stdio.h>
#include <stdlib.h>

typedef char* string;

void fillMatrix(float *M, int row, int col) { // fill a matrix with random numbers
  float a = 5.0;
  for (int i = 0; i < row; i++) {
    for (int j = 0; j < col; j++) {
      //M[i * col + j] = (float)rand() / (float)(RAND_MAX / a);
      M[i * col + j] = 1;
    }
  }
}

void print(float *M, int row, int col) {
  for (int i = 0; i < row; i++) {
    for (int j = 0; j < col; j++) {
      printf("%.2f ", M[i * col + j]);
    }
    printf("\n");
  }
  printf("\n");
}

void writeMatrix(float *M, int row, int col, string archivo) {
  FILE *f = fopen(archivo, "w");
  fprintf(f, "%d\n%d\n", row, col);
  if (f == NULL) {
    printf("Error opening file!\n");
    exit(1);
  }
  int i, j;
  for (i = 0; i < row; i++) {
    for (j = 0; j < col; j++) {
      if (j + 1 == col) {
        fprintf(f, "%.2f", M[i * col + j]);
      } else {
        fprintf(f, "%.2f,", M[i * col + j]);
      }
    }
    fprintf(f, "%s\n", "");
  }

  fclose(f);
}

int main(int argc, char** argv) {
  if (argc =! 2) {
    printf("Must be called with the name of the out file\n");
    return 1;
  }
  int row, col;
  string archivo = argv[1];
  printf("File name: %s\n", archivo);
  printf("ingrese el numero de filas" );
  scanf("%d", &row);
  printf("ingrese el numero de columnas" );
  scanf("%d", &col);
  float *M = (float*)malloc(row*col*sizeof(float));
  fillMatrix(M, row, col);
  // print(M, row, col);
  writeMatrix(M, row, col, archivo);
  return 0;
}