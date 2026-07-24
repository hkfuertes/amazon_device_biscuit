package com.amazon.biscuit.service;

import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.net.LocalSocket;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiManager;
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
    private static final String MIC_MUTE_CHANGED = "com.amazon.biscuit.service.MICROPHONE_MUTE_CHANGED";
    public static final String BLUETOOTH_PAIRING_MODE = "com.amazon.biscuit.service.BLUETOOTH_PAIRING_MODE";
    public static final String BLUETOOTH_OFF = "com.amazon.biscuit.service.BLUETOOTH_OFF";
    public static final String WIFI_ON = "com.amazon.biscuit.service.WIFI_ON";
    public static final String WIFI_OFF = "com.amazon.biscuit.service.WIFI_OFF";
    public static final String WIFI_CONNECT = "com.amazon.biscuit.service.WIFI_CONNECT";
    public static final String VOLUME_UP = "com.amazon.biscuit.service.VOLUME_UP";
    public static final String VOLUME_DOWN = "com.amazon.biscuit.service.VOLUME_DOWN";
    public static final String VOLUME_SET = "com.amazon.biscuit.service.VOLUME_SET";
    public static final String MIC_MUTE_ON = "com.amazon.biscuit.service.MICROPHONE_MUTE_ON";
    public static final String MIC_MUTE_OFF = "com.amazon.biscuit.service.MICROPHONE_MUTE_OFF";
    public static final String MIC_MUTE_TOGGLE = "com.amazon.biscuit.service.MICROPHONE_MUTE_TOGGLE";
    private static final String EXTRA_SSID = "ssid";
    private static final String EXTRA_PSK = "psk";
    private static final String EXTRA_VOLUME = "volume";
    private static final String EXTRA_STREAM_TYPE = "android.media.EXTRA_VOLUME_STREAM_TYPE";
    private static final String EXTRA_STREAM_VALUE = "android.media.EXTRA_VOLUME_STREAM_VALUE";
    private static final String EXTRA_MICROPHONE_MUTED = "com.amazon.biscuit.service.EXTRA_MICROPHONE_MUTED";
    private static final int PAIRING_MODE_SECONDS = 300;
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
            setRealMicMuted(muted);
            return true;
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
            int current = intent.getIntExtra(EXTRA_STREAM_VALUE, audio.getStreamVolume(stream));
            try {
                sendOk("VOLUME " + current + " " + audio.getStreamMaxVolume(stream));
            } catch (RemoteException ignored) { }
        } else if (intent != null && MIC_MUTE_CHANGED.equals(intent.getAction())) {
            updateMicLed(intent.getBooleanExtra(EXTRA_MICROPHONE_MUTED,
                    ((AudioManager) getSystemService(AUDIO_SERVICE)).isMicrophoneMute()));
        } else if (intent != null && MIC_MUTE_TOGGLE.equals(intent.getAction())) {
            AudioManager audio = (AudioManager) getSystemService(AUDIO_SERVICE);
            setRealMicMuted(!audio.isMicrophoneMute());
        } else if (intent != null && BLUETOOTH_PAIRING_MODE.equals(intent.getAction())) {
            startBluetoothPairingMode();
        } else if (intent != null && BLUETOOTH_OFF.equals(intent.getAction())) {
            stopBluetooth();
        } else if (intent != null && WIFI_ON.equals(intent.getAction())) {
            setWifiEnabled(true);
        } else if (intent != null && WIFI_OFF.equals(intent.getAction())) {
            setWifiEnabled(false);
        } else if (intent != null && WIFI_CONNECT.equals(intent.getAction())) {
            connectWifi(intent.getStringExtra(EXTRA_SSID), intent.getStringExtra(EXTRA_PSK));
        } else if (intent != null && VOLUME_UP.equals(intent.getAction())) {
            adjustVolume(AudioManager.ADJUST_RAISE);
        } else if (intent != null && VOLUME_DOWN.equals(intent.getAction())) {
            adjustVolume(AudioManager.ADJUST_LOWER);
        } else if (intent != null && VOLUME_SET.equals(intent.getAction())) {
            setVolume(intent.getIntExtra(EXTRA_VOLUME, -1));
        } else if (intent != null && MIC_MUTE_ON.equals(intent.getAction())) {
            setRealMicMuted(true);
        } else if (intent != null && MIC_MUTE_OFF.equals(intent.getAction())) {
            setRealMicMuted(false);
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

    private void setRealMicMuted(boolean muted) {
        ((AudioManager) getSystemService(AUDIO_SERVICE)).setMicrophoneMute(muted);
    }

    private void adjustVolume(int direction) {
        AudioManager audio = (AudioManager) getSystemService(AUDIO_SERVICE);
        audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, 0);
    }

    private void setVolume(int volume) {
        AudioManager audio = (AudioManager) getSystemService(AUDIO_SERVICE);
        int max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
        if (volume < 0) volume = 0;
        if (volume > max) volume = max;
        audio.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0);
    }

    private void updateMicLed(boolean muted) {
        try {
            sendOk("MUTE " + (muted ? "1" : "0"));
        } catch (RemoteException ignored) { }
    }

    private void startBluetoothPairingMode() {
        final BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        if (adapter == null) return;
        if (!adapter.isEnabled()) adapter.enable();
        new Thread(new Runnable() {
            public void run() {
                for (int i = 0; i < 20 && !adapter.isEnabled(); i++) {
                    try { Thread.sleep(500); } catch (InterruptedException ignored) { return; }
                }
                if (adapter.isEnabled()) {
                    adapter.setScanMode(BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE,
                            PAIRING_MODE_SECONDS);
                }
            }
        }, "BiscuitBtPairingMode").start();
    }

    private void stopBluetooth() {
        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        if (adapter != null && adapter.isEnabled()) adapter.disable();
    }

    private void setWifiEnabled(boolean enabled) {
        WifiManager wifi = (WifiManager) getSystemService(WIFI_SERVICE);
        if (wifi == null) return;
        wifi.setWifiEnabled(enabled);
        if (enabled) wifi.reconnect();
    }

    private void connectWifi(String ssid, String psk) {
        if (ssid == null || ssid.length() == 0) return;
        WifiManager wifi = (WifiManager) getSystemService(WIFI_SERVICE);
        if (wifi == null) return;
        WifiConfiguration config = new WifiConfiguration();
        config.SSID = quote(ssid);
        if (psk == null || psk.length() == 0) {
            config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE);
        } else {
            config.preSharedKey = isHexPsk(psk) ? psk : quote(psk);
        }
        wifi.setWifiEnabled(true);
        int id = wifi.addNetwork(config);
        if (id >= 0) {
            wifi.enableNetwork(id, true);
            wifi.saveConfiguration();
            wifi.reconnect();
        }
    }

    private static String quote(String s) {
        return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }

    private static boolean isHexPsk(String s) {
        if (s.length() != 64) return false;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return false;
        }
        return true;
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
