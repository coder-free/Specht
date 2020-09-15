import Cocoa
import NetworkExtension
import NEKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var barItem: NSStatusItem!
    var managerMap: [String: NETunnelProviderManager]!
    var pendingAction = 0

    var configFolder: String {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".Specht")
        var isDir: ObjCBool = false
        let exist = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if exist && !isDir.boolValue {
            try! FileManager.default.removeItem(atPath: path)
            try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        if !exist {
            try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        reloadAllConfigurationFiles() {
            self.registerObserver()
            self.initMenuBar()
        }
    }


    func initManagerMap(completionHandler: @escaping () -> ()) {
        managerMap = [:]

        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            guard managers != nil else {
                self.alertError(errorDescription: "Failed to load VPN settings from preferences. \(String(describing: error))")
                return
            }

            for manager in managers! {
                self.managerMap[manager.localizedDescription!] = manager
            }

            completionHandler()
        }
    }

    func initMenuBar() {
        barItem = NSStatusBar.system.statusItem(withLength: -1)
        barItem.title = "Sp"
        barItem.menu = NSMenu()
        barItem.menu!.delegate = self
    }

    func registerObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.statusDidChange(notification:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.configurationDidChange(notification:)), name: NSNotification.Name.NEVPNConfigurationChange, object: nil)
    }

    @objc func statusDidChange(notification: NSNotification) {
    }

    @objc func configurationDidChange(notification: NSNotification) {
    }

    @objc func startConfiguration(sender: NSMenuItem) {
        let manager = managerMap[sender.title]!
        do {
            switch manager.connection.status {
            case .disconnected:
//                disconnect()
                try (manager.connection as! NETunnelProviderSession).startTunnel(options: [:])
            case .connected, .connecting, .reasserting:
                (manager.connection as! NETunnelProviderSession).stopTunnel()
            default:
                break
            }
        } catch let error {
            alertError(errorDescription: "Failed to start VPN \(sender.title) due to: \(error)")
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let disableNonConnected = findConnectedManager() != nil
        for manager in managerMap.values {
            let item = buildMenuItemForManager(manager: manager, disableNonConnected: disableNonConnected)
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Disconnect", action: #selector(AppDelegate.disconnect(sender:)), keyEquivalent: "d")
        menu.addItem(withTitle: "Open config folder", action: #selector(AppDelegate.openConfigFolder(sender:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Reload config", action: #selector(AppDelegate.reloadClicked(sender:)), keyEquivalent: "r")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Exit", action: #selector(AppDelegate.terminate(sender:)), keyEquivalent: "q")
    }

    @objc func openConfigFolder(sender: AnyObject) {
        NSWorkspace.shared.openFile(configFolder)
    }

    @objc func reloadClicked(sender: AnyObject) {
        reloadAllConfigurationFiles()
    }

    func reloadAllConfigurationFiles(completionHandler: (() -> ())? = nil) {
        VPNManager.removeAllManagers {
            VPNManager.loadAllConfigFiles(configFolder: self.configFolder) {
                self.initManagerMap() {
                    completionHandler?()
                }
            }
        }
    }

    @objc func disconnect(sender: AnyObject? = nil) {
        for manager in managerMap.values {
            switch manager.connection.status {
            case .connected, .connecting:
                (manager.connection as! NETunnelProviderSession).stopTunnel()
            default:
                break
            }
        }
    }

    func findConnectedManager() -> NETunnelProviderManager? {
        for manager in managerMap.values {
            switch manager.connection.status {
            case .connected, .connecting, .reasserting, .disconnecting:
                return manager
            default:
                break
            }
        }
        return nil
    }

    func buildMenuItemForManager(manager: NETunnelProviderManager, disableNonConnected: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: manager.localizedDescription!, action: #selector(AppDelegate.startConfiguration(sender:)), keyEquivalent: "")

        switch manager.connection.status {
        case .connected:
            item.state = NSControl.StateValue.on
        case .connecting:
            item.title = item.title.appending("(Connecting)")
        case .disconnecting:
            item.title = item.title.appending("(Disconnecting)")
        case .reasserting:
            item.title = item.title.appending("(Reconnecting)")
        case .disconnected:
            break
        case .invalid:
            item.title = item.title.appending("(----)")
        @unknown default:
            break
        }

        if disableNonConnected {
            switch manager.connection.status {
            case .disconnected, .invalid:
                item.action = nil
            default:
                break
            }
        }
        return item
    }

    func alertError(errorDescription: String) {
        let alert = NSAlert()
        alert.messageText = errorDescription
        alert.runModal()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func terminate(sender: AnyObject) {
        NSApp.terminate(self)
    }

}
