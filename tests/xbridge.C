#include <iostream>
#include <fstream>
#include <dlfcn.h>
#include <cstdint>
#include <math.h>
#include <limits>
#include <assert.h>
#include <string.h>

#include "xbridge.h"

extern "C" {

// default handler
void CrossHandler(PwlHandler *,double skew,double Vp, double Vn)
{
    
}

}

PwlHandler::PwlHandler(PWLinDynData *XyceSrc, double trig, handler hndlr, c_string attr)
    : pInstance(NULL),
      xsrc(XyceSrc),
      trigger(trig),
      trig_fn(hndlr),
      args(attr)
{
    if (!*fnPtrs) { 
        intptr_t i = sizeof(fnPtrs)/sizeof(*fnPtrs);
        while (i-- > 0) {
            fnPtrs[i] = (void *)i;
        }
    }
    voltage   = false;
    triggered = 0;
    if (NULL == hndlr && trigger != trigger) {
        long long mode = 0xF & *(long long *)&trigger;
        assert(TRIG_MODE_I(TRIG_NEVER) == mode);
    }
}

tTVVEC *PwlHandler::getTV()
{
    return DeviceGetTVVEC(xsrc);
}

double PwlHandler::getParam(c_string nm,double dflt)
{
    const char *cp = args;
    if (NULL != cp) {
        int l = strlen(nm);
        while (NULL != (cp = strcasestr(cp,nm))) {
            cp += l;
            if ('=' == *cp++) {
                double d;
                if (1 == sscanf(cp,"%lg",&d)) {
                    return d;
                }
                cerr << "Couldn't convert " << cp << " to double\n";
            }
        }
    }
    return dflt;
}

void PwlHandler::show_linking()
{
    intptr_t i = sizeof(fnPtrs)/sizeof(*fnPtrs);
    while (i-- > 0) {
        cerr << "Func[" << i << "] = " << fnPtrs[i] << "\n";
    }
}

void PwlHandler::show_device() {
    cerr << "Source:   " << DeviceGetSrcName(xsrc) << "\n";
    cerr << "Type:     " << DeviceGetTypName(xsrc) << "\n";
    cerr << "Param:    " << DeviceGetPrmName(xsrc) << "\n";
}

void PwlHandler::show_inst() {
    cerr << "Instance: " << InstanceGetName(pInstance) << "\n";
}

int PwlHandler::PwlBridgeInit(PWLinDynData *XyceSrc,void *data)
{
    assert(xsrc == XyceSrc);

    pInstance = (DeviceInstance *)data;

    // show_inst();
    
    c_string inm = InstanceGetName(pInstance);
    c_string cp  = inm;
    c_string next;
    while ((next = strstr(cp,":"))) {
        cp = ++next;
    }
    switch (*cp) {
        case 'v':
        case 'V': voltage = true; 
    }
    
    tTVVEC *TVvec = DeviceGetTVVEC(XyceSrc);

    TVvec->push_back(std::pair<double,double>(                                 0,0));
    TVvec->push_back(std::pair<double,double>(std::numeric_limits<double>::max(),0));

    DeviceResetNUM(XyceSrc);
    
    return 0;
}

void PwlHandler::setProbe(double time)
{    
    tTVVEC &TV(*DeviceGetTVVEC(xsrc));

    tTVVEC::iterator t2 = TV.begin();
    tTVVEC::iterator t0 = t2++;

    while ((*t2).first < time) {
        t0 = t2++;
    }
    double v0 = (*t0).second;
    double v2 = (*t2).second;
    if (v0 == v2) {
        tTVVEC::iterator t1 = t2++;
        if (TV.end() == t2) {
            TV.insert(t1,std::pair<double,double>(time,v2));
        } else {
            if (v0 == (v2 = (*t2).second)) {
                if ((*t1).first == time) {
                    return;
                }
                (*t1).first  = time;
            }
        }
    }
    update();
}


int PwlHandler::PwlBridgeUpdate(PWLinDynData *XyceSrc,void *data)
{
    tTVVEC *TVvec = (tTVVEC *)data;    
    double  time  = DeviceGetTime(XyceSrc);
    double  t1,t2,v1,v2;
    int     sts;

    if (voltage) {
        sts = InstanceGetVsrcV(pInstance,TV);
    } else {
        sts = InstanceGetIsrcV(pInstance,TV);
    
        if (3 == sts) {
            t1 = TV[0]; v1 = TV[1] - TV[2];
            t2 = TV[3]; v2 = TV[4] - TV[5];
            
            // cerr << "Voltage = " << t1 << ":"<< v1 << "->" << t2 << ":" << v2 << "\n";
            
            double skew;
            double div;
            if (triggered && t1 >= break_time) {
                triggered = 0;
                skew      = t1 - break_time;
            call_tf:
                (*trig_fn)(this,skew,Vcross[0],Vcross[1]);
            }
            if (trigger != trigger) { // NaN
                switch (0xF & (*(long long *)&trigger)) {
                case TRIG_MODE_I(TRIG_ALWAYS): break_time = t2;
                                               triggered = 3;
                                               goto do_trig;            // always
                case TRIG_MODE_I(TRIG_EARLY):  skew = break_time - t1;  // negative
                                               goto call_tf;
                default:                       break;                   // do nothing
                }
            }
            else if ((v1 <= trigger && trigger <= v2 && (triggered = 1)) || // rising
                     (v2 <= trigger && trigger <= v1 && (triggered = 2))) { // falling
                if (v1 != v2) { 
                    div = (trigger-v1)/(v2-v1); 
                    // crossing
                    break_time = t1 + div * (t2 - t1);
                do_trig:
                    Tcross[0] = t1; Tcross[1] = t2;
                    Vcross[0] = v1; Vcross[1] = v2;
                    DevAddBreak(XyceSrc,break_time);
                }
            }
        }
    }
    
    return 0;
}

void *PwlHandler::fnPtrs[eEnd];
void  PwlHandler::setFns(void **fns)
{
    if (*fns && NULL == fnPtrs[0]) { // manual linking if set
        memcpy(fnPtrs,*fns,sizeof(fnPtrs));        
    }
}

extern "C" {

int PwlBridge(PWLinDynData *XyceSrc,void *MyData, int op, void *data)
{
    PwlHandler &pwlh(*(PwlHandler *)MyData);
    switch (op) {
# define BRIDGE_OP(o) case o: return pwlh.PwlBridge##o(XyceSrc,data);
# include "N_DEV_BridgeOp.inc"
    }
    return -1;
}

}

