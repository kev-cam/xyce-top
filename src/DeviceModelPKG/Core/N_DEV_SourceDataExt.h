#include <vector>

// for inclusion in non-Xyce code to get some type-checking

class PWLinDynData;
class DeviceInstance;

using namespace std;

extern "C" {
typedef std::vector< std::pair<double,double> > tTVVEC;  // Array (time,voltage)
typedef const char *c_string;

#ifdef NEED_FN_DECL
#define FN_DECL(ret,nm,argt,arg) ret nm argt;
#include "N_DEV_SourceDataExt.inc"
#endif
    
}
