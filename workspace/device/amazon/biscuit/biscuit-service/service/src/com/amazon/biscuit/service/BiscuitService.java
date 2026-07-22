package com.amazon.biscuit.service;

import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import android.os.IBinder;
import android.os.RemoteException;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;

public final class BiscuitService extends Service {
    public static final class BootReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            Intent service = new Intent(context, BiscuitService.class);
            service.setAction(intent.getAction());
            service.putExtras(intent);
            context.startService(service);
        }
    }

    private static final String SOCKET = "biscuit-ledd";
    private static final String VOLUME_CHANGED = "android.media.VOLUME_CHANGED_ACTION";
    private static final String EXTRA_STREAM_TYPE = "android.media.EXTRA_VOLUME_STREAM_TYPE";
    private final Object mLock = new Object();

    private final IBiscuitService.Stub mBinder = new IBiscuitService.Stub() {
        public boolean play(String name) throws RemoteException {
            checkName(name);
            return sendOk("PLAY " + name);
        }

        public boolean setFrame(String rgbHex72) throws RemoteException {
            checkFrame(rgbHex72);
            return sendOk("FRAME " + rgbHex72);
        }

        public boolean setVolume(int current, int max) throws RemoteException {
            if (current < 0 || max <= 0 || current > max) throw new RemoteException("bad volume");
            return sendOk("VOLUME " + current + " " + max);
        }

        public boolean setMicMuted(boolean muted) throws RemoteException {
            return sendOk("MUTE " + (muted ? "1" : "0"));
        }

        public boolean clear() throws RemoteException {
            return sendOk("OFF");
        }

        public String status() throws RemoteException {
            return send("STATUS");
        }
    };

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && VOLUME_CHANGED.equals(intent.getAction())) {
            AudioManager audio = (AudioManager) getSystemService(AUDIO_SERVICE);
            int stream = intent.getIntExtra(EXTRA_STREAM_TYPE, AudioManager.STREAM_MUSIC);
            try {
                sendOk("VOLUME " + audio.getStreamVolume(stream) + " " + audio.getStreamMaxVolume(stream));
            } catch (RemoteException ignored) { }
        }
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }

    private static void checkName(String name) throws RemoteException {
        if (name == null || name.length() < 1 || name.length() > 64) throw new RemoteException("bad name");
        for (int i = 0; i < name.length(); i++) {
            char c = name.charAt(i);
            boolean ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                    || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.';
            if (!ok) throw new RemoteException("bad name");
        }
        if (name.indexOf("..") >= 0) throw new RemoteException("bad name");
    }

    private static void checkFrame(String frame) throws RemoteException {
        if (frame == null || frame.length() != 72) throw new RemoteException("bad frame");
        for (int i = 0; i < frame.length(); i++) {
            char c = frame.charAt(i);
            boolean ok = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
            if (!ok) throw new RemoteException("bad frame");
        }
    }

    private boolean sendOk(String command) throws RemoteException {
        return "OK".equals(send(command));
    }

    private String send(String command) throws RemoteException {
        synchronized (mLock) {
            LocalSocket socket = new LocalSocket();
            try {
                socket.connect(new LocalSocketAddress(SOCKET, LocalSocketAddress.Namespace.RESERVED));
                OutputStream out = socket.getOutputStream();
                out.write((command + "\n").getBytes("US-ASCII"));
                out.flush();
                BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream(), "US-ASCII"));
                String reply = in.readLine();
                if (reply == null) throw new RemoteException("no daemon reply");
                return reply;
            } catch (IOException e) {
                throw new RemoteException(e.toString());
            } finally {
                try { socket.close(); } catch (IOException ignored) { }
            }
        }
    }
}
