"codigo_tecnico.scd".loadRelative;

(
s.meter;
NodeTreeView(s).start;
)

~randDurLo  = 0.05;
~randDurHi  = 0.8;
~randRateLo = 1.0;
~randRateHi = 3.0;
~randDeltaLo = 0.02;
~randDeltaHi = 0.2;

//Liberar nodo 
s.sendMsg(\n_free, 1028);
