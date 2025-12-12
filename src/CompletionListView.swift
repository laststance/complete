import SwiftUI

/// SwiftUI view for displaying completion list
/// Features dark theme with blue selection highlighting
struct CompletionListView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: CompletionViewModel
    var onSelection: (() -> Void)?
    var onTerminalSubmit: ((String) -> Void)?
    var onTerminalCancel: (() -> Void)?

    // Focus state to ensure keyboard input works immediately
    @FocusState private var isFocused: Bool

    // MARK: - Constants

    private let itemHeight: CGFloat = 22
    private let cornerRadius: CGFloat = 6
    private let padding: CGFloat = 4

    // Colors matching macOS dark theme
    private let backgroundColor = Color(white: 0.15)
    private let selectionColor = Color.blue.opacity(0.8)
    private let textColor = Color.white
    private let shadowColor = Color.black.opacity(0.3)

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isTerminalInputMode {
                // Terminal input mode: show text field for user to type word
                TerminalInputView(
                    text: $viewModel.terminalInputText,
                    onSubmit: { text in
                        onTerminalSubmit?(text)
                    },
                    onCancel: {
                        onTerminalCancel?()
                    },
                    textColor: textColor,
                    backgroundColor: backgroundColor
                )
            } else if viewModel.hasCompletions {
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(spacing: 1) {
                            ForEach(Array(viewModel.completions.enumerated()), id: \.offset) { index, completion in
                                CompletionRow(
                                    text: completion,
                                    isSelected: index == viewModel.selectedIndex,
                                    itemHeight: itemHeight,
                                    textColor: textColor,
                                    selectionColor: selectionColor
                                )
                                .id(index)
                                .onTapGesture {
                                    viewModel.select(at: index)
                                    // Trigger selection action
                                    onSelection?()
                                }
                            }
                        }
                        .padding(padding)
                        .onChange(of: viewModel.selectedIndex) { oldValue, newValue in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }
                .frame(maxHeight: 600)  // Max 600pt height for scrollable list
            } else {
                Text("No completions")
                    .foregroundColor(textColor.opacity(0.5))
                    .frame(height: 60)
            }
        }
        .background(backgroundColor)
        .cornerRadius(cornerRadius)
        .shadow(color: shadowColor, radius: 10, x: 0, y: 2)
        .frame(width: 200)  // Fixed width for narrow vertical appearance
        .focusable()  // Make the view focusable for keyboard input
        .focused($isFocused)  // Bind to focus state
        .onAppear {
            // Automatically set focus when view appears
            // Small delay ensures window is fully initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = true
            }
        }
    }
}

// MARK: - Terminal Input View

/// View for Terminal input mode - allows user to type the word they want to complete
struct TerminalInputView: View {
    @Binding var text: String
    var onSubmit: (String) -> Void
    var onCancel: (() -> Void)?
    let textColor: Color
    let backgroundColor: Color

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type word to complete:")
                .font(.system(size: 11))
                .foregroundColor(textColor.opacity(0.7))

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                )
                .focused($isInputFocused)
                .onSubmit {
                    if !text.isEmpty {
                        onSubmit(text)
                    }
                }
                .onKeyPress(.escape) {
                    onCancel?()
                    return .handled
                }
                .onAppear {
                    // Auto-focus the input field
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInputFocused = true
                    }
                }

            Text("Enter=complete, Esc=cancel")
                .font(.system(size: 10))
                .foregroundColor(textColor.opacity(0.5))
        }
        .padding(12)
        .frame(width: 200)
    }
}

// MARK: - Completion Row

/// Individual completion row view
struct CompletionRow: View {
    let text: String
    let isSelected: Bool
    let itemHeight: CGFloat
    let textColor: Color
    let selectionColor: Color

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .frame(height: itemHeight)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? selectionColor : Color.clear)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct CompletionListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with completions
            CompletionListView(viewModel: {
                let vm = CompletionViewModel()
                vm.completions = [
                    "completion",
                    "complete",
                    "completed",
                    "completing",
                    "completeness",
                    "complement",
                    "complementary",
                    "complex",
                    "complexity"
                ]
                vm.selectedIndex = 0
                return vm
            }())
            .frame(width: 300, height: 400)
            .preferredColorScheme(.dark)

            // Preview with selection in middle
            CompletionListView(viewModel: {
                let vm = CompletionViewModel()
                vm.completions = [
                    "test",
                    "testing",
                    "tested",
                    "tester"
                ]
                vm.selectedIndex = 2
                return vm
            }())
            .frame(width: 300, height: 200)
            .preferredColorScheme(.dark)

            // Preview with no completions
            CompletionListView(viewModel: {
                let vm = CompletionViewModel()
                vm.completions = []
                return vm
            }())
            .frame(width: 300, height: 100)
            .preferredColorScheme(.dark)
        }
    }
}
#endif