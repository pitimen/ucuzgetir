import SwiftUI
import Combine
import Foundation

struct StoreCategory: Decodable, Hashable, Identifiable, Sendable {
  let id: String
  let name: String
  let symbol: String
  let featured: Bool
  let level: Int
  let categoryCode: String
}

struct StoreProduct: Decodable, Hashable, Identifiable, Sendable {
  let id: String
  let name: String
  let description: String
  let productURL: URL
  let imageURL: URL?
  let price: Double?
  let cartPrice: Double?
  let discountRate: Double?
  let discountBadge: String?
  let campaignBadge: String?
  let gifted: Bool?
  let freeShipping: Bool?
  let stockQuantity: Double?
  let stockUnit: String?
  let lowStock: Bool?
  let comingSoon: Bool?
  let categoryID: String
  let category: String
  let inStock: Bool

  private enum CodingKeys: String, CodingKey {
    case id, name, description, productURL, imageURL, price, cartPrice, discountRate
    case discountBadge, campaignBadge, gifted, freeShipping, stockQuantity, stockUnit
    case lowStock, comingSoon, inStock
    case categoryID = "categoryId"
    case category = "categoryName"
  }

  var formattedPrice: String {
    guard let price else { return "Fiyatı mağazada görüntüleyin" }
    return "\(price.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "tr_TR")))) TL"
  }

  var formattedCartPrice: String? {
    guard let cartPrice else { return nil }
    return "\(cartPrice.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "tr_TR")))) TL"
  }

  var formattedStockQuantity: String? {
    guard let stockQuantity else { return nil }
    let quantity = stockQuantity.formatted(
      .number.precision(.fractionLength(0...2)).locale(Locale(identifier: "tr_TR"))
    )
    let unit = stockUnit.flatMap { $0.isEmpty ? nil : $0 } ?? "Ad"
    return "Stok: \(quantity) \(unit)"
  }
}

struct CartItem: Identifiable {
  let product: StoreProduct
  var quantity: Int

  var id: String { product.id }
  var lineTotal: Double? {
    guard let price = product.price else { return nil }
    return price * Double(quantity)
  }

  var formattedLineTotal: String {
    guard let lineTotal else { return "—" }
    return lineTotal.formatted(.currency(code: "TRY").locale(Locale(identifier: "tr_TR")))
  }
}

@MainActor
final class NativeStoreModel: ObservableObject {
  private static let productPageSize = 100

  @Published private(set) var featuredCategories: [StoreCategory] = []
  @Published private(set) var categories: [StoreCategory] = []
  @Published private(set) var categoryPath: [StoreCategory] = []
  @Published private(set) var products: [StoreProduct] = []
  @Published private(set) var cart: [String: CartItem] = [:]
  @Published private(set) var favoriteIDs: Set<String>
  @Published private(set) var isLoading = false
  @Published private(set) var hasMoreProducts = false
  @Published private(set) var isSignedIn = false
  @Published private(set) var cartSubtotal = ""
  @Published private(set) var categoryErrorMessage: String?
  @Published private(set) var errorMessage: String?
  @Published var storePagePath: String?

  private var didLoadCategories = false
  private var didLoadProducts = false
  private var categoryRequestID = UUID()
  private var productRequestID = UUID()
  private let favoritesKey = "ucuzgetir.native.favorite-product-ids"

  init() {
    favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
  }

  var cartItems: [CartItem] {
    cart.values.sorted { $0.product.name.localizedCaseInsensitiveCompare($1.product.name) == .orderedAscending }
  }

  var cartCount: Int {
    cart.values.reduce(0) { $0 + $1.quantity }
  }

  var cartTotal: Double {
    cart.values.reduce(0) { $0 + ($1.lineTotal ?? 0) }
  }

  var formattedCartTotal: String {
    cartSubtotal.isEmpty ? "—" : "\(cartSubtotal) TL"
  }

  func loadInitial() async {
    if !didLoadCategories { await loadCategories() }
    if !didLoadProducts {
      await loadProducts()
    }
    await refreshCart()
  }

  func loadCategories(parentID: String? = nil) async {
    let requestID = UUID()
    categoryRequestID = requestID
    categories = []
    do {
      let loaded = try await NativeCommerceAPI.fetchCategories(parentID: parentID)
      guard categoryRequestID == requestID else { return }
      if parentID == nil {
        featuredCategories = loaded.filter(\.featured)
        categories = loaded.filter { !$0.featured }
        didLoadCategories = true
      } else {
        categories = loaded
      }
      categoryErrorMessage = nil
    } catch {
      guard categoryRequestID == requestID else { return }
      categoryErrorMessage = error.localizedDescription
    }
  }

