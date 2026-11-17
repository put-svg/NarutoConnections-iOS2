import SwiftUI
import UniformTypeIdentifiers
import CryptoKit
import GameController
import UIKit
import AudioToolbox
import Metal

struct ContentView: View {
    private enum Page: String, CaseIterable {
        case home = "หน้าแรก"
        case library = "คลังเกม"
        case dlc = "DLC"
        case settings = "ตั้งค่า"
        case info = "ข้อมูล"
        case diagnostics = "ตรวจสอบ"
        case controls = "ปุ่มควบคุม"
        case runtime = "Runtime"

        var symbol: String {
            switch self {
            case .home: return "house.fill"
            case .library: return "square.grid.2x2.fill"
            case .dlc: return "square.stack.3d.up.fill"
            case .settings: return "slider.horizontal.3"
            case .info: return "info.circle.fill"
            case .diagnostics: return "stethoscope"
            case .controls: return "gamecontroller.fill"
            case .runtime: return "cpu.fill"
            }
        }
    }

    private struct GameEntry: Codable, Identifiable {
        var id: String
        var title: String
        var platform: String
        var note: String
        var storedFileName: String?
        var fileSize: Int64?
        var sha256: String?

        init(id: String, title: String, platform: String, note: String, storedFileName: String? = nil, fileSize: Int64? = nil, sha256: String? = nil) {
            self.id = id
            self.title = title
            self.platform = platform
            self.note = note
            self.storedFileName = storedFileName
            self.fileSize = fileSize
            self.sha256 = sha256
        }

