import android.bluetooth.BluetoothAdapter;

public class BtDiscover {
  public static void main(String[] args) throws Exception {
    BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
    System.out.println("adapter=" + adapter
        + " enabled=" + (adapter != null && adapter.isEnabled())
        + " addr=" + (adapter == null ? "" : adapter.getAddress())
        + " name=" + (adapter == null ? "" : adapter.getName()));
    if (adapter == null) return;

    int seconds = args.length > 0 ? Integer.parseInt(args[0]) : 20;
    System.out.println("discovering_before=" + adapter.isDiscovering());
    System.out.println("startDiscovery=" + adapter.startDiscovery());
    for (int i = 0; i < seconds; i++) {
      Thread.sleep(1000);
      System.out.println("t=" + (i + 1) + " discovering=" + adapter.isDiscovering());
    }
    System.out.println("cancelDiscovery=" + adapter.cancelDiscovery());
  }
}
