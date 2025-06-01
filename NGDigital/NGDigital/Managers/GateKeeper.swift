//
//  GateKeeper.swift
//  NGDigital
//
//  Created by Marlon on 5/26/25.
//

import Foundation
import SwiftUI
import UIKit
import MachO
import Contacts
import AVFoundation
import Photos
import CoreLocation
import CoreMotion
import UserNotifications
import LocalAuthentication
import EventKit
import UserNotifications
import CoreBluetooth

class GateKeeper: ObservableObject {
    @Published var user = User()
    @Published var currentViewMode:ViewModes = .dashboard
    @Published var previousViewMode:ViewModes = .profile
    @Published var nextViewMode:ViewModes = .store
    let orientation = UIDevice.current.orientation
    let screen = UIScreen.main
    let batteryLevel = UIDevice.current.batteryLevel
    let batteryState = UIDevice.current.batteryState
    let locale = Locale.current
    let timeZone = TimeZone.current
    let permissionsCenter = PermissionsCenterView()
    @Published var appSettings = AppSettings()
    let bluetoothManager = BluetoothPermissionManager()
    let keyChain = KeychainService()
    
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
    }
    
    func getMemoryInfo() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: stats) / MemoryLayout<integer_t>.size)
        _ = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let host_port: mach_port_t = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host_port, HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            print("Free Memory Pages: \(stats.free_count)")
            print("Active Memory Pages: \(stats.active_count)")
            print("Inactive Memory Pages: \(stats.inactive_count)")
            print("Wired Memory Pages: \(stats.wire_count)")
        }
    }

    
    func getDiskSpace() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attrs[.systemFreeSize] as? NSNumber,
           let totalSize = attrs[.systemSize] as? NSNumber {
            print("Free: \(freeSize.int64Value / (1024 * 1024)) MB")
            print("Total: \(totalSize.int64Value / (1024 * 1024)) MB")
        }
    }

    
    @ViewBuilder
    func tshangSung() -> some View {
        if user.associations.isEmpty {
            Text("No associations found.")
        } else {
            ForEach(user.associations.indices, id: \.self) { index in
                let assoc = self.user.associations[index]
                switch assoc.type {
                case .forum:
                    ForumView(data: assoc.data)
                case .store:
                    StoreView(data: assoc.data)
                case .profile:
                    ProfileView(data: assoc.data)
                case .unknown:
                    Text("Unknown association type.")
                }
            }
        }
    }
    
    func route(for assoc: Association) -> some View {
        switch assoc.type {
        case .profile:
            return AnyView(ProfileView(data: assoc.dataAsDict))
        case .forum:
            return AnyView(ForumView(data: assoc.dataAsDict))
        case .store:
            return AnyView(StoreView(data: assoc.dataAsDict))
        default:
            return AnyView(Text("Unknown View"))
        }
    }

// decoding helper
    func decodeAssociations(from data: Data) -> [Association] {
        let decoder = JSONDecoder()
        do {
            let payloads = try decoder.decode([AssociationPayload].self, from: data)
            return payloads.map { $0.toAssociation() }
        } catch {
            print("Decoding failed: \(error)")
            return []
        }
    }
    
    func loadImage(imageUrl:String,imageWidth:CGFloat = 100,imageHeight:CGFloat = 100,isProfile:Bool = false)-> some View{
        return AsyncImage(url: URL(string: imageUrl)) { phase in
            switch phase {
            case .empty:
                // Placeholder while loading
                ProgressView()
                    .frame(width: 100, height: 100)
            case .success(let image):
                // Successfully loaded image
                if isProfile {
                    image
                        .resizable()
                        .scaledToFit()
                    .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 5)
                }else{
                    image
                        .resizable()
                        .scaledToFit()
                }
            case .failure:
                // Error loading image
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: imageWidth, height: imageHeight)

    }
    
    func addSoundToVideo(originalVideo: URL, musicFile: URL, completion: @escaping (URL?) -> Void) {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("final_merged.mov")

        VideoAudioMerger.merge(videoURL: originalVideo, with: musicFile, outputURL: outputURL) { result in
            switch result {
            case .success(let finalVideoURL):
                print("Final video with music: \(finalVideoURL)")
                completion(finalVideoURL)
            case .failure(let error):
                print("Failed to merge audio: \(error)")
                completion(nil)
            }
        }
    }

}