        private enum CodingKeys: String, CodingKey { case id, title, platform, note, storedFileName, fileSize, sha256 }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id)
            title = try values.decode(String.self, forKey: .title)
            platform = try values.decode(String.self, forKey: .platform)
            note = try values.decode(String.self, forKey: .note)
            storedFileName = try values.decodeIfPresent(String.self, forKey: .storedFileName)
            fileSize = try values.decodeIfPresent(Int64.self, forKey: .fileSize)
            sha256 = try values.decodeIfPresent(String.self, forKey: .sha256)
        }
    }

    private struct LibraryManifest: Codable {
        var formatVersion: Int
        var createdAt: Date
        var selectedGameID: String
        var games: [GameEntry]
    }

    private enum ControlMode: String, CaseIterable, Identifiable {
        case combat = "ต่อสู้"
        case movement = "เคลื่อนที่"
        case support = "สนับสนุน"
        var id: String { rawValue }
    }

    @State private var controlMode: ControlMode = .combat
    @AppStorage("launcher.controlButtonScale") private var controlButtonScale = 1.0
    @AppStorage("launcher.controlButtonOpacity") private var controlButtonOpacity = 0.16
    @State private var lastControlAction = "เลือกปุ่มเพื่อดูคำสั่งตัวอย่าง"
    @State private var page: Page = .home
    @AppStorage("library.gamesJSON") private var gamesJSON = "[]"
    @AppStorage("library.selectedGameID") private var selectedGameID = ""
    @State private var newGameTitle = ""
    @State private var newGamePlatform = "Nintendo Switch"
    @State private var showAddGame = false
    @State private var showGameImportPicker = false
    @State private var gameImportStatus = "ยังไม่มีไฟล์เกมนำเข้า"
    @State private var integrityReport = "ยังไม่ได้ตรวจสอบไฟล์ในคลัง"
    @State private var libraryBackupURL: URL?
    @State private var showLibraryRestorePicker = false
    @State private var libraryBackupStatus = "สำรองเฉพาะรายการและข้อมูล SHA-256 ไม่รวมไฟล์เกม"
    @AppStorage("runtime.graphicsPreset") private var runtimeGraphicsPreset = "สมดุล"
    @AppStorage("runtime.frameRate") private var runtimeFrameRate = 60
    @AppStorage("runtime.resolution") private var runtimeResolution = "100%"
    @AppStorage("runtime.vsync") private var runtimeVSync = true
    @AppStorage("runtime.performanceMode") private var runtimePerformanceMode = false
    @State private var runtimeCheckMessage = "ยังไม่มี Emulator Core สำหรับ iOS"
    @State private var showPicker = false
    @State private var showPackagePicker = false
    @State private var selectedPackageName = ""
    @State private var packageInspection = "ยังไม่ได้เลือกไฟล์แพ็กเกจ"
    @State private var packageSHA256 = ""
    @State private var expectedSHA256 = ""
    @State private var folderURL: URL?
    @State private var status = "เลือกโฟลเดอร์เกมเพื่อตรวจสอบไฟล์"
    @State private var report: [String] = []
    @State private var sha1 = ""
    @State private var inventorySummary = "ยังไม่ได้สแกนไฟล์"
    @State private var formatSummary = "ยังไม่ได้ตรวจสอบประเภทแพ็กเกจ"
    @State private var controllerStatus = "ไม่พบจอยเกม"
    @State private var lastControllerInput = "รอการกดปุ่มจากจอยเกม"
    @State private var controllerName = "ยังไม่ได้เชื่อมต่อ"
    @State private var showMetalTest = false
    @State private var showRuntimeNotice = false
    @AppStorage("launcher.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("launcher.soundEnabled") private var soundEnabled = false
    @AppStorage("launcher.esign.step1") private var esignStep1 = false
    @AppStorage("launcher.esign.step2") private var esignStep2 = false
    @AppStorage("launcher.esign.step3") private var esignStep3 = false
    @AppStorage("launcher.esign.step4") private var esignStep4 = false
    @State private var bundleIDCopied = false
    @State private var controllerObservers: [NSObjectProtocol] = []

    private let accent = Color(red: 1.0, green: 0.36, blue: 0.12)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.035, green: 0.035, blue: 0.055), Color(red: 0.16, green: 0.035, blue: 0.055), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Group {
                    switch page {
                    case .home: homePage
                    case .library: libraryPage
                    case .dlc: dlcPage
                    case .settings: settingsPage
                    case .info: infoPage
                    case .diagnostics: diagnosticsPage
                    case .controls: controlsPage
                    case .runtime: runtimePage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false, onCompletion: inspect)
        .fileImporter(isPresented: $showPackagePicker, allowedContentTypes: [.item], allowsMultipleSelection: false, onCompletion: inspectPackage)
        .fileImporter(isPresented: $showGameImportPicker, allowedContentTypes: [.item], allowsMultipleSelection: true, onCompletion: importGameFiles)
        .fileImporter(isPresented: $showLibraryRestorePicker, allowedContentTypes: [.json], allowsMultipleSelection: false, onCompletion: restoreLibraryManifest)
        .alert("เพิ่มเกมเข้าคลัง", isPresented: $showAddGame) {
            TextField("ชื่อเกม", text: $newGameTitle)
            Button("ยกเลิก", role: .cancel) { }
            Button("เพิ่ม") { addGameToLibrary() }
        } message: {
            Text("เพิ่มชื่อเกมและแพลตฟอร์มลงในคลังส่วนตัว แอปจะยังไม่รวมไฟล์เกมหรือยืนยันว่าเล่นได้")
        }
        .alert("ยังเปิดเกมไม่ได้", isPresented: $showRuntimeNotice) {
            Button("เข้าใจแล้ว", role: .cancel) { }
        } message: {
            Text("แอปนี้เป็น Launcher ต้นแบบ ยังไม่มี Game Runtime สำหรับ iOS และไม่ได้ติดตั้งหรือแปลงตัวเกมให้")
        }
        .onAppear(perform: observeControllers)
        .onDisappear {
            controllerObservers.forEach(NotificationCenter.default.removeObserver)
            controllerObservers.removeAll()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(accent).frame(width: 38, height: 38)
                Image(systemName: "bolt.fill").font(.system(size: 19, weight: .black)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("NARUTO CONNECTIONS").font(.system(size: 14, weight: .black, design: .rounded)).tracking(0.6)
                Text("iOS LAUNCHER • PROTOTYPE").font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
            Circle().fill(Color.orange).frame(width: 7, height: 7)
            Text("DEMO").font(.system(size: 10, weight: .heavy)).foregroundStyle(.orange)
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 14)
    }

    private var homePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 22).fill(LinearGradient(colors: [Color(red: 0.43, green: 0.08, blue: 0.08), Color(red: 0.12, green: 0.07, blue: 0.10), Color.black], startPoint: .topTrailing, endPoint: .bottomLeading))
                    Circle().fill(accent.opacity(0.20)).frame(width: 190, height: 190).blur(radius: 2).offset(x: 190, y: -30)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NINJA WORLD").font(.system(size: 10, weight: .black)).tracking(2.2).foregroundStyle(.orange)
                        Text("READY\nFOR BATTLE?").font(.system(size: 31, weight: .black, design: .rounded)).lineSpacing(-3)
                        Text("จัดการไฟล์เกมและตรวจสอบความพร้อม")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(20)
                    Image(systemName: "flame.fill").font(.system(size: 76)).foregroundStyle(.orange.opacity(0.17)).rotationEffect(.degrees(-18)).offset(x: 205, y: -22)
                }
                .frame(height: 188).clipShape(RoundedRectangle(cornerRadius: 22))

                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Launcher ต้นแบบ — ยังไม่มีระบบเล่นเกมจริง")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                    Spacer(minLength: 0)
                }
                .padding(12).background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))

                sectionTitle("GAME FILES", subtitle: "ตรวจสอบโฟลเดอร์เกม")
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "folder.fill").foregroundStyle(.orange)
                        Text(folderURL?.lastPathComponent ?? "ยังไม่ได้เลือกโฟลเดอร์")
                            .font(.system(size: 13, weight: .bold)).lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: folderURL == nil ? "circle" : "checkmark.circle.fill")
                            .foregroundStyle(folderURL == nil ? .white.opacity(0.35) : .green)
                    }
                    Text(status).font(.system(size: 11)).foregroundStyle(.white.opacity(0.62))
                    if !report.isEmpty {
                        ForEach(report, id: \.self) { line in
                            Text(line).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.72))
                        }
                    }
                    Text(inventorySummary).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.68))
                    Text(formatSummary).font(.system(size: 10, weight: .semibold)).foregroundStyle(.orange.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                    if !sha1.isEmpty {
                        Text("SHA-1: \(sha1)").font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.5)).textSelection(.enabled)
                    }
                    Button { tapFeedback(); showPicker = true } label: {
                        Label("เลือกโฟลเดอร์เกม", systemImage: "folder.badge.plus")
                            .font(.system(size: 13, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent).tint(accent)
                }
                .padding(15).background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 17))

                HStack(spacing: 10) {
                    Button { tapFeedback(); showRuntimeNotice = true } label: {
                        VStack(spacing: 7) {
                            Image(systemName: "play.fill").font(.system(size: 17))
                            Text("PLAY").font(.system(size: 11, weight: .black))
                            Text("ยังไม่พร้อม").font(.system(size: 9)).opacity(0.65)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                    Button { tapFeedback(); showMetalTest.toggle() } label: {
                        VStack(spacing: 7) {
                            Image(systemName: "viewfinder").font(.system(size: 17))
                            Text("METAL TEST").font(.system(size: 11, weight: .black))
                            Text(showMetalTest ? "ซ่อนการทดสอบ" : "ทดสอบกราฟิก").font(.system(size: 9)).opacity(0.65)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                }

                if showMetalTest {
                    MetalSurface().frame(height: 130).clipShape(RoundedRectangle(cornerRadius: 15))
                        .overlay(alignment: .topLeading) {
                            Text("METAL SURFACE TEST ONLY").font(.system(size: 9, weight: .bold)).padding(8).background(.black.opacity(0.55), in: Capsule())
                        }
                }

                sectionTitle("CONTROLLER", subtitle: controllerStatus)
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Image(systemName: "gamecontroller.fill").font(.system(size: 23)).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(controllerName).font(.system(size: 11, weight: .bold))
                            Text("รองรับจอยที่ iOS รู้จักผ่าน GameController API")
                                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Text("LIVE INPUT").font(.system(size: 8, weight: .black)).foregroundStyle(.green)
                    }
                    HStack {
                        Text("อินพุตล่าสุด")
                        Spacer()
                        Text(lastControllerInput).foregroundStyle(.orange).lineLimit(1)
                    }.font(.system(size: 10, weight: .semibold))
                    Text("ทดสอบการเชื่อมต่อและอ่านปุ่มเท่านั้น ยังไม่ได้ส่งคำสั่งเข้าเกม เพราะยังไม่มี Emulator Core")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.48))
                }
                .padding(14).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
            }
            .padding(.horizontal, 16).padding(.bottom, 18)
        }
    }


    private var selectedRuntimeFileName: String? {
        guard let selected = gameEntries.first(where: { $0.id == selectedGameID }) else { return nil }
        return selected.storedFileName
    }

    private var selectedGameFileURL: URL? {
        guard let selected = gameEntries.first(where: { $0.id == selectedGameID }),
              let storedName = selected.storedFileName else { return nil }
        let url = gameLibraryDirectory().appendingPathComponent(storedName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var runtimePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                pageHeading("NINJA CONSOLE", subtitle: "SWITCH-STYLE RUNTIME CONTROL CENTER")

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(colors: [Color(red: 0.34, green: 0.055, blue: 0.045), Color(red: 0.12, green: 0.035, blue: 0.055), Color.black], startPoint: .topTrailing, endPoint: .bottomLeading))
                    Circle().fill(accent.opacity(0.22)).frame(width: 150, height: 150).blur(radius: 22).offset(x: 205, y: 28)
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            Label("RUNTIME PANEL", systemImage: "cpu.fill").font(.system(size: 10, weight: .black)).tracking(1.4).foregroundStyle(.orange)
                            Spacer()
                            Text("PREVIEW").font(.system(size: 9, weight: .black)).padding(.horizontal, 9).padding(.vertical, 5).background(.orange.opacity(0.15), in: Capsule()).foregroundStyle(.orange)
                        }
                        Text("NINJA\nENGINE").font(.system(size: 32, weight: .black, design: .rounded)).lineSpacing(-5)
                        Text("กราฟิกและประสิทธิภาพสำหรับ iOS").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.68))
                        HStack(spacing: 7) {
                            runtimeStatusPill("METAL", symbol: "cube.transparent")
                            runtimeStatusPill("GAMEPAD", symbol: "gamecontroller.fill")
                            runtimeStatusPill("CORE MISSING", symbol: "exclamationmark.circle")
                        }
                    }.padding(18)
                }
                .frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 22))

                infoBanner("เพิ่ม Runtime Bridge สำหรับตรวจชนิดไฟล์และตรวจหา Core แล้ว แต่ยังไม่มี Nintendo Switch CPU/GPU Emulator Core จึงยังเปิดเกมจริงไม่ได้", icon: "exclamationmark.triangle.fill")

                sectionTitle("EMULATOR CORE", subtitle: "สถานะระบบ")
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(.red.opacity(0.15)).frame(width: 46, height: 46)
                            Image(systemName: "cpu.fill").font(.system(size: 21, weight: .bold)).foregroundStyle(.red.opacity(0.9))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nintendo Switch Core").font(.system(size: 13, weight: .bold))
                            Text(RuntimeCoreRegistry().switchCoreStatus).font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer(minLength: 0)
                        Text("OFFLINE").font(.system(size: 9, weight: .black)).foregroundStyle(.red).padding(7).background(.red.opacity(0.12), in: Capsule())
                    }
                    Text(runtimeCheckMessage).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.62)).fixedSize(horizontal: false, vertical: true)
                    Button {
                        tapFeedback()
                        runtimeCheckMessage = RuntimeCoreRegistry().diagnosticSummary(for: selectedRuntimeFileName)
                    } label: {
                        Label("ตรวจสอบ Core ในแอป", systemImage: "magnifyingglass")
                            .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }.buttonStyle(.bordered).tint(.orange)
                }
                .padding(14).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))

                sectionTitle("EXTERNAL SWITCH CORE", subtitle: "MeloNX • ต้องติดตั้งแยก")
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 20)).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("MeloNX สำหรับ iOS").font(.system(size: 13, weight: .bold))
                            Text("Emulator แยกต่างหาก • ยังไม่ได้ฝังใน Naruto Connections")
                                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.58))
                        }
                        Spacer(minLength: 0)
                        Text("EXTERNAL").font(.system(size: 8, weight: .black))
                            .foregroundStyle(.orange).padding(7).background(.orange.opacity(0.12), in: Capsule())
                    }
                    Text("MeloNX ต้องใช้ JIT และสิทธิ์หน่วยความจำที่เหมาะสม การติดตั้ง IPA ด้วย ESign อย่างเดียวไม่ได้รับประกันว่าจะใช้งานได้")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.68)).fixedSize(horizontal: false, vertical: true)
                    Link(destination: URL(string: "https://melonx.org/")!) {
                        Label("เว็บไซต์ MeloNX", systemImage: "globe")
                            .font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 11)
                    }.buttonStyle(.borderedProminent).tint(.orange)
                    Link(destination: URL(string: "https://github.com/nurtrino/MeloNX/releases")!) {
                        Label("ดูรุ่น IPA และบันทึกการอัปเดต", systemImage: "arrow.down.circle")
                            .font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                    }.buttonStyle(.bordered).tint(.white)
                    Link(destination: URL(string: "https://github.com/nurtrino/MeloNX")!) {
                        Label("ซอร์สโค้ดและคู่มือติดตั้ง", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                    }.buttonStyle(.bordered).tint(.white)
                    Text("เปิดเกมจากภายใน MeloNX เองก่อน ขณะนี้ยังไม่มี API ที่ยืนยันแล้วสำหรับส่งไฟล์เกมจาก Launcher ไปเปิดอัตโนมัติ")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.48)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))

                sectionTitle("GRAPHICS PROFILE", subtitle: "การตั้งค่าตัวอย่าง")
                VStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("คุณภาพกราฟิก").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.75))
                        Picker("คุณภาพกราฟิก", selection: $runtimeGraphicsPreset) {
                            Text("ประหยัดพลังงาน").tag("ประหยัดพลังงาน")
                            Text("สมดุล").tag("สมดุล")
                            Text("คุณภาพสูง").tag("คุณภาพสูง")
                        }.pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text("ความละเอียดเรนเดอร์"); Spacer(); Text(runtimeResolution).foregroundStyle(.orange).monospacedDigit() }
                            .font(.system(size: 11, weight: .semibold))
                        Picker("ความละเอียด", selection: $runtimeResolution) {
                            Text("50%").tag("50%")
                            Text("75%").tag("75%")
                            Text("100%").tag("100%")
                        }.pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text("เป้าหมายเฟรมเรต"); Spacer(); Text("\(runtimeFrameRate) FPS").foregroundStyle(.orange).monospacedDigit() }
                            .font(.system(size: 11, weight: .semibold))
                        Picker("FPS", selection: $runtimeFrameRate) {
                            Text("30 FPS").tag(30)
                            Text("60 FPS").tag(60)
                        }.pickerStyle(.segmented)
                    }
                    Divider().overlay(.white.opacity(0.1))
                    Toggle(isOn: $runtimeVSync) { Label("V-Sync", systemImage: "arrow.left.arrow.right") }
                        .font(.system(size: 12, weight: .semibold)).tint(.orange)
                    Toggle(isOn: $runtimePerformanceMode) { Label("โหมดประสิทธิภาพ", systemImage: "speedometer") }
                        .font(.system(size: 12, weight: .semibold)).tint(.orange)
                    Text("ค่าด้านบนเป็นการตั้งค่าหน้าจอที่บันทึกไว้ ยังไม่มีผลต่อการเรนเดอร์เกมจนกว่าจะมี Runtime จริง")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.48)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))

                sectionTitle("SYSTEM MODULES", subtitle: "ความพร้อมเบื้องต้น")
                VStack(spacing: 8) {
                    runtimeModuleRow("Metal graphics layer", detail: "มีหน้าทดสอบกราฟิกพื้นฐาน", ready: true)
                    runtimeModuleRow("Controller input", detail: "ตรวจพบจอยผ่าน GameController API", ready: true)
                    runtimeModuleRow("Switch CPU / GPU emulation", detail: "ยังไม่มี Emulator Core", ready: false)
                    runtimeModuleRow("Game format loader", detail: "ยังไม่มีตัวโหลดเกมที่รองรับ", ready: false)
                    runtimeModuleRow("Firmware / system services", detail: "ยังไม่ได้พัฒนา", ready: false)
                }
                .padding(13).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(16).padding(.bottom, 12)
        }
    }

    private func runtimeStatusPill(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 8, weight: .black)).padding(.horizontal, 8).padding(.vertical, 6)
            .background(.black.opacity(0.32), in: Capsule()).foregroundStyle(.white.opacity(0.85))
    }

    private func runtimeModuleRow(_ title: String, detail: String, ready: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ready ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .bold))
                Text(detail).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
            Text(ready ? "READY" : "MISSING").font(.system(size: 8, weight: .black)).foregroundStyle(ready ? .green : .red)
        }
        .padding(.vertical, 4)
    }

    private var libraryPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                pageHeading("คลังเกมของฉัน", subtitle: "เก็บหลายเกมไว้ใน Launcher เดียว")
                infoBanner("v24 เพิ่มสำรอง/กู้คืนรายการคลังเป็นไฟล์ JSON พร้อมข้อมูล SHA-256 • ไฟล์สำรองนี้ไม่รวมไฟล์เกมจริง", icon: "externaldrive.fill")

                VStack(alignment: .leading, spacing: 9) {
                    Text("สำรองและกู้คืนคลังเกม").font(.system(size: 12, weight: .bold))
                    HStack(spacing: 8) {
                        Button { createLibraryBackup() } label: {
                            Label("สร้างไฟล์สำรอง", systemImage: "square.and.arrow.up")
                                .font(.system(size: 10, weight: .bold)).padding(.horizontal, 11).padding(.vertical, 9)
                                .background(accent, in: Capsule())
                        }.buttonStyle(.plain)
                        Button { showLibraryRestorePicker = true } label: {
                            Label("กู้คืน JSON", systemImage: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold)).padding(.horizontal, 11).padding(.vertical, 9)
                                .background(.white.opacity(0.10), in: Capsule())
                        }.buttonStyle(.plain)
                        if let backupURL = libraryBackupURL {
                            ShareLink(item: backupURL) {
                                Image(systemName: "square.and.arrow.up.on.square").font(.system(size: 13, weight: .bold))
                                    .frame(width: 34, height: 34).background(.white.opacity(0.10), in: Circle())
                            }
                        }
                    }
                    Text(libraryBackupStatus).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
                .padding(13).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                Picker("แพลตฟอร์ม", selection: $newGamePlatform) {
                    Text("Nintendo Switch").tag("Nintendo Switch")
                    Text("PC").tag("PC")
                    Text("Android").tag("Android")
                    Text("อื่น ๆ").tag("อื่น ๆ")
                }
                .pickerStyle(.menu).tint(.orange)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MY GAME LIBRARY").font(.system(size: 10, weight: .black)).tracking(1.5).foregroundStyle(.orange)
                        Text("\(gameEntries.count) เกมในคลัง").font(.system(size: 20, weight: .black, design: .rounded))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 7) {
                        Button { showGameImportPicker = true } label: {
                            Label("นำเข้าไฟล์", systemImage: "square.and.arrow.down")
                                .font(.system(size: 11, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 9)
                                .background(accent, in: Capsule())
                        }.buttonStyle(.plain)
                        Button {
                            newGameTitle = ""
                            showAddGame = true
                        } label: {
                            Label("เพิ่มชื่อเกม", systemImage: "plus")
                                .font(.system(size: 10, weight: .bold)).padding(.horizontal, 10).padding(.vertical, 7)
                                .background(.white.opacity(0.09), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }

                if gameEntries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "gamecontroller.fill").font(.system(size: 34)).foregroundStyle(.orange.opacity(0.8))
                        Text("ยังไม่มีเกมในคลัง").font(.system(size: 15, weight: .bold))
                        Text("กด ‘เพิ่มเกม’ เพื่อสร้างรายการเกมแรกของคุณ").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 17))
                } else {
                    ForEach(gameEntries) { game in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.16)).frame(width: 48, height: 48)
                                .overlay { Image(systemName: "gamecontroller.fill").font(.system(size: 20)).foregroundStyle(.orange) }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.title).font(.system(size: 13, weight: .bold)).lineLimit(1)
                                Text(game.platform + (game.storedFileName == nil ? " • รายการในคลัง" : " • มีไฟล์ในเครื่อง"))
                                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                                Text(game.note + (game.fileSize.map { " • " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""))
                                    .font(.system(size: 9, weight: .medium)).foregroundStyle(.orange.opacity(0.9)).lineLimit(2)
                                if let digest = game.sha256 {
                                    Text("SHA-256  " + String(digest.prefix(16)) + "…")
                                        .font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.42)).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 2)
                            if selectedGameID == game.id {
                                Text("เลือกอยู่").font(.system(size: 9, weight: .bold)).foregroundStyle(.green)
                            } else {
                                Button("เลือก") { selectedGameID = game.id }
                                    .font(.system(size: 10, weight: .bold)).buttonStyle(.bordered).tint(.orange)
                            }
                            Button(role: .destructive) { removeGame(game) } label: {
                                Image(systemName: "trash").font(.system(size: 12, weight: .bold)).padding(7)
                            }.buttonStyle(.plain).foregroundStyle(.red.opacity(0.85))
                        }
                        .padding(12).background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 15))
                    }
                }

                if let selected = gameEntries.first(where: { $0.id == selectedGameID }) {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle("SELECTED GAME", subtitle: "เกมที่เลือก")
                        Text(selected.title).font(.system(size: 16, weight: .black))
                        Button { showRuntimeNotice = true } label: {
                            Label("เปิดเกม", systemImage: "play.fill")
                                .font(.system(size: 12, weight: .black)).frame(maxWidth: .infinity).padding(.vertical, 12)
                        }.buttonStyle(.borderedProminent).tint(accent)
                        if let exportURL = selectedGameFileURL {
                            ShareLink(item: exportURL) {
                                Label("ส่งออกไฟล์ไปยัง Files / MeloNX", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 11)
                            }
                            .buttonStyle(.bordered).tint(.orange)
                            Text("บันทึกไฟล์ลงแอป Files ก่อน แล้วเปิด MeloNX และนำเข้าไฟล์จาก Files ด้วยตนเอง")
                                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("รายการนี้ยังไม่มีไฟล์เกมในเครื่อง จึงส่งออกไม่ได้")
                                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(14).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("ตรวจสอบความสมบูรณ์ของไฟล์").font(.system(size: 12, weight: .bold))
                        Spacer()
                        Button { verifyGameLibrary() } label: {
                            Label("ตรวจไฟล์ทั้งหมด", systemImage: "checkmark.shield")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(accent, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                    Text(integrityReport).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(13).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                infoBanner(gameImportStatus, icon: "doc.zipper")
                Text("นำเข้าไฟล์เกมส่วนตัวเพื่อเก็บไว้ในแอปได้หลายรายการ การนำเข้าไม่ได้แปลว่า iOS รองรับการรันไฟล์นั้น และยังต้องมี Runtime แยกตามแพลตฟอร์ม")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.48)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 20)
        }
    }

    private var gameEntries: [GameEntry] {
        guard let data = gamesJSON.data(using: .utf8),
              let entries = try? JSONDecoder().decode([GameEntry].self, from: data) else { return [] }
        return entries
    }

    private func createLibraryBackup() {
        let manifest = LibraryManifest(formatVersion: 1, createdAt: Date(),
                                       selectedGameID: selectedGameID, games: gameEntries)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(manifest)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("NarutoConnections-Library-\(formatter.string(from: Date())).json")
            try data.write(to: url, options: .atomic)
            libraryBackupURL = url
            libraryBackupStatus = "สร้างไฟล์สำรองแล้ว \(gameEntries.count) รายการ • กดไอคอนแชร์เพื่อบันทึกลง Files"
        } catch {
            libraryBackupStatus = "สร้างไฟล์สำรองไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    private func restoreLibraryManifest(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let manifest = try decoder.decode(LibraryManifest.self, from: data)
            guard manifest.formatVersion == 1, manifest.games.count <= 500 else {
                libraryBackupStatus = "ไฟล์สำรองเวอร์ชันไม่รองรับหรือมีรายการมากเกินไป"
                return
            }
            var merged = gameEntries
            var added = 0
            for var game in manifest.games {
                let duplicate = merged.contains { existing in
                    existing.id == game.id || (!game.sha256.isNilOrEmpty && existing.sha256 == game.sha256)
                }
                if duplicate { continue }
                if let storedName = game.storedFileName {
                    let safeName = URL(fileURLWithPath: storedName).lastPathComponent
                    let candidate = gameLibraryDirectory().appendingPathComponent(safeName)
                    if safeName != storedName || !FileManager.default.fileExists(atPath: candidate.path) {
                        game.note = "กู้คืนรายการแล้ว • ไม่พบไฟล์ในเครื่อง ต้องนำเข้าไฟล์ใหม่"
                    }
                    game.storedFileName = safeName
                }
                merged.append(game)
                added += 1
            }
            saveGameEntries(merged)
            if merged.contains(where: { $0.id == manifest.selectedGameID }) {
                selectedGameID = manifest.selectedGameID
            } else if selectedGameID.isEmpty, let first = merged.first {
                selectedGameID = first.id
            }
            libraryBackupStatus = "กู้คืนรายการเพิ่ม \(added) เกม • รายการซ้ำถูกข้าม • ไฟล์เกมไม่ได้รวมอยู่ใน JSON"
        } catch {
            libraryBackupStatus = "กู้คืนไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    private func saveGameEntries(_ entries: [GameEntry]) {
        guard let data = try? JSONEncoder().encode(entries), let value = String(data: data, encoding: .utf8) else { return }
        gamesJSON = value
    }

    private func addGameToLibrary() {
        let title = newGameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        var entries = gameEntries
        let game = GameEntry(id: UUID().uuidString, title: title, platform: newGamePlatform, note: "ยังไม่ได้เชื่อมต่อ Runtime")
        entries.append(game)
        saveGameEntries(entries)
        selectedGameID = game.id
    }

    private func verifyGameLibrary() {
        let entries = gameEntries
        guard !entries.isEmpty else {
            integrityReport = "ยังไม่มีรายการเกมให้ตรวจสอบ"
            return
        }
        var checked = 0
        var passed = 0
        var missing = 0
        var changed = 0
        var noBaseline = 0
        var details: [String] = []
        let directory = gameLibraryDirectory()

        for game in entries {
            guard let storedName = game.storedFileName else { continue }
            let fileURL = directory.appendingPathComponent(storedName)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                missing += 1
                details.append("ไม่พบไฟล์: \(game.title)")
                continue
            }
            guard let expected = game.sha256, !expected.isEmpty else {
                noBaseline += 1
                details.append("ไม่มีค่า SHA-256 เดิม: \(game.title)")
                continue
            }
            checked += 1
            do {
                let actual = try Self.sha256(fileURL)
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let actualSize = (attributes[.size] as? NSNumber)?.int64Value ?? -1
                if actual == expected && (game.fileSize == nil || game.fileSize == actualSize) {
                    passed += 1
                } else {
                    changed += 1
                    details.append("ข้อมูลไม่ตรงกับตอนนำเข้า: \(game.title)")
                }
            } catch {
                changed += 1
                details.append("อ่านไฟล์ไม่ได้: \(game.title)")
            }
        }

        integrityReport = "ตรวจค่าแฮชแล้ว \(checked) ไฟล์ • ผ่าน \(passed) • ไม่พบ \(missing) • ข้อมูลเปลี่ยน/อ่านไม่ได้ \(changed) • ไม่มีค่าเดิม \(noBaseline)"
        if !details.isEmpty {
            integrityReport += "\n" + details.prefix(4).joined(separator: "\n")
        }
    }

    private func removeGame(_ game: GameEntry) {
        if let storedFileName = game.storedFileName {
            let fileURL = gameLibraryDirectory().appendingPathComponent(storedFileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        let entries = gameEntries.filter { $0.id != game.id }
        saveGameEntries(entries)
        if selectedGameID == game.id { selectedGameID = entries.first?.id ?? "" }
    }

    private func gameLibraryDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("GameLibrary", isDirectory: true)
    }

    private func platformForGameFile(_ url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "nsp", "xci", "nsz", "xcz": return "Nintendo Switch"
        case "exe", "msi", "iso", "7z": return "PC / Disc Image"
        case "apk", "obb": return "Android"
        case "pkg": return "PlayStation"
        case "xex": return "Xbox 360"
        default: return nil
        }
    }

    private func importGameFiles(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            let directory = gameLibraryDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var entries = gameEntries
            var imported = 0
            var skipped: [String] = []

            for sourceURL in urls {
                guard let platform = platformForGameFile(sourceURL) else {
                    skipped.append(sourceURL.lastPathComponent + " (ชนิดไฟล์ยังไม่รองรับในคลัง)")
                    continue
                }
                let hasAccess = sourceURL.startAccessingSecurityScopedResource()
                defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }

                let id = UUID().uuidString
                let safeName = id + (sourceURL.pathExtension.isEmpty ? "" : "." + sourceURL.pathExtension)
                let destination = directory.appendingPathComponent(safeName)
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                    let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
                    let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                    let digest = try Self.sha256(destination)
                    if entries.contains(where: { $0.sha256 == digest }) {
                        try? FileManager.default.removeItem(at: destination)
                        skipped.append(sourceURL.lastPathComponent + " (มีไฟล์เนื้อหาเดียวกันในคลังแล้ว)")
                        continue
                    }
                    let title = sourceURL.deletingPathExtension().lastPathComponent
                    entries.append(GameEntry(id: id, title: title, platform: platform,
                                              note: "นำเข้าแล้ว • ตรวจ SHA-256 แล้ว • Runtime ยังไม่พร้อม",
                                              storedFileName: safeName, fileSize: size, sha256: digest))
                    imported += 1
                } catch {
                    let partialURL = directory.appendingPathComponent(safeName)
                    try? FileManager.default.removeItem(at: partialURL)
                    skipped.append(sourceURL.lastPathComponent + " (คัดลอก/ตรวจสอบไม่สำเร็จ)")
                }
            }

            saveGameEntries(entries)
            if selectedGameID.isEmpty, let first = entries.last { selectedGameID = first.id }
            gameImportStatus = "นำเข้าสำเร็จ \(imported) ไฟล์ • ตรวจ SHA-256 แล้ว" + (skipped.isEmpty ? "" : " • ข้าม \(skipped.count) ไฟล์")
            if !skipped.isEmpty { gameImportStatus += ": " + skipped.prefix(3).joined(separator: ", ") }
        } catch {
            gameImportStatus = "นำเข้าไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    private var dlcPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                pageHeading("DLC CENTER", subtitle: "ข้อมูลส่วนเสริมและสถานะไฟล์")
                infoBanner("หน้านี้เป็นหน้าตัวอย่าง ยังไม่ได้เชื่อมต่อระบบตรวจ DLC หรือปลดล็อกเนื้อหาเกม", icon: "info.circle.fill")
                dlcRow(title: "Additional Playable Characters", detail: "ข้อมูลตัวละครเสริม", symbol: "person.3.fill", state: "ยังไม่ตรวจสอบ")
                dlcRow(title: "Costume Packs", detail: "ข้อมูลชุดตัวละคร", symbol: "tshirt.fill", state: "ยังไม่ตรวจสอบ")
                dlcRow(title: "Extra Missions", detail: "ข้อมูลภารกิจเสริม", symbol: "scroll.fill", state: "ยังไม่ตรวจสอบ")
                dlcRow(title: "Season Pass Content", detail: "ข้อมูล Season Pass", symbol: "ticket.fill", state: "ยังไม่ตรวจสอบ")
            }
            .padding(16)
        }
    }

    private var settingsPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                pageHeading("SETTINGS", subtitle: "ตั้งค่าหน้า Launcher")
                VStack(spacing: 0) {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("การสั่นตอบสนอง", systemImage: "waveform")
                            .font(.system(size: 13, weight: .semibold))
                    }.tint(accent).padding(15)
                    Divider().overlay(.white.opacity(0.08)).padding(.leading, 15)
                    Toggle(isOn: $soundEnabled) {
                        Label("เสียงใน Launcher", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }.tint(accent).padding(15)
                }
                .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 16))
                infoBanner("การตั้งค่าเหล่านี้มีผลเฉพาะหน้าต้นแบบ ยังไม่เปลี่ยนการตั้งค่าภายในเกม", icon: "slider.horizontal.3")

                VStack(alignment: .leading, spacing: 12) {
                    pageHeading("ESIGN INSTALL GUIDE", subtitle: "เช็กลิสต์เตรียมติดตั้ง IPA บน iPhone")
                    infoBanner("IPA ที่ได้จาก GitHub เป็นไฟล์ unsigned ต้อง Sign ด้วยใบรับรองและ Provisioning Profile ที่ได้รับอนุญาตก่อน จึงจะติดตั้งได้", icon: "exclamationmark.shield.fill")
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BUNDLE IDENTIFIER").font(.system(size: 9, weight: .black)).tracking(1).foregroundStyle(.white.opacity(0.5))
                            Text("com.narutoconnections.launcher").font(.system(size: 11, weight: .semibold, design: .monospaced)).textSelection(.enabled)
                        }
                        Spacer(minLength: 4)
                        Button {
                            UIPasteboard.general.string = "com.narutoconnections.launcher"
                            bundleIDCopied = true
                            tapFeedback()
                        } label: {
                            Label(bundleIDCopied ? "คัดลอกแล้ว" : "คัดลอก", systemImage: bundleIDCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.bordered).tint(.orange)
                    }
                    .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                    checklistRow("1. Build สำเร็จใน GitHub Actions", detail: "Job ต้องเป็นสีเขียว แล้วดาวน์โหลด Artifact NarutoConnections-unsigned-IPA", isDone: $esignStep1)
                    checklistRow("2. แตกไฟล์ Artifact", detail: "แตก ZIP ที่ดาวน์โหลด แล้วหาไฟล์ NarutoConnections-unsigned.ipa", isDone: $esignStep2)
                    checklistRow("3. นำ IPA เข้า ESign และ Sign", detail: "เลือก Certificate และ Provisioning Profile ที่รองรับ Bundle ID ด้านบน", isDone: $esignStep3)
                    checklistRow("4. ติดตั้งและเปิดแอป", detail: "ติดตั้งหลัง Sign สำเร็จเท่านั้น หากขึ้นข้อผิดพลาด ให้ตรวจ Profile และ Certificate", isDone: $esignStep4)
                    Button {
                        esignStep1 = false; esignStep2 = false; esignStep3 = false; esignStep4 = false
                        bundleIDCopied = false
                        tapFeedback()
                    } label: {
                        Label("รีเซ็ตเช็กลิสต์", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity).padding(10)
                    }
                    .buttonStyle(.bordered).tint(.white.opacity(0.75))
                    Text("หมายเหตุ: เช็กลิสต์นี้ใช้จดจำขั้นตอนเท่านั้น แอปไม่สามารถ Sign IPA หรือยืนยันสิทธิ์ของใบรับรองแทน ESign ได้ และตัว Launcher ยังไม่มี Game Runtime")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))

                Button { tapFeedback(); showPicker = true } label: {
                    Label("เลือกโฟลเดอร์เกมใหม่", systemImage: "folder")
                        .font(.system(size: 13, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                }.buttonStyle(.bordered).tint(.white.opacity(0.8))
            }
            .padding(16)
        }
    }

    private var infoPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                pageHeading("ABOUT", subtitle: "ข้อมูลแอป")
                VStack(alignment: .leading, spacing: 9) {
                    Text("NARUTO CONNECTIONS").font(.system(size: 17, weight: .black, design: .rounded))
                    Text("iOS Launcher Prototype").font(.system(size: 12, weight: .semibold)).foregroundStyle(.orange)
                    Text("เวอร์ชันต้นแบบสำหรับทดสอบหน้าตาแอป การเลือกโฟลเดอร์ การตรวจไฟล์ และการตรวจพบจอยเกม")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 16))
                infoBanner("ไม่มีไฟล์เกมหรือ Game Runtime รวมอยู่ในแอปนี้ และยังไม่สามารถเล่นเกมได้", icon: "exclamationmark.triangle.fill")
                Label("iOS 16 หรือใหม่กว่า", systemImage: "iphone").font(.system(size: 12, weight: .medium)).padding(13)
                Label("กราฟิกทดสอบผ่าน Metal", systemImage: "cube.transparent").font(.system(size: 12, weight: .medium)).padding(13)
                Label("ตรวจพบจอยผ่าน GameController", systemImage: "gamecontroller").font(.system(size: 12, weight: .medium)).padding(13)
            }
            .padding(16)
        }
    }

    private var controlsPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                pageHeading("MULTI-FUNCTION PAD", subtitle: "ผังปุ่มเสมือนหลายโหมดสำหรับหน้าจอสัมผัส")
                infoBanner("นี่คือผังปุ่มตัวอย่างที่ปรับตามโหมดได้ ยังไม่ได้เชื่อมกับเกมหรือ Game Runtime และไม่ใช่ผังปุ่มที่ยืนยันว่าแกะมาจากเกมจริง", icon: "info.circle.fill")

                VStack(alignment: .leading, spacing: 9) {
                    Text("เลือกโหมดการควบคุม").font(.system(size: 11, weight: .black)).foregroundStyle(.white.opacity(0.75))
                    Picker("โหมด", selection: $controlMode) {
                        ForEach(ControlMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(controlModeDescription).font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                }
                .padding(13).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Label("ปรับแต่งปุ่ม", systemImage: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .black))
                        Spacer()
                        Button("รีเซ็ต") {
                            controlButtonScale = 1.0
                            controlButtonOpacity = 0.16
                            tapFeedback()
                        }
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(.orange)
                    }
                    VStack(spacing: 5) {
                        HStack {
                            Text("ขนาดปุ่ม")
                            Spacer()
                            Text("\(Int(controlButtonScale * 100))%")
                                .monospacedDigit().foregroundStyle(.orange)
                        }
                        .font(.system(size: 10, weight: .semibold))
                        Slider(value: $controlButtonScale, in: 0.8...1.3, step: 0.05).tint(accent)
                    }
                    VStack(spacing: 5) {
                        HStack {
                            Text("ความเข้มพื้นหลัง")
                            Spacer()
                            Text("\(Int(controlButtonOpacity * 100))%")
                                .monospacedDigit().foregroundStyle(.orange)
                        }
                        .font(.system(size: 10, weight: .semibold))
                        Slider(value: $controlButtonOpacity, in: 0.06...0.34, step: 0.02).tint(accent)
                    }
                    Text("บันทึกค่าที่เลือกไว้ในเครื่องโดยอัตโนมัติ")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.48))
                }
                .padding(13).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 9) {
                    Text("SHOULDER BUTTONS").font(.system(size: 10, weight: .black)).tracking(1.1).foregroundStyle(.white.opacity(0.55))
                    HStack(spacing: 8) {
                        multiFunctionButton("LB")
                        multiFunctionButton("LT")
                        multiFunctionButton("RB")
                        multiFunctionButton("RT")
                    }
                }

                HStack(alignment: .center, spacing: 14) {
                    VStack(spacing: 6) {
                        Text("D-PAD").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.5))
                        HStack(spacing: 5) {
                            multiFunctionButton("←", compact: true)
                            multiFunctionButton("↑", compact: true)
                            multiFunctionButton("↓", compact: true)
                            multiFunctionButton("→", compact: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 6) {
                        Text("ACTION BUTTONS").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.5))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                            multiFunctionButton("Y")
                            multiFunctionButton("X")
                            multiFunctionButton("B")
                            multiFunctionButton("A")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(12).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 8) {
                    multiFunctionButton("L3")
                    multiFunctionButton("VIEW")
                    multiFunctionButton("MENU")
                    multiFunctionButton("R3")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("คำสั่งล่าสุด", systemImage: "hand.tap.fill").font(.system(size: 11, weight: .black)).foregroundStyle(.orange)
                    Text(lastControlAction).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                }
                .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                infoBanner("แต่ละปุ่มเปลี่ยนคำสั่งตามโหมด ต่อสู้ / เคลื่อนที่ / สนับสนุน ใช้สำหรับออกแบบหน้าตาและทดสอบการแตะเท่านั้น", icon: "square.grid.3x3.fill")
            }
            .padding(16)
        }
    }

    private var controlModeDescription: String {
        switch controlMode {
        case .combat: return "โหมดต่อสู้: เน้นโจมตี หลบ ป้องกัน และเปลี่ยนตัวละคร"
        case .movement: return "โหมดเคลื่อนที่: เน้นวิ่ง กระโดด ล็อกเป้า และควบคุมกล้อง"
        case .support: return "โหมดสนับสนุน: เน้นเรียกเพื่อน ใช้ไอเท็ม และท่าพิเศษ"
        }
    }

    private func actionForControl(_ key: String) -> String {
        let mappings: [ControlMode: [String: String]] = [
            .combat: ["A":"กระโดด", "B":"หลบ", "X":"โจมตี", "Y":"นินจุตสึ", "LB":"เปลี่ยนตัว", "RB":"เรียกสนับสนุน", "LT":"ป้องกัน", "RT":"พุ่งโจมตี", "←":"เลือกซ้าย", "→":"เลือกขวา", "↑":"เลือกบน", "↓":"เลือกลง", "L3":"เคลื่อนที่", "R3":"ล็อกเป้า", "VIEW":"ข้อมูลต่อสู้", "MENU":"เมนูหยุดเกม"],
            .movement: ["A":"กระโดด", "B":"วิ่ง/หลบ", "X":"โต้ตอบ", "Y":"ล็อกเป้า", "LB":"เป้าหมายก่อนหน้า", "RB":"เป้าหมายถัดไป", "LT":"เดินช้า", "RT":"พุ่ง", "←":"เคลื่อนซ้าย", "→":"เคลื่อนขวา", "↑":"เคลื่อนขึ้น", "↓":"เคลื่อนลง", "L3":"วิ่งต่อเนื่อง", "R3":"รีเซ็ตกล้อง", "VIEW":"แผนที่/ข้อมูล", "MENU":"เมนูหยุดเกม"],
            .support: ["A":"ใช้ไอเท็ม", "B":"สลับตัวละคร", "X":"เรียกทีม 1", "Y":"ท่าพิเศษ", "LB":"ทีมสนับสนุน 1", "RB":"ทีมสนับสนุน 2", "LT":"ล็อกเป้าหมาย", "RT":"ใช้พลัง", "←":"เลือกไอเท็มก่อนหน้า", "→":"เลือกไอเท็มถัดไป", "↑":"เลือกช่องบน", "↓":"เลือกช่องล่าง", "L3":"เคลื่อนที่", "R3":"เลือกเป้าหมาย", "VIEW":"รายละเอียดทีม", "MENU":"เมนูหยุดเกม"]
        ]
        return mappings[controlMode]?[key] ?? "คำสั่งทิศทาง"
    }

    private func multiFunctionButton(_ key: String, compact: Bool = false) -> some View {
        let action = actionForControl(key)
        let scale = CGFloat(controlButtonScale)
        return Button {
            tapFeedback()
            lastControlAction = "\(key) — \(action) • โหมด\(controlMode.rawValue)"
        } label: {
            VStack(spacing: compact ? 2 : 4) {
                Text(key).font(.system(size: (compact ? 12 : 14) * scale, weight: .black, design: .rounded))
                Text(action).font(.system(size: (compact ? 7 : 8) * scale, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.75).multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: (compact ? 48 : 58) * scale)
            .padding(.horizontal, 3)
            .background(key == "A" || key == "B" || key == "X" || key == "Y" ? accent.opacity(controlButtonOpacity) : .white.opacity(controlButtonOpacity * 0.45), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.12), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    private var diagnosticsPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                pageHeading("SYSTEM CHECK", subtitle: "ตรวจสอบสภาพแวดล้อมของ iPhone และ Launcher")
                infoBanner("หน้านี้ตรวจสอบเฉพาะความพร้อมของแอปและอุปกรณ์ ไม่ได้ยืนยันว่าเกมหรือ Game Runtime ใช้งานได้", icon: "info.circle.fill")

                diagnosticRow("iOS Version", value: UIDevice.current.systemVersion, symbol: "iphone")
                diagnosticRow("Launcher", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Prototype", symbol: "app.badge")
                diagnosticRow("Metal Device", value: MTLCreateSystemDefaultDevice()?.name ?? "ไม่พบอุปกรณ์ Metal", symbol: "cube.transparent")
                diagnosticRow("Game Controller", value: controllerStatus, symbol: "gamecontroller.fill")
                diagnosticRow("Game Folder", value: folderURL?.lastPathComponent ?? "ยังไม่ได้เลือก", symbol: "folder.fill")
                diagnosticRow("File Check", value: status, symbol: "doc.text.magnifyingglass")
                diagnosticRow("File Inventory", value: inventorySummary, symbol: "list.bullet.rectangle")
                diagnosticRow("Package Formats", value: formatSummary, symbol: "doc.zipper")
                infoBanner("APK คือแพ็กเกจ Android และไม่สามารถแปลงเป็น IPA ด้วยการเปลี่ยนนามสกุลไฟล์ได้ ส่วน IPA ต้องผ่านการเซ็นที่ถูกต้องก่อนติดตั้งบน iPhone", icon: "info.circle.fill")

                VStack(alignment: .leading, spacing: 9) {
                    Label("PACKAGE FILE CHECK", systemImage: "doc.text.magnifyingglass")
                        .font(.system(size: 11, weight: .black)).tracking(0.8).foregroundStyle(.orange)
                    Text(selectedPackageName.isEmpty ? "ยังไม่ได้เลือกไฟล์" : selectedPackageName)
                        .font(.system(size: 12, weight: .bold)).lineLimit(2)
                    Text(packageInspection)
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
                    if !packageSHA256.isEmpty {
                        Text("SHA-256: \(packageSHA256)")
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.55)).textSelection(.enabled)
                    }
                    TextField("วาง SHA-256 อ้างอิง 64 ตัวอักษร (ถ้ามี)", text: $expectedSHA256)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 11, design: .monospaced))
                        .padding(11)
                        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                    if !expectedSHA256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(hashComparisonStatus)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(hashComparisonColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button {
                        tapFeedback()
                        showPackagePicker = true
                    } label: {
                        Label("เลือกไฟล์ APK / IPA / XEX / ZIP", systemImage: "doc.badge.magnifyingglass")
                            .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity).padding(12)
                    }
                    .buttonStyle(.bordered).tint(.white.opacity(0.85))
                }
                .padding(14).background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 15))

                Button {
                    tapFeedback()
                    refreshControllerStatus()
                } label: {
                    Label("ตรวจสอบจอยอีกครั้ง", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity).padding(13)
                }
                .buttonStyle(.borderedProminent).tint(accent)

                ShareLink(item: diagnosticReport) {
                    Label("แชร์รายงานการตรวจสอบ", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity).padding(13)
                }
                .buttonStyle(.bordered).tint(.white.opacity(0.85))
            }
            .padding(16)
        }
    }

    private var diagnosticReport: String {
        [
            "Naruto Connections iOS Launcher — Diagnostic Report",
            "iOS: \(UIDevice.current.systemVersion)",
            "Launcher: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Prototype")",
            "Metal: \(MTLCreateSystemDefaultDevice()?.name ?? "Unavailable")",
            "Controller: \(controllerStatus)",
            "Folder: \(folderURL?.lastPathComponent ?? "Not selected")",
            "File check: \(status)",
            "Inventory: \(inventorySummary)",
            "Package formats: \(formatSummary)",
            "SHA-1: \(sha1.isEmpty ? "Not calculated" : sha1)",
            "Selected package: \(selectedPackageName.isEmpty ? "Not selected" : selectedPackageName)",
            "Package inspection: \(packageInspection)",
            "Package SHA-256: \(packageSHA256.isEmpty ? "Not calculated" : packageSHA256)",
            "Expected SHA-256 comparison: \(hashComparisonStatus)",
            "Note: This launcher does not include a game runtime."
        ].joined(separator: "\n")
    }

    private var hashComparisonStatus: String {
        let expected = expectedSHA256.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard expected.count == 64, expected.allSatisfy({ $0.isHexDigit }) else {
            return "รูปแบบ SHA-256 อ้างอิงไม่ถูกต้อง — ต้องเป็นเลขฐาน 16 จำนวน 64 ตัวอักษร"
        }
        guard !packageSHA256.isEmpty else {
            return "ยังไม่มีค่า SHA-256 ของไฟล์ที่เลือก กรุณาเลือกไฟล์ก่อน"
        }
        return expected == packageSHA256.lowercased()
            ? "ตรงกัน: SHA-256 ของไฟล์ตรงกับค่าอ้างอิง"
            : "ไม่ตรงกัน: SHA-256 ของไฟล์ไม่ตรงกับค่าอ้างอิง"
    }

    private var hashComparisonColor: Color {
        hashComparisonStatus.hasPrefix("ตรงกัน:") ? .green : .orange
    }

    private func diagnosticRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(.orange).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 10, weight: .black)).tracking(0.7).foregroundStyle(.white.opacity(0.5))
                Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func checklistRow(_ title: String, detail: String, isDone: Binding<Bool>) -> some View {
        Button {
            isDone.wrappedValue.toggle()
            tapFeedback()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isDone.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDone.wrappedValue ? .green : .white.opacity(0.45))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    Text(detail).font(.system(size: 10)).foregroundStyle(.white.opacity(0.58)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 11))
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
            ForEach(Page.allCases, id: \.self) { item in
                Button { tapFeedback(); page = item } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.system(size: 16, weight: .bold))
                        Text(item.rawValue).font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(page == item ? .orange : .white.opacity(0.48))
                    .frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(.black.opacity(0.55))
        }
        .background(.black.opacity(0.55))
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.09)).frame(height: 1) }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title).font(.system(size: 11, weight: .black)).tracking(1.5)
            Spacer()
            Text(subtitle).font(.system(size: 10)).foregroundStyle(.white.opacity(0.48))
        }
    }

    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 23, weight: .black, design: .rounded)).tracking(1)
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
    }

    private func infoBanner(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(.orange)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
    }

    private func dlcRow(title: String, detail: String, symbol: String, state: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11).fill(accent.opacity(0.16)).frame(width: 42, height: 42)
                .overlay { Image(systemName: symbol).foregroundStyle(.orange) }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .bold))
                Text(detail).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 4)
            Text(state).font(.system(size: 9, weight: .bold)).foregroundStyle(.orange)
        }
        .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
    }

    private func inspect(_ result: Result<[URL], Error>) {
        do {
            guard let folder = try result.get().first else { return }
            let access = folder.startAccessingSecurityScopedResource()
            defer { if access { folder.stopAccessingSecurityScopedResource() } }
            folderURL = folder
            report = []
            sha1 = ""
            inventorySummary = "กำลังสแกน..."
            formatSummary = "กำลังตรวจสอบประเภทแพ็กเกจ..."

            for name in ["default.xex", "data", "nxeart", "Content"] {
                let url = folder.appendingPathComponent(name)
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                report.append("\(exists ? "พบ" : "ไม่พบ") \(name)\(exists && isDir.boolValue ? " (โฟลเดอร์)" : "")")
            }

            var fileCount = 0
            var totalBytes: Int64 = 0
            var extensionCounts: [String: Int] = [:]
            var xexURL: URL?
            let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            if let enumerator = FileManager.default.enumerator(
                at: folder,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                while let item = enumerator.nextObject() as? URL {
                    if fileCount >= 20_000 { break }
                    guard let values = try? item.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
                    fileCount += 1
                    totalBytes += Int64(values.fileSize ?? 0)
                    let ext = item.pathExtension.isEmpty ? "(ไม่มีนามสกุล)" : ".\(item.pathExtension.lowercased())"
                    extensionCounts[ext, default: 0] += 1
                    if item.lastPathComponent.lowercased() == "default.xex" && xexURL == nil {
                        xexURL = item
                    }
                }
            }

            let packageTypes: [(String, String)] = [
                (".apk", "APK Android"),
                (".ipa", "IPA iOS"),
                (".xex", "XEX Xbox 360"),
                (".obb", "OBB Android data"),
                (".zip", "ZIP archive")
            ]
            let foundPackages = packageTypes.compactMap { ext, label -> String? in
                guard let count = extensionCounts[ext], count > 0 else { return nil }
                return "\(label): \(count)"
            }
            formatSummary = foundPackages.isEmpty
                ? "ไม่พบไฟล์ APK / IPA / XEX / OBB / ZIP ในรายการที่สแกน"
                : foundPackages.joined(separator: " • ")

            let topExtensions = extensionCounts.sorted { $0.value > $1.value }.prefix(4)
                .map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            let truncated = fileCount >= 20_000 ? " (จำกัดการสแกน 20,000 ไฟล์)" : ""
            inventorySummary = "พบ \(fileCount) ไฟล์ • \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))\(truncated)" + (topExtensions.isEmpty ? "" : " • \(topExtensions)")

            guard let xex = xexURL else {
                if (extensionCounts[".apk"] ?? 0) > 0 {
                    status = "พบไฟล์ APK สำหรับ Android — iPhone ไม่สามารถติดตั้ง APK โดยตรงได้"
                } else if (extensionCounts[".ipa"] ?? 0) > 0 {
                    status = "พบไฟล์ IPA — ต้องตรวจสอบลายเซ็นและ Provisioning Profile ก่อนติดตั้ง"
                } else if (extensionCounts[".obb"] ?? 0) > 0 {
                    status = "พบ OBB ซึ่งเป็นข้อมูลเสริมของ Android ไม่ใช่แอป iOS"
                } else {
                    status = "ไม่พบ default.xex หรือแพ็กเกจ APK / IPA ในโฟลเดอร์ที่เลือก"
                }
                return
            }
            let attrs = try FileManager.default.attributesOfItem(atPath: xex.path)
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            if size <= 512 * 1024 * 1024 {
                sha1 = try Self.hash(xex)
                status = "พบ default.xex • ขนาด \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)) • คำนวณ SHA-1 แล้ว (ยังไม่ได้เทียบกับฐานข้อมูลอ้างอิง)"
            } else {
                status = "พบ default.xex แต่ไฟล์ใหญ่เกิน 512 MB จึงข้ามการคำนวณ SHA-1"
            }
        } catch {
            status = "ตรวจสอบไม่สำเร็จ: \(error.localizedDescription)"
            inventorySummary = "สแกนไม่สำเร็จ"
            formatSummary = "ไม่สามารถตรวจสอบประเภทไฟล์ได้"
        }
    }


    private func inspectPackage(_ result: Result<[URL], Error>) {
        do {
            guard let fileURL = try result.get().first else { return }
            let access = fileURL.startAccessingSecurityScopedResource()
            defer { if access { fileURL.stopAccessingSecurityScopedResource() } }

            selectedPackageName = fileURL.lastPathComponent
            packageSHA256 = ""
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let handle = try FileHandle(forReadingFrom: fileURL)
            let header = handle.readData(ofLength: 8)
            try? handle.close()

            let ext = fileURL.pathExtension.lowercased()
            let isZipContainer = header.starts(with: [0x50, 0x4B, 0x03, 0x04]) ||
                header.starts(with: [0x50, 0x4B, 0x05, 0x06]) ||
                header.starts(with: [0x50, 0x4B, 0x07, 0x08])
            let isXEX = header.starts(with: [0x58, 0x45, 0x58, 0x32])
            let sizeText = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)

            switch ext {
            case "apk":
                packageInspection = isZipContainer
                    ? "ตรวจพบ ZIP signature ของแพ็กเกจ APK • \(sizeText) — ยังไม่ได้ตรวจโครงสร้างภายในหรือลายเซ็น Android"
                    : "นามสกุลเป็น APK แต่ไม่พบ ZIP signature ที่คาดไว้ — ไฟล์อาจเสียหายหรือไม่ใช่ APK"
            case "ipa":
                packageInspection = isZipContainer
                    ? "ตรวจพบ ZIP signature ของแพ็กเกจ IPA • \(sizeText) — ยังไม่ได้ตรวจ Provisioning Profile หรือ Code Signature"
                    : "นามสกุลเป็น IPA แต่ไม่พบ ZIP signature ที่คาดไว้ — ไฟล์อาจเสียหายหรือไม่ใช่ IPA"
            case "xex":
                packageInspection = isXEX
                    ? "ตรวจพบ XEX2 header • \(sizeText) — ตรวจเฉพาะ header ไม่ได้ยืนยันว่าเกมทำงานได้"
                    : "นามสกุลเป็น XEX แต่ไม่พบ XEX2 header ที่คาดไว้"
            case "zip":
                packageInspection = isZipContainer
                    ? "ตรวจพบ ZIP signature • \(sizeText) — ยังไม่ได้แตกหรือยืนยันไฟล์ภายใน"
                    : "นามสกุลเป็น ZIP แต่ไม่พบ ZIP signature ที่คาดไว้"
            case "obb":
                packageInspection = "ไฟล์ OBB ของ Android • \(sizeText) — การตรวจนี้ไม่ยืนยันความสมบูรณ์ของข้อมูล OBB"
            default:
                packageInspection = "ชนิดไฟล์ .\(ext.isEmpty ? "(ไม่มีนามสกุล)" : ext) • \(sizeText) — ยังไม่มีตัวตรวจเฉพาะสำหรับชนิดนี้"
            }

            if size <= 1024 * 1024 * 1024 {
                packageSHA256 = try Self.sha256(fileURL)
            } else {
                packageInspection += " • ขนาดเกิน 1 GB จึงข้ามการคำนวณ SHA-256"
            }
        } catch {
            selectedPackageName = "เปิดไฟล์ไม่สำเร็จ"
            packageInspection = error.localizedDescription
            packageSHA256 = ""
        }
    }

    private static func sha256(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hasher = SHA256()
        while true {
            let chunk = file.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func hash(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hasher = Insecure.SHA1()
        while true {
            let chunk = file.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func tapFeedback() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        if soundEnabled {
            AudioServicesPlaySystemSound(1104)
        }
    }

    private func refreshControllerStatus() {
        let controllers = GCController.controllers()
        controllerStatus = controllers.isEmpty ? "ไม่พบจอยเกม" : "เชื่อมต่อจอยแล้ว \(controllers.count) ตัว"
        controllerName = controllers.first?.vendorName ?? (controllers.isEmpty ? "ยังไม่ได้เชื่อมต่อ" : "Game Controller")
        controllers.forEach(configureControllerInput)
    }

    private func configureControllerInput(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        pad.buttonA.pressedChangedHandler = { _, _, pressed in if pressed { reportControllerInput("A") } }
        pad.buttonB.pressedChangedHandler = { _, _, pressed in if pressed { reportControllerInput("B") } }
        pad.buttonX.pressedChangedHandler = { _, _, pressed in if pressed { reportControllerInput("X") } }
        pad.buttonY.pressedChangedHandler = { _, _, pressed in if pressed { reportControllerInput("Y") } }
        pad.leftShoulder.pressedChangedHandler = { _, _, pressed in if pressed { reportControllerInput("L1") } }
        pad.rightShoulder.pressedChangedHandler = { _, _, pressed in if pressed { reportControllerInput("R1") } }
        pad.buttonMenu.pressedChangedHandler = { _, _, pressed in if pressed { reportControllerInput("MENU") } }
        pad.dpad.valueChangedHandler = { _, x, y in
            guard abs(x) > 0.55 || abs(y) > 0.55 else { return }
            let direction = abs(x) > abs(y) ? (x > 0 ? "ขวา" : "ซ้าย") : (y > 0 ? "ขึ้น" : "ลง")
            reportControllerInput("D-PAD \(direction)")
        }
        pad.leftThumbstick.valueChangedHandler = { _, x, y in
            guard abs(x) > 0.65 || abs(y) > 0.65 else { return }
            reportControllerInput(String(format: "LEFT STICK  %.1f, %.1f", x, y))
        }
    }

    private func reportControllerInput(_ input: String) {
        DispatchQueue.main.async { lastControllerInput = input }
    }

    private func observeControllers() {
        controllerObservers.forEach(NotificationCenter.default.removeObserver)
        controllerObservers.removeAll()

        let center = NotificationCenter.default
        let connected = center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { _ in
            refreshControllerStatus()
        }
        let disconnected = center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { _ in
            refreshControllerStatus()
            if GCController.controllers().isEmpty { lastControllerInput = "รอการกดปุ่มจากจอยเกม" }
        }
        controllerObservers = [connected, disconnected]
        refreshControllerStatus()
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}
