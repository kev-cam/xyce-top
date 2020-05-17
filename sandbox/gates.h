
class Inverter;
class GatePwlHandler;

class Gate {
protected:
    GatePwlHandler *out,*vdd;
    double          delay;
    double          rise_t;
    double          fall_t;
    double          v_min;
    double          t_tol;
    double          v_tol;
    double          vdd_last;
    int             lgc_pend;
#define             LGC_UNKNOWN ((int)0x80000000)
#define             LGC_UNSET   (-1)

    public:
    Gate(GatePwlHandler *output = NULL,
         GatePwlHandler *Vdd    = NULL)
        : out(output),vdd(Vdd),
          delay(1e-11),
          rise_t(1e-12), fall_t(1e-12),
          v_min(0.0),
          v_tol(PWL_TIME_TOL), t_tol(PWL_VALUE_TOL),
          vdd_last(-1.0),
          lgc_pend(LGC_UNSET)

    {
    }

    void setParams();

    inline void setOut(GatePwlHandler *output) {out = output; }
    inline void setVdd(GatePwlHandler *Vdd)    {vdd = Vdd;}

    inline int setLgcPend (int lgc) { return lgc_pend = lgc; }    
    inline int LgcPend()            { return lgc_pend; }    

    inline GatePwlHandler *Out() const { return out; }
    inline GatePwlHandler *Vdd() const { return vdd; }

    inline double Delay() { return delay;  }
    inline double RiseT() { return rise_t; }
    inline double FallT() { return fall_t; }
    inline double Vtol()  { return v_tol;  }
    inline double Ttol()  { return t_tol;  }
    inline double Vmin()  { return v_min;  }
};

template <int I> class GateX : public Gate {
protected:
    GatePwlHandler *in[I];
public:
    GateX(GatePwlHandler *output = NULL,
          GatePwlHandler *Vdd    = NULL)
    : Gate(output,Vdd)
    {
        int i = I;
        while (i-- >0) in[i] = NULL;
    }
};

class GatePwlHandler : public PwlHandler {
public:
    Gate *gate;

GatePwlHandler(PWLinDynData *XyceSrc,Gate *pGate,c_string args = NULL,double trigger=TRIG_MODE(TRIG_NEVER),handler hndlr=NULL)
    : PwlHandler(XyceSrc,trigger,hndlr,args),        
        gate(pGate)
    {
    }
};

class Inverter : public GateX<1> {
public:

    Inverter()
    {        
    }

    inline void            setIn(GatePwlHandler *In)       { in[0] = In;}
    inline GatePwlHandler *In()                      const { return in[0]; }

    bool Finished();
    void Eval(double);
};


extern "C" {
    void InvInCross(PwlHandler *pwlh,double skew,double Vbegin, double Vend);
}
