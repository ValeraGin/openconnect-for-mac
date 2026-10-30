import SwiftUI

struct SignInView: View {
    @ObservedObject var model: DemoModel
    private func t(_ ru: String, _ en: String) -> String { model.t(ru, en) }
    private var profileName: String { model.authProfile.map(model.profileTitle) ?? t("Профиль", "Profile") }
    private var color: Color {
        if model.authStage == .success { return LabColor.success }
        if model.authStage == .expired { return LabColor.warning }
        return LabColor.accent
    }
    private var title: String {
        switch model.authStage {
        case .sso, .password: return t("Вход в «\(profileName)»", "Sign in to \(profileName)")
        case .code: return model.smsSignIn ? t("Код из SMS", "SMS code") : t("Подтвердите вход", "Verify your sign-in")
        case .expired: return t("Время кода истекло", "Your code has expired")
        case .success: return t("Вы подключены", "You’re connected")
        case .credentialPassword: return t("Пароль профиля", "Profile password")
        case .credentialCode: return t("Настроить TOTP", "Set up TOTP")
        case .rememberCode: return t("Вводить код автоматически?", "Fill codes automatically?")
        }
    }
    private var icon: String {
        switch model.authStage {
        case .sso: return "globe"
        case .password, .credentialPassword: return "lock-keyhole"
        case .code, .credentialCode, .rememberCode: return "key-round"
        case .expired: return "circle-alert"
        case .success: return "circle-check"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                BrandMark(size: 24)
                Text("OpenConnect for Mac").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("DEMO").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LabColor.accent).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(LabColor.accent.opacity(0.1), in: Capsule())
            }.padding(.bottom, 28)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
            Lucide(name: icon, size: 28).foregroundStyle(color)
                .frame(width: 54, height: 54).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 16)
            Text(title).font(.system(size: 22, weight: .semibold)).lineLimit(2).help(title).padding(.bottom, 6)
            Text(model.authProfile.flatMap { URL(string: $0.server)?.host } ?? "vpn.example.com")
                .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                .help(model.authProfile?.server ?? "").padding(.bottom, 22)
            content
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
            }
            .padding(.bottom, 12)
            if !model.authStage.isCredential && ![.success, .rememberCode].contains(model.authStage) {
                HStack(spacing: 6) {
                    step(t("Вход", "Sign-in"), done: model.authStage == .code || model.authStage == .expired)
                    Lucide(name: "arrow-right", size: 12).foregroundStyle(.tertiary)
                    Text(t("Подтверждение", "Verification"))
                        .foregroundStyle(model.authStage == .code || model.authStage == .expired ? LabColor.accent : .secondary)
                }.font(.system(size: 11)).padding(.bottom, 12)
            }
            Divider().padding(.bottom, 12)
            HStack {
                Text(t("Только тестовые данные", "Sample data only")).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(t("Закрыть", "Close")) { model.cancelSignIn() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(28).frame(width: 440, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(LabColor.accent)
    }
    private func step(_ title: String, done: Bool) -> some View {
        HStack(spacing: 5) {
            if done { Lucide(name: "check", size: 12) }
            Text(title)
        }.foregroundStyle(done ? LabColor.success : LabColor.accent)
    }
    @ViewBuilder private var content: some View {
        switch model.authStage {
        case .sso:
            Text(t("Откроется страница вашей организации. Шаги входа и подтверждения задаёт сервер.",
                   "Your organization’s sign-in page opens in the app. The server determines the sign-in steps."))
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 20)
            primary(t("Продолжить вход", "Continue to sign-in")) { model.continueSSO() }
            Text(t("В демо откроется тестовая страница входа.", "The demo opens a sample sign-in form."))
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 10)
        case .password:
            inputLabel(t("Пользователь", "Username"))
            SingleLineInput(text: $model.authUsername, label: t("Пользователь", "Username"))
                .frame(height: 26).padding(.bottom, 12)
            passwordInput
            errorIfNeeded(t("Не удалось войти. Проверьте имя и тестовый пароль.", "Sign-in failed. Check your username and sample password."))
            primary(t("Продолжить", "Continue")) { model.submitPassword() }
                .disabled(model.authUsername.isEmpty || model.authPassword.isEmpty)
            demoHint
        case .code:
            Text(model.smsSignIn ? t("Введите код из SMS.", "Enter the code from your SMS.") : t("Введите код из приложения-аутентификатора.", "Enter the code from your authenticator app."))
                .font(.system(size: 13)).padding(.bottom, 16)
            codeInput
            if model.canOfferTOTP {
                Text(t("Код из приложения? После успешного входа можно настроить TOTP и не вводить его вручную.", "An authenticator code? After signing in, you can set up TOTP to fill it automatically."))
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.bottom, 12)
            }
            errorIfNeeded(t("Код не подошёл. Попробуйте \(model.expectedCode).", "That code didn’t work. Try \(model.expectedCode)."))
            primary(t("Подключиться", "Connect")) { model.submitCode() }.disabled(model.authCode.count != model.expectedCode.count)
            demoHint
        case .expired:
            Text(t("Подтверждение не завершено. Начните вход заново.",
                   "Verification wasn’t completed. Start signing in again."))
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 20)
            primary(t("Начать вход заново", "Start again")) { model.beginSignIn() }
        case .success:
            Text(t("Профиль «\(profileName)» подключён. Можно вернуться к работе.",
                   "\(profileName) is connected. You can get back to work."))
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 20)
            IconLabel(title: t("Соединение установлено", "Connection established"), icon: "circle-check")
                .foregroundStyle(LabColor.success).padding(.bottom, 24)
            primary(t("Готово", "Done")) { model.cancelSignIn() }
        case .credentialPassword:
            Text(t("Пароль для «\(profileName)». В демо используйте demo.", "Password for \(profileName). Use demo in this prototype."))
                .font(.system(size: 13)).padding(.bottom, 16)
            passwordInput
            errorIfNeeded(t("Для этого демо используйте пароль demo.", "Use the password demo for this prototype."))
            credentialActions
        case .rememberCode:
            Text(t("Вход выполнен. Если код был из приложения-аутентификатора, добавьте секрет TOTP. Сам одноразовый код не сохраняется.", "You’re signed in. If you used an authenticator, add its TOTP secret. The one-time code itself is not saved."))
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 20)
            primary(t("Настроить TOTP", "Set up TOTP")) { model.configureTOTPAfterSignIn() }
            Button(t("Это SMS / не сейчас", "It’s SMS / not now")) { model.skipTOTP() }.buttonStyle(.link).padding(.top, 12)
        case .credentialCode:
            Text(t("Вставьте ключ настройки или ссылку otpauth:// из QR. Секрет должен давать тот код, который вы ввели.", "Paste the setup key or otpauth:// link from the QR code. The secret must match the code you entered."))
                .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 12)
            SecureField(t("Секрет или otpauth://", "Secret or otpauth://"), text: $model.authSecret)
                .textFieldStyle(.roundedBorder).padding(.bottom, 10)
            Button(t("Подставить тестовый секрет", "Use the sample secret")) { model.authSecret = DemoModel.sampleSecret; model.authError = false }
                .buttonStyle(.link).padding(.bottom, 10)
            Text(t("Демо проверяет код \(model.expectedCode) в фиксированный момент времени. Камера и чтение QR доступны в рабочем приложении.", "This demo checks code \(model.expectedCode) at a fixed time. Camera and QR capture are available in the production app."))
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.bottom, 12)
            errorIfNeeded(t("Секрет не соответствует введённому коду.", "The secret does not match the entered code."))
            credentialActions
        }
    }
    private func inputLabel(_ label: String) -> some View {
        Text(label).font(.system(size: 12, weight: .medium)).padding(.bottom, 5)
    }
    private var passwordInput: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t("Пароль", "Password")).font(.system(size: 12, weight: .medium))
            SecureField("", text: $model.authPassword).labelsHidden().textFieldStyle(.roundedBorder)
                .accessibilityLabel(t("Пароль", "Password"))
        }.padding(.bottom, 14)
    }
    private var codeInput: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t("Одноразовый код", "One-time code")).font(.system(size: 12, weight: .medium))
            SingleLineInput(text: Binding(get: { model.authCode }, set: {
                model.authCode = DemoModel.singleCode($0, digits: model.expectedCode.count)
            }), label: t("Одноразовый код", "One-time code"), placeholder: model.expectedCode).frame(height: 28)
        }.padding(.bottom, 14)
    }
    private var credentialActions: some View {
        VStack(spacing: 12) {
            primary(t("Использовать для профиля", "Use for this profile")) { model.saveCredential() }
            if model.authStage == .credentialPassword ? model.authProfile?.passwordSaved == true : model.authProfile?.codeSaved == true {
                Button(t("Удалить сохранённое значение", "Remove saved value"), role: .destructive) { model.clearCredential() }
                    .buttonStyle(.link)
            }
        }
    }
    private var demoHint: some View {
        Text(t("Демо: пароль demo · код \(model.expectedCode)", "Demo: password demo · code \(model.expectedCode)"))
            .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 10)
    }
    @ViewBuilder private func errorIfNeeded(_ message: String) -> some View {
        if model.authError {
            IconLabel(title: message, icon: "circle-alert").font(.system(size: 12))
                .foregroundStyle(LabColor.failure).fixedSize(horizontal: false, vertical: true)
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(LabColor.failure.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 14)
        }
    }
    private func primary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity).padding(.vertical, 3) }
            .buttonStyle(.borderedProminent).tint(LabColor.accent).keyboardShortcut(.defaultAction)
    }
}