class BluetoothPermissionManager: NSObject, CBCentralManagerDelegate {
    var centralManager: CBCentralManager?
    var statusUpdate: ((String) -> Void)?

    func requestBluetoothPermission() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: statusUpdate?("Granted")
        case .unauthorized: statusUpdate?("Denied")
        default: statusUpdate?("Unknown")
        }
    }
}


struct AppSettings {
    @AppStorage("biometricAuthStatus") static var biometricAuthStatus: String = "Not Authenticated"
    @AppStorage("selectedTheme") static var selectedTheme: String = "system" // options: system, light, dark
    @AppStorage("backendURL") static var backendURL: String = "https://lightek.diy/users/sign_in"
    @AppStorage("features") static var features: String = "sex"
    @AppStorage("motionPermission") var motionPermission: String = "Unknown"
    @AppStorage("bluetoothPermission") var bluetoothPermission: String = "Unknown"
    @AppStorage("notificationPermission") var notificationPermission: String = "Unknown"
    @AppStorage("authToken") var authToken = ""
    // etc.

    // Add more settings below as needed:
    // @AppStorage("someOtherSetting") static var someOtherSetting: String = "default"
}

struct UserProfileDashboardView: View {
    @State private var model = UIDevice.current.model
    @State private var name = UIDevice.current.name
    @State private var systemName = UIDevice.current.systemName
    @State private var systemVersion = UIDevice.current.systemVersion
    @State private var identifier = UIDevice.current.identifierForVendor?.uuidString ?? "Unavailable"
    @State private var batteryLevel = UIDevice.current.batteryLevel
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    @State private var locationStatus: String = "Unknown"
    @State private var contactStatus: String = "Unknown"
    @State private var photoStatus: String = "Unknown"
    @State private var calendarStatus: String = "Unknown"
    @State private var microphoneStatus: String = "Unknown"
    @State private var cameraStatus: String = "Unknown"
    @State private var notificationStatus: String = "Unknown"
    @State private var bluetoothStatus: String = "Unknown"
    @State private var motionStatus: String = "Unknown"

    
    @AppStorage("biometricAuthStatus") private var biometricAuthStatus: String = "Not Authenticated"
    @AppStorage("selectedTheme") private var selectedTheme: String = "system"
    @AppStorage("locationPermission") var locationPermission: String = "Unknown"
    @AppStorage("contactPermission") var contactPermission: String = "Unknown"
    @AppStorage("photoPermission") var photoPermission: String = "Unknown"
    @AppStorage("calendarPermission") var calendarPermission: String = "Unknown"
    @AppStorage("microphonePermission") var microphonePermission: String = "Unknown"
    @AppStorage("cameraPermission") var cameraPermission: String = "Unknown"
    @AppStorage("notificationPermission") var notificationPermission: String = "Unknown"
    @AppStorage("bluetoothPermission") var bluetoothPermission: String = "Unknown"
    @AppStorage("motionPermission") var motionPermission: String = "Unknown"


