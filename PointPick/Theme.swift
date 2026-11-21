import SwiftUI

enum Theme {
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.07)
    static let tile = Color(red: 0.11, green: 0.11, blue: 0.15)
    static let accent = Color(red: 0.62, green: 0.40, blue: 1.0)
    static let gradient = LinearGradient(colors: [Color(red: 0.55, green: 0.25, blue: 0.95), Color(red: 0.30, green: 0.30, blue: 0.95)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    /// Dark list styling with rounded tiles, similar to CardPointers.
    func appList() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .listRowBackground(Theme.tile)
    }
}

struct Tile<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SectionTitle: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text).font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading) }
}
