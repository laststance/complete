import SwiftUI

/// SwiftUI view for displaying completion list
/// Features dark theme with blue selection highlighting
struct CompletionListView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: CompletionViewModel
    
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
            if viewModel.hasCompletions {
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
                                    CompletionWindowController.shared.handleMouseSelection()
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
                let vm = CompletionViewModel.shared
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
                let vm = CompletionViewModel.shared
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
                let vm = CompletionViewModel.shared
                vm.completions = []
                return vm
            }())
            .frame(width: 300, height: 100)
            .preferredColorScheme(.dark)
        }
    }
}
#endif