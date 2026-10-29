import Foundation

enum AuthStage: String {
    case sso, password, code, expired, success, credentialPassword, credentialCode, rememberCode
    var isCredential: Bool { self == .credentialPassword || self == .credentialCode }
}

extension DemoModel {
    static let sampleSecret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    static let sampleTime = Date(timeIntervalSince1970: 59)
    static var sampleCode: String { TOTP.code(secretBase32: sampleSecret, at: sampleTime)! }
    var smsSignIn: Bool { authProfile?.browserLogin == false }
    var canOfferTOTP: Bool { !smsSignIn && authProfile?.codeSaved == false }
    func secretMatchesRecordedCode() -> Bool {
        let raw = authSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = recordedCode.isEmpty ? Self.sampleCode : recordedCode
        func matches(_ secret: String, _ params: TOTPParams) -> Bool {
            guard params.isSupported, params.digits == code.count else { return false }
            return (-1...1).contains { offset in
                TOTP.code(secretBase32: secret, at: Self.sampleTime.addingTimeInterval(Double(offset * params.period)), params: params) == code
            }
        }
        if raw.lowercased().hasPrefix("otpauth") {
            return ((try? QRImport.parse(raw)) ?? []).contains { $0.isTOTP && matches($0.secretBase32, $0.params) }
        }
        return TOTPParams.algorithms.contains { algorithm in
            [30, 60].contains { period in matches(raw, TOTPParams(algorithm: algorithm, digits: code.count, period: period)) }
        }
    }
    func configureTOTPAfterSignIn() {
        guard canOfferTOTP else { return }
        totpAfterLogin = true; authSecret = ""; authError = false; authStage = .credentialCode
    }
    func skipTOTP() { authStage = .success; totpAfterLogin = false; authSecret = ""; authError = false }
    private func updateCredential(password: Bool, saved: Bool) {
        guard let id = authTargetID, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        if password { profiles[index].passwordSaved = saved } else { profiles[index].codeSaved = saved }
        if draft?.id == id {
            if password { draft?.passwordSaved = saved } else { draft?.codeSaved = saved }
        }
    }
    static func singleLine(_ value: String) -> String {
        value.components(separatedBy: .newlines).joined(separator: "")
    }
    static func singleCode(_ value: String) -> String {
        String(value.filter { "0123456789".contains($0) }.prefix(6))
    }
    var authProfile: DemoProfile? { profiles.first { $0.id == authTargetID } }
    func beginSignIn() {
        guard let id = selectedID, !dirty, valid else { showValidation = true; return }
        authTargetID = id
        recordedCode = ""
        authStage = draft?.browserLogin == true ? .sso : .password
        authUsername = draft?.user ?? ""
        authPassword = ""; authCode = ""; authSecret = ""; authError = false; totpAfterLogin = false
        linkTarget = id; link = .signIn
        authPresented = true
    }
    func openCredential(_ stage: AuthStage) {
        guard stage.isCredential, draft != nil, !dirty, valid else { return }
        authTargetID = selectedID; authStage = stage
        recordedCode = ""
        authPassword = ""; authCode = ""; authSecret = ""; authError = false; totpAfterLogin = false
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
        guard authCode == Self.sampleCode, let id = authTargetID, profiles.contains(where: { $0.id == id }) else {
            authError = true; return
        }
        activeID = id; linkTarget = id; link = .connected
        recordedCode = authCode
        authPassword = ""; authCode = ""; authSecret = ""; authError = false; totpAfterLogin = false
        authStage = canOfferTOTP ? .rememberCode : .success
    }
    func restartCode() { authCode = ""; authError = false; authStage = .code }
    func cancelSignIn() {
        if link == .signIn && linkTarget == authTargetID { link = .idle }
        authPresented = false
        authPassword = ""; authCode = ""; authSecret = ""; authError = false; totpAfterLogin = false
    }
    func saveCredential() {
        guard draft?.id == authTargetID else { cancelSignIn(); return }
        if authStage == .credentialPassword {
            guard authPassword == "demo" else { authError = true; return }
            updateCredential(password: true, saved: true)
        } else if authStage == .credentialCode {
            guard secretMatchesRecordedCode() else { authError = true; return }
            updateCredential(password: false, saved: true)
            if totpAfterLogin { skipTOTP(); return }
        } else { return }
        cancelSignIn()
    }
    func clearCredential() {
        guard draft?.id == authTargetID else { cancelSignIn(); return }
        if authStage == .credentialPassword { updateCredential(password: true, saved: false) }
        if authStage == .credentialCode { updateCredential(password: false, saved: false) }
        cancelSignIn()
    }
    func loadAuthFixture(_ scenario: Scenario) {
        guard scenario.rawValue.hasPrefix("signIn") || scenario.rawValue.hasPrefix("credential") || [.totpOffer, .totpSetup, .smsCode].contains(scenario) else { return }
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
        case .smsCode: authStage = .code
        case .totpOffer: authStage = .rememberCode; activeID = selectedID; recordedCode = Self.sampleCode
        case .totpSetup: authStage = .credentialCode; activeID = selectedID; recordedCode = Self.sampleCode; totpAfterLogin = true
        default: break
        }
        if !authStage.isCredential { link = [.success, .rememberCode].contains(authStage) ? .connected : .signIn }
        page = .login; authPresented = true
    }
}
