FN_DECL(tTVVEC*,  DeviceGetTVVEC,      (PWLinDynData *dev), (dev))
FN_DECL(double,   DeviceGetTime,       (PWLinDynData *dev), (dev))
FN_DECL(void,     DeviceResetNUM,      (PWLinDynData *dev), (dev))
FN_DECL(void,     DeviceRedoBreaks,    (PWLinDynData *dev), (dev))
FN_DECL(c_string, DeviceGetSrcName,    (PWLinDynData *dev), (dev))
FN_DECL(c_string, DeviceGetTypName,    (PWLinDynData *dev), (dev))
FN_DECL(c_string, DeviceGetPrmName,    (PWLinDynData *dev), (dev))

FN_DECL(int,      DevAddBreak,   (PWLinDynData *dev, double  bp),   (dev,bp))

FN_DECL(double,   DeviceGetParam,      (DeviceInstance *inst,c_string name,double dflt), (inst,name,dflt))
FN_DECL(c_string, InstanceGetName,     (DeviceInstance *inst), (inst))
FN_DECL(int,      InstanceGetVsrcV,    (DeviceInstance *inst, double *pRet), (inst,pRet))
FN_DECL(int,      InstanceGetIsrcV,    (DeviceInstance *inst, double *pRet), (inst,pRet))

#undef FN_DECL
