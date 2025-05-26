//
//  DataLayer.swift
//  NGDigital
//
//  Created by Marlon on 5/26/25.
//

import Foundation
import os
import SwiftUI

extension GateKeeper {
    func loadThatJSON<T: Decodable>(from endpoint: String, as type: T.Type) async -> Result<T, Error> {
        let maxRetries = 3
        let baseURL = user.appSettings.backendURL
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return .failure(URLError(.badURL))
        }

        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                let decoded = try JSONDecoder().decode(T.self, from: data)
                return .success(decoded)

            } catch {
                os_log("Attempt %d failed for endpoint '%@': %@", type: .error, attempt, endpoint, error.localizedDescription)
                // Optional: backoff delay
                try? await Task.sleep(nanoseconds: UInt64(500_000_000)) // 0.5s
                if attempt == maxRetries {
                    return .failure(error)
                }
            }
        }

        return .failure(URLError(.unknown))
    }
    
    func featureEnabled(_ key: String) -> Bool {
            user.appSettings.features[key] ?? false
        }
}

extension View {
    func fetchOnAppear<T: Decodable>(
        from endpoint: String,
        as type: T.Type,
        into binding: Binding<T?>,
        using gatekeeper: GateKeeper
    ) -> some View {
        self.onAppear {
            Task {
                let result = await gatekeeper.loadThatJSON(from: endpoint, as: type)
                switch result {
                case .success(let decoded):
                    binding.wrappedValue = decoded
                case .failure(let error):
                    print("❌ Failed to fetch \(endpoint): \(error.localizedDescription)")
                }
            }
        }
    }
    
    @ViewBuilder
        func withPullToRefresh(_ action: @escaping () async -> Void) -> some View {
            if #available(iOS 15.0, *) {
                self.refreshable {
                    await action()
                }
            } else {
                self // For iOS versions <15, just return the view as-is.
            }
        }
}

protocol CarouselCardViewProtocol: Identifiable {
    var id: UUID { get }
    var title: String { get }
    var subTitle: String { get }
    var imageName: String { get } // local or remote
}

struct CarouselItem: CarouselCardViewProtocol {
    let id = UUID()
    let title: String
    let subTitle: String
    let imageName: String
}

struct CarouselCardView<Item: CarouselCardViewProtocol>: View {
    let item: Item
    @EnvironmentObject var gk:GateKeeper
    var body: some View {
        ZStack(alignment: .bottomLeading) {
//            Image(item.imageName)
//                .resizable()
//                .scaledToFill()
//                .clipped()
//            gk.loadImage(imageUrl: item.imageName)
            
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.7), .clear]),
                startPoint: .bottom,
                endPoint: .center
            )
            
            VStack(spacing:10){
                gk.loadImage(imageUrl: item.imageName,imageWidth: 300,imageHeight: 300)
                Spacer().frame(height: 20)
                Text(item.title)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .padding()
                
                Text(item.subTitle)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil) // Or just omit this entirely
                    .fixedSize(horizontal: false, vertical: true)
                    .padding([.horizontal, .bottom])
            }
            .padding(.bottom,25)
            
        }
        .cornerRadius(20)
        .shadow(radius: 6)
    }
}

class CarouselViewModel: ObservableObject {
    @Published var currentIndex = 0
    @Published var isUserInteracting = false
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
}

struct CarouselView<Item: CarouselCardViewProtocol>: View {
    let items: [Item]
    @ObservedObject var viewModel: CarouselViewModel
    
    private let cardWidth = UIScreen.main.bounds.width * 0.9
    private let cardHeight: CGFloat = 420
    
    var body: some View {
        ZStack{
            
            TabView(selection: $viewModel.currentIndex) {
                ForEach(items.indices, id: \.self) { index in
                    CarouselCardView(item: items[index])
                        .frame(width: cardWidth, height: cardHeight)
                        .padding(.vertical)
                        .tag(index)
                        .gesture(
                            DragGesture()
                                .onChanged { _ in viewModel.isUserInteracting = true }
                                .onEnded { _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        viewModel.isUserInteracting = false
                                    }
                                }
                        )
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: cardHeight + 50)
            .onReceive(viewModel.timer) { _ in
                guard !viewModel.isUserInteracting else { return }
                withAnimation {
                    viewModel.currentIndex = (viewModel.currentIndex + 1) % items.count
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        
        self.init(red: r, green: g, blue: b)
    }
}

struct ParamountPlusTabBarView: View {
    @Binding var selectedTab: Int
    let profileImageURL: String

    var body: some View {
        Spacer().frame(height:20)
        HStack(spacing: 50) {
            tabBarItem(icon: "house.fill", label: "Home", tab: 0)
            tabBarItem(icon: "plus.square.fill", label: "Create", tab: 1)
            tabBarItem(icon: "tray.full.fill", label: "Inbox", tab: 2)
            tabBarProfileItem(imageURL: profileImageURL, label: "Me", tab: 3)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }

    private func tabBarItem(icon: String, label: String, tab: Int) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(selectedTab == tab ? .black : .white)
                Text(label)
                    .font(.caption)
                    .foregroundColor(selectedTab == tab ? .black : .white)
            }
        }
    }

    private func tabBarProfileItem(imageURL: String, label: String, tab: Int) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(selectedTab == tab ? Color.red : Color.white, lineWidth: 2))
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 32, height: 32)
                    }
                }
                Text(label)
                    .font(.caption)
                    .foregroundColor(selectedTab == tab ? .black : .white)
            }
        }
    }
}

// Example Usage
struct TabBarContainerView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    Color.blue.ignoresSafeArea()
                case 1:
                    Color.purple.ignoresSafeArea()
                default:
                    Color.black.ignoresSafeArea()
                }
            }

            ParamountPlusTabBarView(
                selectedTab: $selectedTab,
                profileImageURL: "https://yourdomain.com/path-to-profile-pic.jpg"
            )
        }
    }
}