    private let locationManager = CLLocationManager()
    let btManager = BluetoothPermissionManager()
    let motionManager = CMMotionActivityManager()


    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Group{
                    SectionView(title: "Device Information") {
                        LabeledRow(label: "Model", value: model)
                        LabeledRow(label: "Name", value: name)
                        LabeledRow(label: "System", value: systemName)
                        LabeledRow(label: "Version", value: systemVersion)
                        LabeledRow(label: "UUID", value: identifier)
                        LabeledRow(label: "Battery Level", value: "\(Int(batteryLevel * 100))%")
                        
                        Group{
                            LabeledRow(label: "Low Power Mode", value: isLowPowerModeEnabled ? "On" : "Off")
                            LabeledRow(label: "Calendar", value: calendarStatus)
                            LabeledRow(label: "Microphone", value: microphoneStatus)
                            LabeledRow(label: "Camera", value: cameraStatus)
                            LabeledRow(label: "Notifications", value: notificationStatus)
                            LabeledRow(label: "Bluetooth", value: bluetoothStatus)
                            LabeledRow(label: "Motion & Fitness", value: motionStatus)

                        }

                    }
                }

                Group{
                    SectionView(title: "Permissions") {
                        LabeledRow(label: "Location", value: locationStatus)
                        LabeledRow(label: "Contacts", value: contactStatus)
                        LabeledRow(label: "Photos", value: photoStatus)

                        Button("Request All Permissions") {
                            requestAllPermissions()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Group{
                    SectionView(title: "Biometric Authentication") {
                        Button("Authenticate") {
                            authenticateUser()
                        }
                        .buttonStyle(.borderedProminent)

                        Text("Status: \(biometricAuthStatus)")
                            .font(.subheadline)
                            .foregroundColor(biometricAuthStatus.contains("Success") ? .green : .red)
                    }
                }

                Group{
                    SectionView(title: "Theme") {
                        Picker("App Theme", selection: $selectedTheme) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding()
        }
        .onAppear(perform: {
            UIDevice.current.isBatteryMonitoringEnabled = true
            btManager.statusUpdate = { status in
                DispatchQueue.main.async {
                    bluetoothStatus = status
                }
            }
            requestAllPermissions()
        })
    }

    func requestAllPermissions() {
        // Location
        locationManager.requestWhenInUseAuthorization()
        locationStatus = locationManager.authorizationStatus.description

        // Contacts
        CNContactStore().requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                contactStatus = granted ? "Granted" : "Denied"
            }
        }

        // Photos
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                photoStatus = status.description
            }
        }

        // Calendar
        EKEventStore().requestAccess(to: .event) { granted, _ in
            DispatchQueue.main.async {
                calendarStatus = granted ? "Granted" : "Denied"
            }
        }

        // Microphone
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                microphoneStatus = granted ? "Granted" : "Denied"
            }
        }

        // Camera
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraStatus = granted ? "Granted" : "Denied"
            }
        }
        
        //Notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationStatus = granted ? "Granted" : "Denied"
            }
        }
        
        btManager.requestBluetoothPermission()
        
        motionManager.queryActivityStarting(from: Date(), to: Date(), to: .main) { _, error in
            DispatchQueue.main.async {
                motionStatus = error == nil ? "Granted" : "Denied"
            }
        }
        
        // Contacts
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    contactStatus = granted ? "Granted" : "Denied"
                    contactPermission = contactStatus
                }
            }
        
        motionPermission = motionStatus
        bluetoothPermission = bluetoothStatus
        notificationPermission = notificationStatus


    }


    func authenticateUser() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Access Profile Features") { success, error in
                DispatchQueue.main.async {
                    biometricAuthStatus = success ? "Success" : (error?.localizedDescription ?? "Failed")
                }
            }
        } else {
            biometricAuthStatus = "Biometric auth not available"
        }
    }
}

struct BiometricAuthSection: View {
    @AppStorage("biometricAuthStatus") private var biometricAuthStatus: String = "Not Authenticated"

    var body: some View {
        SectionView(title: "Biometric Authentication") {
            Button("Authenticate with Face ID / Touch ID") {
                authenticateUser()
            }
            .buttonStyle(.borderedProminent)

            Text("Status: \(biometricAuthStatus)")
                .font(.subheadline)
                .foregroundColor(biometricAuthStatus.contains("Success") ? .green : .red)
        }
    }