  func loadProducts(
    force: Bool = false,
    categoryPath: [StoreCategory] = [],
    featuredCategoryID: String? = nil,
    search: String = "",
    append: Bool = false
  ) async {
    guard !isLoading || force else { return }
    let requestID = UUID()
    productRequestID = requestID
    isLoading = true
    if !append { hasMoreProducts = false }
    errorMessage = nil
    defer {
      if productRequestID == requestID { isLoading = false }
    }

    do {
      let loaded = try await NativeCommerceAPI.fetchProducts(
        categoryPath: categoryPath,
        featuredCategoryID: featuredCategoryID,
        search: search,
        offset: append ? products.count : 0
      )
      guard productRequestID == requestID else { return }
      if append {
        let existingIDs = Set(products.map(\.id))
        products.append(contentsOf: loaded.filter { !existingIDs.contains($0.id) })
      } else {
        products = loaded
      }
      hasMoreProducts = loaded.count == Self.productPageSize
      didLoadProducts = true
      errorMessage = nil
    } catch {
      guard productRequestID == requestID else { return }
      errorMessage = error.localizedDescription
    }
  }

  func loadMoreProducts(
    categoryPath: [StoreCategory],
    featuredCategoryID: String?,
    search: String
  ) async {
    guard hasMoreProducts, !isLoading else { return }
    await loadProducts(
      categoryPath: categoryPath,
      featuredCategoryID: featuredCategoryID,
      search: search,
      append: true
    )
  }

  func selectCategory(_ category: StoreCategory, search: String = "") async {
    categoryPath.append(category)
    await loadCategories(parentID: category.id)
    await loadProducts(force: true, categoryPath: categoryPath, search: search)
  }

  func selectFeaturedCategory(_ id: String, search: String = "") async {
    categoryPath = []
    await loadCategories()
    await loadProducts(force: true, featuredCategoryID: id, search: search)
  }

  func navigateToCategory(level: Int, search: String = "") async {
    categoryPath = Array(categoryPath.prefix(max(0, level)))
    await loadCategories(parentID: categoryPath.last?.id)
    await loadProducts(force: true, categoryPath: categoryPath, search: search)
  }

  func resetCategoryPath(search: String = "") async {
    await navigateToCategory(level: 0, search: search)
  }

  func retryCategories() async {
    await loadCategories(parentID: categoryPath.last?.id)
  }

