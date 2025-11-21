// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vsimple_inv__pch.h"

//============================================================
// Constructors

Vsimple_inv::Vsimple_inv(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vsimple_inv__Syms(contextp(), _vcname__, this)}
    , in{vlSymsp->TOP.in}
    , out{vlSymsp->TOP.out}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vsimple_inv::Vsimple_inv(const char* _vcname__)
    : Vsimple_inv(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vsimple_inv::~Vsimple_inv() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vsimple_inv___024root___eval_debug_assertions(Vsimple_inv___024root* vlSelf);
#endif  // VL_DEBUG
void Vsimple_inv___024root___eval_static(Vsimple_inv___024root* vlSelf);
void Vsimple_inv___024root___eval_initial(Vsimple_inv___024root* vlSelf);
void Vsimple_inv___024root___eval_settle(Vsimple_inv___024root* vlSelf);
void Vsimple_inv___024root___eval(Vsimple_inv___024root* vlSelf);

void Vsimple_inv::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vsimple_inv::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vsimple_inv___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vsimple_inv___024root___eval_static(&(vlSymsp->TOP));
        Vsimple_inv___024root___eval_initial(&(vlSymsp->TOP));
        Vsimple_inv___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vsimple_inv___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vsimple_inv::eventsPending() { return false; }

uint64_t Vsimple_inv::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vsimple_inv::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vsimple_inv___024root___eval_final(Vsimple_inv___024root* vlSelf);

VL_ATTR_COLD void Vsimple_inv::final() {
    Vsimple_inv___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vsimple_inv::hierName() const { return vlSymsp->name(); }
const char* Vsimple_inv::modelName() const { return "Vsimple_inv"; }
unsigned Vsimple_inv::threads() const { return 1; }
void Vsimple_inv::prepareClone() const { contextp()->prepareClone(); }
void Vsimple_inv::atClone() const {
    contextp()->threadPoolpOnClone();
}

//============================================================
// Trace configuration

VL_ATTR_COLD void Vsimple_inv::trace(VerilatedVcdC* tfp, int levels, int options) {
    vl_fatal(__FILE__, __LINE__, __FILE__,"'Vsimple_inv::trace()' called on model that was Verilated without --trace option");
}