    func authenticateUser() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to access your profile features."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    biometricAuthStatus = success ? "Success" : (error?.localizedDescription ?? "Failed")
                }
            }
        } else {
            biometricAuthStatus = "Biometric auth not available"
        }
    }
}

struct LabeledRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct DeviceInfoSection: View {
    let device = UIDevice.current

    var body: some View {
        SectionView(title: "Device Info") {
            LabeledRow(label: "Name", value: device.name)
            LabeledRow(label: "Model", value: device.model)
            LabeledRow(label: "System", value: device.systemName)
            LabeledRow(label: "Version", value: device.systemVersion)
            LabeledRow(label: "UUID", value: device.identifierForVendor?.uuidString ?? "Unavailable")
        }
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
            content
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct PermissionsCenterSection: View {
    @State private var contactStatus: String = "Unknown"
    @State private var cameraStatus: String = "Unknown"
    @State private var photoStatus: String = "Unknown"
    @State private var micStatus: String = "Unknown"
    @State private var locationStatus: String = "Unknown"
    @State private var motionStatus: String = "Unknown"
    @State private var notificationStatus: String = "Unknown"

    let locationManager = CLLocationManager()
    let motionManager = CMMotionActivityManager()

    var body: some View {
        SectionView(title: "Permissions Center") {
            PermissionRow(name: "Contacts", status: contactStatus) {
                CNContactStore().requestAccess(for: .contacts) { _, _ in updateStatuses() }
            }
            PermissionRow(name: "Camera", status: cameraStatus) {
                AVCaptureDevice.requestAccess(for: .video) { _ in updateStatuses() }
            }
            PermissionRow(name: "Photos", status: photoStatus) {
                PHPhotoLibrary.requestAuthorization { _ in updateStatuses() }
            }
            PermissionRow(name: "Microphone", status: micStatus) {
                AVAudioSession.sharedInstance().requestRecordPermission { _ in updateStatuses() }
            }
            PermissionRow(name: "Location", status: locationStatus) {
                locationManager.requestWhenInUseAuthorization()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    updateStatuses()
                }
            }
            PermissionRow(name: "Motion", status: motionStatus) {
                motionManager.queryActivityStarting(from: Date(), to: Date(), to: .main) { _, _ in updateStatuses() }
            }
            PermissionRow(name: "Notifications", status: notificationStatus) {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in updateStatuses() }
            }
        }
        .onAppear(perform: updateStatuses)
    }

    func updateStatuses() {
        contactStatus = CNContactStore.authorizationStatus(for: .contacts).description
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video).description
        photoStatus = PHPhotoLibrary.authorizationStatus().description
        micStatus = AVAudioSession.sharedInstance().recordPermission.description
        locationStatus = locationManager.authorizationStatus.description
        motionStatus = CMMotionActivityManager.authorizationStatus() == .authorized ? "Authorized" : "Not Authorized"
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus.description
            }
        }
    }
}

struct PermissionsCenterView: View {
    @State private var contactStatus: String = "Unknown"
    @State private var cameraStatus: String = "Unknown"
    @State private var photoStatus: String = "Unknown"
    @State private var micStatus: String = "Unknown"
    @State private var locationStatus: String = "Unknown"
    @State private var motionStatus: String = "Unknown"
    @State private var notificationStatus: String = "Unknown"

    let locationManager = CLLocationManager()
    let motionManager = CMMotionActivityManager()