  func refreshCart() async {
    do {
      let state = try await NativeCommerceAPI.fetchCart()
      isSignedIn = state.isSignedIn
      cartSubtotal = state.subtotal
      cart = state.quantities.reduce(into: [:]) { result, entry in
        guard entry.value > 0,
              let product = products.first(where: { $0.id == entry.key }) else { return }
        result[entry.key] = CartItem(product: product, quantity: NSDecimalNumber(decimal: entry.value).intValue)
      }
      let missingIDs = state.quantities.keys.filter { id in
        !products.contains(where: { $0.id == id })
      }
      for id in missingIDs {
        let missing = try await NativeCommerceAPI.fetchProducts(productID: id)
        guard let product = missing.first, let quantity = state.quantities[id] else { continue }
        products.append(product)
        cart[id] = CartItem(product: product, quantity: NSDecimalNumber(decimal: quantity).intValue)
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func addToCart(_ product: StoreProduct) async {
    do {
      try await NativeCommerceAPI.updateCart(productID: product.id, quantity: nil)
      await refreshCart()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func setQuantity(_ quantity: Int, for product: StoreProduct) async {
    do {
      try await NativeCommerceAPI.updateCart(productID: product.id, quantity: Decimal(max(0, quantity)))
      await refreshCart()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func removeFromCart(_ product: StoreProduct) {
    Task { await setQuantity(0, for: product) }
  }

  func signIn(username: String, password: String, remember: Bool) async -> Bool {
    do {
      try await NativeCommerceAPI.signIn(username: username, password: password, remember: remember)
      errorMessage = nil
      await loadProducts(force: true)
      await refreshCart()
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  func isFavorite(_ product: StoreProduct) -> Bool {
    favoriteIDs.contains(product.id)
  }

  func toggleFavorite(_ product: StoreProduct) {
    if favoriteIDs.contains(product.id) {
      favoriteIDs.remove(product.id)
    } else {
      favoriteIDs.insert(product.id)
    }
    UserDefaults.standard.set(Array(favoriteIDs), forKey: favoritesKey)
  }

  func clearError() {
    errorMessage = nil
  }
}

private enum NativeCommerceAPI {
  private static let baseURL = URL(string: "https://www.ucuzgetir.com/")!
  private static let decoder = JSONDecoder()

  private struct CatalogEnvelope: Decodable {
    let success: Bool
    let error: String?
    let categories: [StoreCategory]?
    let products: [StoreProduct]?
  }

  private struct CartEnvelope: Decodable {
    let basarili: Bool
    let hata: String?
    let miktarlar: [String: Decimal]?
    let sepetTutar: String?
    let girisYapildi: Bool?
  }

  private struct LoginEnvelope: Decodable {
    let basarili: Bool
    let hata: String?
  }

  static func fetchCategories(parentID: String? = nil) async throws -> [StoreCategory] {
    var query = [URLQueryItem(name: "action", value: "categories")]
    if let parentID { query.append(URLQueryItem(name: "parentId", value: parentID)) }
    let envelope: CatalogEnvelope = try await get(
      "NativeCatalog.ashx",
      query: query
    )
    guard envelope.success, let categories = envelope.categories else {
      throw APIError.server(envelope.error ?? "Kategoriler yüklenemedi.")
    }
    return categories
  }

  static func fetchProducts(
    categoryPath: [StoreCategory] = [],
    featuredCategoryID: String? = nil,
    search: String = "",
    productID: String? = nil,
    offset: Int = 0
  ) async throws -> [StoreProduct] {
    var query = [URLQueryItem(name: "action", value: "products")]
    if let featuredCategoryID {
      query.append(URLQueryItem(name: "categoryId", value: featuredCategoryID))
    }
    for category in categoryPath {
      query.append(URLQueryItem(name: "category\(category.level)", value: category.categoryCode))
    }
    if !search.isEmpty { query.append(URLQueryItem(name: "q", value: search)) }
    if let productID { query.append(URLQueryItem(name: "productId", value: productID)) }
    query.append(URLQueryItem(name: "offset", value: String(offset)))
    let envelope: CatalogEnvelope = try await get("NativeCatalog.ashx", query: query)
    guard envelope.success, let products = envelope.products else {
      throw APIError.server(envelope.error ?? "Ürünler yüklenemedi.")
    }
    return products
  }

  static func fetchCart() async throws -> (
    quantities: [String: Decimal],
    subtotal: String,
    isSignedIn: Bool
  ) {
    let envelope: CartEnvelope = try await postForm("SepetIslem.ashx", fields: ["islem": "durum"])
    guard envelope.basarili else {
      throw APIError.server(envelope.hata ?? "Sepet yüklenemedi.")
    }
    return (envelope.miktarlar ?? [:], envelope.sepetTutar ?? "", envelope.girisYapildi ?? false)
  }

  static func updateCart(productID: String, quantity: Decimal?) async throws {
    var fields = ["stokKodu": productID]
    if let quantity {
      fields["islem"] = "miktarAyarla"
      fields["miktar"] = NSDecimalNumber(decimal: quantity).stringValue
    } else {
      fields["islem"] = "ekle"
      fields["miktar"] = "1"
    }
    let envelope: CartEnvelope = try await postForm("SepetIslem.ashx", fields: fields)
    guard envelope.basarili else {
      throw APIError.server(envelope.hata ?? "Sepet güncellenemedi.")
    }
  }

  static func signIn(username: String, password: String, remember: Bool) async throws {
    let envelope: LoginEnvelope = try await postForm(
      "UyeGiris.ashx",
      fields: [
        "username": username,
        "password": password,
        "rememberMe": remember ? "1" : "0"
      ]
    )
    guard envelope.basarili else {
      throw APIError.server(envelope.hata ?? "Giriş yapılamadı.")
    }
  }

  private static func get<Value: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> Value {
    var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    components.queryItems = query
    var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return try await send(request)
  }

  private static func postForm<Value: Decodable>(_ path: String, fields: [String: String]) async throws -> Value {
    var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: 30)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
    request.httpBody = fields
      .map { formEncode($0.key) + "=" + formEncode($0.value) }
      .sorted()
      .joined(separator: "&")
      .data(using: .utf8)
    return try await send(request)
  }

  private static func send<Value: Decodable>(_ request: URLRequest) async throws -> Value {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw APIError.invalidResponse
    }
    guard (200...299).contains(response.statusCode) else {
      if let cart = try? decoder.decode(CartEnvelope.self, from: data), let error = cart.hata {
        throw APIError.server(error)
      }
      throw APIError.http(response.statusCode)
    }
    do {
      return try decoder.decode(Value.self, from: data)
    } catch {
      throw APIError.invalidData
    }
  }

  private static func formEncode(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._*")
    return value
      .addingPercentEncoding(withAllowedCharacters: allowed)?
      .replacingOccurrences(of: " ", with: "+") ?? ""
  }

  private enum APIError: LocalizedError {
    case invalidResponse
    case invalidData
    case http(Int)
    case server(String)

    var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Sunucudan geçerli bir yanıt alınamadı."
      case .invalidData: return "Sunucu yanıtı okunamadı."
      case .http(let status): return "İstek tamamlanamadı (HTTP \(status))."
      case .server(let message): return message
      }
    }
  }
}
