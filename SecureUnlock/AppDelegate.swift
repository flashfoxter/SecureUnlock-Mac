import Cocoa
import CoreBluetooth
import IOBluetooth
import IOKit
import IOKit.pwr_mgt
import KeychainAccess

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CBPeripheralManagerDelegate {
    var peripheralManager: CBPeripheralManager?
    static let UNLOCK_SCRIPT_BASE = "tell application \"System Events\" to keystroke \"%@\" \ntell application \"System Events\" to keystroke return";
    var screenLocked = false
    static let KEYCHAIN_PASSWORD = "SecureUnlock"
    static let KEYCHAIN_UNLOCK_KEY = "UnlockKey"
    static let SERVICE_UUID = CBUUID(string: "B45D4BC9-D040-48BA-92DF-1BABFB533BCD")
    static let CHARACTERISTIC_UUID = CBUUID(string: "64C52ED8-EBBA-4279-8D5A-DA040C5574FC")
    let keychain = Keychain(service: "org.wenyu.secureunlock")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: nil) { (notification) in
            self.screenLocked = true
        }
        center.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: nil) { (notification) in
            self.screenLocked = false
        }
        let unlockKey = self.keychain[AppDelegate.KEYCHAIN_UNLOCK_KEY]
        let password = self.keychain[AppDelegate.KEYCHAIN_PASSWORD]
        if (unlockKey != nil && password != nil) {
            print("Hide main window")
            NSApplication.shared.windows.last!.close()
        }
        oath_init()
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if (peripheral.state == CBManagerState.poweredOn) {
            let characteristic = CBMutableCharacteristic(
                    type: AppDelegate.CHARACTERISTIC_UUID,
                    properties: [CBCharacteristicProperties.write],
                    value: nil,
                    permissions: [CBAttributePermissions.writeEncryptionRequired])
            let includeService = CBMutableService(type: AppDelegate.SERVICE_UUID, primary: true)
            includeService.characteristics = [characteristic]
            peripheral.add(includeService)
            peripheral.startAdvertising([CBAdvertisementDataLocalNameKey: "SecureUnlock",
                                         CBAdvertisementDataServiceUUIDsKey: UUID()])
        } else {
            peripheral.stopAdvertising()
            peripheral.removeAllServices()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("Request received!: " + String(requests.count))
        for request in requests {
            let receivedUnlockKeyword = String(data: request.value!, encoding: String.Encoding.utf8)
            let secret = self.keychain[AppDelegate.KEYCHAIN_UNLOCK_KEY]
            if (secret != nil && receivedUnlockKeyword != nil) {
                print(receivedUnlockKeyword!)
                print(secret!)
                if (oath_totp_validate(secret!.cString(using: String.Encoding.utf8), secret!.count, time(nil), 30, 0, 1, receivedUnlockKeyword!.cString(using: String.Encoding.utf8)) >= 0) {
                    if (self.screenLocked) {
                        print("unlock screen!")
                        var assertionID: IOPMAssertionID = 0
                        IOPMAssertionDeclareUserActivity("SecureUnlock" as CFString, kIOPMUserActiveLocal, &assertionID)
                        sleep(1)
                        let unlockScript = String(format: AppDelegate.UNLOCK_SCRIPT_BASE, arguments: [keychain[AppDelegate.KEYCHAIN_PASSWORD]!])
                        NSAppleScript(source: unlockScript)!.executeAndReturnError(nil)
                        IOPMAssertionRelease(assertionID)
                    }
                    peripheral.respond(to: request, withResult: CBATTError.success)
                    return
                }
            }
            peripheral.respond(to: request, withResult: CBATTError.writeNotPermitted)
        }
    }
}