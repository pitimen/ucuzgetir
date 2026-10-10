import SwiftUI

struct StoreView: View {
  @EnvironmentObject private var model: NativeStoreModel
  @State private var searchText = ""
  @State private var selectedCategory = "Tümü"

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]

  private var categories: [String] {
    let values = Set(model.products.map(\.category).filter { !$0.isEmpty })
    return ["Tümü"] + values.sorted()
  }

  private var visibleProducts: [StoreProduct] {
    let query = Self.normalized(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
    return model.products.filter { product in
      let matchesCategory = selectedCategory == "Tümü" || product.category == selectedCategory
      let matchesSearch = query.isEmpty
        || Self.normalized(product.name).contains(query)
        || product.id.localizedCaseInsensitiveContains(searchText)
      return matchesCategory && matchesSearch
    }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {
        categoryPicker

        if model.isLoading && model.products.isEmpty {
          ProgressView("Ürünler yükleniyor")
            .frame(maxWidth: .infinity, minHeight: 180)
        } else if let errorMessage = model.errorMessage, model.products.isEmpty {
          emptyState(
            symbol: "wifi.exclamationmark",
            title: "Mağazaya ulaşılamıyor",
            message: errorMessage,
            actionTitle: "Yeniden Dene"
          ) {
            Task { await model.loadProducts(force: true) }
          }
        } else if let errorMessage = model.errorMessage {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
              .foregroundStyle(.orange)
            Text(errorMessage)
              .font(.footnote)
              .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("Yenile") {
              Task { await model.loadProducts(force: true) }
            }
            .font(.footnote.weight(.semibold))
          }
          .padding(12)
          .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        } else if visibleProducts.isEmpty {
          emptyState(
            symbol: "magnifyingglass",
            title: "Ürün bulunamadı",
            message: "Aramanızı veya seçtiğiniz kategoriyi değiştirebilirsiniz."
          )
        } else {
          LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            ForEach(visibleProducts) { product in
              ProductCard(product: product)
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 24)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("Mağaza")
    .navigationBarTitleDisplayMode(.large)
    .searchable(
      text: $searchText,
      placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Ürün veya stok kodu ara"
    )
    .refreshable {
      await model.loadProducts(force: true)
    }
    .navigationDestination(for: StoreProduct.self) { product in
      ProductDetailView(product: product)
    }
    .task {
      await model.loadProducts()
    }
  }

  private var categoryPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(categories, id: \.self) { category in
          let isSelected = selectedCategory == category
          Button {
            withAnimation(.easeInOut(duration: 0.18)) {
              selectedCategory = category
            }
          } label: {
            Text(category)
              .font(.subheadline.weight(isSelected ? .semibold : .regular))
              .padding(.horizontal, 15)
              .padding(.vertical, 9)
              .background(
                isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground),
                in: Capsule()
              )
              .foregroundStyle(isSelected ? Color.white : Color.primary)
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
      .padding(.vertical, 2)
    }
  }

  @ViewBuilder
  private func emptyState(
    symbol: String,
    title: String,
    message: String,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
  ) -> some View {
    VStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.system(size: 34))
        .foregroundStyle(.secondary)
      Text(title)
        .font(.headline)
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if let actionTitle, let action {
        Button(actionTitle, action: action)
          .buttonStyle(.borderedProminent)
          .padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 210)
    .padding()
  }

  private static func normalized(_ value: String) -> String {
    value
      .lowercased()
      .replacingOccurrences(of: "ı", with: "i")
      .replacingOccurrences(of: "ç", with: "c")
      .replacingOccurrences(of: "ğ", with: "g")
      .replacingOccurrences(of: "ö", with: "o")
      .replacingOccurrences(of: "ş", with: "s")
      .replacingOccurrences(of: "ü", with: "u")
  }
}

private struct ProductCard: View {
  @EnvironmentObject private var model: NativeStoreModel
  let product: StoreProduct

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      NavigationLink(value: product) {
        ProductImage(url: product.imageURL)
          .frame(height: 132)
          .frame(maxWidth: .infinity)
          .background(Color(uiColor: .secondarySystemGroupedBackground))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .accessibilityLabel(product.name)
      }
      .buttonStyle(.plain)

      HStack(alignment: .top, spacing: 6) {
        NavigationLink(value: product) {
          Text(product.name)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)

        Button {
          model.toggleFavorite(product)
        } label: {
          Image(systemName: model.isFavorite(product) ? "heart.fill" : "heart")
            .foregroundStyle(model.isFavorite(product) ? .red : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isFavorite(product) ? "Favorilerden çıkar" : "Favorilere ekle")
      }
      .frame(minHeight: 40, alignment: .top)

      Text(product.formattedPrice)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      Button {
        model.addToCart(product)
      } label: {
        Label("Sepete Ekle", systemImage: "plus")
          .font(.caption.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    }
    .padding(10)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .accessibilityElement(children: .contain)
  }
}

struct ProductImage: View {
  let url: URL?

  var body: some View {
    Group {
      if let url {
        AsyncImage(url: url) { phase in
          if let image = phase.image {
            image
              .resizable()
              .scaledToFit()
          } else if phase.error != nil {
            imagePlaceholder
          } else {
            ProgressView()
          }
        }
      } else {
        imagePlaceholder
      }
    }
    .padding(8)
  }

  private var imagePlaceholder: some View {
    Image(systemName: "shippingbox")
      .font(.system(size: 34))
      .foregroundStyle(.tertiary)
  }
}

private struct ProductDetailView: View {
  @EnvironmentObject private var model: NativeStoreModel
  let product: StoreProduct

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        ProductImage(url: product.imageURL)
          .frame(height: 280)
          .frame(maxWidth: .infinity)
          .background(Color(uiColor: .secondarySystemGroupedBackground))
          .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        Text(product.name)
          .font(.title2.weight(.semibold))
        Text(product.formattedPrice)
          .font(.title3.weight(.semibold))
          .foregroundStyle(.tint)
        Text(product.description)
          .font(.body)
          .foregroundStyle(.secondary)

        Button {
          model.addToCart(product)
        } label: {
          Label("Sepete Ekle", systemImage: "cart.badge.plus")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(16)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("Ürün")
    .navigationBarTitleDisplayMode(.inline)
  }
}
