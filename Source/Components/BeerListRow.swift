import NukeUI
import OluttaShared
import SwiftUI

struct BeerRow: View {
    let beer: ProductEntity
    @State private var showingLinkOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 50, height: 50)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                Text(beer.name)
                    .font(.headline)
                    .lineLimit(2)
                if beer.manufacturer != nil || beer.beerStyle != nil {
                    HStack {
                        if let manufacturer = beer.manufacturer {
                            Text(manufacturer)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        if let beerStyle = beer.beerStyle {
                            Text(beerStyle)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .cornerRadius(4)
                        }
                    }
                }
                HStack {
                    if let price = beer.price {
                        HStack(spacing: 2) {
                            Text(price.formatted(.currency(code: "EUR")))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    Spacer()
                    if let alcoholPercentage = beer.alcoholPercentage {
                        HStack(spacing: 2) {
                            Image(systemName: "percent")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text(alcoholPercentage.formatted(.number.precision(.fractionLength(1))))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .onTapGesture {
            showingLinkOptions = true
        }
        .confirmationDialog(
            .openIn,
            isPresented: $showingLinkOptions,
            titleVisibility: .visible,
        ) {
            if let alkoUrl = URL(string: "https://www.alko.fi/tuotteet/\(beer.alkoId)") {
                Link("Alko", destination: alkoUrl)
            }
            if let untappdId = beer.untappdId, let untappdUrl = URL(string: "https://untappd.com/b/_/\(untappdId)") {
                Link(.untappd, destination: untappdUrl)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
