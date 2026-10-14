s.options.memSize = 262144;
s.options.sampleRate_(48000);
s.options.hardwareBufferSize_(128);

s.waitForBoot({
//*************************************************INICIALIZACIÓN/****************************************************//
MIDIClient.init;
MIDIIn.connectAll;

~bus=Array.fill(8,{Bus.audio(s,2)});

~fxGroup = Group.new(target: s, addAction: \addToTail);
~recPlayGroups = Array.fill(8, { |i| Group.head(s.defaultGroup)});

//*************************************************PLAY****************************************************//
~ampIn = Array.fill(2, {Bus.control(s,1)});
~ampIn.do {|bus| bus.set(0.73)};

~ampIn.do{ |bus, i|
	var ccNum = i;
	MIDIdef.cc(\ampIn_ ++ i, { |val| ("Input " ++ (i+1) ++" Amp: ").post; ~ampIn[i].value_(val.linlin(0,127,0.0,3.0).postln)},
		ccNum: ccNum, chan: 2)};

SynthDef(\input1,{
	var sig, env, amp;
	sig = SoundIn.ar(0);
	sig = Compander.ar(sig);
	env = Env.asr(releaseTime: \rel.kr(0.1)).kr(2,\gate.kr(1));
	amp = In.kr(~ampIn[0],1);
	sig = sig * env * amp;
	Out.ar (0, sig!2);
}).play;

SynthDef(\input2,{
	var sig, env, amp;
	sig = SoundIn.ar(1);
	sig = Compander.ar(sig);
	env = Env.asr(releaseTime: \rel.kr(0.1)).kr(2,\gate.kr(1));
	amp = In.kr(~ampIn[0],1);
	sig = sig * env * amp;
	Out.ar (0, sig!2);
}).play;


//*****************************************PLAYER, MAGFREEZE & SCRAMBLE************************************************//
~freezeGate = Array.fill(8, { Bus.control(s, 1) });
~freezeGate.do { |bus| bus.set(0) };

~freezeGate.do { |bus, i|
    var ccNum = 8 + i;
	MIDIdef.cc(\freezeOn_ ++ i, {("Freeze " ++ (i+1) ++ " ON").postln; bus.set(1) },
        ccNum: ccNum, chan: 1, argTemplate: { |val| val == 127 });
	MIDIdef.cc(\freezeOff_ ++ i, {("Freeze " ++ (i+1) ++ " OFF").postln; bus.set(0) },
        ccNum: ccNum, chan: 1, argTemplate: { |val| val == 0 });
};

~scrambleGate = Array.fill(8, {Bus.control(s,1)});
~scrambleGate.do {arg bus; bus.set(0)};

~scrambleGate.do { arg bus, i;
	var ccNum = 16 + i;
	MIDIdef.cc(\scrambleOn_ ++ i , { ("Scramble " ++ (i+1) ++ " ON").postln; bus.set(1) },
		ccNum: ccNum, chan: 1, argTemplate: {arg val; val == 127});
	MIDIdef.cc(\scrambleOff_ ++ i, { ("Scramble " ++ (i+1) ++ " OFF").postln; bus.set(0) },
		ccNum: ccNum, chan: 1, argTemplate: {arg val; val == 0});
};

~scrambleAmt = Array.fill(8, {Bus.control(s,1)});
~scrambleAmt.do {|bus| bus.set(0.5)};

~scrambleAmt.do{ |bus, i|
	var ccNum = 8 + i;
	MIDIdef.cc(\scrambleAmt_ ++ i,{|val| ("Scramble Amount " ++ (i+1) ++ ": ").post; ~scrambleAmt[i].value_(val.linlin(0,127,0.0,1.0).postln)},
		ccNum: ccNum,chan: 0)};

~amp = Array.fill(8, {Bus.control(s,1)});
~amp.do {|bus| bus.set(0.8)};

~amp.do{ |bus, i|
	var ccNum = i;
	MIDIdef.cc(\amp_ ++ i, { |val| ("Amp " ++ (i+1) ++": ").post; ~amp[i].value_(val.linlin(0,127,0.0,1.3).postln)},
		ccNum: ccNum, chan: 0)};

~rate = Array.fill(8,{Bus.control(s,1)});
~rate.do {|bus| bus.set(1)};

~rate.do{ |bus, i|
	var ccNum = 24 + i;
	MIDIdef.cc(\rate_ ++ i,{|val| ("Rate " ++ (i+1) ++ ": ").post; ~rate[i].value_(val.linlin(0,127,-1.0,1.0).postln)},
		ccNum: ccNum, chan: 0)};

SynthDef(\player,{
	arg gate = 1, buf = 0, pan = 0, start = 0;
	var sig, env, inicio, amp, sigOut, sigBus, chain, freezeGate, scrambleGate, scrambleAmount, outSig, rate1;
	amp = In.kr(\amp.kr);
	freezeGate = In.kr(\fGate.kr);
	scrambleGate = In.kr(\scrambleGate.kr);
	scrambleAmount = In.kr(\scrambleAmt.kr);
	inicio = BufFrames.kr(buf) * \startPos.kr();
	rate1 = In.kr(\rate.kr);
	sig = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * rate1, rate1,startPos: inicio, loop: 1);
	env = Env.asr(releaseTime: 0.5).kr(gate: gate, doneAction: 2);
	sig = sig * env;
	chain = FFT(LocalBuf(2048), sig);
    chain = PV_MagFreeze(chain, freezeGate);
	chain = PV_BinScramble(chain, scrambleAmount * scrambleGate, 0.1);
	outSig = IFFT(chain);
	sigBus = outSig * amp;
	sigOut = Pan2.ar(outSig*amp, \pos.kr);
	Out.ar(0,sigOut);
	Out.ar(\outBus.kr, sigBus!2);
}).add;

~buf = Array.newClear(8);
//*****************************************************RECORD BUFF****************************************************//

~recBuff = Array.fill(8, {Buffer.alloc(s, s.sampleRate * 15, 1)});
s.sync;

SynthDef(\recorder, {
	|buf, gate = 1|
	var sig, env;
	env = EnvGen.kr(Env.asr(0.5, 1, 0.5), gate, doneAction: 2);
	sig = SoundIn.ar(\in.kr) * env * 1.1;
	RecordBuf.ar(sig, buf, run: gate,loop: 0);
}).add;

~togRec = Array.fill(8,{0});
~recSynth = Array.newClear(8);
~playSynth = Array.newClear(8);
~startTime = Array.newClear(8);
~endTime = Array.newClear(8);
~recDur = Array.newClear(8);
~finalFrames = Array.newClear(8);
~stopSynthR = Array.newClear(8);


~playSynth.do { |bus, i|
	var ccNum = i;
	MIDIdef.cc(\recorderToggle_ ++ i, {
		switch(~togRec[i],
			0, {
				~togRec[i] = 1;
				~recBuff[i].zero;
				("Grabación " ++ (i + 1)).postln;
				~startTime[i] = SystemClock.seconds;
				~recSynth[i] = Synth.tail(~recPlayGroups[i],\recorder, [\buf, ~recBuff[i].bufnum, \in,(i < 4).if({0},{1})]);
			},
			1, {
				~togRec[i] = 2;
				("Reproducción " ++ (i + 1)).postln;
				~buf[i] = nil;
				~recSynth[i].set(\gate, 0);
				~endTime[i] = SystemClock.seconds;
				~recDur[i] = ~endTime[i] - ~startTime[i];
				~finalFrames[i] = (~recDur[i] * s.sampleRate).asInteger;
				~buf[i] = Buffer.alloc(s, ~finalFrames[i], 1);
				~recBuff[i].copyData(~buf[i]);
				~playSynth[i] = Synth.tail(~recPlayGroups[i],\player, [
					\buf, ~buf[i],
					\rate, ~rate[i].set(1),
					\amp, ~amp[i],
					\pos, 0,
					\startPos, 0,
					\fGate, ~freezeGate[i],
					\scrambleGate, ~scrambleGate[i],
					\scrambleAmt, ~scrambleAmt[i],
					\outBus, ~bus[i]
				]);
			},
			2, {
				~stopSynthR[i] =
					~togRec[i] = 0;
					("Detener " ++ (i + 1)).postln;
					~playSynth[i].set(\gate, 0);
			}
		);
	}, ccNum: ccNum, chan: 1, argTemplate: {|val| val == 127});
};

//*****************************************************MODO ALEATORIO****************************************************//
~randMode = Array.fill(8, { 0 }); //toggle
~randStream = Array.newClear(8); //array de Pbinds

// Parámetros
~randDurLo  = 0.05;
~randDurHi  = 0.8;
~randRateLo = -2.0;
~randRateHi = 2.0;
~randDeltaLo = 0.02;
~randDeltaHi = 1.2;

~startRandStream = { |i|
	var pbind;
	~playSynth[i].tryPerform(\set, \amp, ~ampIn[0].getSynchronous);
	~playSynth[i].tryPerform(\set, \gate, 0);

	pbind = Pbind(
		\instrument, \player,
		\group,      ~recPlayGroups[i],
		\buf,        Pfunc { ~buf[i].bufnum},
		\rate,       Pfunc { rrand(~randRateLo, ~randRateHi) * [-1,1].choose },
		\dur,        Pfunc { rrand(~randDurLo, ~randDurHi) },
		\delta,      Pfunc { rrand(~randDeltaLo, ~randDeltaHi) },
		\amp,        Pfunc { ~amp[i] },
		\pos,        Pfunc { rrand(-1.0, 1.0) },
		\startPos,   Pfunc { rrand(0.0, 0.85) },
		\fGate,      Pfunc { ~freezeGate[i] },
		\scrambleGate, Pfunc { ~scrambleGate[i] },
		\scrambleAmt,  Pfunc { ~scrambleAmt[i] },
		\outBus,     ~bus[i],
		\addAction,  \addToTail
	);
	~randStream[i] = pbind.play(TempoClock.default, quant: 0);
	("Modo aleatorio ON — looper " ++ (i+1)).postln;
};

~stopRandStream = { |i|
	~randStream[i].tryPerform(\stop);
	~randStream[i] = nil;
	if (
			(~togRec[i] == 2)
			and: { ~buf[i].notNil }
			) {
		~playSynth[i].tryPerform(\free);
		~playSynth[i] = Synth.tail(~recPlayGroups[i], \player, [
			\buf,          ~buf[i],
			\amp,          ~amp[i],
			\pos,          0,
			\startPos,     0,
			\fGate,        ~freezeGate[i],
			\scrambleGate, ~scrambleGate[i],
			\scrambleAmt,  ~scrambleAmt[i],
			\outBus,       ~bus[i]
		]);
	};
	("Modo aleatorio OFF — looper " ++ (i+1)).postln;
};

8.do { |i|
	var ccNum = 56 + i;
	MIDIdef.cc(\randOn_ ++ i, {
		{ ~startRandStream.(i) }.defer;
	}, ccNum: ccNum, chan: 1, argTemplate: { |val| val == 127 });

	MIDIdef.cc(\randOff_ ++ i, {
		{ ~stopRandStream.(i) }.defer;
	}, ccNum: ccNum, chan: 1, argTemplate: { |val| val == 0 });
};

//*****************************************************PAUL STRECH****************************************************//

~psRate = Array.fill(8,{Bus.control(s,1)});
~psRate.do {|bus| bus.set(50)};

~psRate.do{ |bus, i|
	var ccNum = 40 + i;
	MIDIdef.cc(\psRate_ ++ i,{|val| ("PS Rate " ++ (i+1) ++ " : ").post; ~psRate[i].value_(val.linlin(0,127,-150,150).postln)},
		ccNum: ccNum, chan: 0)};

~psAmp = Array.fill(8,{Bus.control(s,1)});
~psAmp.do {|bus| bus.set(0.4)};

~psAmp.do{ |bus, i|
	var ccNum = 32 + i;
	MIDIdef.cc(\psAmp_ ++ i,{|val| ("PS Amp " ++ (i+1) ++ " : ").post; ~psAmp[i].value_(val.linlin(0,127,0.0,1).postln)},
		ccNum: ccNum, chan: 0)};

SynthDef(\paulstretchMono, { |out = 0, bufnum, envBufnum, pan = 0, window = 0.25|
	var trigPeriod, sig, chain, trig, pos, fftSize, env, stretch, randOffset, amp;
	amp = In.kr(\psAmp.kr);
	stretch = In.kr(\stretchp.kr);
	fftSize = 2**floor(log2(window*SampleRate.ir));
	trigPeriod = fftSize/SampleRate.ir;
	randOffset = Rand(0.0, BufDur.kr(bufnum) - (trigPeriod/stretch));
	trig = Impulse.ar(1/trigPeriod);
	pos = Demand.ar(trig, 0, Dseries(randOffset, trigPeriod/stretch));
	sig = [GrainBuf.ar(1, trig, trigPeriod, bufnum, 1, pos, envbufnum: envBufnum),
		GrainBuf.ar(1, trig, trigPeriod, bufnum, 1, pos + (trigPeriod/(2*stretch)), envbufnum: envBufnum)]*amp;
	sig = sig.collect({ |item, i|
		chain = FFT(LocalBuf(fftSize), item, hop: 1.0, wintype: -1);
		chain = PV_Diffuser(chain, 1 - trig);
		item = IFFT(chain, wintype: -1);
	});
	sig = sig*PlayBuf.ar(1, envBufnum, 1/(trigPeriod), loop:1);
	sig[1] = DelayC.ar(sig[1], trigPeriod/2, trigPeriod/2);
	env = Env.asr().kr(2,\gate.kr(1));
	Out.ar(out, Pan2.ar(Mix.new(sig*env), pan));
}).add;

~envSignal = Signal.newClear(s.sampleRate).waveFill({|x| (1 - x.pow(2)).pow(1.25)}, -1.0, 1.0);
~envBuf = Array.fill(8, {Buffer.alloc(s, s.sampleRate, 1)});
s.sync;
~envBuf.do {|buff| buff.loadCollection(~envSignal)};
~psSynth = Array.newClear(8);

~envBuf.do{|buff, i|
	var ccNum = 24 + i;
	MIDIdef.cc(\pStretchOn_ ++ i, {
		("Paul Stretch " ++ (i+1) ++ " ON").postln;
		~psSynth[i].tryPerform(\free);
		~psSynth[i] = Synth.tail(~recPlayGroups[i],\paulstretchMono, [
		\bufnum, ~buf[i],
		\envBufnum, ~envBuf[i].bufnum,
		\psAmp, ~psAmp[i],
		\stretchp, ~psRate[i]])},
	ccNum: ccNum ,chan: 1,  argTemplate: {|val| val == 127});
	MIDIdef.cc(\pStretchOff_ ++ i, {
		("Paul Stretch " ++ (i+1) ++ " OFF").postln;
		~psSynth[i].set(\gate,0)},
	ccNum: ccNum ,  chan: 1, argTemplate: {|val| val == 0})};

//*****************************************************DELAY****************************************************//
~delT = Array.fill(8, {Bus.control(s,1)});
~delT.do {|bus| bus.set(0.4)};

~delT.do{ |bus, i|
	var ccNum = 16 + i;
	MIDIdef.cc(\delT_ ++ i,{|val|
		("Del Time " ++ (i+1) ++ " : ").post;
		~delT[i].value_(val.linlin(0,127,0.1,1.0).postln)},
		ccNum: ccNum, chan: 0)};

SynthDef(\pingPongDelay, {
    var sig, delTime, feedback, dry, wet, delayedL, delayedR, output;

    // Parámetros controlables
    delTime = In.kr(\delT.kr(0.4));  // Tiempo de delay (sincronizado con MIDI)
    feedback = \fb.kr(0.5);           // Cantidad de retroalimentación (0-1)
    dry = \dry.kr(1.0);               // Señal seca
    wet = \wet.kr(0.7);               // Señal con delay

    // Señal de entrada (estéreo)
    sig = In.ar(\busIn.kr, 2);

    // Procesamiento del ping-pong delay
    delayedL = DelayN.ar(sig[1], 10, delTime);  // Delay del canal derecho en el izquierdo
    delayedR = DelayN.ar(sig[0], 10, delTime);  // Delay del canal izquierdo en el derecho

    // Retroalimentación cruzada (alternancia estéreo)
    delayedL = delayedL + DelayN.ar(delayedR, 10, delTime) * feedback;
    delayedR = delayedR + DelayN.ar(delayedL, 10, delTime) * feedback;

    // Mezcla de señal seca y procesada
    output = [
        (sig[0] * dry) + (delayedL * wet),
        (sig[1] * dry) + (delayedR * wet)
    ];

    // Envolvente para suavizar encendido/apagado
    output = output * 0.55 * Env.asr(\rel.kr(0.2)).kr(2, \gate.kr(1));

    Out.ar(\out.kr(0), output);
}).add;

~delP = Array.newClear(8);

~bus.do{|bus, i |
    var ccNum = 32 + i;
    MIDIdef.cc(\delOn_ ++ i, {
        ("Delay " ++ (i+1) ++ " ON").postln;
        ~delP[i].tryPerform(\free);
		~delP[i] = Synth(\pingPongDelay, [
    \busIn, ~bus[i],
    \delT, ~delT[i],
    \fb, 0.6,    // Feedback más alto = más repeticiones
    \wet, 0.8    // Más señal procesada
], ~fxGroup)
    },
    ccNum: ccNum, chan: 1, argTemplate: {|val| val == 127});

    MIDIdef.cc(\delOff_ ++ i, {
        ("Delay " ++ (i+1) ++ " OFF").postln;
        ~delP[i].set(\gate, 0)
    },
    ccNum: ccNum, chan: 1, argTemplate: {|val| val == 0})};

//*************************************************DISTORCIÓN****************************************************//

SynthDef(\distor,{
    var sig, amp, od, speakerSim, comp, env;
	env = Env.asr(releaseTime: \rel.kr(0.2)).kr(2,\gate.kr(1));
    sig = In.ar(\bus.kr, 2);
    sig = sig * env * 0.3;
    sig = sig * \drive.kr(10);
    od = tanh(sig);
    od = od * abs(od) * \driveShape.kr(1.5);
    od = Limiter.ar(od, level: 0.9);
	comp = Compander.ar(
        od, od,
        thresh: 0.3,
        slopeBelow: 1,
        slopeAbove: 0.5,
        clampTime: 0.01,
			relaxTime: 0.1);
    speakerSim = LPF.ar(comp, 3500);
    speakerSim = HPF.ar(speakerSim, 100);
    Out.ar(\out.kr([0,1]), speakerSim);
}).add;

~disP = Array.newClear(8);

~disP.do{|bus, i |
	var ccNum = 40 + i;
	MIDIdef.cc(\disOn_ ++ i, {
		("Distorsión " ++ (i+1) ++ " ON").postln;
		~disP[i].tryPerform(\free);
		~disP[i] = Synth(\distor,[\bus, ~bus[i]],target: ~fxGroup)},
	ccNum: ccNum, chan: 1, argTemplate: {|val| val == 127});
	MIDIdef.cc(\isOff_ ++ i, {
		("Distorsión " ++ (i+1) ++ " OFF").postln;
		~disP[i].set(\gate, 0)},
	ccNum: ccNum, chan: 1, argTemplate: {|val| val == 0})};

//*************************************************GRANULACIÓN****************************************************//
~grainBuff = Array.fill(8, Buffer.alloc(s, s.sampleRate * 6));
s.sync;

SynthDef(\grainLive, {
	var sig, env, amp, mic, ptr, pos, buf = \buf.kr(0);
	env = Env.asr(\atk.ir(0.1), \sus.ir(1), \rel.ir(1)).kr(2, \gate.kr(1));
	mic = In.ar(\bus.kr ? 0, 2).mean;  // Conversión estéreo->mono
	ptr = Phasor.ar(0, 1, 0, BufFrames.kr(buf));
	BufWr.ar(mic, buf, ptr);

	pos = (ptr/SampleRate.ir) - 0.25;
	pos = pos + LFNoise1.kr(100).bipolar(0.2);

	sig = TGrains.ar(
		numChannels: 2,
		trigger: Dust.kr(40),
		bufnum: buf,
		rate: \rate.kr(1),
		centerPos: pos,
		dur: 0.05,
		pan: LFNoise0.kr(0.3).range(-1, 1),
		amp: 2,
	);
	sig = sig * env ;
	Out.ar(\out.kr(0), sig);
}).add;

~grainP = Array.newClear(8);


~grainP.do{|bus, i |
	var ccNum = 48 + i;
	MIDIdef.cc(\grainOn_ ++ i, {
		("Granulación " ++ (i+1) ++ " ON").postln;
		~grainP[i].tryPerform(\free);
		~grainP[i] = Synth(\grainLive,[\buf, ~grainBuff[i], \bus, ~bus[i]],target: ~fxGroup)},
	ccNum: ccNum, chan: 1, argTemplate: {|val| val == 127});
	MIDIdef.cc(\grainOff_ ++ i, {
		("Granulación " ++ (i+1) ++ " OFF").postln;
		~grainP[i].set(\gate, 0)},
	ccNum: ccNum, chan: 1, argTemplate: {|val| val == 0})};



StageLimiter.activate;

});