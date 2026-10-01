//Dispositivo de salida
ServerOptions.outDevices;
Server.default.options.outDevice_("BlackHole 2ch");

//Entradas y salidas
Server.default.options.numInputBusChannels_(8);
Server.default.options.numOutputBusChannels_(8);

//Iniciar servidor
s.boot;

//Reiniciar servidor
s.reboot;

//Opciones de servidor
s.options.dump;

//Abrir configurción de audio MacOS
"open -a 'Audio MIDI Setup'".unixCmd;

//Tamaño de la memoria
s.options.memSize_(100000);

//GUI de servidor
s.makeGUI;