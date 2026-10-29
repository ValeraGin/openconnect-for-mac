import SwiftUI

struct SignInView: View {
    @ObservedObject var model: DemoModel
    private func t(_ ru: String, _ en: String) -> String { model.t(ru, en) }
    private var profileName: String { model.authProfile?.name ?? t("Профиль", "Profile") }
    private var color: Color {
        if model.authStage == .success { return LabColor.success }
        if model.authStage == .expired { return LabColor.warning }
        return LabColor.accent
    }
    private var title: String {
        switch model.authStage {
        case .sso, .password: return t("Вход в «\(profileName)»", "Sign in to \(profileName)")
        case .code: return t("Подтвердите вход", "Verify your sign-in")
        case .expired: return t("Время кода истекло", "Your code has expired")
        case .success: return t("Вы подключены", "You’re connected")
        case .credentialPassword: return t("Пароль профиля", "Profile password")
        case .credentialCode: return t("Одноразовый код", "One-time code")
        }
    }
    private var icon: String {
        switch model.authStage {
        case .sso: return "globe"
        case .password, .credentialPassword: return "lock-keyhole"
        case .code, .credentialCode: return "key-round"
        case .expired: return "circle-alert"
        case .success: return "shield-check"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Lucide(name: "shield", size: 18).foregroundStyle(LabColor.accent)
                Text("OpenConnect").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("DEMO").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LabColor.accent).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(LabColor.accent.opacity(0.1), in: Capsule())
            }.padding(.bottom, 28)
            Lucide(name: icon, size: 28).foregroundStyle(color)
                .frame(width: 54, height: 54).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 16)
            Text(title).font(.system(size: 22, weight: .semibold)).lineLimit(2).padding(.bottom, 6)
            Text(model.authProfile.flatMap { URL(string: $0.server)?.host } ?? "vpn.example.com")
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.bottom, 22)
            content
            Spacer(minLength: 12)
            if !model.authStage.isCredential && model.authStage != .success {
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
            Text(t("Войдите с учётной записью организации. После входа подтвердите его одноразовым кодом.",
                   "Use your organization account, then verify your sign-in with a one-time code."))
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
            Text(t("Введите 6 цифр из приложения с кодами.", "Enter the 6 digits from your authenticator app."))
                .font(.system(size: 13)).padding(.bottom, 16)
            codeInput
            errorIfNeeded(t("Код не подошёл. Попробуйте 123456.", "That code didn’t work. Try 123456."))
            primary(t("Подключиться", "Connect")) { model.submitCode() }.disabled(model.authCode.count != 6)
            demoHint
        case .expired:
            Text(t("Подтверждение не завершено. Запросите новый код и попробуйте ещё раз.",
                   "Verification wasn’t completed. Request a new code and try again."))
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 20)
            primary(t("Получить новый код", "Get a new code")) { model.restartCode() }
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
        case .credentialCode:
            Text(t("Проверьте код перед добавлением к профилю. В демо используйте 123456.",
                   "Verify a code before adding it to the profile. Use 123456 in this demo."))
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).padding(.bottom, 16)
            codeInput
            errorIfNeeded(t("Для этого демо используйте код 123456.", "Use the code 123456 for this demo."))
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
                model.authCode = String($0.filter { "0123456789".contains($0) }.prefix(6))
            }), label: t("Одноразовый код", "One-time code"), placeholder: "123456").frame(height: 28)
        }.padding(.bottom, 14)
    }
    private var credentialActions: some View {
        VStack(spacing: 12) {
            primary(t("Использовать для профиля", "Use for this profile")) { model.saveCredential() }
            Button(t("Удалить сохранённое значение", "Remove saved value"), role: .destructive) { model.clearCredential() }
                .buttonStyle(.link)
        }
    }
    private var demoHint: some View {
        Text(t("Демо: пароль demo · код 123456", "Demo: password demo · code 123456"))
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
