HID.findAvailable;
HID.findAvailable.keysValuesDo { |key, val| val.postln };


HIDInfo(VKB-Sim (C) Alex Oz 2023,  VKBsim Gladiator EVO R  , IDs:8989, 512, USB_231d_0200_1120000, , 8601, -1);

~vkb = HID.open(8989, 512); 
~vkb.elements.do { |el| el.postln };

(
~vkb.elements.do { |el|
	"usage: %, usagePage: %, id: %".format(el.usage, el.usagePage, el.id).postln
};

s.options.sampleRate_(48000);
s.reboot;

)
(
~sampleFlight = {
	fork {
		var src, indices, play_slice, tree, dataBase;
		var point, previous, vkbX, vkbY, gate, vkb;
		var gatePrev = false;

		src = Buffer.read(s, thisProcess.nowExecutingPath.dirname ++ "/analisis/audios_mono.aiff", action: {"Audio cargado".postln});
		indices = Buffer.read(s, thisProcess.nowExecutingPath.dirname ++ "/analisis/indices.wav", action: {"Índices cargados".postln});

		s.sync;

		play_slice = {
			arg index;
			{
				var startPos = Index.kr(indices,index);
				var stopPos = Index.kr(indices, index + 1);
				var phsr = Phasor.ar(rate: BufRateScale.ir(src),start: startPos,end: stopPos);
				var player = BufRd.ar(1,src,phsr);
				var durSecs = (stopPos - startPos) / BufSampleRate.ir(src);
				var env;

				durSecs = min(durSecs, 1);
				env = EnvGen.kr(Env([0,1,1,0],[0.3,durSecs-0.5,0.2]), doneAction: 2);
				player = player!2 * env;

			}.play;
		};

		dataBase = FluidDataSet(s);
		dataBase.read(thisProcess.nowExecutingPath.dirname ++ "/analisis/dataBase.json", {"Base de datos cargada correctamente".postln});

		tree = FluidKDTree(s);
		tree.fit(dataBase);

		point   = Buffer.alloc(s, 2);
		vkbX    = 0.5;
		vkbY    = 0.5;
		gate  = false;
		previous = nil;

		~queryPoint = { |view, x, y|
			point.setn(0, [x, y]);
			tree.kNearest(point, 1, { |nearest|
				if(nearest != previous) {
					previous = nearest;
					{ view.highlight_(nearest)}.defer;
					play_slice.(nearest.asInteger);
				}
			});
		};

		HID.findAvailable;
		vkb = HID.open(8989, 512); // ajustar el nombre exacto

		if(vkb.isNil) {
			"ERROR: No se encontró el joystick.".postln;
		} {
			"Joystick conectado".postln;

			HIDFunc.element({ |val|
				vkbX = val;
				vkbX.postln;
			}, elID: 359);

			// Eje Y
			HIDFunc.element({ |val|
				vkbY = 1.0 - val;
				vkbY.postln;

			}, elID: 360);

			HIDFunc.element({ |val|
				var pressed = val > 0.5;
				if(pressed && gatePrev.not) {  
					gate = gate.not;          
				};
				gatePrev = pressed;
				gate.postln;
			}, elID: 231);
		};

		dataBase.dump({ |dict|
			var view;
			{
				view = FluidPlotter(dict: dict,

					mouseMoveAction: { |v, x, y|
						if(gate.not) {  
							~queryPoint.(v, x, y)
						}
					}
				);

				~joyRoutine = Routine({
					loop {
						if(gate) {
							~queryPoint.(view, vkbX, vkbY);
						};
						0.05.wait;
					}
				}).play(AppClock);

			}.defer;
		});

	}
};
)

~sampleFlight.();
HID.closeAll;