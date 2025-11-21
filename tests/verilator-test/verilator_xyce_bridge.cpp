#include <iostream>
#include <vector>
#include <cmath>
#include <ctype.h>
#include <strings.h>
#include "obj_dir/Vsimple_inv.h"
#include "../xbridge.h"
#include "../gates.h"

// Verilator-based inverter using generated C++ model
class VerilatorInverter : public GateX<1> {
private:
    Vsimple_inv* verilator_model;
    double vth_high;  // Threshold for logic high
    double vth_low;   // Threshold for logic low

public:
    VerilatorInverter() : verilator_model(nullptr) {
        verilator_model = new Vsimple_inv;
        vth_high = 1.5;  // 1.5V threshold
        vth_low = 1.5;
    }

    ~VerilatorInverter() {
        if (verilator_model) {
            verilator_model->final();
            delete verilator_model;
        }
    }

    inline void setIn(GatePwlHandler *In) { in[0] = In; }
    inline GatePwlHandler *In() const { return in[0]; }

    bool Finished() {
        bool ret = false;
        if (NULL != in[0] &&
            NULL != vdd   &&
            NULL != out   && out->ready()) {
            setParams();
            ret = true;
        }
        return ret;
    }

    void Eval(double now) {
        double v_in = in[0]->startV();
        double v_dd = vdd->startV();

        if (abs(v_dd - vdd_last) >= v_tol) {
            vdd_last = v_dd;
            in[0]->setTimes(now, now);
            lgc_pend |= LGC_UNKNOWN;

            if (v_dd > v_min && v_in > (v_dd/2)) {
                InvInCross(in[0], 0.0, 0.0, v_dd);
            } else {
                InvInCross(in[0], 0.0, v_dd, 0.0);
            }
        }
        in[0]->setProbe(t_tol/2.0);
    }

    // Evaluate the Verilator model
    double EvaluateModel(double v_in, double v_dd) {
        // Convert analog to digital
        uint8_t in_digital = (v_in > vth_high) ? 1 : 0;

        // Run Verilator model
        verilator_model->in = in_digital;
        verilator_model->eval();
        uint8_t out_digital = verilator_model->out;

        // Convert digital back to analog
        return out_digital ? v_dd : 0.0;
    }
};

std::vector<VerilatorInverter *> VerilatorInverters;

void Gate::setParams() {
    v_min  = out->getParam("Vmin", v_min);
    t_tol  = out->getParam("Ttol", t_tol);
    v_tol  = out->getParam("Vtol", v_tol);
    delay  = out->getParam("Delay", v_tol);
    rise_t = out->getParam("RiseT", v_tol);
    fall_t = out->getParam("FallT", v_tol);
}

extern "C" {

int GatePwlBridgeOut(PWLinDynData *XyceSrc, void *MyData, int op, void *data) {
    VerilatorInverter *inv = (VerilatorInverter *)MyData;
    return PwlBridge(XyceSrc, inv->Out(), op, data);
}

int GatePwlBridgeIn(PWLinDynData *XyceSrc, void *MyData, int op, void *data) {
    VerilatorInverter *inv = (VerilatorInverter *)MyData;
    return PwlBridge(XyceSrc, inv->In(), op, data);
}

int GatePwlBridgeVdd(PWLinDynData *XyceSrc, void *MyData, int op, void *data) {
    VerilatorInverter *inv = (VerilatorInverter *)MyData;
    return PwlBridge(XyceSrc, inv->Vdd(), op, data);
}

void InvSetVdd(PwlHandler *pwlh, double skew, double Vbegin, double Vend) {
    GatePwlHandler *gpwlh = (GatePwlHandler *)pwlh;
    VerilatorInverter *inv = (VerilatorInverter *)gpwlh->gate;

    if (inv->In()->setTrig(Vbegin/2.0)) {
        inv->Eval(inv->Vdd()->endT());
    }
}

void InvInCross(PwlHandler *pwlh, double skew, double Vbegin, double Vend) {
    GatePwlHandler *gpwlh = (GatePwlHandler *)pwlh;
    VerilatorInverter &inv = (*(VerilatorInverter *)gpwlh->gate);

    GatePwlHandler &out(*inv.Out());
    GatePwlHandler &vdd(*inv.Vdd());
    tTVVEC &TV(*out.getTV());

    double dt = inv.Delay() - skew;
    if (dt < 0.0) dt = 0.0;

    double t = out.endT() + dt;
    double v_in_start = Vbegin;
    double v_dd = vdd.startV();

    // Use Verilator model to determine output
    double v_out = inv.EvaluateModel((Vbegin + Vend)/2.0, v_dd);

    // Add transition
    TV.push_back(std::pair<double,double>(t, v_out));
    out.setProbe(0.0);
}

// Attachment function for Xyce
BridgeFn AttachVerilatorInv(PWLinDynData *XyceSrc, void **MyData, const char *args) {
    BridgeFn bFn = PwlBridge;
    std::vector<VerilatorInverter *>::iterator ii = VerilatorInverters.begin();
    bool new_inv = false;
    VerilatorInverter *inv, *check = NULL;

    if (ii == VerilatorInverters.end()) { // first time only
        inv = new VerilatorInverter();
        PwlHandler::setFns(MyData);
        VerilatorInverters.insert(VerilatorInverters.begin(), inv);
    } else {
        inv = *ii; // try adding to last
    }

    if (0 == strncasecmp(args, "output", 6)) {
        if (new_inv = (NULL != inv->Out())) {
            check = inv;
            inv   = new VerilatorInverter();
        }
        while (*args && *args++ != ',');
        inv->setOut(new GatePwlHandler(XyceSrc, inv, args));
        bFn = GatePwlBridgeOut;
    }
    else if (0 == strncasecmp(args, "vdd", 3)) {
        if (new_inv = (NULL != inv->Vdd())) {
            check = inv;
            inv   = new VerilatorInverter();
        }
        while (*args && *args++ != ',');
        inv->setVdd(new GatePwlHandler(XyceSrc, inv, args, TRIG_MODE(TRIG_ALWAYS), InvSetVdd));
        bFn = GatePwlBridgeVdd;
    }
    else {
        while (*args && !(isdigit(*args) || ',' == *args)) {
            args++;
        }
        if (new_inv = (NULL != inv->In())) {
            check = inv;
            inv   = new VerilatorInverter();
        }
        while (*args && *args++ != ',');
        inv->setIn(new GatePwlHandler(XyceSrc, inv, args, TRIG_MODE(TRIG_NEVER), InvInCross));
        bFn = GatePwlBridgeIn;
    }

    if (NULL != check) { // Trying to build two at once?
        if (check->Finished()) {
            assert(*ii == check);
            VerilatorInverters.erase(ii);
        }
    }

    if (new_inv) {
        VerilatorInverters.insert(VerilatorInverters.begin(), inv);
    }
    else {
        if (inv->Finished()) {
            assert(*ii == inv);
            VerilatorInverters.erase(ii);
        }
    }

    *MyData = inv;
    return bFn;
}

} // extern "C"
