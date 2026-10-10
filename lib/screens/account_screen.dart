import 'package:flutter/material.dart';

import 'store_web_view_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static const String _site = 'www.ucuzgetir.com';

  void _openPage(BuildContext context, String path, String title) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StoreWebViewScreen(
          initialUrl: Uri.https(_site, path),
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesabım')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Text(
              'Giriş yaparak siparişlerinizi ve hesabınızı yönetin. Üye olmadan da alışveriş yapabilirsiniz.',
            ),
          ),
          _AccountLink(
            icon: Icons.login,
            title: 'Giriş yap',
            onTap: () => _openPage(context, '/uyegiris.aspx', 'Giriş yap'),
          ),
          _AccountLink(
            icon: Icons.person_add_alt_1,
            title: 'Üye ol',
            onTap: () => _openPage(context, '/uyeol.aspx', 'Üye ol'),
          ),
          _AccountLink(
            icon: Icons.receipt_long_outlined,
            title: 'Siparişlerim',
            onTap: () =>
                _openPage(context, '/siparislerim.aspx', 'Siparişlerim'),
          ),
          _AccountLink(
            icon: Icons.manage_accounts_outlined,
            title: 'Hesap bilgilerim',
            onTap: () =>
                _openPage(context, '/Hesabim.aspx', 'Hesap bilgilerim'),
          ),
          _AccountLink(
            icon: Icons.delete_outline,
            title: 'Hesap silme talebi',
            onTap: () =>
                _openPage(context, '/HesapSil.aspx', 'Hesap silme talebi'),
          ),
          const Divider(height: 20),
          _AccountLink(
            icon: Icons.support_agent,
            title: 'Yardım ve müşteri hizmetleri',
            onTap: () =>
                _openPage(context, '/yardim-merkezi.aspx', 'Yardım merkezi'),
          ),
          _AccountLink(
            icon: Icons.privacy_tip_outlined,
            title: 'Gizlilik politikası',
            onTap: () => _openPage(
              context,
              '/gizlilik-politikasi.aspx',
              'Gizlilik politikası',
            ),
          ),
          _AccountLink(
            icon: Icons.policy_outlined,
            title: 'Kişisel veriler ve KVKK',
            onTap: () =>
                _openPage(context, '/kvkk.aspx', 'Kişisel veriler ve KVKK'),
          ),
          _AccountLink(
            icon: Icons.description_outlined,
            title: 'Kullanım koşulları',
            onTap: () => _openPage(
              context,
              '/kullanim-kosullari.aspx',
              'Kullanım koşulları',
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Text(
              'Talebiniz müşteri hizmetlerine iletilir. Yasal olarak saklanması gereken sipariş ve fatura kayıtları korunabilir.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountLink extends StatelessWidget {
  const _AccountLink({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
