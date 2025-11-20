// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vsimple_inv.h for the primary calling header

#include "Vsimple_inv__pch.h"
#include "Vsimple_inv__Syms.h"
#include "Vsimple_inv___024root.h"

#ifdef VL_DEBUG
VL_ATTR_COLD void Vsimple_inv___024root___dump_triggers__stl(Vsimple_inv___024root* vlSelf);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vsimple_inv___024root___eval_triggers__stl(Vsimple_inv___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vsimple_inv__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vsimple_inv___024root___eval_triggers__stl\n"); );
    // Body
    vlSelf->__VstlTriggered.set(0U, (IData)(vlSelf->__VstlFirstIteration));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vsimple_inv___024root___dump_triggers__stl(vlSelf);
    }
#endif
}
