# Nivel de micrófono y wake word (microWakeWord) — Biscuit

Estado: diagnóstico cerrado, fix parcial aplicado, pendiente de validar con AVA real.

Relacionado: `docs/audio-beam-direction.md` (ASP/beam/LED). No duplicar contenido.

## Síntoma

Stock FireOS detecta "Alexa" desde el otro extremo de la habitación (~5 m).
Con CM12 + AVA hay que estar a ~10 cm para que dispare el wake word.

## Causa raíz

**No es un problema de la cadena de audio.** Es un desajuste de nivel absoluto
entre lo que entrega el HAL y lo que espera microWakeWord.

- AVA usa **microWakeWord** con el modelo `okay_nabu`
  (visto en `ava5/echo-biscuit-support/.../BiscuitMuteControllerTest.kt`:
  `{"wakeWords":["okay_nabu"],"microWakeWords":["okay_nabu"]}`).
- microWakeWord está diseñado para ESP32-S3 con micrófono cercano y **no lleva AGC**.
  Clasifica directamente sobre el mel-spectrogram, que es sensible a la **amplitud
  absoluta**. Sus modelos se entrenan con voz a niveles normales (~-25 dBFS).
- La captura de Biscuit entrega **-69 dBFS**, unos 40 dB por debajo del rango de
  entrenamiento. Los features caen fuera de distribución y la red no dispara.
- El wake word engine de Amazon normaliza el nivel antes de clasificar, por eso a
  stock le da igual correr con la misma ganancia analógica.

La cuenta cuadra con la ley inversa del cuadrado:

```
10 cm -> 5 m  =  20*log10(500/10)  =  34 dB
```

Hacen falta ~34 dB más de nivel para alcance de habitación.

## Qué se descartó (con evidencia)

Todas estas hipótesis se investigaron y se descartaron. No volver a abrirlas sin
un dato nuevo.

### El "AudioRecord es 256x más bajo que raw" era un artefacto de escala

`biscuit_mic_test` reporta fondo de escala **24-bit** (±8388607).
`biscuit_audiorecord_test` reporta **16-bit** (±32767). Normalizados:

| Medida | rms | fondo escala | dBFS |
|---|---|---|---|
| raw tinyalsa | 3000 | 8388608 | -69.0 |
| AudioRecord | 11 | 32768 | -69.5 |

Es el mismo nivel. El HAL no pierde ni un dB. El factor 256 era exactamente
la diferencia 24-bit vs 16-bit.

### NVRAM / MTK audio params — irrelevante

- El HAL no toca NVRAM en la ruta de captura: cero llamadas a
  `GetAudioCustomParamFromNV`, `SetCaptureGain`, `SetMicGain` en logcat durante
  un `openInputStream`.
- Biscuit **no tiene** particiones `nvdata`, `nvram` ni `proinfo`. Solo `persist`.
  Amazon usa IDME, no NVRAM MTK. `nvram_daemon` no aportaría nada.
- Particiones reales: `boot boot_a boot_a_x boot_b boot_b_x cache dkb expdb kb lk
  lk_a lk_b misc persist recovery system system_a system_b tee1 tee2 userdata`.

### Calibración de micrófonos — presente y válida

`libasp.so` lee `/proc/idme/miccal.<n>` y `/proc/idme/board_id`.
En el device existen `miccal.0`..`miccal.6` (7 mics) con valores válidos
(18150, 17869, 15532, 16924, 17377, 17108, 13429). No aparece el error
`ERROR! micCals[%d]=0! PLEASE CHECK IDME MIC VALUE!`.

### Mixer / audio_init.sh — correctamente aplicado

El estado del mixer en vivo coincide exactamente con `audio_init.sh`.
`INPUT_GAIN_SEL=0` significa "0 dB", por eso `DIF1_L Input Gain = Off`; es correcto.

### ASP passthrough — no es el interruptor

`libasp.so` expone `persist.asp.asr.passthrough`, `persist.asp.voice.passthrough`,
`persist.asp.speaker.passthrough`. En el device ninguna está definida.
A/B alternando `true`/`false` cuatro veces: rms 10, 7, 8, 8 (ruido, sin diferencia)
y el log entrega siempre el mismo `PipelineAsr in 6 9 16000 out 1 1 16000`.

### El nivel RMS no mide si el beamforming funciona

Un beamformer normalizado (delay-and-sum / MVDR) mantiene **ganancia unidad** en la
dirección de mira; mejora el **SNR**, no el nivel absoluto. Que la salida del ASP
esté a -0.8 dB de un micrófono individual es normal. No hay "déficit de 8 dB".

### `ADC_A Digital Volume Control = 88` — no es un bug funcional

```c
static const DECLARE_TLV_DB_SCALE(adc_3101_vol_tlv, -1200, -50, 0);
SOC_DOUBLE_R_SX_TLV("ADC_A Digital Volume Control",
                    ADC_LADC_VOL(0), ADC_RADC_VOL(0), 0, 0x28, 0x68, ...);
```

