# Makefile for parallel_dictionary

CXX = g++
CXXFLAGS = -std=c++20 -pthread
TARGET = parallel_dictionary
SRC = parallel_dictionary.cpp

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SRC)

clean:
	rm -f $(TARGET)

