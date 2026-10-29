import Foundation
// The shared QR parser's diagnostic errors are not shown by this demo UI.
func L(_ source: String, _ arguments: CVarArg...) -> String {
    String(format: source, arguments: arguments)
}
