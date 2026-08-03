# Dirección de voz / beam ASP — Biscuit

## Resumen

Stock no parece calcular la dirección en Alexa directamente. La cadena vista en blobs stock es:

```txt
libasp / audiosignalprocessor
  -> callback ASP con evento de beam/dirección
  -> stock audiohub
  -> LIPC event/property beamDir en com.doppler.audio
  -> stock ledd BeamDirection / BeamPattern
  -> animación del anillo
```

En CM12 actual:

- `audiosignalprocessor` existe como Binder service.
- `libasp.so` y `libaspclient.so` están presentes.
- `biscuit-ledd` es nuestro daemon simple por socket Unix; no implementa `BeamDirection`/`beamDir`.
- `BiscuitService` Java es el punto correcto para exponer una API pública nuestra; el wrapper shell solo debe invocarla.

## Evidencia stock

Fuentes locales inspeccionadas:

```txt
workspace/extracted/biscuit-stock-272.6.4.1/system.img
/tmp/biscuit-stock-led/audiohub
/tmp/biscuit-stock-led/ledd
/tmp/biscuit-stock-asp/libasp.so
/tmp/biscuit-stock-asp/libaspclient.so
```

Strings relevantes:

### `bin/audiohub`

```txt
audiosignalprocessor
libaspclient.so
beamDir
E AudioHub:setBeamDirFailed:reason=unableToSendEvent,event=%s,err=%s:
E AudioHub:initASPFailed:reason=failedToRegisterASPEventListener:
E AudioHub:onEventFailed:reason=invalidSize,size=%d:
com.doppler.audio
```

### `bin/ledd`

```txt
com.doppler.ledd
Pattern
BeamPattern
BeamPatternOn
BeamPatternOff
BeamDirection
com.doppler.audiod
com.doppler.audio
beamDir
E LipcInterface:setBeamPattern:reason=invalidArg,val=%s:Bad argument
E LipcInterface:beamDirEvent:reason=invalidArg:Could not get beam value
WakeWordLEDComplete
```

### `libasp.so`

```txt
com.amazon.asp.IAudioEventListener
com.amazon.asp.IAudioSignalProcessor
audiosignalprocessor
AFE config mics %d beams %d speakers %d
AFEDiagBeamChangeCount
Beam change count: %d
```

También aparecen comandos de arbitraje, probablemente no la dirección directa:

```txt
ASP_CMD_REQUEST_ARBITRATION_DATA
{"sequenceID":%d,"voiceEnergy":%d,"ambientEnergy":%d}
```

## Comprobación en CM12 actual

Lectura en dispositivo:

```txt
service list | grep audiosignalprocessor
87 audiosignalprocessor: [com.amazon.asp.IAudioSignalProcessor]
```

Esto sugiere que podemos registrar un listener igual que stock `audiohub`, sin portar `audiohub` completo.

## Cómo averiguar el valor real

Prueba mínima, sin cambios persistentes:

1. Compilar/subir `biscuit_asp_beam_probe` temporal a `/data/local/tmp`.
2. El probe registra un `com.amazon.asp.IAudioEventListener` contra `audiosignalprocessor` por Binder.
3. Abrir captura con `AudioRecord` source `VOICE_RECOGNITION` (`6`) para activar `PipelineAsr`.
4. Descartar audio; loguear solo eventos ASP: `what`, `size`, bytes crudos, y si `size == 4`, interpretarlo como `int32` candidato `beamDir`.
5. Hablar desde varias posiciones y mapear valor -> sector físico del anillo.

No usar reproducción de audio para esta prueba.

```sh
# desde la raíz de amazon_device_biscuit
scripts/stage-tree.sh

docker rm -f cm12-biscuit-build >/dev/null 2>&1 || true
docker run -d --name cm12-biscuit-build \
  -v "$PWD:$PWD" \
  -w "$PWD/workspace/cm12" \
  cm12-ubuntu14:latest \
  bash -lc 'source build/envsetup.sh >/dev/null && lunch cm_biscuit-userdebug && export OUT_DIR="$PWD/out-docker" && export PATH="$OUT_DIR/host/linux-x86/bin:$PATH" && mmm hardware/amazon/audio'

docker logs -f cm12-biscuit-build

adb push workspace/cm12/out-docker/target/product/biscuit/system/bin/biscuit_asp_beam_probe /data/local/tmp/
adb shell chmod 755 /data/local/tmp/biscuit_asp_beam_probe
adb shell /data/local/tmp/biscuit_asp_beam_probe 20
```

