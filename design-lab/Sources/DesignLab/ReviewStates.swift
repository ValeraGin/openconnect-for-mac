import Foundation

/// Additional reachable UI states for passive review. Never invokes system UI.
extension DemoModel {
    func applyReviewVariant(_ variant: String) {
        switch variant {
        case "long-password":
            beginSignIn(); authStage = .password; authPassword = "wrong"; submitPassword()
        case "long-success":
            beginSignIn(); authStage = .success; activeID = selectedID
        case "secret-error": authSecret = "wrong"; saveCredential()
        case "code-error": authCode = "000000"; submitCode()
        case "profile-step": setupStep = 0
        case "system-step": setupStep = 1; setupNeedsSystemStep = true
        case "system-ready": setupStep = 1; setupNeedsSystemStep = true; helperReady = true
        case "invalid-profile": draft?.server = "http://invalid.example.com"; advanceSetup()
        case "proxy-setup": draft?.route = .proxy; advanceSetup()
        case "signin-step": setupStep = 2; setupResource = "https://intranet.example.com"
        case "access-ok": setupStep = 2; setupResource = "https://intranet.example.com"; accessChecked = true
        case "second-step": learningStep = 1; learningSelections = ["username", "password"]
        case "mapped": learningSelections = ["username", "password", "totp"]; finishLearning()
        case "runtime-edited": draft?.zones = []; draft?.route = .proxy
        case "full-tunnel": draft?.route = .all
        case "empty-dns": draft?.zones = []
        case "text": qrSource = "text"; qrDetected = false
        case "developer": developer = true
        case "preview": notice = t("Пример: Нужен вход — сессия истекла, войдите снова.", "Preview: Sign-in required — your session expired. Sign in again.")
        case "other-profile": select("home")
        default: break
        }
    }
}
