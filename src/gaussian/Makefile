# CUDA toolkit installation path
CUDA_DIR = /opt/cuda

# CUDA toolkit libraries
CUDA_LIB_DIR := $(CUDA_DIR)/lib
ifeq ($(shell uname -m), x86_64)
     ifeq ($(shell if test -d $(CUDA_DIR)/lib64; then echo T; else echo F; fi), T)
	CUDA_LIB_DIR := $(CUDA_DIR)/lib64
     endif
endif

# CUDA SDK installation path
SDK_DIR = /usr/local/cuda-7.5/samples/


CC := $(CUDA_DIR)/bin/nvcc

INCLUDE := $(CUDA_DIR)/include

SRC = gaussian.cu
EXE = gaussian

# NVCC_FLAGS=-Xptxas --def-load-cache="lu"

release: $(SRC)
	$(CC) $(KERNEL_DIM) $(SRC) -o $(EXE) $(NVCC_FLAGS) -I$(INCLUDE) -L$(CUDA_LIB_DIR) -lcuda -lcudart -lm

clean:
	rm gaussian
