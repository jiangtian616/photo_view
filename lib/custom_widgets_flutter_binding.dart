library custom_widgets_flutter_binding;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class CustomGestureArenaManager extends GestureArenaManager {
  final Map<int, int> holdCount = <int, int>{};

  @override
  void hold(int pointer) {
    final int oldValue = holdCount[pointer] ?? 0;
    holdCount[pointer] = oldValue + 1;

    if (debugPrintGestureArenaDiagnostics) {
      debugPrint(
          'Gesture arena ${pointer.toString().padRight(4)} ❙ hold 1 count. Current count: ${holdCount[pointer]}');
    }

    super.hold(pointer);
  }

  @override
  void release(int pointer) {
    final int oldValue = holdCount[pointer] ?? 1;
    holdCount[pointer] = oldValue - 1;

    if (debugPrintGestureArenaDiagnostics) {
      debugPrint(
          'Gesture arena ${pointer.toString().padRight(4)} ❙ Releasing 1 count. Current count: ${holdCount[pointer]}');
    }

    if (holdCount[pointer] == 0) {
      holdCount.remove(pointer);
      super.release(pointer);
    }
  }
}

class CustomWidgetsFlutterBinding extends WidgetsFlutterBinding {
  static CustomWidgetsFlutterBinding get instance => BindingBase.checkInstance(_instance);
  static CustomWidgetsFlutterBinding? _instance;

  static CustomWidgetsFlutterBinding ensureInitialized() {
    if (CustomWidgetsFlutterBinding._instance == null) {
      CustomWidgetsFlutterBinding();
    }
    return CustomWidgetsFlutterBinding.instance;
  }

  @override
  final GestureArenaManager gestureArena = CustomGestureArenaManager();

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }
}

void runApp(Widget app) {
  CustomWidgetsFlutterBinding.ensureInitialized()
    ..scheduleAttachRootWidget(app)
    ..scheduleWarmUpFrame();
}
