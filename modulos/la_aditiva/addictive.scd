
MIDIdef.freeAll;

MIDIFunc.trace(false);
MIDIFunc.trace(true);

---------------------------
MIDIClient.init;
MIDIIn.connectAll;

//NanoKontrolStudio: cc 0 - 7 faders, cc 8 - 15 knobs, todo en ch 0

//Frecuencia fundamental que deriva los demás armónicos
~root = Bus.control(s,1);
~root.set(33); //Valor inicial de 33
MIDIdef.cc(\root, {|val| "Root freq : ".post; ~root.value_(val.linlin(0,127,20,2000).postln)}, 0, 0);

//Número de parciales
~harms = Bus.control(s,33);
33.do { |i| ~harms.setAt(i, 1.0) };
MIDIdef.cc(\harms, {|val| var harms;
	"Cantidad de armónicos : ".post;
	harms = val.linlin(0,127,0,33).asInteger.postln;
	33.do({ |i| ~harms.setAt(i, if( i <  harms,1.0,0) )})},
1, 0
);

//Factor de cercanía (unísono cuando es 0)
~close = Bus.control(s,1);
~close.set(1);
MIDIdef.cc(\close, {|val| "Cercanía : ".post; ~close.value_(val.linlin(0,127,0.0,3.0).postln)}, 2, 0); //Valores de 0 a 3

//Frecuencia de modulación AM
~modFreq = Bus.control(s,1);
~modFreq.set(1);
MIDIdef.cc(\modFreq, {|val| "Frecuencia de modulación AM: ".post; ~modFreq.value_(val.linlin(0,127,0.05,400).postln)}, 3, 0); //Valores de 0.05 a 400 hz

//Amplitud de modulación AM
~modAmp = Bus.control(s,1);
~modAmp.set(1);
MIDIdef.cc(\modAmp, {|val| "Amplitud de modulación AM: ".post; ~modAmp.value_(val.linlin(0,127,0.01,0.8).postln)}, 4, 0); //Valores de 0.01 a 0.3

//Amplitud
~amp = Bus.control(s,1);
~amp.set(1);
MIDIdef.cc(\amp, {|val| "Amplitud : ".post; ~amp.value_(val.linlin(0,127,0.0,10.0).postln)}, 7, 0); //Valores de 0.0 al 10.0

(
SynthDef(\addictive, {
	var root, mod, close,freqs, amps, harms, amp, specs, sig, modFreq, modAmp;
	close = In.kr(~close);
	root = In.kr(~root);
	freqs = Array.fill(33, {|i| root * (1 + (i*close))});
	amps = Array.rand(33,0.1,0.93)/33;
	harms  = Array.fill(33, {|i| In.kr(~harms.index + i)});
	amp = In.kr(~amp);
	modFreq = In.kr(~modFreq);
	modAmp = In.kr(~modAmp);
	mod = Array.fill(33, {SinOsc.kr(modFreq + rrand(0.03, 16).reciprocal).range(1 - modAmp, 1 + modAmp)});
	amps = amps * harms * mod * amp;
	specs = `[freqs , amps];
	sig = DynKlang.ar(specs);
	sig = Limiter.ar(sig, 0.93);
	Out.ar(0,sig!2);
}).add;
)

Synth(\addictive);

FreqScope.new;