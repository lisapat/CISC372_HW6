// Names : Raj Trivedi, Lisa Pathania

//Simple optimized box blur
//by: Greg Silber
//Date: 5/1/2021
//This program reads an image and performs a simple averaging of pixels within a supplied radius.  For optimization,
//it does this by computing a running sum for each column within the radius, then averaging that sum.  Then the same for 
//each row.  This should allow it to be easily parallelized by column then by row, since each call is independent.

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#define BLOCK_SIZE 256

// Computes a single row of the destination image by summing radius pixels
// Parameters: src: The src image as width*height*bpp 1d array
//            dest: pre-allocated array of size width*height*bpp to receive summed row
//            row: The current row number
//            pWidth: The width of the image * the bpp (i.e. number of bytes in a row)
//            height: The height of the source image
//            rad: the width of the blur
//            bpp: The bits per pixel in the src image
// Returns: None
__global__ void computeRow(float* src, float* dest, int pWidth, int height, int radius, int bpp){
    
    // Local row	
    int row = blockIdx.x * blockDim.x + threadIdx.x;

    // Check if ALL threads are between 0 and IMAGE_HEIGHT
    // If yes, execute the algorithm
    // If no, then terminate right away

    if(row < height){
    	int i;
    	int bradius = radius * bpp;

    	// initialize the first bpp elements so that nothing fails
    	for (i = 0 ; i < bpp ; i++)
        	dest[row * pWidth + i] = src[row * pWidth + i];

    	// start the sum up to radius*2 by only adding (nothing to subtract yet)
    	for (i = bpp ; i < bradius  * 2 * bpp ; i++)
        	dest[row*pWidth+i]=src[row*pWidth+i]+dest[row*pWidth+i-bpp];
     
	for (i = bradius * 2 + bpp ; i < pWidth ; i++)
        	dest[row * pWidth + i] = src[row * pWidth + i] + dest[row * pWidth + i - bpp] - src[row * pWidth + i - 2 * bradius - bpp];

    	// now shift everything over by radius spaces and blank out the last radius items to account for sums at the end of the kernel, instead of the middle
    	for (i = bradius; i < pWidth ; i++){
        	dest[row * pWidth + i - bradius] = dest[row * pWidth + i] / (radius * 2 + 1);
    	}
    
	// now the first and last radius values make no sense, so blank them out
    	for (i = 0; i < bradius; i++){
        	dest[row * pWidth + i] = 0;
        	dest[ (row+1) * pWidth - 1 - i] = 0;
    	}
    }
}

//Computes a single column of the destination image by summing radius pixels
//Parameters: src: The src image as width*height*bpp 1d array
//            dest: pre-allocated array of size width*height*bpp to receive summed row
//            col: The current column number
//            pWidth: The width of the image * the bpp (i.e. number of bytes in a row)
//            height: The height of the source image
//            radius: the width of the blur
//            bpp: The bits per pixel in the src image
//Returns: None
__global__ void computeColumn(uint8_t* src, float* dest, int pWidth, int height, int radius, int bpp){
	
    // Local column	
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    // Check if ALL threads between 0 and PWIDTH
    // If yes, execute the algorithm
    // If no, then terminate right away

    if(col < pWidth){
    	int i;

    	//initialize the first element of each column
    	dest[col] = src[col];

    	//start the sum up to radius * 2 by only adding
    	for (i = 1 ; i <= radius * 2; i++)
        	dest[i * pWidth + col] = src[i * pWidth + col] + dest[(i-1) * pWidth + col];
    
    	for (i = radius * 2 + 1 ; i < height ; i++)
        	dest[i * pWidth + col] = src[i * pWidth + col] + dest[(i-1) * pWidth + col] - src[(i - 2 * radius - 1) * pWidth + col];

    	//now shift everything up by radius spaces and blank out the last radius items to account for sums at the end of the kernel, instead of the middle
    	for (i = radius; i < height; i++){
        	dest[(i-radius) * pWidth + col] = dest[i * pWidth + col] / (radius * 2 + 1);
    	}

    	//now the first and last radius values make no sense, so blank them out
    	for (i = 0 ; i < radius ; i++){
        	dest[i * pWidth + col] = 0;
        	dest[(height - 1) * pWidth - i * pWidth + col] = 0;
    	}
    }
}

//Usage: Prints the usage for this program
//Parameters: name: The name of the program
//Returns: Always returns -1
int Usage(char* name){
    printf("%s: <filename> <blur radius>\n\tblur radius=pixels to average on any side of the current pixel\n",name);
    return -1;
}

int main(int argc,char** argv){	
    clock_t t1,t2;
    int radius=0;
    int i;
    int num_blocks_row, num_blocks_col;
    int width,height,bpp,pWidth;
    char* filename;
    uint8_t *img;             // Array of bytes for src image on CPU 
    uint8_t *host_dev_img;    // Array of bytes for src image on CPU and GPU(Unified Memory)
    float *dest, *mid;        // Array of float values of destination image on CPU and GPU(Unified Memory)
    
    if (argc!=3)
        return Usage(argv[0]);
    filename=argv[1];
    sscanf(argv[2],"%d",&radius);

    // Load a src image
    img = stbi_load(filename,&width,&height,&bpp,0);

    // Actual width in bytes of an image row
    pWidth = width * bpp;  

    // Number of blocks to be used for computeRow(...) function
    num_blocks_row = (height  + (BLOCK_SIZE - 1) ) / BLOCK_SIZE; 

    // Number of blocks to be used for computeColumn(...) function
    num_blocks_col = (pWidth  + (BLOCK_SIZE - 1) ) / BLOCK_SIZE; 

    // Allocate Unified Memory for "host_dev_img" array
    cudaMallocManaged(&host_dev_img, sizeof(uint8_t) * pWidth * height);

    // Copy "img" array to "host_dev_img"
    memcpy(host_dev_img, img, sizeof(uint8_t) * pWidth * height);

    // Done with "img"
    stbi_image_free(img);

    // Allocate Unified Memory for "mid" and "dest" arrays
    // Unified Memory which means accessible from both GPU and CPU
    cudaMallocManaged(&mid,  sizeof(float) * pWidth * height);
    cudaMallocManaged(&dest, sizeof(float) * pWidth * height);

    // Start the timer for parallelization
    t1 = clock();

    // Invoke kernel code computeColumn(...)
    computeColumn<<< num_blocks_col, BLOCK_SIZE >>>(host_dev_img, mid, pWidth, height, radius, bpp);

    // Wait for ALL threads to reach here
    cudaDeviceSynchronize();

    // Invoke kernel code computeRow(...)
    computeRow<<< num_blocks_row, BLOCK_SIZE >>>(mid, dest, pWidth, height, radius, bpp);

    // Wait for device to finish before accessing on host
    cudaDeviceSynchronize();

    // End the timer for parallelization
    t2 = clock(); 

    // Now back to uint8_t and save the image
    for (i = 0 ; i < pWidth * height ; i++){    
         host_dev_img[i] = (uint8_t) dest[i];
    }

    // Write all bytes of final image to "output.png"
    stbi_write_png("output.png",width,height,bpp,host_dev_img,bpp*width);

    // Frees allocated space from device(GPU)
    cudaFree(host_dev_img);
    cudaFree(mid);
    cudaFree(dest);
    
    // Check how much time it took parallelizing serialized version
    printf("Blur with radius %d complete in %lf seconds\n",radius, (double) (t2-t1) / (double) CLOCKS_PER_SEC);
}
