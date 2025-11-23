// Verilator-Xyce Bridge for simple_inv module
#include "xbridge.h"
#include "Vsimple_inv.h"

class VerilatorInvBridge : public XyceBridge {
private:
    Vsimple_inv* top;

public:
    VerilatorInvBridge() {
        top = new Vsimple_inv;
    }

    ~VerilatorInvBridge() {
        delete top;
    }

    void eval(double* inputs, double* outputs, int numInputs, int numOutputs) override {
        // Convert voltage to digital (threshold at 0.5V)
        if (numInputs > 0) {
            top->in = (inputs[0] > 0.5) ? 1 : 0;
        }

        // Evaluate the model
        top->eval();

        // Convert digital output to voltage (0V or 1V)
        if (numOutputs > 0) {
            outputs[0] = top->out ? 1.0 : 0.0;
        }
    }
};

// Factory function for Xyce to create bridge instance
extern "C" {
    XyceBridge* createBridge() {
        return new VerilatorInvBridge();
    }

    void destroyBridge(XyceBridge* bridge) {
        delete bridge;
    }
}
