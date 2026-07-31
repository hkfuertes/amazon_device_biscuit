import android.media.MediaCodec;
import android.media.MediaFormat;

public class FlacMediaCodecProbe {
  public static void main(String[] args) throws Exception {
    int[] sampleRates = {16000, 44100, 48000};
    int[] channelCounts = {1, 2};
    Throwable last = null;

    for (int sampleRate : sampleRates) {
      for (int channelCount : channelCounts) {
        MediaCodec codec = null;
        MediaFormat format = MediaFormat.createAudioFormat("audio/flac", sampleRate, channelCount);
        format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 32768);
        System.out.println("format=" + format);
        try {
          codec = MediaCodec.createDecoderByType("audio/flac");
          System.out.println("codec=" + codec.getName());

          // Mirrors Ava/ExoPlayer's failing path: MediaCodec.configure().
          codec.configure(format, null, null, 0);
          codec.start();
          System.out.println("OK: FLAC MediaCodec configure/start succeeded");
          return;
        } catch (Throwable t) {
          last = t;
          System.out.println("FAIL variant sampleRate=" + sampleRate + " channels=" + channelCount);
          t.printStackTrace(System.out);
        } finally {
          if (codec != null) {
            try { codec.stop(); } catch (Throwable ignored) {}
            try { codec.release(); } catch (Throwable ignored) {}
          }
        }
      }
    }

    System.out.println("FAIL: all FLAC MediaCodec configure/start variants failed");
    if (last != null) last.printStackTrace(System.out);
    System.exit(1);
  }
}
