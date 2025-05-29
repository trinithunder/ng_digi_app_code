//
//  RegisterView.swift
//  NGDigital
//
//  Created by Marlon on 5/27/25.
//

import SwiftUI

struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    //@State private var fullName = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Register")
                .font(.largeTitle)
                .bold()

//            TextField("Full Name", text: $fullName)
//                .textFieldStyle(.roundedBorder)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            SecureField("Confirm Password", text: $passwordConfirmation)
                .textFieldStyle(.roundedBorder)

            if isLoading {
                ProgressView()
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            Button("Create Account") {
                registerUser()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    func registerUser() {
        guard !email.isEmpty, !password.isEmpty, password == passwordConfirmation else {
            errorMessage = "Please fill all fields correctly"
            return
        }

        isLoading = true
        errorMessage = ""

        let url = URL(string: "https://lightek.diy/register")! // Adjust to match your backend
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = [
            "user":
            [
                "email": email,
            "password": password,
            "password_confirmation": passwordConfirmation
            ]
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
                    // Registration successful
                    errorMessage = ""
                    // TODO: Navigate to next screen
                } else {
                    errorMessage = "Failed to register (status: \(httpResponse.statusCode))"
                }
            }
        }.resume()
    }
}

