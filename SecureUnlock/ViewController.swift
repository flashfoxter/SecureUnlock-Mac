import Cocoa
import KeychainAccess
import EFQRCode
import IOBluetooth

class ViewController: NSViewController {
    @IBOutlet var passwordSecureTextField: NSSecureTextField!
    @IBOutlet var codeImageView: NSImageView!
    let keychain = Keychain(service: "org.wenyu.secureunlock")

    @IBAction func savePassword(_ sender: NSButton) {
        if (!passwordSecureTextField.stringValue.isEmpty) {
            keychain[AppDelegate.KEYCHAIN_PASSWORD] = passwordSecureTextField.stringValue
            passwordSecureTextField.stringValue = ""
        }
    }

    @IBAction func generateQRCode(_ sender: NSButton) {
        let btAddress = IOBluetoothHostController.default().addressAsString()!
        let unlockKey = UUID()
        keychain[AppDelegate.KEYCHAIN_UNLOCK_KEY] = unlockKey.uuidString
        let encodeString = btAddress + "," + unlockKey.uuidString
        let image = EFQRCode.generate(content: encodeString)!
        codeImageView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
