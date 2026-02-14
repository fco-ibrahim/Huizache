s.options.sampleRate = 48000;
s.reboot;

(
~sampleFlight = {
	|folder, tresh = 0.05|
	fork {
		var loader = FluidLoadFolder(folder).play(s, {"Folder cargado al servidor correctamente".postln;"".postln});
		var indices = Buffer(s);
		var src, play_slice, analyses, normed, tree;

		s.sync;

		if(loader.buffer.numChannels > 1){
			src = Buffer(s);
			FluidBufCompose.processBlocking(s, loader.buffer, startChan: 0,numChans: 1,destination: src, gain: -6.dbamp);
			FluidBufCompose.processBlocking(s, loader.buffer, startChan: 1,numChans: 1,destination: src, gain: -6.dbamp,destGain: 1)}
		{src = loader.buffer};

		FluidBufOnsetSlice.processBlocking(s,src,metric: 9,threshold: tresh,indices: indices, action: {
			"Cortes establecidos correctamente".postln;
			"Segundos promedio de cada bloque: %".format(src.duration/indices.numFrames).postln;
		});


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

		analyses = FluidDataSet(s);
		"Iniciando creación de dataset".postln;
		"".postln;
		indices.loadToFloatArray(action: {
			|fa|
			fork {
				var spec = Buffer(s);
				var stats = Buffer(s);
				var stats2 = Buffer(s);
				var loudness = Buffer(s);
				var point = Buffer(s);

				fa.doAdjacentPairs{
					|inicio, final, index|
					var num = final - inicio;
					var porcentaje, barras;

					FluidBufSpectralShape.processBlocking(s, src, inicio, num, features: spec, select:[\centroid]);
					FluidBufStats.processBlocking(s,spec,stats: stats, select: [\mean]);

					FluidBufLoudness.processBlocking(s,src, inicio, num,features: loudness, select: [\loudness]);
					FluidBufStats.processBlocking(s,loudness,stats: stats2, select: [\mean]);

					FluidBufCompose.processBlocking(s, stats, destination: point, destStartFrame: 0);
					FluidBufCompose.processBlocking(s, stats2, destination: point, destStartFrame: 1);

					analyses.addPoint(index, point);
					"Progreso: % porciento (% de %)".format(
						((index + 1) / fa.size * 100).round(0.01),
						index + 1,
						fa.size
					).postln;

					if( (index%100) == 99) {s.sync};

				};

				s.sync;
				analyses.print;

				normed = FluidDataSet(s);
				FluidNormalize(s).fitTransform(analyses, normed);

				tree = FluidKDTree(s);
				tree.fit(normed);

				normed.dump({
					arg dict;
					var point = Buffer.alloc(s,2);
					var previous = nil;
					dict.postln;
					{FluidPlotter(dict: dict,mouseMoveAction: {
						|view, x, y|
						[x, y].postln;
						point.setn(0,[x,y]);
						tree.kNearest(point, 1, {
							|nearest|
							if (nearest != previous) {
								nearest.postln;
								view.highlight_(nearest);
								play_slice.(nearest.asInteger);
								previous = nearest
							}
						});
					})}.defer;
				});
			}
		});
	}
};
)


~sampleFlight.("/Users/ibrahim/Downloads/grabacionesDeCampo/", 0.5);