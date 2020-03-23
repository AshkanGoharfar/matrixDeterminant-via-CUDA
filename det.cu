#include <stdio.h>
#include <stdlib.h>
#include <time.h>

const int BLOCKS_PER_GRID = 5;
const int THREADS_PER_BLOCK = 20;
const int N=5;

void printMatrix(int* X){
	printf("%3d\n",X[0]);
	for(int i=0;i<X[0];i++){
		for(int j=0;j<X[0];j++){
			printf("%4d",X[i*X[0]+j+1]);
		}
		printf("\n");
	}
	printf("\n");
}

__global__
void det(int* M,int* w,int* tab){
	int N = M[0];
	int idx = threadIdx.x + blockDim.x * blockIdx.x;	
	int stride = blockDim.x * gridDim.x;

	//const int shared = blockDim.x;
        
	//__shared__ int sharedTab[THREADS_PER_BLOCK];

	int* idxTab = new int[N];
	for(int i=1;i<=N;i++){
		idxTab[N-i] = idx%i;
		idx/=i;
	}
	//idxTab[0]+=idx;

	if(idx==0){
		int* strideTab = new int[N];
		for(int i=1;i<=N;i++){
			strideTab[N-i] = stride%i;
			stride/=i;
		}
		//strideTab[0]+=stride;

		idx = threadIdx.x + blockDim.x * blockIdx.x;	
		stride = blockDim.x * gridDim.x;
		
		/*__syncthreads();
		//printf("N: %3d,idx: %3d,stride: %3d",N,idx,stride);
		for(int i=0;i<N;i++){
			printf("N: %3d,idx: %3d,stride: %3d,idxTab[%d]==%d\n",N,idx,stride,i,idxTab[i]);
		}
		for(int i=0;i<N;i++){
			printf("N: %3d,idx: %3d,stride: %3d,stride[%d]==%d\n",N,idx,stride,i,strideTab[i]);
		}*/
		while(idxTab[0]<N){	
			//int parz = (idxTab[N-3]+idxTab[N-2]+idxTab[N-1])%2; //0 lub 1(wskaznik parzystosci)
			int parz = 0;
			for(int i=0;i<N;i++) parz = (parz + idxTab[i])%2;
			//conv
			for(int i=0;i<N;i++){
				for(int j=1;j<=N;j++){
					bool niepojawilo = true;
					for(int k=0;k<i;k++){
						if(idxTab[k] == j){niepojawilo = false; break;}
					}
					if(niepojawilo){
						if(idxTab[i]==0){
							idxTab[i]=j;break;
						}
						else idxTab[i]--;
					}
				}
			}

			//idxTab zawiera teraz interesuja permutacje
			int product = ((parz%2==0) ? 1 : -1);//trzeba bedzie jakis inny typ, pewnie double albo klase, bo to duzo wychodzi i w incie sie nie miesci
			for(int i=0;i<N;i++) product*=M[i*N+(idxTab[i]-1)+1]; //here we have a product, one of N!
		
			//__syncthreads();
			tab[idx] += product;
			
			//sharedTab[idx%stride] = product;

			/*if(idx%THREADS_PER_BLOCK==0){
				int nr_bloku = blockIdx.x;
				for(int i=0;i<THREADS_PER_BLOCK;i++){
					tab[nr_bloku] += sharedTab[i]; 
				}
				printf("nr_bloku: %d, tab[i]=%d",nr_bloku,tab[nr_bloku]);
			}*/

				
			/*if(idx==0){
				for(int i=0;i<stride;i++) (*w)+=tab[i];
			}*/
			//__syncthreads();
			
			//(*w)+=product;

			//printf("Idx: %2d, product: %3d,tab[%d]: %d\n",idx,product,idx,tab[idx]);
			
			//negconv
			for(int i=0;i<N;i++){
				int ile = 0;
				for(int j=i+1;j<N;j++){
					if(idxTab[j]<idxTab[i]) ile++;
				}
				idxTab[i] = ile;
			}
			
			//idxTab+=strideTab
			int ak=0;
			for(int i=1;i<=N;i++){
				idxTab[N-i]=idxTab[N-i]+strideTab[N-i]+ak;
				ak=idxTab[N-i]/i;
				if(i!=N) idxTab[N-i]%=i;		
			}
			idxTab[0]+=ak;
			/*ak=0;
			for(int i=1;i<=N;i++){
				idxTab[N-i]=idxTab[N-i]+strideTab[N-i]+ak;
				ak=idxTab[N-i]/i;
				if(i!=N) idxTab[N-i]%=i;		
			}
			idxTab[0]+=ak;
			ak=0;
			for(int i=1;i<=N;i++){
				idxTab[N-i]=idxTab[N-i]+strideTab[N-i]+ak;
				ak=idxTab[N-i]/i;
				if(i!=N) idxTab[N-i]%=i;		
			}
			idxTab[0]+=ak;*/

			}
		delete[] strideTab;
	}
	/*__syncthreads();
		//printf("N: %3d,idx: %3d,stride: %3d",N,idx,stride);
		for(int i=0;i<N;i++){
			printf("N: %3d,idx: %3d,stride: %3d,idxTab[%d]==%d\n",N,idx,stride,i,idxTab[i]);
		}
		for(int i=0;i<N;i++){
			printf("N: %3d,idx: %3d,stride: %3d,stride[%d]==%d\n",N,idx,stride,i,strideTab[i]);
		}*/
	delete[] idxTab;

	/*for(int i=0;i<BLOCKS_PER_GRID*THREADS_PER_BLOCK;i++){
		(*w) += tab[i];
	}*/
}

int main(){
	srand(time(NULL));
	//const int N = 5;
	int* tab;// = new int[BLOCKS_PER_GRID*THREADS_PER_BLOCK];
	cudaMallocManaged(&tab, sizeof(int)*BLOCKS_PER_GRID*THREADS_PER_BLOCK);
	for(int i=0;i<BLOCKS_PER_GRID*THREADS_PER_BLOCK;i++) tab[i] = 0;
	
	int *A;

	cudaMallocManaged(&A, (1+N*N)*sizeof(int));

	A[0] = N;

	for(int i=0;i<A[0];i++){
		for(int j=0;j<A[0];j++){
			A[i*A[0]+j+1] = ((i==j) ? 3.0 : 2.0);//rand()%21-10;
		}
	}

	printMatrix(A);

	clock_t start = clock();

	int* w = new int; *w = 0;
	det<<<BLOCKS_PER_GRID,THREADS_PER_BLOCK>>>(A,w,tab);
	cudaDeviceSynchronize();

	for(int i=0;i<BLOCKS_PER_GRID*THREADS_PER_BLOCK;i++) (*w)+=tab[i];	
	printf("%5d\n",*w);

	cudaFree(A);	
	cudaFree(tab);
	delete w;

	clock_t koniec = clock();
	double czas = (double)(koniec-start)/CLOCKS_PER_SEC;
	printf("Czas wykonania: %lfs\n",czas);

	return 0;
}
