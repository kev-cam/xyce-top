// Verilator-Xyce Bridge for simple_inv module
#include <iostream>
#include <vector>
#include <cstring>
#include <assert.h>
#include "xbridge.h"
#include "Vsimple_inv.h"

class VerilatorInv;
class VerilatorPwlHandler;

// Verilator inverter model wrapper
class VerilatorInv {
protected:
    Vsimple_inv* verilator_model;
    VerilatorPwlHandler *in, *out;
    double threshold;  // Voltage threshold for digital conversion

public:
    VerilatorInv()
        : verilator_model(new Vsimple_inv()),
          in(NULL), out(NULL),
          threshold(0.5)
    {
    }

    ~VerilatorInv() {
        delete verilator_model;
    }

    inline void setIn(VerilatorPwlHandler *In)   { in = In; }
    inline void setOut(VerilatorPwlHandler *Out) { out = Out; }

    inline VerilatorPwlHandler *In()  const { return in; }
    inline VerilatorPwlHandler *Out() const { return out; }

    bool Finished();
    void Eval(double now);
};

// PWL handler for Verilator devices
class VerilatorPwlHandler : public PwlHandler {
public:
    VerilatorInv *device;

    VerilatorPwlHandler(PWLinDynData *XyceSrc, VerilatorInv *pDevice,
                        c_string args = NULL, double trigger = TRIG_MODE(TRIG_NEVER),
                        handler hndlr = NULL)
        : PwlHandler(XyceSrc, trigger, hndlr, args),
          device(pDevice)
    {
    }
};

std::vector<VerilatorInv *> VerilatorInvs;
std::vector<VerilatorInv *> VerilatorInvsTmp;

bool VerilatorInv::Finished() {
    return (NULL != in && NULL != out && out->ready());
}

void VerilatorInv::Eval(double now) {
    if (!in || !out) return;

    // Get input voltage
    double v_in = in->startV();

    // Convert analog to digital
    verilator_model->in = (v_in > threshold) ? 1 : 0;

    // Evaluate Verilator model
    verilator_model->eval();

    // Convert digital output to analog voltage (0V or 1V)
    double v_out = verilator_model->out ? 1.0 : 0.0;

    // Set output voltage
    tTVVEC *TV = out->getTV();
    if (TV && TV->size() > 0) {
        TV->clear();
        TV->push_back(std::make_pair(now, v_out));
    }

    out->update();
}

extern "C" {

// Input change handler
void VerilatorInCross(PwlHandler *pwlh, double skew, double Vbegin, double Vend) {
    VerilatorPwlHandler *vpwlh = (VerilatorPwlHandler *)pwlh;
    VerilatorInv *inv = vpwlh->device;

    double now = vpwlh->endT();
    inv->Eval(now);
}

// Bridge functions
int VerilatorPwlBridgeIn(PWLinDynData *XyceSrc, void *MyData, int op, void *data) {
    VerilatorInv *inv = (VerilatorInv *)MyData;
    return PwlBridge(XyceSrc, inv->In(), op, data);
}

int VerilatorPwlBridgeOut(PWLinDynData *XyceSrc, void *MyData, int op, void *data) {
    VerilatorInv *inv = (VerilatorInv *)MyData;
    return PwlBridge(XyceSrc, inv->Out(), op, data);
}

// Attachment function (called by Xyce to create device instances)
BridgeFn ConnectVerilatorInv(PWLinDynData *XyceSrc, void **MyData, const char *args) {
    BridgeFn bFn;
    std::vector<VerilatorInv *>::iterator ii = VerilatorInvsTmp.begin();
    bool new_inv = false;
    VerilatorInv *inv, *check = NULL;

    if (ii == VerilatorInvsTmp.end()) {  // first time only
        inv = new VerilatorInv();
        PwlHandler::setFns(MyData);
        VerilatorInvsTmp.insert(VerilatorInvsTmp.begin(), inv);
    } else {
        inv = *ii;  // try adding to last
    }

    if (0 == strncasecmp(args, "output", 6)) {
        if (new_inv = (NULL != inv->Out())) {
            check = inv;
            inv = new VerilatorInv();
        }
        while (*args && *args++ != ',');
        inv->setOut(new VerilatorPwlHandler(XyceSrc, inv, args));
        bFn = VerilatorPwlBridgeOut;
    }
    else {  // input
        while (*args && !(isdigit(*args) || ',' == *args)) {
            args++;
        }
        if (new_inv = (NULL != inv->In())) {
            check = inv;
            inv = new VerilatorInv();
        }
        while (*args && *args++ != ',');
        inv->setIn(new VerilatorPwlHandler(XyceSrc, inv, args,
                   TRIG_MODE(TRIG_ALWAYS), VerilatorInCross));
        bFn = VerilatorPwlBridgeIn;
    }

    if (NULL != check) {  // Trying to build two at once?
        if (check->Finished()) {
            assert(*ii == check);
            VerilatorInvsTmp.erase(ii);
            VerilatorInvs.push_back(check);
        }
    }

    if (new_inv) {
        VerilatorInvsTmp.insert(VerilatorInvsTmp.begin(), inv);
    }
    else {
        if (inv->Finished()) {
            assert(*ii == inv);
            VerilatorInvsTmp.erase(ii);
            VerilatorInvs.push_back(inv);
        }
    }

    *MyData = inv;

    return bFn;
}

}  // extern "C"
