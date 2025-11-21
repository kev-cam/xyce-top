// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vsimple_inv__pch.h"
#include "Vsimple_inv.h"
#include "Vsimple_inv___024root.h"

// FUNCTIONS
Vsimple_inv__Syms::~Vsimple_inv__Syms()
{
}

Vsimple_inv__Syms::Vsimple_inv__Syms(VerilatedContext* contextp, const char* namep, Vsimple_inv* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    // Setup module instances
    , TOP{this, namep}
{
    // Configure time unit / time precision
    _vm_contextp__->timeunit(-12);
    _vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
    // Setup each module's pointer back to symbol table (for public functions)
    TOP.__Vconfigure(true);
}
