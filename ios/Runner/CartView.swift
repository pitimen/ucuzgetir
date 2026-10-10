import SwiftUI

struct CartView: View {
  @EnvironmentObject private var model: NativeStoreModel
  @State private var showingCheckoutNotice = false

  var body: some View {
    List {
      if model.cartItems.isEmpty {
        ContentUnavailableCart()
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      } else {
        Section {
          ForEach(model.cartItems) { item in
            CartRow(item: item)
          }
          .onDelete { offsets in
            let items = model.cartItems
            for offset in offsets {
              model.removeFromCart(items[offset].product)
            }
          }
        } header: {
          Text("Sepetiniz")
        } footer: {
          Text("Fiyat ve stok bilgileri sipariş aşamasında mağazada doğrulanır.")
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("Sepetim")
    .navigationBarTitleDisplayMode(.large)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      checkoutBar
    }
    .alert("Sipariş adımı hazır değil", isPresented: $showingCheckoutNotice) {
      Button("Tamam", role: .cancel) {}
    } message: {
      Text("Native sipariş ve ödeme servisleri henüz bu uygulamaya bağlanmadı. Sepetiniz cihazda tutuluyor.")
    }
  }

  private var checkoutBar: some View {
    VStack(spacing: 10) {
      HStack {
        Text("Toplam")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        Text(model.formattedCartTotal)
          .font(.title3.weight(.semibold))
      }

      Button {
        showingCheckoutNotice = true
      } label: {
        Text("Siparişi Tamamla")
          .font(.headline)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(model.cartItems.isEmpty)
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background(.regularMaterial)
    .overlay(alignment: .top) {
      Divider()
    }
  }
}

private struct CartRow: View {
  @EnvironmentObject private var model: NativeStoreModel
  let item: CartItem

  var body: some View {
    HStack(spacing: 12) {
      ProductImage(url: item.product.imageURL)
        .frame(width: 64, height: 64)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .leading, spacing: 5) {
        Text(item.product.name)
          .font(.subheadline.weight(.medium))
          .lineLimit(2)
        Text(item.product.formattedPrice)
          .font(.caption)
          .foregroundStyle(.secondary)
        quantityControl
      }
      Spacer(minLength: 4)
      Text(item.formattedLineTotal)
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
    }
    .padding(.vertical, 5)
  }

  private var quantityControl: some View {
    HStack(spacing: 12) {
      Button {
        model.setQuantity(item.quantity - 1, for: item.product)
      } label: {
        Image(systemName: "minus.circle")
      }
      .accessibilityLabel("Adedi azalt")

      Text("\(item.quantity)")
        .font(.subheadline.monospacedDigit())
        .frame(minWidth: 18)
        .accessibilityLabel("Adet \(item.quantity)")

      Button {
        model.setQuantity(item.quantity + 1, for: item.product)
      } label: {
        Image(systemName: "plus.circle")
      }
      .accessibilityLabel("Adedi artır")
    }
    .buttonStyle(.plain)
    .foregroundStyle(.tint)
  }
}

private struct ContentUnavailableCart: View {
  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "cart")
        .font(.system(size: 36))
        .foregroundStyle(.secondary)
      Text("Sepetiniz boş")
        .font(.headline)
      Text("Mağazadan ürün eklediğinizde burada görünecek.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 56)
  }
}