    var body: some View {
        NavigationView {
            List {
                PermissionRow(name: "Contacts", status: contactStatus) {
                    requestContactsPermission()
                }

                PermissionRow(name: "Camera", status: cameraStatus) {
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        updateStatuses()
                    }
                }

                PermissionRow(name: "Photos", status: photoStatus) {
                    PHPhotoLibrary.requestAuthorization { _ in
                        updateStatuses()
                    }
                }

                PermissionRow(name: "Microphone", status: micStatus) {
                    AVAudioSession.sharedInstance().requestRecordPermission { _ in
                        updateStatuses()
                    }
                }

                PermissionRow(name: "Location", status: locationStatus) {
                    locationManager.requestWhenInUseAuthorization()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        updateStatuses()
                    }
                }

                PermissionRow(name: "Motion", status: motionStatus) {
                    motionManager.queryActivityStarting(from: Date(), to: Date(), to: .main) { _, _ in
                        updateStatuses()
                    }
                }

                PermissionRow(name: "Notifications", status: notificationStatus) {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                        updateStatuses()
                    }
                }
            }
            .navigationTitle("Permissions Center")
            .onAppear(perform: updateStatuses)
        }
    }

    func requestContactsPermission() {
        CNContactStore().requestAccess(for: .contacts) { granted, _ in
            updateStatuses()
        }
    }

    func updateStatuses() {
        let contactAuth = CNContactStore.authorizationStatus(for: .contacts)
        contactStatus = contactAuth.description

        let cameraAuth = AVCaptureDevice.authorizationStatus(for: .video)
        cameraStatus = cameraAuth.description

        let photoAuth = PHPhotoLibrary.authorizationStatus()
        photoStatus = photoAuth.description

        let micAuth = AVAudioSession.sharedInstance().recordPermission
        micStatus = micAuth.description

        let locAuth = locationManager.authorizationStatus.description
        locationStatus = locAuth.description

        CMMotionActivityManager.authorizationStatus() == .authorized
            ? (motionStatus = "Authorized")
            : (motionStatus = "Not Authorized")

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus.description
            }
        }
    }
}

struct PermissionRow: View {
    var name: String
    var status: String
    var action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text("Status: \(status)").font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            Button("Request") {
                action()
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Extensions for Descriptions

extension CNAuthorizationStatus {
    var description: String {
        switch self {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }
}

extension AVAudioSession.RecordPermission {
    var description: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .undetermined: return "Undetermined"
        @unknown default: return "Unknown"
        }
    }
}

extension AVAuthorizationStatus {
    var description: String {
        switch self {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }
}

extension PHAuthorizationStatus {
    var description: String {
        switch self {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .limited: return "Limited"
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }
}

extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .ephemeral: return "Ephemeral"
        case .notDetermined: return "Not Determined"
        case .provisional: return "Provisional"
        @unknown default: return "Unknown"
        }
    }
}

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }
}

//struct AppSettings:Codable {
//    var appName: String = ""
//    var bundleID: String = ""
//    var version: String = "1.0.0"
//    var themeColorHex: String = "#007AFF"  // Default iOS blue
//    var backendURL: String = ""
//    var features: [String: Bool] = [
//        "Comments": true,
//        "E-Commerce": false,
//        "User Profiles": true
//    ]
//    var gitRepoURL: String = ""
//    var buildTarget: String = "iOS"
//    var appleTeamID: String = ""
//    var googleProjectID: String = ""
//}

struct User:Codable{
    var email = ""
    var profile: Profile?
    var password = ""
    var associations: [Association] = []
    var device = Device()
    
}

struct Device:Codable,Hashable{
    var name = ""
    var model = ""
    var localizedModel = ""
    var systemName = ""
    var systemVersion = ""
    var uuid = UIDevice.current.identifierForVendor?.uuidString
}

struct ForumData: Codable {
    let topics: [String]
}

struct StoreView: View {
    var data: [String: Any]
    
    var body: some View {
        VStack {
            Text("🛒 Store View")
                .font(.title)
            if let products = data["products"] as? [String] {
                ForEach(products, id: \.self) { product in
                    Text("• \(product)")
                }
            } else {
                Text("No products listed.")
            }
        }
        .padding()
    }
}

struct Profile: Codable, Identifiable {
    var id: Int
    var name: String
    var avatarURL: String?
    var bio: String?
}

