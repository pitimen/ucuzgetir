import SwiftUI
import WebKit

struct NativeStorePage: UIViewRepresentable {
  let path: String

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    context.coordinator.webView = webView
    context.coordinator.load(path: path)
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    guard context.coordinator.loadedPath != path else { return }
    context.coordinator.load(path: path)
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    weak var webView: WKWebView?
    fileprivate var loadedPath: String?

    func load(path: String) {
      guard let url = URL(string: path, relativeTo: URL(string: "https://www.ucuzgetir.com/")!)?.absoluteURL else {
        return
      }
      loadedPath = path
      guard let webView else { return }
      let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
      let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
      let group = DispatchGroup()
      for cookie in cookies {
        group.enter()
        cookieStore.setCookie(cookie) {
          group.leave()
        }
      }
      group.notify(queue: .main) { [weak self] in
        self?.webView?.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
      }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
        for cookie in cookies where cookie.domain.hasSuffix("ucuzgetir.com") {
          HTTPCookieStorage.shared.setCookie(cookie)
        }
      }
    }
  }
}
