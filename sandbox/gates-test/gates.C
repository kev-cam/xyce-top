#include <iostream>
#include <fstream>
#include <dlfcn.h>
#include <cstdint>
#include <assert.h>
#include <string.h>
#include <vector>
#include <math.h>
#include <limits>

#include "xbridge.h"
#include "gates.h"

std::vector<Inverter *> Inverters;
std::vector<Inverter *> InvertersTmp;

void Gate::setParams() {
    v_min  = out->getParam("Vmin", v_min);
    t_tol  = out->getParam("Ttol", t_tol);
    v_tol  = out->getParam("Vtol", v_tol);
    delay  = out->getParam("Delay",v_tol);
    rise_t = out->getParam("RiseT",v_tol);
    fall_t = out->getParam("FallT",v_tol);
}

bool Inverter::Finished() {
    bool ret = false;
    if (NULL != in[0] &&
        NULL != vdd   &&
        NULL != out   && out->ready()) {
        setParams();
        ret = true;
    }
    return ret;
}

void Inverter::Eval(double now) {
    double v_in = in[0]->startV();
    double v_dd = vdd->startV();
    if (abs(v_dd - vdd_last) >= v_tol) {
        vdd_last = v_dd;
        in[0]->setTimes(now,now);
        lgc_pend |= LGC_UNKNOWN;
        if (v_dd > v_min && v_in > (v_dd/2)) {
            InvInCross(in[0],0.0,0.0,v_dd);
        } else {
            InvInCross(in[0],0.0,v_dd,0.0);       
        }
    }
    in[0]->setProbe(t_tol/2.0);
}

