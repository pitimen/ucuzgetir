import Combine
import Foundation

struct StoreProduct: Hashable, Identifiable, Sendable {
  let id: String
  let name: String
  let description: String
  let productURL: URL
  let imageURL: URL?
  let price: Double?
  let category: String

  var formattedPrice: String {
    guard let price else { return "Fiyatı mağazada görüntüleyin" }
    return price.formatted(.currency(code: "TRY").locale(Locale(identifier: "tr_TR")))
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
  @Published private(set) var products: [StoreProduct] = []
  @Published private(set) var cart: [String: CartItem] = [:]
  @Published private(set) var favoriteIDs: Set<String>
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?

  private var didLoadProducts = false
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
    if cart.values.contains(where: { $0.lineTotal == nil }) {
      return "Siparişte doğrulanacak"
    }
    return cartTotal.formatted(.currency(code: "TRY").locale(Locale(identifier: "tr_TR")))
  }

  func loadProducts(force: Bool = false) async {
    guard !isLoading, force || !didLoadProducts else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let loaded = try await ProductCatalogService.fetchProducts()
      products = loaded
      didLoadProducts = true
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func addToCart(_ product: StoreProduct) {
    var item = cart[product.id] ?? CartItem(product: product, quantity: 0)
    item.quantity += 1
    withAnimation(.easeInOut(duration: 0.18)) {
      cart[product.id] = item
    }
  }

  func setQuantity(_ quantity: Int, for product: StoreProduct) {
    guard quantity > 0 else {
      removeFromCart(product)
      return
    }
    guard var item = cart[product.id] else { return }
    item.quantity = quantity
    withAnimation(.easeInOut(duration: 0.18)) {
      cart[product.id] = item
    }
  }

  func removeFromCart(_ product: StoreProduct) {
    withAnimation(.easeInOut(duration: 0.18)) {
      cart.removeValue(forKey: product.id)
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
}

private enum ProductCatalogService {
  private static let feedURL = URL(string: "https://www.ucuzgetir.com/GoogleMerchant.aspx")!

  static func fetchProducts() async throws -> [StoreProduct] {
    var request = URLRequest(url: feedURL)
    request.timeoutInterval = 20
    request.setValue("application/rss+xml, application/xml", forHTTPHeaderField: "Accept")
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
      throw CatalogError.invalidResponse
    }

    return try await Task.detached(priority: .userInitiated) {
      try ProductCatalogService.parseFeed(data)
    }.value
  }

  private static func parseFeed(_ data: Data) throws -> [StoreProduct] {
    let delegate = ProductFeedParser()
    let parser = XMLParser(data: data)
    parser.shouldProcessNamespaces = true
    parser.delegate = delegate

    guard parser.parse() else {
      throw delegate.parseError ?? parser.parserError ?? CatalogError.invalidFeed
    }
    guard !delegate.products.isEmpty else {
      throw CatalogError.emptyCatalog
    }

    return delegate.products.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }
}

private enum CatalogError: LocalizedError {
  case invalidResponse
  case invalidFeed
  case emptyCatalog

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "Ürün kataloğu şu anda yanıt vermiyor. Lütfen yeniden deneyin."
    case .invalidFeed:
      return "Ürün kataloğu okunamadı. Lütfen daha sonra yeniden deneyin."
    case .emptyCatalog:
      return "Mağazada şu anda görüntülenecek ürün bulunamadı."
    }
  }
}

private final class ProductFeedParser: NSObject, XMLParserDelegate {
  private static let googleNamespace = "http://base.google.com/ns/1.0"
  private static let fields: Set<String> = [
    "id", "title", "description", "link", "image_link", "price", "product_type"
  ]

  private var currentProduct: [String: String]?
  private var currentField: String?
  private var fieldBuffer = ""
  private var productIDs = Set<String>()
  private(set) var products: [StoreProduct] = []
  private(set) var parseError: Error?

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    let name = Self.localName(elementName)
    if name == "item" {
      currentProduct = [:]
      return
    }

    guard currentProduct != nil,
          namespaceURI == Self.googleNamespace,
          Self.fields.contains(name) else { return }
    currentField = name
    fieldBuffer = ""
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    guard currentField != nil else { return }
    fieldBuffer += string
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    let name = Self.localName(elementName)
    if name == "item" {
      appendCurrentProduct()
      currentProduct = nil
      currentField = nil
      fieldBuffer = ""
      return
    }

    guard currentField == name else { return }
    currentProduct?[name] = fieldBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
    currentField = nil
    fieldBuffer = ""
  }

  func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
    self.parseError = parseError
  }

  private func appendCurrentProduct() {
    guard let fields = currentProduct,
          let id = fields["id"], !id.isEmpty,
          let name = fields["title"], !name.isEmpty,
          let rawProductURL = fields["link"],
          let productURL = URL(string: rawProductURL),
          productURL.scheme?.lowercased() == "https",
          ["ucuzgetir.com", "www.ucuzgetir.com"].contains(productURL.host?.lowercased() ?? "") else {
      return
    }
    guard productIDs.insert(id).inserted else { return }

    let imageURL = fields["image_link"]
      .flatMap { URL(string: $0) }
      .flatMap { $0.scheme?.lowercased() == "https" ? $0 : nil }
    let priceText = fields["price"]?.split(separator: " ").first.map(String.init) ?? ""
    let price = Double(priceText.replacingOccurrences(of: ",", with: "."))
    let categoryPath = fields["product_type"]?
      .split(separator: ">")
      .last
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

    let category = categoryPath.flatMap { $0.isEmpty ? nil : $0 } ?? "Ürünler"
    products.append(
      StoreProduct(
        id: id,
        name: name,
        description: fields["description"] ?? name,
        productURL: productURL,
        imageURL: imageURL,
        price: price,
        category: category
      )
    )
  }

  private static func localName(_ qualifiedName: String) -> String {
    qualifiedName.split(separator: ":").last.map(String.init) ?? qualifiedName
  }
}
