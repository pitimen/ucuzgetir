import SwiftUI

struct StoreView: View {
  @EnvironmentObject private var model: NativeStoreModel
  @State private var searchText = ""
  @State private var selectedFeaturedID: String?

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]

  private var visibleProducts: [StoreProduct] {
    model.products
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {
        featuredCategories
        categoryBreadcrumb
        categoryPicker

        if let categoryError = model.categoryErrorMessage {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "tag")
              .foregroundStyle(.orange)
            Text("Kategoriler yüklenemedi: \(categoryError)")
              .font(.footnote)
              .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("Yenile") {
              Task { await model.retryCategories() }
            }
            .font(.footnote.weight(.semibold))
          }
          .padding(12)
          .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }

        if model.isLoading && model.products.isEmpty {
          ProgressView("Ürünler yükleniyor")
            .frame(maxWidth: .infinity, minHeight: 180)
        } else if visibleProducts.isEmpty {
          if let errorMessage = model.errorMessage {
            emptyState(
              symbol: "wifi.exclamationmark",
              title: "Mağazaya ulaşılamıyor",
              message: errorMessage,
              actionTitle: "Yeniden Dene"
            ) {
              Task { await reloadProducts() }
            }
          } else {
            emptyState(
              symbol: "magnifyingglass",
              title: "Ürün bulunamadı",
              message: "Aramanızı veya seçtiğiniz kategoriyi değiştirebilirsiniz."
            )
          }
        } else {
          if let errorMessage = model.errorMessage {
            productErrorBanner(errorMessage)
          }
          LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            ForEach(visibleProducts) { product in
              ProductCard(product: product)
            }
          }
          if model.hasMoreProducts {
            if model.isLoading {
              ProgressView("Daha fazla ürün yükleniyor")
                .frame(maxWidth: .infinity)
            } else {
              Button("Daha Fazla Ürün Göster") {
                Task {
                  await model.loadMoreProducts(
                    categoryPath: model.categoryPath,
                    featuredCategoryID: selectedFeaturedID,
                    search: searchText
                  )
                }
              }
              .frame(maxWidth: .infinity)
              .buttonStyle(.bordered)
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
    .task(id: searchText) {
      if !searchText.isEmpty {
        try? await Task.sleep(for: .milliseconds(350))
      }
      guard !Task.isCancelled else { return }
      await model.loadProducts(
        force: true,
        categoryPath: model.categoryPath,
        featuredCategoryID: selectedFeaturedID,
        search: searchText
      )
    }
    .refreshable {
      await model.loadProducts(
        force: true,
        categoryPath: model.categoryPath,
        featuredCategoryID: selectedFeaturedID,
        search: searchText
      )
    }
    .navigationDestination(for: StoreProduct.self) { product in
      ProductDetailView(product: product)
    }
    .task {
      await model.loadInitial()
    }
  }

  private var featuredCategories: some View {
    return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
      ForEach(model.featuredCategories) { category in
        Button {
          selectedFeaturedID = category.id
          Task { await model.selectFeaturedCategory(category.id, search: searchText) }
        } label: {
          HStack(spacing: 12) {
            Image(systemName: category.symbol)
              .font(.title3.weight(.semibold))
              .frame(width: 38, height: 38)
              .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 11))
            Text(category.name)
              .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
          }
          .foregroundStyle(.white)
          .padding(12)
          .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
          .background(
            category.id == "deals" ? Color.orange : Color(red: 0.18, green: 0.48, blue: 0.25),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
          )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var categoryBreadcrumb: some View {
    Group {
      if !model.categoryPath.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            Button("Tüm Kategoriler") {
              selectedFeaturedID = nil
              Task { await model.resetCategoryPath(search: searchText) }
            }
            ForEach(Array(model.categoryPath.enumerated()), id: \.element.id) { item in
              let index = item.offset
              let category = item.element
              Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
              Button(category.name) {
                selectedFeaturedID = nil
                Task { await model.navigateToCategory(level: index + 1, search: searchText) }
              }
              .foregroundStyle(index == model.categoryPath.count - 1 ? Color.primary : Color.accentColor)
            }
          }
          .font(.caption.weight(.medium))
        }
      }
    }
  }

  private var categoryPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        if !model.categoryPath.isEmpty {
          Button {
            selectedFeaturedID = nil
            Task { await model.navigateToCategory(level: model.categoryPath.count - 1, search: searchText) }
          } label: {
            Label("Geri", systemImage: "arrow.left")
              .font(.subheadline.weight(.medium))
              .padding(.horizontal, 15)
              .padding(.vertical, 9)
              .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
          }
          .buttonStyle(.plain)
        } else {
          Button {
            selectedFeaturedID = nil
            Task { await model.resetCategoryPath(search: searchText) }
          } label: {
            Label("Tümü", systemImage: "square.grid.2x2")
              .font(.subheadline.weight(.medium))
              .padding(.horizontal, 15)
              .padding(.vertical, 9)
              .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
          }
          .buttonStyle(.plain)
        }
        ForEach(model.categories) { category in
          categoryChip(category)
        }
      }
      .padding(.vertical, 2)
    }
  }

  private func categoryChip(_ category: StoreCategory) -> some View {
    Button {
      selectedFeaturedID = nil
      Task { await model.selectCategory(category, search: searchText) }
    } label: {
      HStack(spacing: 6) {
        Text(categoryEmoji(category.name))
        Text(category.name)
          .lineLimit(1)
      }
      .font(.subheadline.weight(.medium))
      .padding(.horizontal, 15)
      .padding(.vertical, 9)
      .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
      .foregroundStyle(Color.primary)
    }
    .buttonStyle(.plain)
  }

  private func reloadProducts() async {
    await model.loadProducts(
      force: true,
      categoryPath: model.categoryPath,
      featuredCategoryID: selectedFeaturedID,
      search: searchText
    )
  }

  private func productErrorBanner(_ errorMessage: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "wifi.exclamationmark")
        .foregroundStyle(.orange)
      Text(errorMessage)
        .font(.footnote)
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
      Button("Yenile") {
        Task { await reloadProducts() }
      }
      .font(.footnote.weight(.semibold))
    }
    .padding(12)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
  }

  private func categoryEmoji(_ name: String) -> String {
    let value = name.lowercased()
    if value.contains("baharat") { return "🌿" }
    if value.contains("bayram") { return "🎉" }
    if value.contains("bisküvi") || value.contains("biskuvi") { return "🍪" }
    if value.contains("cips") { return "🍿" }
    if value.contains("çikolata") || value.contains("cikolata") { return "🍫" }
    if value.contains("gazlı") || value.contains("gazli") { return "🛒" }
    if value.contains("gazsız") || value.contains("gazsiz") || value.contains("meyve suyu") { return "🧃" }
    if value.contains("gofret") { return "🍫" }
    if value.contains("yemek") { return "🍲" }
    if value.contains("jelibon") || value.contains("sakız") || value.contains("sakiz") { return "🍬" }
    if value.contains("kahvaltı") || value.contains("kahvalti") { return "🍳" }
    if value.contains("kahve") || value.contains("çay") || value.contains("cay") { return "☕" }
    if value.contains("kek") { return "🍰" }
    if value.contains("oyuncak") { return "🧸" }
    if value.contains("su") { return "💧" }
    if value.contains("süt") || value.contains("sut") { return "🥛" }
    if value.contains("şekerleme") || value.contains("sekerleme") { return "🍭" }
    if value.contains("un") || value.contains("bakliyat") { return "🌾" }
    if value.contains("bez") { return "👶" }
    if value.contains("evcil") || value.contains("hayvan") { return "🐾" }
    if value.contains("hırdavat") || value.contains("hirdavat") { return "🔧" }
    if value.contains("mendil") || value.contains("havlu") { return "🧻" }
    if value.contains("kırtasiye") || value.contains("kirtasiye") { return "✏️" }
    if value.contains("temizlik") { return "🧹" }
    return "🛍️"
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

}