struct ProfileView: View {
    var data: [String: Any]

    var body: some View {
        VStack {
            Text("👤 Profile View")
            if let name = data["username"] as? String {
                Text("Welcome, \(name)")
            }
        }
    }
}

struct ForumView: View {
    var data: [String: Any]

    var body: some View {
        VStack {
            Text("🗣 Forum View")
            if let topics = data["topics"] as? [String] {
                ForEach(topics, id: \.self) {
                    Text("• \($0)")
                }
            }
        }
    }
}

struct RefreshableScrollView<Content: View>: View {
    let content: () -> Content
    let onRefresh: () -> Void

    var body: some View {
        ScrollViewWrapper(content: content, onRefresh: onRefresh)
    }

    struct ScrollViewWrapper<Content: View>: UIViewRepresentable {
        let content: () -> Content
        let onRefresh: () -> Void

        func makeCoordinator() -> Coordinator {
            Coordinator(onRefresh: onRefresh)
        }

        func makeUIView(context: Context) -> UIScrollView {
            let scrollView = UIScrollView()
            scrollView.backgroundColor = UIColor.black

            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh), for: .valueChanged)
            scrollView.refreshControl = refreshControl

            let hostingController = UIHostingController(rootView: content())
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false

            scrollView.addSubview(hostingController.view)

            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                hostingController.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])

            context.coordinator.hostingController = hostingController
            context.coordinator.scrollView = scrollView

            return scrollView
        }

        func updateUIView(_ uiView: UIScrollView, context: Context) {
            context.coordinator.hostingController?.rootView = content()

        }

        class Coordinator: NSObject {
            var onRefresh: () -> Void
            var hostingController: UIHostingController<Content>?
            weak var scrollView: UIScrollView!

            init(onRefresh: @escaping () -> Void) {
                self.onRefresh = onRefresh
            }

            @objc func handleRefresh() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.scrollView.refreshControl?.endRefreshing()
                    self.onRefresh()
                }
            }
        }
    }
}

struct ContentCard:Hashable{
    var title = "This is the title"
    var subTitle = "This is the subtitle"
    let cardWidth = UIScreen.main.bounds.width * 0.85
    let cardHeight = (UIScreen.main.bounds.width * 0.85) * 9 / 16

}

struct SocialView: View {
    @State private var itemsArray: [CarouselItem] = [
        .init(title: "Halo", subTitle: "Halo is a game I played on Xbox", imageName: "https://platform.polygon.com/wp-content/uploads/sites/2/chorus/uploads/chorus_asset/file/25543078/TDW_14349_R.jpg?quality=90&strip=all&crop=0%2C0%2C100%2C100&w=2400"),
        .init(title: "Star Trek", subTitle: "I actually love Lower Decks", imageName: "https://platform.polygon.com/wp-content/uploads/sites/2/chorus/uploads/chorus_asset/file/25543078/TDW_14349_R.jpg?quality=90&strip=all&crop=0%2C0%2C100%2C100&w=2400"),
        .init(title: "SpongeBob", subTitle: "Sophia loved this not me", imageName: "https://platform.polygon.com/wp-content/uploads/sites/2/chorus/uploads/chorus_asset/file/25543078/TDW_14349_R.jpg?quality=90&strip=all&crop=0%2C0%2C100%2C100&w=2400"),
        .init(title: "Survivor", subTitle: "The show or the song by DC?", imageName: "https://platform.polygon.com/wp-content/uploads/sites/2/chorus/uploads/chorus_asset/file/25543078/TDW_14349_R.jpg?quality=90&strip=all&crop=0%2C0%2C100%2C100&w=2400")
    ]
    @State private var topNavCatArray = ["Title1", "Title2", "Title3", "Title4", "Title5"]
    @EnvironmentObject var gk: GateKeeper
    @State private var currentIndex = 0
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    @StateObject private var viewModel = CarouselViewModel()

