import SwiftUI

private enum ProfileField: Hashable {
  case email
  case password
}

private enum ProfileNotice: String, Identifiable {
  case signIn
  case registration
  case accountDeletion

  var id: String { rawValue }

  var title: String {
    switch self {
    case .signIn: return "Giriş servisi bağlı değil"
    case .registration: return "Üyelik servisi bağlı değil"
    case .accountDeletion: return "Hesap silme servisi bağlı değil"
    }
  }

  var message: String {
    switch self {
    case .signIn:
      return "Bu SwiftUI arayüzü için yerel kimlik doğrulama API'si henüz tanımlanmadı."
    case .registration:
      return "Hesap oluşturma işlemi native üyelik API'si bağlandıktan sonra kullanılabilir olacak."
    case .accountDeletion:
      return "Hesap silme talebi için güvenli hesap API'si ve sunucu tarafı işlem akışı henüz bağlanmadı."
    }
  }
}

struct ProfileView: View {
  @FocusState private var focusedField: ProfileField?
  @State private var email = ""
  @State private var password = ""
  @State private var rememberMe = true
  @State private var notice: ProfileNotice?

  var body: some View {
    ScrollViewReader { proxy in
      Form {
        Section {
          Text("Giriş yaparak siparişlerinizi ve hesabınızı yönetin. Üye olmadan da alışveriş yapabilirsiniz.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden)
        }

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
              notice = .signIn
            }

          Toggle("Beni hatırla", isOn: $rememberMe)

          Button("Giriş Yap") {
            focusedField = nil
            notice = .signIn
          }
          .frame(maxWidth: .infinity)
          .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
        }

        Section("Hesap İşlemleri") {
          Button {
            notice = .registration
          } label: {
            Label("Üye Ol", systemImage: "person.badge.plus")
          }

          Button(role: .destructive) {
            notice = .accountDeletion
          } label: {
            Label("Hesap Silme Talebi", systemImage: "trash")
          }
        }

        Section("Yardım ve Bilgiler") {
          Link(destination: URL(string: "https://www.ucuzgetir.com/yardim-merkezi.aspx")!) {
            Label("Yardım ve müşteri hizmetleri", systemImage: "questionmark.circle")
          }
          Link(destination: URL(string: "https://www.ucuzgetir.com/gizlilik-politikasi.aspx")!) {
            Label("Gizlilik politikası", systemImage: "hand.raised")
          }
          Link(destination: URL(string: "https://www.ucuzgetir.com/kvkk.aspx")!) {
            Label("Kişisel veriler ve KVKK", systemImage: "lock.shield")
          }
          Link(destination: URL(string: "https://www.ucuzgetir.com/kullanim-kosullari.aspx")!) {
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
    .alert(item: $notice) { value in
      Alert(
        title: Text(value.title),
        message: Text(value.message),
        dismissButton: .default(Text("Tamam"))
      )
    }
  }
}