private struct ProductCard: View {
  @EnvironmentObject private var model: NativeStoreModel
  let product: StoreProduct

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      NavigationLink(value: product) {
        ZStack(alignment: .topLeading) {
          ProductImage(url: product.imageURL)
            .frame(height: 132)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          ProductBadges(product: product)
            .padding(8)
        }
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
            .foregroundStyle(model.isFavorite(product) ? Color.red : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isFavorite(product) ? "Favorilerden çıkar" : "Favorilere ekle")
      }
      .frame(minHeight: 40, alignment: .top)

      Text(product.formattedPrice)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      if let cartPrice = product.formattedCartPrice {
        HStack(spacing: 4) {
          Text("Sepette:")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(cartPrice)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.accentColor)
        }
        .accessibilityElement(children: .combine)
      }

      if let stockText = product.formattedStockQuantity {
        Text(stockText)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Button {
        Task { await model.addToCart(product) }
      } label: {
        Label(
          product.comingSoon == true ? "Yakında Stokta" : "Sepete Ekle",
          systemImage: product.comingSoon == true ? "clock" : "plus"
        )
          .font(.caption.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(!product.inStock)
      .controlSize(.small)
    }
    .padding(10)
    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .accessibilityElement(children: .contain)
  }
}

private struct ProductBadges: View {
  let product: StoreProduct

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      if let badge = product.discountBadge, !badge.isEmpty {
        badgeLabel(badge, symbol: "tag.fill", color: .red)
      }
      if let badge = product.campaignBadge, !badge.isEmpty {
        badgeLabel(badge, symbol: "gift.fill", color: .orange)
      }
      if product.lowStock == true {
        badgeLabel("Tükenmek Üzere", symbol: "exclamationmark.triangle.fill", color: .orange)
      }
      if product.comingSoon == true {
        badgeLabel("Yakında Stokta", symbol: "clock.fill", color: .secondary)
      }
      if product.gifted == true {
        badgeLabel("Hediyeli", symbol: "gift.fill", color: .green)
      }
      if product.freeShipping == true {
        badgeLabel("Ücretsiz Kargo", symbol: "shippingbox.fill", color: .blue)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .allowsHitTesting(false)
  }

