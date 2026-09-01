import Cocoa
import FlutterMacOS
import RUN

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    let channel = FlutterMethodChannel.init(name: "com.example.img_syncer/RunGrpcServer", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler({
      (_ call: FlutterMethodCall, _ result: FlutterResult) -> Void in
      if call.method == "RunGrpcServer" {
        var error: NSError? = nil
        let ports = RunRunGrpcServer(&error)
        result(ports)
      } else {
        result(FlutterMethodNotImplemented)
      }
    });
  }
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
