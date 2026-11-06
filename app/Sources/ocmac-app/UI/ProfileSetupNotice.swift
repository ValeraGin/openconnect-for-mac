import SwiftUI

struct ProfileSetupNotice: View {
    let state: ProfileSystemState?
    let checking: Bool
    let canFinish: Bool
    let check: () -> Void
    let finish: () -> Void

    var body: some View {
        if let state, !state.ready {
            VStack(alignment: .leading, spacing: 8) {
                Label(state.error ?? state.setupMessage,
                      systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12)).foregroundStyle(Palette.warn)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(L("Завершить настройку…"), action: finish).disabled(!canFinish || checking)
                    Button(checking ? L("Проверяю…") : L("Проверить готовность"), action: check).disabled(checking)
                }
            }
        }
    }
}
