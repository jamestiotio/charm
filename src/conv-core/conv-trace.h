/*****************************************************************************
 * $Source$
 * $Author$
 * $Date$
 * $Revision$
 *****************************************************************************/

#ifndef _CONV_TRACE_H
#define _CONV_TRACE_H

#include "converse.h"

/* 
 * These functions are called from Converse, and should be provided C binding
 * by the tracing strategies.
 */

void traceInit(char **argv);
void traceCharmInit(char **argv);	/* init trace module in ck */
void traceMessageRecv(char *msg, int pe);
void traceBeginIdle(void);
void traceEndIdle(void);
void traceResume(CmiObjId *);
void traceSuspend(void);
void traceAwaken(CthThread t);
void traceUserEvent(int);
void traceUserBracketEvent(int, double, double);
int  traceRegisterUserEvent(const char*, int e
#ifdef __cplusplus
=-1
#endif
);

int registerFunction(char*);
void beginFuncIndexProj(int, char*, int);
void endFuncIndexProj(int);

void traceClose(void);
void traceCharmClose(void);          /* close trace in ck */
void traceBegin(void);
void traceEnd(void);
void traceWriteSts(void);
void traceFlushLog(void);

#ifndef CMK_OPTIMIZE
CpvExtern(int, traceOn);
#define traceIsOn()  (CpvAccess(traceOn))
#else 
#define traceIsOn()  0
#endif

int  traceAvailable();

#endif
