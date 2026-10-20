CXX = g++
CXXFLAGS = -O2 -fopenmp -std=c++17 -Wall

all: bin/dbscan_serial.exe bin/dbscan_p1.exe bin/dbscan_p2.exe

bin:
	if not exist bin mkdir bin

bin/dbscan_serial.exe: src/dbscan_serial.cpp src/dbscan_common.h | bin
	$(CXX) $(CXXFLAGS) -o $@ src/dbscan_serial.cpp

bin/dbscan_p1.exe: src/dbscan_p1.cpp src/dbscan_common.h | bin
	$(CXX) $(CXXFLAGS) -o $@ src/dbscan_p1.cpp

bin/dbscan_p2.exe: src/dbscan_p2.cpp src/dbscan_common.h | bin
	$(CXX) $(CXXFLAGS) -o $@ src/dbscan_p2.cpp

clean:
	-del /Q bin\*.exe