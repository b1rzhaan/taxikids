import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme.dart';

/// Halyk ePay hosted card form. The widget page is served by our backend
/// (real origin) so payment-api.js initialises correctly. On success the bank
/// redirects to [backLink]; we then run [onSuccess] to confirm server-side.
class HalykCheckoutScreen extends StatefulWidget {
  final String pageUrl;
  final String backLink;
  final String failLink;
  final Future<bool> Function() onSuccess;

  const HalykCheckoutScreen({
    super.key,
    required this.pageUrl,
    required this.backLink,
    required this.failLink,
    required this.onSuccess,
  });

  @override
  State<HalykCheckoutScreen> createState() => _HalykCheckoutScreenState();
}

class _HalykCheckoutScreenState extends State<HalykCheckoutScreen> {
  late final WebViewController _controller;
  bool _busy = false;
  bool _pageLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _pageLoading = false);
        },
        onNavigationRequest: (req) {
          if (req.url.startsWith(widget.backLink)) {
            _finish(true);
            return NavigationDecision.prevent;
          }
          if (req.url.startsWith(widget.failLink)) {
            _finish(false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.pageUrl));
  }

  Future<void> _finish(bool ok) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (!ok) {
      if (mounted) Navigator.pop(context, false);
      return;
    }
    try {
      final success = await widget.onSuccess();
      if (mounted) Navigator.pop(context, success);
    } catch (_) {
      if (mounted) Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оплата картой (Halyk)')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_busy || _pageLoading)
            Container(
              color: Colors.white,
              child: const Center(
                  child: CircularProgressIndicator(color: AppColors.brand)),
            ),
        ],
      ),
    );
  }
}
