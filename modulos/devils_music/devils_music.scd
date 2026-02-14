b = Buffer.alloc(s, s.sampleRate * 5);

b.zero;
b.plot;

(
x = {
	var sig;
	sig = SoundIn.ar(0);
	RecordBuf.ar(sig, b, \offset.kr(0), \reclev.kr(1).varlag(0.3), \prelev.kr(0).varlag(0.3), \run.kr(1), \loop.kr(1));
	PlayBuf.ar(1!2, b, loop:1);
}.play;
)

x.set(\reclev,0,\prelev, 1);
x.set(\reclev,1,\prelev, 2);


