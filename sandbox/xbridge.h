

#define NEED_FN_DECL
#include "N_DEV_SourceDataExt.h"

#define PWL_TIME_TOL  (1.0e-18)
#define PWL_VALUE_TOL (1.0e-12)

class PWLinDynData;

using namespace std;

extern "C" {
typedef std::vector< std::pair<double,double> > tTVVEC;  // Array (time,voltage)
}

#define FN_DECL(ret,nm,argt,arg) e##nm,
enum {
#include "N_DEV_SourceDataExt.inc"
    eEnd
};
    
enum BridgeOP {
# define BRIDGE_OP(o) o,
# include "N_DEV_BridgeOp.inc"
    NoOp
};

using namespace std;

class PwlHandler;

extern "C" {

    typedef void (*handler)(PwlHandler *,double skew,double Vbegin, double Vend);

    void CrossHandler(PwlHandler *,double skew,double Vp, double Vn);

    typedef int (*BridgeFn)
             (PWLinDynData *XyceSrc,void *MyData, int op, void *data);

    typedef int (*BridgeFn)
             (PWLinDynData *XyceSrc,void *MyData, int op, void *data);
    
    int      PwlBridge (PWLinDynData *XyceSrc,void  *MyData, int op, void *data);
    BridgeFn ConnectPWL(PWLinDynData *XyceSrc,void **MyData, const char *args);
}

class PwlHandler {
    
    DeviceInstance *pInstance;
    PWLinDynData   *xsrc;
    bool            voltage;
    double          trigger;
    int             triggered;
    handler         trig_fn;
    double          break_time;
    double          TV[6];
    double          Tcross[2];
    double          Vcross[2];
    c_string        args;

public:
    inline double startV() {return TV[1] - TV[2];}
    inline double endV()   {return TV[4] - TV[5];}

    inline double startT() {return TV[0];}
    inline double endT()   {return TV[3];}

    inline PWLinDynData   *Xsrc() { return xsrc; }
    
    inline bool setTrig(double t) { if (trigger != t) {trigger = t; return true; }
                                    else return false; }

    inline void setTrigFn(handler fn) { trig_fn = fn; }
    
    inline void setTimes(double start, double end) { TV[0]=start; TV[3] = end; }
    
    inline DeviceInstance *pInst() { return pInstance; }
    
#   define TRIG_NEVER    "1"
#   define TRIG_ALWAYS   "2"
#   define TRIG_EARLY    "4"
#   define TRIG_MODE(m)   std::nan(m)
#   define TRIG_MODE_I(m) ((*m)-'0')
    
#   define MAN_LINK 1
#   if MAN_LINK
    static void *fnPtrs[eEnd]; // for manual linking
    static void setFns(void**);
#endif

    PwlHandler(PWLinDynData *XyceSrc, double trig = TRIG_MODE(TRIG_NEVER), handler hndlr = CrossHandler, c_string args = NULL);

    int PwlBridgeInit  (PWLinDynData *XyceSrc,void *);
    int PwlBridgeUpdate(PWLinDynData *XyceSrc,void *);


#   if  MAN_LINK
#   define FN_DECL(ret,nm,argt,arg) static inline ret nm argt {  typeof(::nm) *fn = (typeof(::nm) *)fnPtrs[e##nm]; return (*fn) arg; }
#   include "N_DEV_SourceDataExt.inc"
#   endif

    tTVVEC *getTV();
    
    inline void update() { DeviceResetNUM(xsrc); }
    inline bool  ready() { return NULL != pInstance; }

    
    double getParam(c_string nm,double dflt = 0.0);

    void setProbe(double time);
    
    void show_device();
    void show_linking();
    void show_inst();
};

