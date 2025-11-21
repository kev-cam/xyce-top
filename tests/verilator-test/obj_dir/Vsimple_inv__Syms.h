// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VSIMPLE_INV__SYMS_H_
#define VERILATED_VSIMPLE_INV__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vsimple_inv.h"

// INCLUDE MODULE CLASSES
#include "Vsimple_inv___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vsimple_inv__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vsimple_inv* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vsimple_inv___024root          TOP;

    // CONSTRUCTORS
    Vsimple_inv__Syms(VerilatedContext* contextp, const char* namep, Vsimple_inv* modelp);
    ~Vsimple_inv__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard
