package com.amazon.biscuit.service.test;

import android.app.IntentService;
import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.IBinder;
import android.os.RemoteException;
import android.util.Log;

import com.amazon.biscuit.service.IBiscuitService;

public final class BiscuitServiceIntentService extends IntentService {
    private static final String TAG = "BiscuitServiceTest";

    public BiscuitServiceIntentService() {
        super("BiscuitServiceIntentService");
    }

    @Override
    protected void onHandleIntent(Intent intent) {
        final Intent bind = new Intent("com.amazon.biscuit.service.IBiscuitService");
        bind.setPackage("com.amazon.biscuit.service");
        final Box box = new Box();
        ServiceConnection conn = new ServiceConnection() {
            @Override public void onServiceConnected(ComponentName name, IBinder service) {
                synchronized (box) { box.led = IBiscuitService.Stub.asInterface(service); box.notifyAll(); }
            }
            @Override public void onServiceDisconnected(ComponentName name) { }
        };
        if (!bindService(bind, conn, BIND_AUTO_CREATE)) { Log.e(TAG, "bind failed"); return; }
        try {
            synchronized (box) { if (box.led == null) box.wait(3000); }
            if (box.led == null) { Log.e(TAG, "bind timeout"); return; }
            Log.i(TAG, run(box.led, intent));
        } catch (Exception e) {
            Log.e(TAG, "command failed", e);
        } finally {
            unbindService(conn);
        }
    }

    private static String run(IBiscuitService led, Intent intent) throws RemoteException {
        String cmd = intent.getStringExtra("cmd");
        if (cmd == null) cmd = "status";
        if ("play".equals(cmd)) return "play=" + led.play(intent.getStringExtra("name"));
        if ("volume".equals(cmd)) return "volume=" + led.setVolume(intent.getIntExtra("current", 5), intent.getIntExtra("max", 10));
        if ("mute".equals(cmd)) return "mute=" + led.setMicMuted(intent.getBooleanExtra("muted", true));
        if ("frame".equals(cmd)) return "frame=" + led.setFrame(intent.getStringExtra("hex"));
        if ("clear".equals(cmd)) return "clear=" + led.clear();
        return "status=" + led.status();
    }

    private static final class Box { IBiscuitService led; }
}
