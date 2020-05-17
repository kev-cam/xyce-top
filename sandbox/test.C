#include <iostream>
#include <fstream>
#include <dlfcn.h>
#include <cstdint>
#include <assert.h>
#include <string.h>
#include <math.h>
#include <limits>

#include <xbridge.h>

#define NEED_FN_DECL
#include "N_DEV_SourceDataExt.h"

class PWLinDynData;

using namespace std;

// default handler
void Crossing(PwlHandler *,double skew,int dirn)
{
    
}

extern "C" {

BridgeFn ConnectPWL(PWLinDynData *XyceSrc,void **MyData, const char *args)
{
    PwlHandler *pwlh = new PwlHandler(XyceSrc,2.0);

    PwlHandler::setFns(MyData);
    *MyData = pwlh;
 
    cerr << "In ConnectPWL " << args << "\n";


    // pwlh->show_linking();
    pwlh->show_device();
    
    return PwlBridge;
}

}

