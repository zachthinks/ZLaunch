import SwiftUI

struct WindowLayoutDestinationPicker: View {
    struct Choice: Identifiable {
        let id: String
        let title: String
    }

    let title: String
    let selectedID: String
    let choices: [Choice]
    let onSelect: (String) -> Void

    @State private var showingChoices = false

    var body: some View {
        Button { showingChoices = true } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Text(title).lineLimit(1)
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.down").font(Theme.Typography.disclosure)
            }
            .layoutFieldChrome()
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingChoices, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(choices) { choice in
                    Button {
                        showingChoices = false
                        onSelect(choice.id)
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(choice.title)
                            Spacer(minLength: Theme.Spacing.sm)
                            if choice.id == selectedID {
                                Image(systemName: "checkmark").font(Theme.Typography.disclosure)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: Theme.Size.layoutControlHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.sm)
            .frame(width: Theme.Size.layoutEntryPopover)
        }
    }
}
