(
~generador = {
	|folder, tresh = 0.05, neigh = 15, minDis = 0.9|
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

		src.write(thisProcess.nowExecutingPath.dirname ++ "/audios_mono.aiff");

		FluidBufOnsetSlice.processBlocking(s,src,metric: 9,threshold: tresh, indices: indices);
		indices.write(thisProcess.nowExecutingPath.dirname ++ "/indices.wav", "wav", "float");

		s.sync;

		"Cortes establecidos correctamente".postln;
		"".postln;
		"Número de cortes: %".format(indices.numFrames).postln;
		"".postln;
		"Segundos promedio de cada bloque: %".format(src.duration / indices.numFrames + 1).postln;
		"".postln;

		analyses = FluidDataSet(s);

		"Iniciando creación de dataset".postln;
		"".postln;

		indices.loadToFloatArray(action: {
			|fa|
			var umapped = FluidDataSet(s);

			File.use(thisProcess.nowExecutingPath.dirname ++ "/indices.json", "w", { |f|
                f.write(fa.asCompileString)
            });

            "Índices guardados".postln;

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

				FluidUMAP(s, numNeighbours: neigh, minDist: minDis).fitTransform(analyses, umapped, {"Umap generado".postln});

				normed = FluidDataSet(s);
				FluidNormalize(s).fitTransform(umapped, normed, {"Data Set normalizado correctamente".postln});

				s.sync;

				normed.write(thisProcess.nowExecutingPath.dirname ++ "/dataBase.json", {"Data Set creado correctamente".postln});

			}
		});
	}
};
)







~generador.("/Users/ibrahim/Documents/acervo_sonoro/grabacionesDeCampoZoom/2025 _2/prueba/", 0.5, 15, 0.9);