extern "C" {

void InvSetVdd(PwlHandler *pwlh,double skew,double Vbegin, double Vend)
{
    GatePwlHandler *gpwlh = (GatePwlHandler *)pwlh;

    Inverter *inv = (Inverter *)gpwlh->gate;

    if (inv->In()->setTrig(Vbegin/2.0)) {
        inv->Eval(inv->Vdd()->endT());
    }
}
    
void InvInCross2(PwlHandler *pwlh,double skew,double Vbegin, double Vend)
{
    GatePwlHandler *gpwlh = (GatePwlHandler *)pwlh;

    Inverter &inv = (*(Inverter *)gpwlh->gate);

    GatePwlHandler &out(*inv.Out());
    GatePwlHandler &vdd(*inv.Vdd());
    tTVVEC         &TV(*out.getTV());

    double  dt = inv.Delay() - skew;

    if (dt < 0.0) {
        // ???
        dt = 0.0;
    }
    
    double Ve,trf;
    int lgc_out = (Vbegin < Vend); // 1 if true, 0 otherwise
    int lgc_stt = inv.LgcPend();

    if ((lgc_stt & ~LGC_UNKNOWN) == lgc_out) {
        return;
    }

    if (inv.setLgcPend(lgc_out)) {
        Ve = vdd.endV(); trf = inv.RiseT(); 
    } else {             // input falling
        Ve = 0.0;        trf = inv.FallT(); 
    }
        
    double           t0  = inv.In()->startT();
    double           nxt = t0 + dt;
    double           tl  = -1e-20;

    std::pair<double,double> TVnew[3] ={std::pair<double,double>(nxt,0.0),
                                        std::pair<double,double>(nxt+trf,Ve),
                                        std::pair<double,double>(std::numeric_limits<double>::max(),Ve)};
    tTVVEC::iterator tv0,tv;
    double t;
    for (;;) {
        tv0 = tv = TV.begin();
        tv++;
        t = (*tv).first;
        if (t >= t0) break;
            TV.erase(tv0); // discard old pt
    }
        
    tTVVEC::iterator tvl = tv0;
    double vl,v;
    for (tv = tv0;;tv++) {
        t  = (*tv).first;
        v  = (*tv).second;
        if (abs(dt = t - nxt)  < inv.Ttol()) {
            tv++;
            // on top
            if (abs(v - Ve) < inv.Vtol()) {
                goto no_change;
            }
            TV.erase(tv,TV.end());
            break;
        } else {
            if (dt > 0) {
                (*tv).first  = nxt;
                (*tv).second = v + ((vl - v) * dt/(t - tl));
                tv++;
                break;
            }
        }
        assert(t > tl);
        vl  = v;
        tl  = t;
        tvl = tv;
    }
    TV.erase(tv,TV.end());
    TV.push_back(TVnew[1]);
    TV.push_back(TVnew[2]);
    double v0,dv,frc,vx,tx;
    tv0 = TV.begin();
    while (TV.size() > 4) { // eliminate interim pts
        tv  = tv0;
        tvl = ++tv;
        if (tvl == TV.end()) break;
        tvl++;
        tl  = (*tvl).first;
        t   = (*tv).first;
        t0  = (*tv0).first;
        v0  = (*tv0).second;
        vl  = (*tvl).second;
        dv  = vl - v0;
        dt  = tl - t0;
        v   = (*tv).second;
        frc = (t - t0)/dt;
        vx  = v0 + frc * dv;
        if (abs(vx - v) < inv.Vtol()) {
        discard:
            TV.erase(tv);
        } else {
            tv0++;
        }
    }
    out.update();
no_change:;
}
    
void InvInCross(PwlHandler *pwlh,double skew,double Vbegin, double Vend)
{
    GatePwlHandler *gpwlh = (GatePwlHandler *)pwlh;

    Inverter &inv = (*(Inverter *)gpwlh->gate);

    GatePwlHandler *out = inv.Out();

    if (NULL != out) { // still initializing ?
        InvInCross2(pwlh,skew,Vbegin,Vend);
        pwlh->setTrigFn(InvInCross2);
    }
}
    
int GatePwlBridgeOut(PWLinDynData *XyceSrc,void *MyData, int op, void *data)
{
    Inverter *inv = (Inverter *)MyData;
    return PwlBridge(XyceSrc,inv->Out(),op,data);
}
    
int GatePwlBridgeIn(PWLinDynData *XyceSrc,void *MyData, int op, void *data)
{
    Inverter *inv = (Inverter *)MyData;
    return PwlBridge(XyceSrc,inv->In(),op,data);
}
    
int GatePwlBridgeVdd(PWLinDynData *XyceSrc,void *MyData, int op, void *data)
{
    Inverter *inv = (Inverter *)MyData;
    return PwlBridge(XyceSrc,inv->Vdd(),op,data);
}
    
BridgeFn AttachInv(PWLinDynData *XyceSrc,void **MyData, const char *args)
{
    BridgeFn bFn;
    std::vector<Inverter *>::iterator ii = InvertersTmp.begin();
    bool new_inv = false;
    Inverter *inv,*check = NULL;
    
    if (ii == InvertersTmp.end()) { // first time only
        inv = new Inverter();
        PwlHandler::setFns(MyData);
        InvertersTmp.insert(InvertersTmp.begin(),inv);
    } else {
        inv = *ii; // try adding to last
    }
    
    if (0 == strncasecmp(args,"output",6)) {
        if (new_inv = (NULL != inv->Out())) {
            check = inv;
            inv   = new Inverter();
        }
        while (*args && *args++ != ',');
        inv->setOut(new GatePwlHandler(XyceSrc,inv,args));
        bFn = GatePwlBridgeOut;
        
    }
    else if (0 == strncasecmp(args,"vdd",3)) {
        if (new_inv = (NULL != inv->Vdd())) {
            check = inv;
            inv   = new Inverter();
        }
        while (*args && *args++ != ',');
        inv->setVdd(new GatePwlHandler(XyceSrc,inv,args,TRIG_MODE(TRIG_ALWAYS),InvSetVdd));
        bFn = GatePwlBridgeVdd;
    }
    else {
        while (*args && !(isdigit(*args) || ',' == *args)) {
            args++;
        }
        if (new_inv = (NULL != inv->In())) {
            check = inv;
            inv   = new Inverter();
        }
        while (*args && *args++ != ',');
        inv->setIn(new GatePwlHandler(XyceSrc,inv,args,TRIG_MODE(TRIG_NEVER),InvInCross)); // sensitize later
        bFn = GatePwlBridgeIn;
    }
        
    if (NULL != check) { // Trying to build two at once?
        if (check->Finished()) {
            assert(*ii == check);
            InvertersTmp.erase(ii);
            Inverters.push_back(check);
        }            
    }
        
    if (new_inv) {
        InvertersTmp.insert(InvertersTmp.begin(),inv);
    }
    else {
        if (inv->Finished()) {
            assert(*ii == inv);
            InvertersTmp.erase(ii);
            Inverters.push_back(inv);
        }
    }

    *MyData = inv;

    return bFn;
}

}