    var body: some View {
        ZStack{
            Color(hex: "#343434").ignoresSafeArea()
            RefreshableScrollView(content: {
                VStack(alignment: .leading) {
                    Spacer().frame(height: 20)
                    gk.loadImage(imageUrl: "https://platform.polygon.com/wp-content/uploads/sites/2/chorus/uploads/chorus_asset/file/25543078/TDW_14349_R.jpg?quality=90&strip=all&crop=0%2C0%2C100%2C100&w=2400",isProfile: true).padding(.leading,10)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(topNavCatArray, id: \.self) { catItem in
                                VStack{
                                    Text(catItem)
                                        .padding()
                                        .foregroundColor(.white)
                                        .padding(.bottom,-20)
                                    Rectangle().frame(width: 30, height: 1).foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.leading, 10)
                        
                    }
                    
                    Spacer().frame(height:20)
                    
                    carouselView()
                    
                    Group{
                        Spacer().frame(height:20)
                        HStack{
                            Spacer()
                            Text("Discover")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding(.leading,10)
                            Spacer()
                        }
                        
                    }
                    
                        ScrollView(.horizontal){
                            HStack(spacing:20){
                                Spacer().frame(width:10)
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2)) // fallback if image fails
                                    .frame(width: 95, height: 150)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2)) // fallback if image fails
                                    .frame(width: 95, height: 150)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2)) // fallback if image fails
                                    .frame(width: 95, height: 150)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            
                        }
                    
                }.background(Color(hex: "#343434"))
            }, onRefresh: {
                print("Pulled to refresh!")
                topNavCatArray.append("Title\(topNavCatArray.count + 1)")
            })
        }
        
    }
    
    func carouselView() -> some View{
        return CarouselView(items: itemsArray, viewModel: viewModel)
    }
}

struct HomeView: View {
    @EnvironmentObject var gatekeeper: GateKeeper

    var body: some View {
        SmartNavigation {
            List {
                ForEach(gatekeeper.user.associations) { assoc in
                    NavigationLink(destination: gatekeeper.route(for: assoc)) {
                        Text(assoc.label)
                    }
                }

                if gatekeeper.featureEnabled("E-Commerce") {
                    NavigationLink("Shop", destination: StorefrontView())
                }
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct SmartNavigation<Content: View>: View {
    let content: () -> Content

    var body: some View {
        #if swift(>=5.7) // iOS 16 / Xcode 14+ compatible
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
        }
        #else
        NavigationView {
            content()
        }
        #endif
    }
}

struct StorefrontView: View {
    var body: some View {
        Text("Welcome to the store...now give me money bitches!!!")
    }
}

enum ViewModes {
    case dashboard
    case forum
    case profile
    case store
}

protocol Associations: Identifiable, Codable {
    var id: String { get }
    var type: String { get }
    var label: String { get }  // optional: for use in List display
}

enum AssociationType: String, Codable {
    case forum
    case store
    case profile
    case unknown
}

struct Association: Codable,Identifiable {
    var id: String               // e.g. "forum", "profile", etc.
    var type: AssociationType    // could be used for matching views
    var label: String            // "Forums", "Profile", etc
    var data: [String: AnyCodable]  // payload for the destination view
}

struct AssociationPayload: Decodable {
    let id: String
    let type: AssociationType
    let label: String
    let data: [String: AnyCodable]
    
    func toAssociation() -> Association {
        Association(id: id, type: type, label: label, data: data)
    }
}

//Association helper:
extension Association {
    var dataAsDict: [String: Any] {
        data.mapValues { $0.value }
    }
}

//AnyCodable HELPER:
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let stringVal as String:
            try container.encode(stringVal)
        case let arrayVal as [Any]:
            try container.encode(arrayVal.map { AnyCodable($0) })
        case let dictVal as [String: Any]:
            try container.encode(dictVal.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
}


