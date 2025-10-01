import AuthenticationServices
import CryptoKit
import OSLog
import SwiftUI

typealias OnSignInWithApple = (_ token: String, _ nonce: String) async throws -> Void

struct SignInWithAppleButtonView: View {
    private let logger = Logger(label: "SignInWithAppleView")
    @State private var nonce: String?

    let onSignIn: OnSignInWithApple

    var body: some View {
        SignInWithAppleButton(.continue, onRequest: { request in
            let nonce = randomString()
            self.nonce = nonce
            request.nonce = sha256(nonce)
            request.requestedScopes = []
        }, onCompletion: { result in Task {
            await handleAuthorizationResult(result)
        }})
    }

    private func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) async {
        if case let .success(asAuthorization) = result {
            guard let credential = asAuthorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken else { return }
            let token = String(decoding: tokenData, as: UTF8.self)
            guard let nonce else { return }
            do {
                try await onSignIn(token, nonce)
            } catch {
                logger.error("Error occured when trying to sign in with Apple. Localized: \(error.localizedDescription). Error: \(error) (\(#file):\(#line))")
            }
        }
    }

    private func randomString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        return String((0 ..< length).compactMap { _ in
            charset.randomElement()
        })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
