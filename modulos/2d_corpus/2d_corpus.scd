//VIDEO 5
//En este video se utilizará un tipo distinto de análisis (MFCC)


//Sample rate para mis audios
s.options.sampleRate = 48000;

//Sample rate para tutorial
s.options.sampleRate = 44100;

//Iniciar servidor
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
			loader.buffer.numChannels.do{
				|chan|
				FluidBufCompose.processBlocking(s,
					loader.buffer,
					startChan: chan,
					numChans: 1,
					destination: src,
					gain: loader.buffer.numChannels.reciprocal,
					destGain: 1);
				"Canal % reducido a mono correctamente".format(chan + 1).postln; "".postln
			}
		}
		{
			"Buffer previamente en mono".postln;
			"".postln;
			src = loader.buffer
		};

		FluidBufOnsetSlice.processBlocking(s,src,metric: 9,threshold: tresh, indices: indices);

		"Cortes establecidos correctamente".postln;
		"".postln;

		s.sync;

		"Número de cortes: %".format(indices.numFrames).postln;
		"".postln;
		"Segundos promedio de cada bloque: %".format(src.duration / indices.numFrames + 1).postln;
		"".postln;

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
			var umapped = FluidDataSet(s);

			fork {
				var mfccs = Buffer(s);
				var stats = Buffer(s);
				var flat = Buffer(s);

				fa.doAdjacentPairs{
					|inicio, final, index|
					var num = final - inicio;

					FluidBufMFCC.processBlocking(s, src, inicio, num, features: mfccs, numCoeffs: 13, startCoeff: 1);
					FluidBufStats.processBlocking(s,source: mfccs, stats: stats, select: [\mean]);
					FluidBufFlatten.processBlocking(s,source: stats, destination: flat);

					analyses.addPoint(index, flat);

					"Progreso: % porciento (% de %)".format(
						((index + 1) / fa.size * 100).round(0.01),
						index + 1,
						fa.size
					).postln;

					if( (index%100) == 99) {s.sync};

				};

				s.sync;
				analyses.print;

				FluidUMAP(s, numNeighbours:15,minDist:0.9).fitTransform(analyses, umapped, {"Umap generado".postln});

				normed = FluidDataSet(s);
				FluidNormalize(s).fitTransform(umapped, normed, {"Data Set normalizado correctamente"});

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


~sampleFlight.(FluidFilesPath(), 0.05);