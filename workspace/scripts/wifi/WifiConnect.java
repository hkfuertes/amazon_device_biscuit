import android.app.ActivityThread;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.DhcpInfo;
import android.net.NetworkInfo;
import android.net.wifi.SupplicantState;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Looper;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.List;

public class WifiConnect {
  private static String quote(String s) {
    return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
  }

  private static String ip(int v) {
    return (v & 0xff) + "." + ((v >> 8) & 0xff) + "." + ((v >> 16) & 0xff) + "." + ((v >> 24) & 0xff);
  }

  public static void main(String[] args) throws Exception {
    Looper.prepare();

    BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
    String ssid = in.readLine();
    String psk = in.readLine();
    if (ssid == null || ssid.length() == 0 || psk == null || psk.length() == 0) {
      System.err.println("ssid and psk required on stdin");
      return;
    }

    Context ctx = ActivityThread.systemMain().getSystemContext();
    WifiManager wifi = (WifiManager) ctx.getSystemService(Context.WIFI_SERVICE);
    ConnectivityManager conn = (ConnectivityManager) ctx.getSystemService(Context.CONNECTIVITY_SERVICE);

    if (!wifi.isWifiEnabled()) {
      System.out.println("setWifiEnabled=" + wifi.setWifiEnabled(true));
      Thread.sleep(3000);
    }

    String quotedSsid = quote(ssid);
    WifiConfiguration cfg = new WifiConfiguration();
    cfg.SSID = quotedSsid;
    cfg.preSharedKey = quote(psk);
    cfg.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK);

    int networkId = -1;
    List<WifiConfiguration> configured = wifi.getConfiguredNetworks();
    if (configured != null) {
      for (WifiConfiguration existing : configured) {
        if (quotedSsid.equals(existing.SSID)) {
          cfg.networkId = existing.networkId;
          networkId = wifi.updateNetwork(cfg);
          break;
        }
      }
    }
    if (networkId < 0) networkId = wifi.addNetwork(cfg);
    System.out.println("networkId=" + networkId);
    if (networkId < 0) throw new IllegalStateException("add/updateNetwork failed");

    System.out.println("saveConfiguration=" + wifi.saveConfiguration());
    System.out.println("disconnect=" + wifi.disconnect());
    System.out.println("enableNetwork=" + wifi.enableNetwork(networkId, true));
    System.out.println("reconnect=" + wifi.reconnect());

    for (int i = 0; i < 45; i++) {
      WifiInfo wi = wifi.getConnectionInfo();
      DhcpInfo dhcp = wifi.getDhcpInfo();
      NetworkInfo ni = conn.getNetworkInfo(ConnectivityManager.TYPE_WIFI);
      String state = wi == null ? "" : String.valueOf(wi.getSupplicantState());
      int ip = dhcp == null ? 0 : dhcp.ipAddress;
      System.out.println("t=" + (i + 1)
          + " supplicant=" + state
          + " wifi=" + (ni == null ? "" : ni.getState())
          + " ip=" + (ip == 0 ? "" : ip(ip)));
      if (wi != null && wi.getSupplicantState() == SupplicantState.COMPLETED
          && ni != null && ni.isConnected() && ip != 0) {
        System.out.println("connected ssid=" + wi.getSSID()
            + " ip=" + ip(ip)
            + " gateway=" + ip(dhcp.gateway)
            + " dns1=" + ip(dhcp.dns1));
        return;
      }
      Thread.sleep(1000);
    }
    throw new IllegalStateException("wifi did not reach connected+dhcp");
  }
}
