import SwiftUI

enum StoreTab: Hashable {
  case store
  case cart
  case profile
}

struct ContentView: View {
  @StateObject private var model = NativeStoreModel()
  @State private var selectedTab: StoreTab = .store

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack {
        StoreView()
      }
      .tabItem {
        Label("Mağaza", systemImage: "storefront.fill")
      }
      .tag(StoreTab.store)

      NavigationStack {
        CartView()
      }
      .tabItem {
        Label("Sepetim", systemImage: "cart.fill")
      }
      .badge(model.cartCount)
      .tag(StoreTab.cart)

      NavigationStack {
        ProfileView()
      }
      .tabItem {
        Label("Hesabım", systemImage: "person.fill")
      }
      .tag(StoreTab.profile)
    }
    .tint(.green)
    .environmentObject(model)
  }
}
