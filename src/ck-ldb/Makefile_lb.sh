#!/bin/sh
LOADBALANCERS="DummyLB RandCentLB RecBisectBfLB MetisLB RefineLB CommLB Comm1LB\
           GreedyLB NeighborLB GreedyRefLB OrbLB RandRefLB WSLB"

out="Makefile_lb"

echo "# Automatically generated by script Makefile_lb.sh" > $out
echo "#  by" `id` >>$out
echo "#  at" `hostname` >>$out
echo "#  on" `date` >> $out
echo "LOADBALANCERS=\\" >> $out
for bal in $LOADBALANCERS 
do 
	echo "   \$(L)/libmodule$bal.a \\" >> $out 
done
echo "   manager.o" >> $out
echo >> $out

cat >> $out << EOB 
manager.o: manager.C manager.h
	\$(CHARMC) -c manager.C

EOB

for bal in $LOADBALANCERS 
do 
	dep=""
	[ -r libmodule$bal.dep ] && dep="cp libmodule$bal.dep "'$'"(L)/"
        manager=""
        [ $bal = 'CommLB' ] && manager="manager.o"
	cat >> $out << EOB 
$bal.decl.h: $bal.ci charmxi
	\$(CHARMC) $bal.ci

$bal.o: $bal.C $bal.decl.h \$(CKHEADERS)
	\$(CHARMC) -c $bal.C

\$(L)/libmodule$bal.a: $bal.o $manager
	\$(CHARMC) -o \$(L)/libmodule$bal.a $bal.o $manager
	$dep

EOB
done

rm EveryLB.ci
echo "module EveryLB {" >> EveryLB.ci
for bal in $LOADBALANCERS
do
	echo "   extern module $bal;" >> EveryLB.ci
done
echo "   initnode void initEveryLB(void);" >>EveryLB.ci
echo "};" >> EveryLB.ci

echo "LB_OBJ=EveryLB.o \\" >>$out
for bal in $LOADBALANCERS
do
	echo "    $bal.o \\" >>$out
done
echo "    manager.o" >> $out
cat >> $out <<EOB

EveryLB.o: EveryLB.C EveryLB.decl.h
	\$(CHARMC) -c EveryLB.C

EveryLB.decl.h: EveryLB.ci
	\$(CHARMC) EveryLB.ci

\$(L)/libmoduleEveryLB.a: \$(LB_OBJ)
	\$(CHARMC) -o \$(L)/libmoduleEveryLB.a \$(LB_OBJ)
	cp libmoduleEveryLB.dep \$(L)/
EOB