`snd_soc_info_volsw_sx` declara `max = 0x68 - 0x28 = 64`, y `get` hace
`(reg - xmin) & 0x7F`. Despejando el 88 observado: `(reg - 40) & 127 = 88` → `reg = 0x00`,
que es 0 dB, el reset default correcto. No hay atenuación oculta.

Lo que sí está roto es **escribir**: ALSA 0–64 mapea a registros `0x28`–`0x68`, y
`0x29`–`0x67` es zona reservada del TLV320AIC3101. Arreglarlo exige tocar el driver
y recompilar kernel. **No hacer**: la ganancia digital del codec no mejora SNR y
lo que se necesita (nivel para microWakeWord) se consigue más barato en el wrapper.

### Symlink `mtk-msdc.0` roto — impacto ~nulo

```
init.mt8163.rc:59   symlink /dev/block/platform/soc/11230000.mmc   <- destino NO existe, gana
init.device.rc:4    symlink /dev/block/platform/soc                <- correcto, igual que stock
```

Ambos son `on fs`; el primero en parsearse crea el symlink, el segundo falla con
`EEXIST`. Solo lo usan `bin/idme` y `lib/libnvram.so`, ninguno crítico
(`/proc/idme` lo expone el kernel y funciona). Fix trivial (`soc/11230000.mmc` → `soc`)
si algún día hace falta `bin/idme`.

## Medidas de referencia

Barrido del PGA en los 4 ADCs, medianas sobre capturas de 5 s intercaladas
(40/80/40/80/40/80) para cancelar la deriva del ruido ambiente:

| PGA | dB | raw rms | raw dBFS | AudioRecord rms | AR dBFS | AR peak |
|---|---|---|---|---|---|---|
| 40 | 20 dB | 4781 | -64.9 | 17 | -65.7 | 682 (2% FS) |
| 80 | 40 dB | 49902 | -44.5 | 91 | -51.1 | 12559 (38% FS) |

```
delta raw          +20.4 dB  (esperado +20.0)  -> el PGA escala lineal
delta AudioRecord  +14.6 dB                    -> el AGC del ASP absorbe ~5 dB
clipping           ninguno (raw peak 16% FS)
```

Medido en silencio, con ruido ambiente. **No validado con altavoz sonando.**

## Quién fija la ganancia analógica

| Capa | Valor | De quién |
|---|---|---|
| Chip TLV320ADC3101 | 0–119 (0–59.5 dB) | Texas Instruments |
| Driver `tlv320aic3101.c` (`xmax = 0x50`) | 0–80 (0–40 dB) | Amazon (recorta el chip) |
| `audio_init.sh` | 40 (20 dB) | Amazon |
| Tabla init del driver (`MIC_PGA_GAIN_IDC`) | 20 dB | Amazon |

Las 5 únicas ocurrencias de `MICPGA` en los 800 MB del `system.img` stock son las
5 líneas de `audio_init.sh`. Ningún blob lo toca en runtime:

```
lib/hw/audio.primary_amazon.mt8163.so   0
lib/libasp.so                           0
lib/libaudiosetting.so                  0
lib/libaudiocustparam.so                0
lib/libaudiocomponentengine.so          0
```

Stock corre con 20 dB permanentes, siempre. Es una decisión deliberada de Amazon,
tomada dos veces, y probablemente protege el headroom del AEC (el altavoz está a
centímetros de los mics).

## Estado actual

Commit `79e7b75` — `scripts/extract-biscuit-stock-blobs.sh`:

```
A_PGA_L="40" -> "70"     (20 dB -> 35 dB)
A_PGA_R="40" -> "70"
A_PGA_R_LINEIN="46"      <- intacto
```

Aplicado como `sed` post-extracción porque `etc/audio_init.sh` es un blob
regenerado desde `system.img`, con un `grep -qx` que aborta la extracción si el
formato stock cambiara. Marcado `ponytail:` para plegarlo a `patches/` cuando se
unifique el parcheo de vendor.

Aporta ~+11 dB en AudioRecord: alcance estimado 10 cm → ~35 cm.
Mejora, pero es la palanca **peor** de las dos disponibles (ver más abajo).

## Objetivo revisado: 2 m, no 5 m

```
10 cm -> 5 m :  20*log10(50) = 34 dB
10 cm -> 2 m :  20*log10(20) = 26 dB
```

8 dB menos, y son justo la diferencia entre "forzado" y "cómodo". Más allá de
2-3 m el limitante deja de ser el nivel y pasa a ser la reverberación de la sala,
que la ganancia no arregla.

### Presupuesto de ganancia

Del barrido medido, +20 dB de PGA en crudo dieron **+14.6 dB en AudioRecord**
(el AGC del ASP absorbe el resto). Factor de transferencia ~0.73:

