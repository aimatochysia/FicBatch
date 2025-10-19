import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

Future<void> goHome({
  required bool isWindows,
  required win.WebviewController? winController,
  required WebViewController? controller,
  required void Function(String) onUrlChange,
  required void Function() clearInput,
}) async {
  clearInput();
  const url = 'https://archiveofourown.org/';
  try {
    if (isWindows) {
      await winController?.loadUrl(url);
    } else {
      await controller?.loadRequest(Uri.parse(url));
    }
    onUrlChange(url);
  } catch (_) {}
}

Future<void> goBack({
  required bool isWindows,
  required win.WebviewController? winController,
  required WebViewController? controller,
  required void Function() clearInput,
}) async {
  clearInput();
  try {
    if (isWindows) {
      try {
        await winController?.goBack();
      } catch (_) {
        await winController?.executeScript('history.back()');
      }
    } else {
      if (await (controller?.canGoBack() ?? Future.value(false))) {
        await controller?.goBack();
      }
    }
  } catch (_) {}
}

Future<void> goForward({
  required bool isWindows,
  required win.WebviewController? winController,
  required WebViewController? controller,
  required void Function() clearInput,
}) async {
  clearInput();
  try {
    if (isWindows) {
      try {
        await winController?.goForward();
      } catch (_) {
        await winController?.executeScript('history.forward()');
      }
    } else {
      if (await (controller?.canGoForward() ?? Future.value(false))) {
        await controller?.goForward();
      }
    }
  } catch (_) {}
}

Future<void> refreshPage({
  required bool isWindows,
  required win.WebviewController? winController,
  required WebViewController? controller,
}) async {
  try {
    if (isWindows) {
      try {
        await winController?.reload();
      } catch (_) {
        await winController?.executeScript('location.reload()');
      }
    } else {
      await controller?.reload();
    }
  } catch (_) {}
}