  private func badgeLabel(_ title: String, symbol: String, color: Color) -> some View {
    Label(title, systemImage: symbol)
      .font(.system(size: 9, weight: .semibold))
      .lineLimit(1)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .foregroundStyle(.white)
      .background(color, in: Capsule())
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
          .overlay(alignment: .topLeading) {
            ProductBadges(product: product)
              .padding(12)
          }

        Text(product.name)
          .font(.title2.weight(.semibold))
        Text(product.formattedPrice)
          .font(.title3.weight(.semibold))
          .foregroundStyle(.tint)
        if let cartPrice = product.formattedCartPrice {
          HStack(spacing: 5) {
            Text("Sepette:")
              .foregroundStyle(.secondary)
            Text(cartPrice)
              .fontWeight(.bold)
              .foregroundStyle(Color.accentColor)
          }
          .font(.headline)
        }
        if let stockText = product.formattedStockQuantity {
          Text(stockText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Text(product.description)
          .font(.body)
          .foregroundStyle(.secondary)

        Button {
          Task { await model.addToCart(product) }
        } label: {
          Label(
            product.comingSoon == true ? "Yakında Stokta" : "Sepete Ekle",
            systemImage: product.comingSoon == true ? "clock" : "cart.badge.plus"
          )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!product.inStock)
      }
      .padding(16)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("Ürün")
    .navigationBarTitleDisplayMode(.inline)
  }
}