| Configuración | dB en AudioRecord | Alcance estimado |
|---|---|---|
| PGA 40 (stock) | 0 | 10 cm |
| PGA 70 (commit actual) | +11 | ~35 cm |
| PGA 80 (máximo analógico) | +14.6 | ~55 cm |
| PGA 80 + 11 dB digital | +26 | **2 m** |
| PGA 80 + 19 dB digital | +34 | 5 m |

El PGA analógico por sí solo **no llega ni a 1 m**. Hace falta ganancia digital sí o sí.

### Por qué la ganancia digital es mejor palanca que el PGA aquí

1. **No mejora el SNR ninguna de las dos.** El ADC tiene ~92 dB de SNR (suelo por
   debajo de -90 dBFS) y la señal está a -65 dBFS: 27 dB por encima del suelo
   electrónico. Domina el ruido acústico de la sala, no el ADC. Subir el PGA
   analógico es, en este caso, equivalente a multiplicar en digital.
2. **El PGA sí come headroom del AEC** (el altavoz está a centímetros de los mics).
   La ganancia en `audio_wrapper.c` se aplica **después** de todo el procesado del
   HAL, así que es inocua para el AEC.
3. **Tunable en caliente** por property, sin recompilar ni reflashear.
4. **Clampable** con precisión.

Conclusión: el PGA a 70 no está mal, pero la palanca principal debe ser el wrapper.

### Por qué ganancia fija no basta, y hace falta AGC

En la medida a PGA 80, el pico de AudioRecord llegó al **38% FS con solo ruido
ambiente** (rms -51 dBFS, pico -8.3 dBFS → factor de cresta de 43 dB, algún
transitorio impulsivo). Multiplicar eso por 3.6 satura.

Una ganancia fija calibrada para disparar a 2 m **saturará** al hablar cerca o con
un ruido impulsivo. Lo correcto es **normalización lenta hacia un RMS objetivo**
(~-25 dBFS) con limitador: justo lo que hace el motor de Amazon y lo que
microWakeWord no trae. ~40 líneas en vez de ~20, pero resuelve cerca y lejos a la
vez en lugar de elegir uno.

## Plan pendiente

1. **Validar con AVA real** y voz: ¿a qué distancia dispara ahora el wake word con
   PGA 70? Es el dato que falta para calibrar todo lo demás.
2. **AGC lento en `sources/hardware_amazon/audio/audio_wrapper.c`** — palanca principal.
   Es nuestro código y ya envuelve el HAL: interceptar `in->read()` y normalizar antes
   de devolver.
   - RMS objetivo ~-25 dBFS (lo que espera microWakeWord)
   - ganancia máxima limitada (~+20 dB) para no amplificar ruido de fondo hasta
     provocar falsos positivos
   - ataque y release lentos (es normalización, no compresión de dinámica)
   - limitador suave en el pico
   - properties para tunear en caliente: objetivo, ganancia máxima, on/off
   Con objetivo de 2 m el AGC no debería pasar de ~+15 dB, rango muy manejable.
3. **Dejar el PGA en 70.** No subir a 80: no aporta SNR y sí quita headroom al AEC.
   Si hiciera falta probarlo, es volátil y no requiere recompilar:
   ```sh
   for a in A B C D; do adb shell tinymix "ADC_$a MICPGA Volume Ctrl" 80 80; done
   ```
4. **Validar el AEC con música a volumen alto** antes de dar el PGA por definitivo:
   - que el raw no llegue a clipping (`peak` cerca de 8388607 en `biscuit_mic_test`)
   - que el wake word siga disparando con el altavoz sonando
   Si satura, bajar el PGA a 50-60 y compensar en el AGC del wrapper.

## Cómo reproducir las medidas

```sh
# nivel raw (24-bit full scale) y post-HAL (16-bit full scale)
adb shell biscuit_mic_test 5
adb shell biscuit_audiorecord_test 5 6      # 6 = VOICE_RECOGNITION

# ganancia analógica actual y rango
adb shell tinymix "ADC_A MICPGA Volume Ctrl"

# calibración de mics de fábrica
adb shell 'for i in 0 1 2 3 4 5 6; do cat /proc/idme/miccal.$i; echo; done'

# traza del pipeline ASP durante una captura
adb shell logcat -c
adb shell biscuit_audiorecord_test 2 6
adb shell logcat -d | grep -iE 'AudioALSA|ASP|Pipeline'
```

Para comparar niveles entre las dos herramientas hay que normalizar por el fondo
de escala: `dBFS = 20*log10(rms/8388608)` para `biscuit_mic_test` y
`20*log10(rms/32768)` para `biscuit_audiorecord_test`. No compararlos en crudo.

El ruido ambiente no es estacionario: medir con capturas de 5 s intercaladas entre
los puntos a comparar y quedarse con la mediana, no con una sola muestra.
