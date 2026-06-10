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
        .tint(Brand.emerald)
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
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Brand.card)
                        .padding(.vertical, 4)
                )
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if listing.status != .listed {
                        Button { setStatus(listing, .listed) } label: { Label("Listed", systemImage: "checkmark.circle") }
                            .tint(Brand.emerald)
                    }
                    if listing.status != .sold {
                        Button { setStatus(listing, .sold) } label: { Label("Sold", systemImage: "dollarsign.circle") }
                            .tint(Brand.amber)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    modelContext.delete(listings[index])
                }
                // Явная фиксация: autosave отложенный, kill сразу после свайпа терял бы изменение
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
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Brand.paper)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "tag")
                            .foregroundStyle(Brand.inkMuted)
                    )
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(listing.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Brand.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    statusChip(listing.status)
                    Text("\(listing.platform.displayName) · \(listing.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Brand.inkMuted)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func setStatus(_ listing: Listing, _ status: ListingStatus) {
        listing.status = status
        try? modelContext.save()
    }

    private func statusChip(_ status: ListingStatus) -> some View {
        let color: Color = switch status {
        case .draft: Brand.inkMuted
        case .listed: Brand.emerald
        case .sold: Brand.amber
        }
        return Text(status.label.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                ViewfinderBrackets()
                    .stroke(Brand.lineOnPaper, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 76, height: 76)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(Brand.inkMuted)
            }
            Text("No listings yet")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.ink)
            Text("Your generated listings will appear here.")
                .font(.subheadline)
                .foregroundStyle(Brand.inkMuted)
        }
    }

    private var lockedState: some View {
        VStack(spacing: 18) {
            ZStack {
                ViewfinderBrackets()
                    .stroke(Brand.amber, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 76, height: 76)
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(Brand.amber)
            }
            Text("History is a Pro feature")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.ink)
            Text("Upgrade to keep every listing you've created and reopen it anytime.")
                .font(.subheadline)
                .foregroundStyle(Brand.inkMuted)
                .multilineTextAlignment(.center)
            Button {
                appState.showPaywall = true
            } label: {
                Text("Upgrade to Pro")
                    .padding(.horizontal, 26)
            }
            .buttonStyle(BrandPrimaryButtonStyle())
            .fixedSize()
        }
        .padding(32)
    }
}
