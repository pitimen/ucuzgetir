import SwiftUI

private enum ProfileField: Hashable {
  case email
  case password
}

struct ProfileView: View {
  @EnvironmentObject private var model: NativeStoreModel
  @FocusState private var focusedField: ProfileField?
  @State private var email = ""
  @State private var password = ""
  @State private var rememberMe = true

  var body: some View {
    ScrollViewReader { proxy in
      Form {
        Section {
          Text(model.isSignedIn
            ? "Oturumunuz açık. Sipariş ve hesap bilgilerinizi buradan yönetin."
            : "Giriş yaparak siparişlerinizi ve hesabınızı yönetin. Üye olmadan da alışveriş yapabilirsiniz.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden)
        }

        if !model.isSignedIn {
          Section("Giriş Yap") {
            TextField("E-posta veya cari kod", text: $email)
              .textContentType(.username)
              .keyboardType(.emailAddress)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .submitLabel(.next)
              .focused($focusedField, equals: .email)
              .id(ProfileField.email)
              .onSubmit {
                focusedField = .password
              }

            SecureField("Şifre", text: $password)
              .textContentType(.password)
              .submitLabel(.go)
              .focused($focusedField, equals: .password)
              .id(ProfileField.password)
              .onSubmit {
                focusedField = nil
                Task { await signIn() }
              }

            Toggle("Beni hatırla", isOn: $rememberMe)

            Button("Giriş Yap") {
              focusedField = nil
              Task { await signIn() }
            }
            .frame(maxWidth: .infinity)
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
          }
        }

        Section("Hesap İşlemleri") {
          Button {
            model.storePagePath = "Hesabim.aspx"
          } label: {
            Label("Hesap bilgilerim", systemImage: "person.text.rectangle")
          }
          Button {
            model.storePagePath = "siparislerim.aspx"
          } label: {
            Label("Siparişlerim", systemImage: "shippingbox")
          }
          Button {
            model.storePagePath = "uyeol.aspx"
          } label: {
            Label("Üye Ol", systemImage: "person.badge.plus")
          }

          Button(role: .destructive) {
            model.storePagePath = "HesapSil.aspx"
          } label: {
            Label("Hesap Silme Talebi", systemImage: "trash")
          }
        }

        Section("Yardım ve Bilgiler") {
          Button {
            model.storePagePath = "yardim-merkezi.aspx"
          } label: {
            Label("Yardım ve müşteri hizmetleri", systemImage: "questionmark.circle")
          }
          Button {
            model.storePagePath = "gizlilik-politikasi.aspx"
          } label: {
            Label("Gizlilik politikası", systemImage: "hand.raised")
          }
          Button {
            model.storePagePath = "kvkk.aspx"
          } label: {
            Label("Kişisel veriler ve KVKK", systemImage: "lock.shield")
          }
          Button {
            model.storePagePath = "kullanim-kosullari.aspx"
          } label: {
            Label("Kullanım koşulları", systemImage: "doc.text")
          }
        }

        Section {
          Text("Sipariş ve fatura kayıtları yasal saklama süreleri boyunca korunabilir.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("Hesabım")
      .navigationBarTitleDisplayMode(.large)
      .onChange(of: focusedField) { field in
        guard let field else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
          proxy.scrollTo(field, anchor: .center)
        }
      }
    }
    .alert("Hesap", isPresented: errorBinding) {
      Button("Tamam", role: .cancel) { model.clearError() }
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  private func signIn() async {
    let username = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard await model.signIn(username: username, password: password, remember: rememberMe) else { return }
    focusedField = nil
    password = ""
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { model.errorMessage != nil },
      set: { if !$0 { model.clearError() } }
    )
  }
}
