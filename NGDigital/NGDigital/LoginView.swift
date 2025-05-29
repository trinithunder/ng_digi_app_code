//
//  LoginView.swift
//  NGDigital
//
//  Created by Marlon on 5/27/25.
//

import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @AppStorage("useBiometrics") var useBiometrics = false
    @AppStorage("authToken") var authToken = ""

    var body: some View {
        SmartNavigation {
            VStack(spacing: 16) {
                Text("Login")
                    .font(.largeTitle).bold()

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red)
                }

                Button("Sign In") {
                    login()
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty)

                if useBiometrics {
                    Button("Login with Face ID / Touch ID") {
                        authenticateWithBiometrics()
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                // ✅ New Navigation to Registration
                NavigationLink("Create an Account", destination: RegisterView())
                    .font(.footnote)
            }
            .padding()
            .onAppear {
                if useBiometrics && authToken.isEmpty {
                    authenticateWithBiometrics()
                }
            }
        }
    }

    // ... existing login() and authenticateWithBiometrics() functions ...
    func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Sign in with Face ID / Touch ID"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        // You can set a flag here or retrieve a token if needed
                        print("Biometric authentication succeeded.")
                        // Example: Automatically call login or set authToken if cached
                    } else {
                        print("Biometric authentication failed: \(authError?.localizedDescription ?? "Unknown error")")
                        errorMessage = "Biometric authentication failed: \(authError?.localizedDescription ?? "Unknown error")"
                    }
                }
            }
        } else {
            print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    func login(){
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill all fields correctly"
            return
        }

        isLoading = true
        errorMessage = ""

        let url = URL(string: "https://lightek.diy/login")! // Adjust to match your backend
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = [
                "email": email,
            "password": password
            
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "Invalid server response"
                    return
                }

                if (200...299).contains(httpResponse.statusCode) {
                    // Login successful
                    errorMessage = ""
                    // TODO: Navigate to next screen
                } else {
                    errorMessage = "Failed authorization (status: \(httpResponse.statusCode))"
                }
            }
        }.resume()
    }
    }


