import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme.dart';

/// Generic hosted checkout WebView for providers such as Stripe Checkout.
/// It watches provider return URLs and lets the caller verify payment server-side.
class HostedCheckoutScreen extends StatefulWidget {
  final String title;
  final String pageUrl;
  final String successPrefix;
  final String failPrefix;
  final Future<bool> Function() onSuccess;

  const HostedCheckoutScreen({
    super.key,
    required this.title,
    required this.pageUrl,
    required this.successPrefix,
    required this.failPrefix,
    required this.onSuccess,
  });

  @override
  State<HostedCheckoutScreen> createState() => _HostedCheckoutScreenState();
}

class _HostedCheckoutScreenState extends State<HostedCheckoutScreen> {
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
          if (req.url.startsWith(widget.successPrefix)) {
            _finish(true);
            return NavigationDecision.prevent;
          }
          if (req.url.startsWith(widget.failPrefix)) {
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
      appBar: AppBar(title: Text(widget.title)),
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
