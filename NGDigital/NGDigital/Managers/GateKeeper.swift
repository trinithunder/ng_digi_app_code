//
//  GateKeeper.swift
//  NGDigital
//
//  Created by Marlon on 5/26/25.
//

import Foundation
import SwiftUI
import UIKit

class GateKeeper: ObservableObject {
    @Published var user = User()
    @Published var currentViewMode:ViewModes = .dashboard
    @Published var previousViewMode:ViewModes = .profile
    @Published var nextViewMode:ViewModes = .store
    
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

struct User:Codable{
    var email = ""
    var profile: Profile?
    var password = ""
    var appSettings = AppSettings()
    var associations: [Association] = []
    
}

struct AppSettings:Codable {
    var appName: String = ""
    var bundleID: String = ""
    var version: String = "1.0.0"
    var themeColorHex: String = "#007AFF"  // Default iOS blue
    var backendURL: String = ""
    var features: [String: Bool] = [
        "Comments": true,
        "E-Commerce": false,
        "User Profiles": true
    ]
    var gitRepoURL: String = ""
    var buildTarget: String = "iOS"
    var appleTeamID: String = ""
    var googleProjectID: String = ""
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


