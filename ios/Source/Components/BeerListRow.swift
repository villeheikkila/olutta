import NukeUI
import SwiftUI

struct BeerRow: View {
    let beer: BeerEntity
    @State private var showingLinkOptions = false

    var body: some View {
        HStack(spacing: 12) {
            if let imageUrl = beer.imageUrl {
                LazyImage(url: imageUrl) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(beer.beerStyle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(beer.name)
                    .font(.headline)
                Text(beer.manufacturer)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(beer.containerSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Text("\(beer.price, specifier: "%.2f") €")
                    Spacer()
                    if let rating = beer.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("\(rating, specifier: "%.2f")")
                        }
                    }

                    Text("\(beer.alcoholPercentage, specifier: "%.1f")%")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            showingLinkOptions = true
        }
        .confirmationDialog(
            "Open in",
            isPresented: $showingLinkOptions,
            titleVisibility: .visible
        ) {
            Link("Alko", destination: beer.alkoUrl)
            if let untappdUrl = beer.untappdUrl {
                Link("Untappd", destination: untappdUrl)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
