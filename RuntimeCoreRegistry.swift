import Foundation

/// Runtime discovery and compatibility gate. This does not emulate a console by itself.
/// A platform core must be compiled for iOS and linked/bundled by the Xcode project.
struct RuntimeCoreRegistry {
    enum Platform: String {
        case nintendoSwitch = "Nintendo Switch"
        case windowsPC = "PC / Windows"
        case android = "Android"
        case playStation = "PlayStation"
        case xbox360 = "Xbox 360"
        case unknown = "ไม่ทราบแพลตฟอร์ม"
    }

    struct FileAssessment {
        let platform: Platform
        let extensionName: String
        let canRunNativelyOnIOS: Bool
        let requiredRuntime: String
        let explanation: String
    }

    var switchCoreStatus: String {
        hasBundledSwitchCore ? "พบ Switch Core ในแอป" : "ยังไม่มี Switch Emulator Core ในแอป"
    }

    private var hasBundledSwitchCore: Bool {
        // Deliberately require an explicit marker shipped with a real, tested core.
        // A filename or placeholder must never be mistaken for an operational emulator.
        Bundle.main.url(forResource: "SwitchCoreRuntime", withExtension: "manifest") != nil
    }

    func assess(fileName: String?) -> FileAssessment? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        switch ext {
        case "nsp", "xci", "nsz", "xcz":
            return FileAssessment(platform: .nintendoSwitch, extensionName: ext,
                canRunNativelyOnIOS: false, requiredRuntime: "Nintendo Switch Emulator Core",
                explanation: hasBundledSwitchCore
                    ? "พบ manifest ของ Switch Core แล้ว แต่ยังต้องตรวจว่า Core โหลดเกมชนิดนี้และทำงานบนอุปกรณ์ได้จริง"
                    : "ตรวจพบไฟล์เกม Switch แล้ว แต่ยังไม่มี Core ภายในแอป: ใช้ MeloNX เป็น Emulator แยกต่างหากได้ โดยต้องติดตั้งและตั้งค่าเองก่อน แอปนี้ยังเชื่อมเปิดเกมเข้า MeloNX อัตโนมัติไม่ได้")
        case "exe", "msi", "iso", "7z":
            return FileAssessment(platform: .windowsPC, extensionName: ext,
                canRunNativelyOnIOS: false, requiredRuntime: "PC compatibility layer หรือ streaming host",
                explanation: "ไฟล์ PC ไม่สามารถรันเป็นแอป iOS โดยตรง ต้องใช้ compatibility layer ที่พอร์ตมาสำหรับ iOS หรือสตรีมจาก PC")
        case "apk", "obb":
            return FileAssessment(platform: .android, extensionName: ext,
                canRunNativelyOnIOS: false, requiredRuntime: "Android runtime",
                explanation: "ไฟล์ Android ไม่สามารถติดตั้งหรือรันบน iOS โดยตรง")
        case "pkg":
            return FileAssessment(platform: .playStation, extensionName: ext,
                canRunNativelyOnIOS: false, requiredRuntime: "PlayStation-specific emulator",
                explanation: "พบไฟล์ PKG แต่ต้องระบุรุ่น PlayStation และมี Emulator Core ที่รองรับโดยเฉพาะ")
        case "xex":
            return FileAssessment(platform: .xbox360, extensionName: ext,
                canRunNativelyOnIOS: false, requiredRuntime: "Xbox 360 emulator core",
                explanation: "พบไฟล์ XEX แต่ยังไม่มี Xbox 360 CPU/GPU emulation และ system services")
        case "ipa":
            return FileAssessment(platform: .unknown, extensionName: ext,
                canRunNativelyOnIOS: false, requiredRuntime: "iOS code signing / installation",
                explanation: "IPA เป็นแพ็กเกจแอป iOS ต้องตรวจลายเซ็นและติดตั้งตามสิทธิ์ ไม่ใช่ ROM สำหรับ Emulator")
        default:
            return FileAssessment(platform: .unknown, extensionName: ext,
                canRunNativelyOnIOS: false, requiredRuntime: "Runtime ที่ตรงกับรูปแบบไฟล์",
                explanation: "ยังไม่มีตัวอ่านหรือ Runtime ที่ระบุได้จากนามสกุลไฟล์นี้")
        }
    }

    func diagnosticSummary(for fileName: String?) -> String {
        guard let fileName else {
            return "Runtime Bridge พร้อมตรวจสอบ แต่ยังไม่ได้เลือกเกมในคลัง และยังไม่มี Switch Emulator Core ที่ใช้งานได้"
        }
        guard let result = assess(fileName: fileName) else {
            return "ไม่สามารถระบุชนิดไฟล์ได้"
        }
        return "ไฟล์: .\(result.extensionName) • แพลตฟอร์ม: \(result.platform.rawValue)\nต้องใช้: \(result.requiredRuntime)\n\(result.explanation)"
    }
}
