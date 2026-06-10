import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Listing.createdAt, order: .reverse) private var listings: [Listing]

    var body: some View {
        NavigationStack {
            Group {
                if !purchases.isPro {
                    lockedState
                } else if listings.isEmpty {
                    emptyState
                } else {
                    listBody
                }
            }
            .background(Brand.paper.ignoresSafeArea())
            .navigationTitle("History")
            .toolbarBackground(Brand.paper, for: .navigationBar)
        }
        .tint(Brand.stamp)
    }

    private var listBody: some View {
        List {
            ForEach(listings) { listing in
                NavigationLink {
                    if let draft = listing.draft {
                        ResultView(
                            draft: draft,
                            photos: [],
                            isNew: false,
                            initialPlatform: listing.platform
                        )
                        .toolbar(.hidden, for: .tabBar)
                    } else {
                        ContentUnavailableView(
                            "Listing unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("This saved listing couldn't be read.")
                        )
                    }
                } label: {
                    row(listing)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Brand.ticket)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Brand.ink, lineWidth: 1.2))
                        .padding(.vertical, 4)
                )
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if listing.status != .listed {
                        Button { setStatus(listing, .listed) } label: { Label("Listed", systemImage: "checkmark.circle") }
                            .tint(Brand.ink)
                    }
                    if listing.status != .sold {
                        Button { setStatus(listing, .sold) } label: { Label("Sold", systemImage: "dollarsign.circle") }
                            .tint(Brand.stamp)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    modelContext.delete(listings[index])
                }
                // Явная фиксация: autosave отложенный
                try? modelContext.save()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ listing: Listing) -> some View {
        HStack(spacing: 12) {
            if let data = listing.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Brand.ink, lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Brand.paper)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "tag").foregroundStyle(Brand.inkFaint))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(listing.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Brand.ink)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    statusStamp(listing.status)
                    Text("\(listing.platform.displayName) · \(listing.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Brand.inkFaint)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func setStatus(_ listing: Listing, _ status: ListingStatus) {
        listing.status = status
        try? modelContext.save()
    }

    private func statusStamp(_ status: ListingStatus) -> some View {
        let color: Color = switch status {
        case .draft: Brand.inkFaint
        case .listed: Brand.ink
        case .sold: Brand.stamp
        }
        return Text(status.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .kerning(1)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(color, lineWidth: 1.1))
            .rotationEffect(.degrees(status == .sold ? -3 : 0))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            TagMark(size: 42, color: Brand.inkFaint)
            Text("No listings yet")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Brand.ink)
            Text("Your generated listings will appear here.")
                .font(.subheadline)
                .foregroundStyle(Brand.inkSoft)
        }
    }

    private var lockedState: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title)
                    .foregroundStyle(Brand.ink)
                StampLabel(text: "Pro only", angle: -5)
            }
            Text("History is a Pro feature")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Brand.ink)
            Text("Upgrade to keep every listing you've created and reopen it anytime.")
                .font(.subheadline)
                .foregroundStyle(Brand.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                appState.showPaywall = true
            } label: {
                Text("Get Pro Pass")
                    .padding(.horizontal, 22)
            }
            .buttonStyle(InkButtonStyle())
            .fixedSize()
        }
        .padding(32)
    }
}