Salida esperada:

```txt
listening seconds=20 source=VOICE_RECOGNITION discard_audio=1
asp_event what=<n> size=<n> int32=<candidate> bytes=<hex>
done
```

## Búsqueda de ángulos precalculados (RE estático)

Hipótesis: Amazon convierte beam -> ángulo en algún blob userspace y podemos
copiar la tabla. Resultado: **no existe en userspace**.

Método: desensamblado local con capstone+pyelftools (wheels en
`~/.local/lib/python3.13/site-packages`, sin sudo), búsqueda de xrefs a
strings (pools, relocs R_ARM_RELATIVE, movw/movt) y escaneo de `.rodata`
en busca de tablas float/double en progresión aritmética (0,30,60... o radianes).

Hallazgos:

- `libasp.so`: 0 tablas de ángulos. El beam lo calcula el AFE en el DSP;
  libasp solo recibe el índice y lo reemite vía `ReportEvent(what=3, int32)`.
- El nº de beams llega por config AFE en runtime (JSON WHA desde la nube):
  `AFE config mics %d beams %d speakers %d`. No hardcodeado en el blob.
- `audiohub`: passthrough crudo, sin conversión (ver sección anterior).
- `ledd`: cluster de strings `BeamPattern/BeamPatternOn/BeamPatternOff/
  BeamDirection/beamDir` en `.rodata` (0x4c1cc..0x4c2b3) **sin ninguna
  referencia** desde código ni desde datos (probablemente código muerto o
  manejado por una lib que no tenemos extraída). No hay tabla beam->LED.

Conclusión: el valor `beamDir` es un índice de beam crudo del AFE de
principio a fin. La correspondencia con ángulos/posición física hay que
medirla empíricamente.

Pista sobre la resolución: los valores observados en la primera prueba real
fueron `3,5,7,9,11` (todos impares). Encaja con **12 beams de 30°**
(índice x 30 = grados: 90,150,210,270,330...), coherente con un aro de 12
LEDs. Pendiente de confirmar con el protocolo de mapeo.

## Protocolo de mapeo empírico beam -> sector físico (pendiente)

1. Elegir referencia física del aro (p.ej. botones / conector cable).
2. Fuente de voz en bucle (teléfono/altavoz) a distancia fija (~1 m).
3. Para cada posición (frente, 45°, derecha, 135°, detrás, 225°, izquierda,
   315°): 15-20 s de voz mientras corre `biscuit_asp_beam_probe 25`.
4. Anotar `int32` dominante por posición -> tabla `beam idx -> sector`.
5. Validar repitiendo 2 posiciones; si el mapa es lineal (idx x 30 + offset),
   interpolar el resto.

## Posible soporte futuro en `BiscuitService` Java

API pública nuestra debería vivir en el servicio Java, no en el wrapper shell:

- Binder/AIDL opcional: `int getBeamDirection()` o `String beamStatus()`.
- Broadcast sticky opcional:

```txt
com.amazon.biscuit.service.BEAM_DIRECTION_CHANGED
com.amazon.biscuit.service.EXTRA_BEAM_DIRECTION   int
```

Implementación mínima sugerida:

```txt
native ASP listener/helper
  -> notifica dirección actual a BiscuitService Java
  -> BiscuitService valida/ratea
  -> opcionalmente manda comando nuevo a biscuit-ledd
```

Motivo del helper nativo: `libaspclient.so` expone una interfaz Binder C++ (`com.amazon.asp.IAudioSignalProcessor`), no una API Java/AIDL ya disponible en el árbol.

Extensión LED mínima si queremos visualizarlo:

```txt
biscuit-ledd: comando BEAM <0..N-1>
BiscuitService Java: método/action para set/get beam
wrapper shell: solo cliente fino después
```

Mantenerlo lazy: primero probe + mapa de valores; solo después añadir API estable.
