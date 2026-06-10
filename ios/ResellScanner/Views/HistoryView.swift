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
                    ContentUnavailableView(
                        "No listings yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Your generated listings will appear here.")
                    )
                } else {
                    listBody
                }
            }
            .navigationTitle("History")
        }
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
                    }
                } label: {
                    row(listing)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if listing.status != .listed {
                        Button { listing.status = .listed } label: { Label("Listed", systemImage: "checkmark.circle") }
                            .tint(.blue)
                    }
                    if listing.status != .sold {
                        Button { listing.status = .sold } label: { Label("Sold", systemImage: "dollarsign.circle") }
                            .tint(.green)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    modelContext.delete(listings[index])
                }
            }
        }
    }

    private func row(_ listing: Listing) -> some View {
        HStack(spacing: 12) {
            if let data = listing.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "tag").foregroundStyle(.secondary))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    statusChip(listing.status)
                    Text("\(listing.platform.displayName) · \(listing.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statusChip(_ status: ListingStatus) -> some View {
        let color: Color = switch status {
        case .draft: .secondary
        case .listed: .blue
        case .sold: .green
        }
        return Text(status.label.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var lockedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("History is a Pro feature")
                .font(.title3.bold())
            Text("Upgrade to keep every listing you've created and reopen it anytime.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                appState.showPaywall = true
            } label: {
                Text("Upgrade to Pro")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.tint, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(32)
    }
}
