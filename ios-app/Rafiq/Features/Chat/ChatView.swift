// PATH: ios-app/Rafiq/Features/Chat/
// FILENAME: ChatView.swift

import SwiftUI

// ============================================================
// MARK: - ChatViewModel
// ============================================================

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var showReportSheet = false
    @Published var showLocationShare = false

    private var listener: Any?

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func loadAndListen(conversationId: String, service: ChatServiceProtocol) {
        isLoading = true

        listener = service.listenToMessages(conversationId: conversationId) { [weak self] updated in
            Task { @MainActor in
                self?.messages = updated.sorted { $0.sentDate < $1.sentDate }
                self?.isLoading = false
            }
        }
    }

    func sendMessage(conversationId: String, service: ChatServiceProtocol) {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        let sentText = text
        messageText = ""

        Task {
            do {
                try await service.sendMessage(conversationId: conversationId, text: sentText)
            } catch {
                errorMessage = "فشل في إرسال الرسالة"
                messageText = sentText // restore
            }
            isSending = false
        }
    }

    func markAsRead(conversationId: String, service: ChatServiceProtocol) {
        Task {
            try? await service.markAsRead(conversationId: conversationId)
        }
    }

    func shareLocationLink() -> String {
        // Placeholder — in production, use CLLocationManager
        return "https://maps.google.com/?q=24.7136,46.6753"
    }

    func stopListening() {
        listener = nil
    }
}

// ============================================================
// MARK: - ChatView
// ============================================================

struct ChatFullView: View {
    let conversationId: String

    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    private var currentUid: String {
        environment.currentUser?.uid ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            if viewModel.isLoading && viewModel.messages.isEmpty {
                LoadingView(message: "جاري تحميل المحادثة...")
            } else {
                messagesScrollView
            }

            // Error banner
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.errorMessage = nil
                }
            }

            // Input bar
            inputBar
        }
        .background(RafiqColors.backgroundFallback)
        .navigationTitle("محادثة")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        viewModel.showLocationShare = true
                    } label: {
                        Label("مشاركة الموقع", systemImage: "location.fill")
                    }

                    Divider()

                    Button(role: .destructive) {
                        viewModel.showReportSheet = true
                    } label: {
                        Label("إبلاغ", systemImage: "exclamationmark.triangle.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
            }
        }
        .onAppear {
            viewModel.loadAndListen(conversationId: conversationId, service: environment.chat)
            viewModel.markAsRead(conversationId: conversationId, service: environment.chat)
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .alert("مشاركة الموقع", isPresented: $viewModel.showLocationShare) {
            Button("إرسال رابط الموقع") {
                let link = viewModel.shareLocationLink()
                viewModel.messageText = "📍 موقعي الحالي: \(link)"
                viewModel.sendMessage(conversationId: conversationId, service: environment.chat)
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("سيتم إرسال رابط موقعك الحالي في المحادثة")
        }
        .sheet(isPresented: $viewModel.showReportSheet) {
            ReportSheet(conversationId: conversationId)
        }
    }

    // MARK: - Messages Scroll

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: RafiqSpacing.xs) {
                    // Date headers + messages
                    ForEach(groupedMessages, id: \.date) { group in
                        dateHeader(group.date)

                        ForEach(group.messages) { message in
                            MessageBubble(
                                message: message,
                                isMine: message.isMine(uid: currentUid)
                            )
                            .id(message.messageId)
                        }
                    }
                }
                .padding(.horizontal, RafiqSpacing.md)
                .padding(.vertical, RafiqSpacing.sm)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastId = viewModel.messages.last?.messageId {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastId = viewModel.messages.last?.messageId {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Grouped Messages by Date

    private struct MessageGroup {
        let date: String
        let messages: [ChatMessage]
    }

    private var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.messages) { msg -> String in
            let date = msg.sentDate
            if calendar.isDateInToday(date) {
                return "اليوم"
            } else if calendar.isDateInYesterday(date) {
                return "أمس"
            } else {
                return date.arabicShortDate
            }
        }

        return grouped.map { MessageGroup(date: $0.key, messages: $0.value) }
            .sorted { first, second in
                guard let f = first.messages.first?.sentDate,
                      let s = second.messages.first?.sentDate else { return false }
                return f < s
            }
    }

    private func dateHeader(_ text: String) -> some View {
        Text(text)
            .font(RafiqFonts.small())
            .foregroundStyle(RafiqColors.textSecondaryFallback)
            .padding(.horizontal, RafiqSpacing.sm)
            .padding(.vertical, 4)
            .background(RafiqColors.textSecondaryFallback.opacity(0.08))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, RafiqSpacing.sm)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: RafiqSpacing.sm) {
                // Location button
                Button {
                    viewModel.showLocationShare = true
                } label: {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(RafiqColors.primaryFallback.opacity(0.7))
                }

                // Text field
                HStack(alignment: .bottom) {
                    TextField("اكتب رسالة...", text: $viewModel.messageText, axis: .vertical)
                        .font(RafiqFonts.body())
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, RafiqSpacing.sm + 2)
                .padding(.vertical, RafiqSpacing.sm)
                .background(RafiqColors.surfaceFallback)
                .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.lg))
                .overlay {
                    RoundedRectangle(cornerRadius: RafiqRadius.lg)
                        .stroke(RafiqColors.textSecondaryFallback.opacity(0.15), lineWidth: 1)
                }

                // Send button
                Button {
                    viewModel.sendMessage(conversationId: conversationId, service: environment.chat)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.canSend
                                ? RafiqColors.primaryFallback
                                : RafiqColors.textSecondaryFallback.opacity(0.3)
                        )
                        // Flip for RTL (send arrow should point left)
                        .scaleEffect(x: -1, y: 1)
                }
                .disabled(!viewModel.canSend)
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm)
            .background(.ultraThinMaterial)
        }
    }
}

