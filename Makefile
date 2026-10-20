UNAME_S := $(shell uname -s)

# En macOS, g++ apunta a Clang (que no soporta -fopenmp), asi que usamos el GCC real de Homebrew.
# En Linux/WSL (Windows), el g++ normal ya trae soporte de OpenMP, asi que se usa tal cual.
ifeq ($(UNAME_S),Darwin)
    CXX := g++-16
else
    CXX := g++
endif

CXXFLAGS = -O2 -fopenmp -std=c++17 -Wall
all: bin/dbscan_serial bin/dbscan_p1 bin/dbscan_p2

bin:
	mkdir -p bin

bin/dbscan_serial: src/dbscan_serial.cpp src/dbscan_common.h | bin
	$(CXX) $(CXXFLAGS) -o $@ src/dbscan_serial.cpp

bin/dbscan_p1: src/dbscan_p1.cpp src/dbscan_common.h | bin
	$(CXX) $(CXXFLAGS) -o $@ src/dbscan_p1.cpp

bin/dbscan_p2: src/dbscan_p2.cpp src/dbscan_common.h | bin
	$(CXX) $(CXXFLAGS) -o $@ src/dbscan_p2.cpp

clean:
	rm -rf bin
