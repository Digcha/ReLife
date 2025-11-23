import SwiftUI

struct LeafyView: View {
    private let appState: AppState
    @StateObject private var viewModel: LeafyChatViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: LeafyChatViewModel(appState: appState))
    }

    var body: some View {
        LeafyChatView(viewModel: viewModel)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct LeafyChatView: View {
    @ObservedObject var viewModel: LeafyChatViewModel
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isShowingArchive = false
    @Namespace private var bottomID

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            chatArea
            LeafyInputBar(
                text: $viewModel.inputText,
                isSending: viewModel.isThinking,
                onSend: { viewModel.sendUserMessage(viewModel.inputText) }
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            scrollToBottom()
        }
        .onChange(of: viewModel.isThinking) { _, _ in
            scrollToBottom()
        }
        .sheet(isPresented: $isShowingArchive) {
            LeafyArchiveListView(
                dates: viewModel.archiveDates,
                onSelect: { date in
                    viewModel.selectedArchiveDate = date
                },
                onClose: { isShowingArchive = false }
            )
            .environmentObject(viewModel)
        }
        .background(background.ignoresSafeArea())
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.08, blue: 0.14),
                    Color(red: 0.02, green: 0.05, blue: 0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.25), Color.blue.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 80)
                .scaleEffect(1.6)
                .offset(x: -120, y: -280)
            Circle()
                .fill(Color.cyan.opacity(0.2))
                .blur(radius: 120)
                .scaleEffect(1.3)
                .offset(x: 160, y: 240)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center) {
            LeafyAvatar()
            VStack(alignment: .leading, spacing: 4) {
                Text("Leafy")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Dein ReLife Assistant")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
            }
            Spacer()
            LeafyArchiveButton(action: {
                viewModel.openArchive()
                isShowingArchive = true
            })
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        LeafyMessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isThinking {
                        LeafyTypingIndicator()
                            .id("thinking")
                    }

                    Color.clear.frame(height: 24).id(bottomID)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }
            .scrollDismissesKeyboard(.immediately)
            .onAppear { scrollProxy = proxy; scrollToBottom() }
        }
    }

    private func scrollToBottom() {
        guard let proxy = scrollProxy else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
}

private struct LeafyAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.9), Color.teal]),
                        center: .center
                    )
                )
                .frame(width: 52, height: 52)
                .shadow(color: Color.green.opacity(0.35), radius: 10, y: 4)
            Image(systemName: "leaf.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct LeafyMessageBubble: View {
    let message: LeafyMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.isUser {
                Spacer(minLength: 40)
                bubble
            } else {
                bubble
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.text)
                .font(.body)
                .foregroundColor(message.isUser ? .white : .white.opacity(0.9))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(bubbleBackground)
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(borderColor, lineWidth: 0.6))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: shadowColor, radius: 12, y: 6)
        .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: message.isUser ? .trailing : .leading)
    }

    private var bubbleBackground: some ShapeStyle {
        if message.isUser {
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.72, blue: 0.62), Color(red: 0.0, green: 0.55, blue: 0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        message.isUser ? Color.white.opacity(0.2) : Color.white.opacity(0.12)
    }

    private var shadowColor: Color {
        message.isUser ? Color.green.opacity(0.28) : Color.black.opacity(0.28)
    }
}

struct LeafyTypingIndicator: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 58, height: 32)
                .overlay(dotRow)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private var dotRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 6, height: 6)
                    .opacity(Double(0.4 + (phase * 0.6)) - Double(index) * 0.12)
                    .scaleEffect(1 + CGFloat(index) * 0.02)
            }
        }
    }
}

struct LeafyInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Schreib Leafy…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .foregroundColor(.white)

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(isSendDisabled ? Color.white.opacity(0.2) : Color.green)
                    .clipShape(Circle())
                    .shadow(color: Color.green.opacity(0.6), radius: 12, y: 6)
            }
            .disabled(isSendDisabled)
        }
    }

    private var isSendDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
    }

    private func send() {
        onSend()
        hideKeyboard()
    }

    private func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

struct LeafyArchiveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        }
    }
}

struct LeafyArchiveListView: View {
    @EnvironmentObject var viewModel: LeafyChatViewModel
    let dates: [Date]
    let onSelect: (Date) -> Void
    let onClose: () -> Void

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "de_DE")
        return f
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(dates, id: \.self) { date in
                    NavigationLink(destination: LeafyArchiveDetailView(date: date, messages: viewModel.loadArchive(for: date))) {
                        VStack(alignment: .leading) {
                            Text(title(for: date))
                                .font(.headline)
                            Text(formatter.string(from: date))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onTapGesture {
                        onSelect(date)
                    }
                }
            }
            .navigationTitle("Archiv")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig", action: onClose)
                }
            }
        }
    }

    private func title(for date: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)
        if Calendar.current.isDate(today, inSameDayAs: target) {
            return "Heute"
        }
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today),
           Calendar.current.isDate(yesterday, inSameDayAs: target) {
            return "Gestern"
        }
        return formatter.string(from: target)
    }
}

struct LeafyArchiveDetailView: View {
    let date: Date
    let messages: [LeafyMessage]

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "de_DE")
        return f
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(messages) { message in
                    LeafyMessageBubble(message: message)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
        .navigationTitle(formatter.string(from: date))
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

#Preview {
    LeafyView(appState: AppState())
}