// ============================================================
// MARK: - Message Bubble
// ============================================================

struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                // Message text
                Text(message.text)
                    .font(RafiqFonts.body())
                    .foregroundStyle(isMine ? .white : RafiqColors.textPrimaryFallback)
                    .multilineTextAlignment(isMine ? .trailing : .leading)

                // Time + read status
                HStack(spacing: 4) {
                    Text(message.sentDate.arabicTime)
                        .font(.system(size: 10))

                    if isMine {
                        Image(systemName: message.readBy.count > 1 ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 10))
                    }
                }
                .foregroundStyle(
                    isMine
                        ? .white.opacity(0.7)
                        : RafiqColors.textSecondaryFallback
                )
            }
            .padding(.horizontal, RafiqSpacing.md)
            .padding(.vertical, RafiqSpacing.sm + 2)
            .background(
                isMine
                    ? RafiqColors.primaryFallback
                    : RafiqColors.surfaceFallback
            )
            .clipShape(BubbleShape(isMine: isMine))
            .rafiqShadow(.light)

            if !isMine { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Bubble Shape (RTL aware)

struct BubbleShape: Shape {
    let isMine: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 6

        var path = Path()

        if isMine {
            // Sender bubble — tail on trailing (left in RTL)
            path.addRoundedRect(
                in: CGRect(x: 0, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Tail
            path.move(to: CGPoint(x: rect.width - tailSize, y: rect.height - 20))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - 12))
            path.addLine(to: CGPoint(x: rect.width - tailSize, y: rect.height - 4))
        } else {
            // Receiver bubble — tail on leading (right in RTL)
            path.addRoundedRect(
                in: CGRect(x: tailSize, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Tail
            path.move(to: CGPoint(x: tailSize, y: rect.height - 20))
            path.addLine(to: CGPoint(x: 0, y: rect.height - 12))
            path.addLine(to: CGPoint(x: tailSize, y: rect.height - 4))
        }

        return path
    }
}

// ============================================================
// MARK: - Report Sheet
// ============================================================

struct ReportSheet: View {
    let conversationId: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason?
    @State private var details = ""
    @State private var isSubmitting = false

    enum ReportReason: String, CaseIterable {
        case spam = "رسائل مزعجة"
        case harassment = "تحرش أو إساءة"
        case scam = "احتيال"
        case inappropriate = "محتوى غير لائق"
        case other = "سبب آخر"

        var icon: String {
            switch self {
            case .spam: return "envelope.badge.fill"
            case .harassment: return "hand.raised.fill"
            case .scam: return "exclamationmark.shield.fill"
            case .inappropriate: return "eye.slash.fill"
            case .other: return "ellipsis.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RafiqSpacing.lg) {
                    Text("اختر سبب الإبلاغ")
                        .font(RafiqFonts.heading3())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)

                    // Reasons
                    VStack(spacing: RafiqSpacing.sm) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            reasonRow(reason)
                        }
                    }

                    // Details
                    if selectedReason != nil {
                        VStack(alignment: .leading, spacing: RafiqSpacing.sm) {
                            Text("تفاصيل إضافية (اختياري)")
                                .font(RafiqFonts.caption())
                                .foregroundStyle(RafiqColors.textSecondaryFallback)

                            TextField("اكتب تفاصيل...", text: $details, axis: .vertical)
                                .font(RafiqFonts.body())
                                .lineLimit(3...6)
                                .padding(RafiqSpacing.sm)
                                .background(RafiqColors.surfaceFallback)
                                .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.sm))
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Submit
                    PrimaryButton(
                        title: "إرسال الإبلاغ",
                        icon: "paperplane.fill",
                        style: .destructive,
                        isLoading: isSubmitting,
                        isDisabled: selectedReason == nil
                    ) {
                        submitReport()
                    }

                    // Note
                    HStack(alignment: .top, spacing: RafiqSpacing.sm) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                        Text("سيتم مراجعة الإبلاغ من فريق الدعم. للحالات العاجلة تواصل عبر واتساب.")
                            .font(RafiqFonts.small())
                            .foregroundStyle(RafiqColors.textSecondaryFallback)
                    }
                }
                .padding(RafiqSpacing.md)
            }
            .background(RafiqColors.backgroundFallback)
            .navigationTitle("إبلاغ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                        .foregroundStyle(RafiqColors.textSecondaryFallback)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedReason)
        }
    }

    private func reasonRow(_ reason: ReportReason) -> some View {
        let isSelected = selectedReason == reason

        return Button {
            selectedReason = reason
        } label: {
            HStack(spacing: RafiqSpacing.md) {
                Image(systemName: reason.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? RafiqColors.errorFallback : RafiqColors.textSecondaryFallback)
                    .frame(width: 24)

                Text(reason.rawValue)
                    .font(RafiqFonts.body())
                    .foregroundStyle(RafiqColors.textPrimaryFallback)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? RafiqColors.errorFallback : RafiqColors.textSecondaryFallback.opacity(0.3))
            }
            .padding(RafiqSpacing.md)
            .background(
                isSelected
                    ? RafiqColors.errorFallback.opacity(0.06)
                    : RafiqColors.surfaceFallback
            )
            .clipShape(RoundedRectangle(cornerRadius: RafiqRadius.md))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: RafiqRadius.md)
                        .stroke(RafiqColors.errorFallback.opacity(0.3), lineWidth: 1)
                }
            }
        }
    }

    private func submitReport() {
        isSubmitting = true
        // In production: send report to Firestore or support system
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            isSubmitting = false
            dismiss()
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Chat View") {
    NavigationStack {
        ChatFullView(conversationId: "mock_convo_001")
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Message Bubbles") {
    VStack(spacing: RafiqSpacing.sm) {
        MessageBubble(
            message: ChatMessage.mockList[0],
            isMine: false
        )
        MessageBubble(
            message: ChatMessage.mockList[1],
            isMine: true
        )
        MessageBubble(
            message: ChatMessage.mockList[2],
            isMine: false
        )
    }
    .padding()
    .background(RafiqColors.backgroundFallback)
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Report Sheet") {
    ReportSheet(conversationId: "mock_convo_001")
        .environment(\.layoutDirection, .rightToLeft)
}
