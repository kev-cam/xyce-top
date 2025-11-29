#include <iostream>
#include <iomanip>
#include "Vnand2.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vnand2* top = new Vnand2;

    double time_ns = 0.0;
    double time_step = 1.0;  // 1ns per step

    std::cout << "# Testing nand2" << std::endl;
    std::cout << "# time(ns)";

    std::cout << " a";
    std::cout << " b";
    std::cout << " out";
    std::cout << std::endl;

    // Test all input combinations
    for (int a = 0; a <= 1; a++) {
        for (int b = 0; b <= 1; b++) {
            top->a = a;
            top->b = b;
            top->eval();
            std::cout << std::fixed << std::setprecision(2) << time_ns;
            std::cout << " " << (int)top->a;
            std::cout << " " << (int)top->b;
            std::cout << " " << (int)top->out;
            std::cout << std::endl;
            time_ns += time_step;
        }
    }

    delete top;
    return 0;
}
