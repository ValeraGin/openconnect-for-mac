import Foundation

enum AuthStage: String {
    case sso, password, code, expired, success, credentialPassword, credentialCode
    var isCredential: Bool { self == .credentialPassword || self == .credentialCode }
}

extension DemoModel {
    static func singleLine(_ value: String) -> String {
        value.components(separatedBy: .newlines).joined(separator: "")
    }
    var authProfile: DemoProfile? { profiles.first { $0.id == authTargetID } }
    func beginSignIn() {
        guard let id = selectedID, !dirty, valid else { showValidation = true; return }
        authTargetID = id
        authStage = draft?.browserLogin == true ? .sso : .password
        authUsername = draft?.user ?? ""
        authPassword = ""; authCode = ""; authError = false
        linkTarget = id; link = .signIn
        authPresented = true
    }
    func openCredential(_ stage: AuthStage) {
        guard stage.isCredential, draft != nil else { return }
        authTargetID = selectedID; authStage = stage
        authPassword = ""; authCode = ""; authError = false
        authPresented = true
    }
    func continueSSO() {
        guard authStage == .sso else { return }
        authStage = .password; authError = false
    }
    func submitPassword() {
        guard authStage == .password else { return }
        guard !authUsername.trimmingCharacters(in: .whitespaces).isEmpty, authPassword == "demo" else {
            authError = true; return
        }
        authPassword = ""; authError = false; authStage = .code
    }
    func submitCode() {
        guard authStage == .code else { return }
        guard authCode == "123456", let id = authTargetID, profiles.contains(where: { $0.id == id }) else {
            authError = true; return
        }
        activeID = id; linkTarget = id; link = .connected
        authPassword = ""; authCode = ""; authError = false; authStage = .success
    }
    func restartCode() { authCode = ""; authError = false; authStage = .code }
    func cancelSignIn() {
        if !authStage.isCredential && authStage != .success && linkTarget == authTargetID { link = .idle }
        authPresented = false
        authPassword = ""; authCode = ""; authError = false
    }
    func saveCredential() {
        guard draft?.id == authTargetID else { cancelSignIn(); return }
        if authStage == .credentialPassword {
            guard authPassword == "demo" else { authError = true; return }
            draft?.passwordSaved = true
        } else if authStage == .credentialCode {
            guard authCode == "123456" else { authError = true; return }
            draft?.codeSaved = true
        } else { return }
        cancelSignIn()
    }
    func clearCredential() {
        guard draft?.id == authTargetID else { cancelSignIn(); return }
        if authStage == .credentialPassword { draft?.passwordSaved = false }
        if authStage == .credentialCode { draft?.codeSaved = false }
        cancelSignIn()
    }
    func loadAuthFixture(_ scenario: Scenario) {
        guard scenario.rawValue.hasPrefix("signIn") || scenario.rawValue.hasPrefix("credential") else { return }
        authTargetID = selectedID; authUsername = "alex"; authError = false
        authPassword = ""; authCode = ""
        switch scenario {
        case .signInSSO: authStage = .sso
        case .signInPassword: authStage = .password
        case .signInCode: authStage = .code
        case .signInRejected: authStage = .password; authPassword = "wrong"; authError = true
        case .signInExpired: authStage = .expired
        case .signInSuccess: authStage = .success; activeID = selectedID
        case .credentialPassword: authStage = .credentialPassword
        case .credentialCode: authStage = .credentialCode
        default: break
        }
        if !authStage.isCredential { link = authStage == .success ? .connected : .signIn }
        page = .login; authPresented = true
    }
}
