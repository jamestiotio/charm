#ifndef __ROUTINGALGORITHM_H
#define __ROUTINGALGORITHM_H
#include "../Main/BgSim_sim.h"
#include "../Topology/MainTopology.h"
#define SELECT_ANY_PORT -1

class RoutingAlgorithm {
        public:
        virtual int selectRoute(int current,int dst,int numP,Topology *top,Packet *p,map<int,int> & Bufsize){}
        virtual int expectedTime(int src,int dst,POSE_TimeType ovt,POSE_TimeType origovt,int len,int *hops){}
	//virtual int selectRoute(int,int,const Packet *){}
	virtual int convertOutputToInputPort(int,Packet *,int)=0;
	virtual void populateRoutes(Packet *,int){}
	virtual int loadTable(Packet *,int){}
	virtual int getNextSwitch(int){}
	virtual void sourceToSwitchRoutes(Packet *,int){}
};
#endif
