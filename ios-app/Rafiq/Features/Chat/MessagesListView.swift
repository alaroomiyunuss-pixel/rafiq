// PATH: ios-app/Rafiq/Features/Chat/
// FILENAME: MessagesListView.swift

import SwiftUI

// ============================================================
// MARK: - MessagesListViewModel
// ============================================================

@MainActor
final class MessagesListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var listener: Any?

    var totalUnread: Int {
        conversations.reduce(0) { sum, convo in
            sum + (currentUserId.map { convo.unreadFor(uid: $0) } ?? 0)
        }
    }

    private var currentUserId: String?

    func load(userId: String, service: ChatServiceProtocol) {
        currentUserId = userId
        isLoading = true
        errorMessage = nil

        Task {
            do {
                conversations = try await service.getConversations(userId: userId)
            } catch {
                errorMessage = "فشل في تحميل المحادثات"
            }
            isLoading = false
        }
    }

    func listen(userId: String, service: ChatServiceProtocol) {
        currentUserId = userId
        listener = service.listenToConversations(userId: userId) { [weak self] updated in
            Task { @MainActor in
                self?.conversations = updated
            }
        }
    }

    func stopListening() {
        if let reg = listener as? any NSObjectProtocol {
            // Listener cleanup handled by Firebase
        }
        listener = nil
    }
}

// ============================================================
// MARK: - MessagesListView
// ============================================================

struct MessagesFullListView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = MessagesListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(message: "جاري تحميل المحادثات...")
            } else if let error = viewModel.errorMessage {
                ErrorStateView(title: "خطأ", message: error) {
                    reload()
                }
            } else if viewModel.conversations.isEmpty {
                EmptyStateView.noMessages
            } else {
                conversationsList
            }
        }
        .background(RafiqColors.backgroundFallback)
        .navigationTitle("الرسائل")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { reload() }
        .onDisappear { viewModel.stopListening() }
    }

    // MARK: - List

    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedConversations) { convo in
                    Button {
                        router.showChat(convo.conversationId)
                    } label: {
                        conversationRow(convo)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sortedConversations: [Conversation] {
        viewModel.conversations.sorted {
            ($0.lastMessageAt?.dateValue() ?? .distantPast) > ($1.lastMessageAt?.dateValue() ?? .distantPast)
        }
    }

    private func conversationRow(_ convo: Conversation) -> some View {
        let uid = environment.currentUser?.uid ?? ""
        let otherUid = convo.otherParticipant(myUid: uid)
        let unread = convo.unreadFor(uid: uid)

        return HStack(spacing: RafiqSpacing.md) {
            // Avatar
            ZStack(alignment: .topTrailing) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(RafiqColors.textSecondaryFallback.opacity(0.4))

                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(RafiqColors.errorFallback)
                        .clipShape(Circle())
                        .offset(x: 4, y: -2)
                }
            }

            VStack(alignment: .leading, spacing: RafiqSpacing.xs) {
                HStack {
                    Text(otherUid.prefix(8).description)
                        .font(unread > 0 ? RafiqFonts.bodyBold() : RafiqFonts.body())
                        .foregroundStyle(RafiqColors.textPrimaryFallback)

                    Spacer()

                    if let date = convo.lastMessageAt?.dateValue() {
                        Text(formatMessageTime(date))
                            .font(RafiqFonts.small())
                            .foregroundStyle(
                                unread > 0
                                    ? RafiqColors.primaryFallback
                                    : RafiqColors.textSecondaryFallback
                            )
                    }
                }

                HStack {
                    Text(convo.lastMessage ?? "محادثة جديدة")
                        .font(RafiqFonts.caption())
                        .foregroundStyle(
                            unread > 0
                                ? RafiqColors.textPrimaryFallback
                                : RafiqColors.textSecondaryFallback
                        )
                        .fontWeight(unread > 0 ? .medium : .regular)
                        .lineLimit(1)

                    Spacer()

                    if unread > 0 {
                        Circle()
                            .fill(RafiqColors.primaryFallback)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.horizontal, RafiqSpacing.md)
        .padding(.vertical, RafiqSpacing.sm + 2)
        .background(
            unread > 0
                ? RafiqColors.primaryFallback.opacity(0.03)
                : RafiqColors.surfaceFallback
        )
    }

    // MARK: - Helpers

    private func reload() {
        guard let uid = environment.currentUser?.uid else { return }
        viewModel.load(userId: uid, service: environment.chat)
        viewModel.listen(userId: uid, service: environment.chat)
    }

    private func formatMessageTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.arabicTime
        } else if calendar.isDateInYesterday(date) {
            return "أمس"
        } else {
            return date.arabicShortDate
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Messages List") {
    NavigationStack {
        MessagesFullListView()
    }
    .environmentObject(AppEnvironment.preview())
    .environmentObject(AppRouter())
    .environment(\.layoutDirection, .rightToLeft)
}
