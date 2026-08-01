import android.app.ActivityThread;
import android.content.Context;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Looper;

public class FlacMediaPlayerProbe {
  public static void main(String[] args) throws Exception {
    String path = args.length > 0 ? args[0] : "/data/local/tmp/flac-probe.flac";
    int repeats = args.length > 1 ? Integer.parseInt(args[1]) : 1;

    Looper.prepare();
    Context ctx = ActivityThread.systemMain().getSystemContext();
    AudioManager audio = (AudioManager) ctx.getSystemService(Context.AUDIO_SERVICE);
    int max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
    audio.setStreamVolume(AudioManager.STREAM_MUSIC, max, 0);
    System.out.println("musicVolume=" + audio.getStreamVolume(AudioManager.STREAM_MUSIC) + "/" + max);

    for (int i = 0; i < repeats; i++) {
      MediaPlayer mp = new MediaPlayer();
      try {
        mp.setAudioStreamType(AudioManager.STREAM_MUSIC);
        mp.setVolume(1.0f, 1.0f);
        mp.setDataSource(path);
        mp.prepare();
        System.out.println("prepared repeat=" + (i + 1) + "/" + repeats + " durationMs=" + mp.getDuration());
        mp.start();
        System.out.println("started isPlaying=" + mp.isPlaying());
        Thread.sleep(Math.min(Math.max(mp.getDuration() + 300, 1000), 5000));
      } finally {
        try { mp.release(); } catch (Throwable ignored) {}
      }
    }
    System.out.println("OK: FLAC MediaPlayer prepare/start succeeded");
  }
}
