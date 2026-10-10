# UcuzGetir

## iOS

iPhone uygulaması SwiftUI ile oluşturulur; `AppDelegate.swift`, `ContentView.swift` içindeki native arayüzü başlatır. Mağaza, sepet ve hesap ekranları ayrı SwiftUI dosyalarındadır. Uygulamanın iOS akışında WebView kullanılmaz. Ürün kataloğu UcuzGetir HTTPS Merchant akışından native `URLSession`/`XMLParser` ile okunur; arama ve ürün detayları uygulama içinde gösterilir. Favoriler cihazda saklanır, sepet şu an yalnızca uygulama belleğinde tutulur.

Bu native iskelette hesap açma/girişi, hesap silme talebi, sunucuya senkronize sepet, sipariş ve ödeme servisleri henüz bağlı değildir. Bu ekranlardaki işlemler tamamlanmadan uygulama App Store incelemesine hazır kabul edilmemelidir. Yardım ve politika bağlantıları varsayılan iOS tarayıcısında açılır.

## Geliştirme

- iOS minimum sürümü iOS 16'dır ve Xcode hedef cihaz ailesi iPhone olarak ayarlanmıştır.
- iOS derlemesini macOS üzerinde Xcode (`Runner` scheme) veya imzalama için Appcircle ile doğrulayın.
- Android uygulaması Flutter kaynaklarını kullanmaya devam eder. Flutter analiz ve testleri için proje kökünde `flutter analyze` ve `flutter test` çalıştırın.
- iOS bundle ID `com.ucuzgetir.app`; bu App Store Connect kaydıyla eşleşmelidir.
- Sürüm ve derleme numarası `pubspec.yaml` içindeki `version` alanından yönetilir; App Store’a her yüklemede derleme numarasını artırın.

## Appcircle ve iOS imzalama

1. Appcircle iş akışını Flutter proje köküne (`ucuzgetir_app`) bağlayın.
2. iOS scheme olarak `Runner`, hedef cihaz ailesi olarak iPhone seçin.
3. App Store Connect’e gönderilecek her derlemede Apple Distribution sertifikası (`.p12`) ve `com.ucuzgetir.app` için App Store provisioning profile kullanın.
4. `.p12` parolasını, App Store Connect API anahtarını ve diğer sırları Appcircle’ın güvenli değişken/kimlik bilgisi alanlarında tutun; kaynak depoya veya bu uygulama paketine koymayın.
5. İmzalı `.ipa` dosyasını gerçek iPhone’da ve TestFlight üzerinden doğrulayın; ürün kataloğu, arama, ürün detayları, favoriler, sepet ve klavye davranışını test edin.

## App Store gönderim kontrolü

- Bu native iskelet kamera veya barkod taraması istemez.
- Favoriler yalnızca cihazda saklanır. Sepet, uygulama kapatılana kadar bellekte tutulur.
- Hesap, silme, sipariş ve ödeme servisleri bağlanıp gerçek cihazda uçtan uca test edilmeden build'i incelemeye göndermeyin.
- Canlı Merchant akışının kontrol edilen ürün kayıtları `ResimKucult.ashx` üzerinden JPEG görsel URL'leri ve fiyat verileri döndürüyor. Yayın öncesinde tam katalogdaki görsel, fiyat ve stok bilgisini yeniden doğrulayın.
- Gizlilik politikası: `https://www.ucuzgetir.com/gizlilik-politikasi.aspx`.
- App Store Connect’te veri toplama/gizlilik beyanını uygulamanın gerçek davranışıyla eşleştirin ve mağaza ekran görüntülerini hazırlayın.
