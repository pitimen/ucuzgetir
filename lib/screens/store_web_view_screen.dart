import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StoreWebViewScreen extends StatefulWidget {
  const StoreWebViewScreen({
    required this.initialUrl,
    required this.title,
    super.key,
  });

  final Uri initialUrl;
  final String title;

  @override
  State<StoreWebViewScreen> createState() => _StoreWebViewScreenState();
}

class _StoreWebViewScreenState extends State<StoreWebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  String? _errorMessage;

  static const Set<String> _externalSchemes = {
    'tel',
    'mailto',
    'sms',
    'whatsapp',
    'intent',
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = progress;
              if (progress > 0) _errorMessage = null;
            });
          },
          onNavigationRequest: _handleNavigation,
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) return;
            setState(() {
              _errorMessage = 'Sayfa yüklenemedi. İnternet bağlantınızı kontrol edip yeniden deneyin.';
            });
          },
        ),
      )
      ..loadRequest(widget.initialUrl);
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    final scheme = uri.scheme.toLowerCase();
    final isWhatsApp =
        scheme == 'https' &&
        (uri.host == 'wa.me' || uri.host == 'api.whatsapp.com');
    if (_externalSchemes.contains(scheme) || isWhatsApp) {
      _openExternal(uri);
      return NavigationDecision.prevent;
    }

    if (scheme != 'https') {
      if (!mounted) return NavigationDecision.prevent;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güvenli olmayan bağlantı açılmadı.')),
      );
      return NavigationDecision.prevent;
    }

    if (uri.host.isEmpty) {
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı bu cihazda açılamadı.')),
        );
      }
    } on PlatformException catch (_, stackTrace) {
      developer.log(
        'Harici bağlantı açılamadı.',
        name: 'ucuzgetir.links',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılırken bir hata oluştu.')),
      );
    } on MissingPluginException catch (_, stackTrace) {
      developer.log(
        'Harici bağlantı eklentisi kullanılamıyor.',
        name: 'ucuzgetir.links',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı bu cihazda açılamadı.')),
      );
    }
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _errorMessage = null;
      _loadingProgress = 0;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Geri',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingProgress < 100)
            LinearProgressIndicator(
              value: _loadingProgress / 100,
              minHeight: 2,
            ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(errorMessage, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tekrar dene'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
