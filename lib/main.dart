import 'package:flutter/material.dart';

import 'screens/account_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/store_web_view_screen.dart';
import 'services/favorites_store.dart';
import 'services/product_catalog_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UcuzGetirApp());
}

class UcuzGetirApp extends StatelessWidget {
  const UcuzGetirApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF562A8C);

    return MaterialApp(
      title: 'UcuzGetir',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brandColor),
        scaffoldBackgroundColor: const Color(0xFFF9F8FC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFF9F8FC),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const StoreShell(),
    );
  }
}

class StoreShell extends StatefulWidget {
  const StoreShell({super.key});

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  late final ProductCatalogController _catalog;
  late final FavoritesStore _favorites;
  late final List<Widget?> _pages;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _catalog = ProductCatalogController(ProductCatalogService());
    _favorites = FavoritesStore();
    _pages = [_createPage(0), _createPage(1), null, null, null];
    _catalog.load();
    _favorites.load();
  }

  @override
  void dispose() {
    _catalog.dispose();
    _favorites.dispose();
    super.dispose();
  }

  Widget _createPage(int index) {
    switch (index) {
      case 0:
        return StoreWebViewScreen(
          initialUrl: Uri.https('www.ucuzgetir.com', '/Default.aspx'),
          title: 'Mağaza',
        );
      case 1:
        return CatalogScreen(
          controller: _catalog,
          favorites: _favorites,
          favoritesOnly: false,
        );
      case 2:
        return CatalogScreen(
          controller: _catalog,
          favorites: _favorites,
          favoritesOnly: true,
        );
      case 3:
        return StoreWebViewScreen(
          initialUrl: Uri.https('www.ucuzgetir.com', '/sepet.aspx'),
          title: 'Sepetim',
        );
      case 4:
        return const AccountScreen();
      default:
        throw RangeError.index(index, _pages, 'index');
    }
  }

  void _selectTab(int index) {
    if (_pages[index] == null) {
      _pages[index] = _createPage(index);
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [for (final page in _pages) page ?? const SizedBox.shrink()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Mağaza',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Ürünler',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoriler',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Sepet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Hesabım',
          ),
        ],
      ),
    );
  }
}
