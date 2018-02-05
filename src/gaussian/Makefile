# CUDA toolkit installation path
CUDA_DIR = /usr/local/cuda-8.0

# CUDA toolkit libraries
CUDA_LIB_DIR := $(CUDA_DIR)/lib
ifeq ($(shell uname -m), x86_64)
     ifeq ($(shell if test -d $(CUDA_DIR)/lib64; then echo T; else echo F; fi), T)
     	CUDA_LIB_DIR := $(CUDA_DIR)/lib64
     endif
endif

# CUDA SDK installation path
SDK_DIR = /usr/local/cuda/samples/


CC := $(CUDA_DIR)/bin/nvcc

INCLUDE := $(CUDA_DIR)/include

SRC = gaussian.cu
EXE = gaussian

release: $(SRC)
	$(CC) $(KERNEL_DIM) $(SRC) -o $(EXE) $(NVCC_FLAGS) -I$(INCLUDE) -L$(CUDA_LIB_DIR) -lcuda -lcudart -lm

clean:
	rm gaussian
