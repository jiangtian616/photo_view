import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'photo_view_hit_corners.dart';

class PhotoViewGestureDetector extends StatelessWidget {
  const PhotoViewGestureDetector({
    Key? key,
    this.hitDetector,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onDoubleTapDown,
    this.onDoubleTap,
    this.onDoubleTapCancel,
    this.child,
    this.onTapUp,
    this.onTapDown,
    this.onZoomStart,
    this.onZoomUpdate,
    this.onZoomEnd,
    this.behavior,
  }) : super(key: key);

  final GestureTapDownCallback? onDoubleTapDown;
  final GestureDoubleTapCallback? onDoubleTap;
  final GestureTapCancelCallback? onDoubleTapCancel;

  final HitCornersDetector? hitDetector;

  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;

  final GestureTapDragZoomStartCallback? onZoomStart;
  final GestureTapDragZoomUpdateCallback? onZoomUpdate;
  final GestureTapDragZoomEndCallback? onZoomEnd;

  final GestureTapUpCallback? onTapUp;
  final GestureTapDownCallback? onTapDown;

  final Widget? child;

  final HitTestBehavior? behavior;

  @override
  Widget build(BuildContext context) {
    final scope = PhotoViewGestureDetectorScope.of(context);

    final Axis? axis = scope?.axis;

    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};

    if (onTapDown != null || onTapUp != null) {
      gestures[TapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp;
        },
      );
    }

    if (onDoubleTapDown != null ||
        onDoubleTap != null ||
        onDoubleTapCancel != null ||
        onZoomStart != null ||
        onZoomUpdate != null ||
        onZoomEnd != null) {
      gestures[DoubleTapAndTagDragZoomGestureRecognizer] = GestureRecognizerFactoryWithHandlers<DoubleTapAndTagDragZoomGestureRecognizer>(
        () => DoubleTapAndTagDragZoomGestureRecognizer(debugOwner: this, allowedButtonsFilter: (int button) => button == kPrimaryButton),
        (DoubleTapAndTagDragZoomGestureRecognizer instance) {
          instance
            ..onDoubleTapDown = onDoubleTapDown
            ..onDoubleTap = onDoubleTap
            ..onDoubleTapCancel = onDoubleTapCancel
            ..onZoomStart = onZoomStart
            ..onZoomUpdate = onZoomUpdate
            ..onZoomEnd = onZoomEnd;
        },
      );
    }

    gestures[PhotoViewGestureRecognizer] = GestureRecognizerFactoryWithHandlers<PhotoViewGestureRecognizer>(
      () => PhotoViewGestureRecognizer(hitDetector: hitDetector, debugOwner: this, validateAxis: axis),
      (PhotoViewGestureRecognizer instance) {
        instance
          ..dragStartBehavior = DragStartBehavior.start
          ..onStart = onScaleStart
          ..onUpdate = onScaleUpdate
          ..onEnd = onScaleEnd;
      },
    );

    return RawGestureDetector(
      behavior: behavior,
      child: child,
      gestures: gestures,
    );
  }
}

class PhotoViewGestureRecognizer extends ScaleGestureRecognizer {
  PhotoViewGestureRecognizer({
    this.hitDetector,
    Object? debugOwner,
    this.validateAxis,
    PointerDeviceKind? kind,
  }) : super(debugOwner: debugOwner);
  final HitCornersDetector? hitDetector;
  final Axis? validateAxis;

  Map<int, Offset> _pointerLocations = <int, Offset>{};

  Offset? _initialFocalPoint;
  Offset? _currentFocalPoint;

  bool ready = true;

  @override
  void addAllowedPointer(event) {
    if (ready) {
      ready = false;
      _pointerLocations = <int, Offset>{};
    }
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    ready = true;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (validateAxis != null) {
      _computeEvent(event);
      _updateDistances();
      _decideIfWeAcceptEvent(event);
    }
    super.handleEvent(event);
  }

  void _computeEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (!event.synthesized) {
        _pointerLocations[event.pointer] = event.position;
      }
    } else if (event is PointerDownEvent) {
      _pointerLocations[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocations.remove(event.pointer);
    }

    _initialFocalPoint = _currentFocalPoint;
  }

  void _updateDistances() {
    final int count = _pointerLocations.keys.length;
    Offset focalPoint = Offset.zero;
    for (int pointer in _pointerLocations.keys) focalPoint += _pointerLocations[pointer]!;
    _currentFocalPoint = count > 0 ? focalPoint / count.toDouble() : Offset.zero;
  }

  void _decideIfWeAcceptEvent(PointerEvent event) {
    if (!(event is PointerMoveEvent)) {
      return;
    }
    final move = _initialFocalPoint! - _currentFocalPoint!;
    final bool shouldMove = hitDetector!.shouldMove(move, validateAxis!);
    if (shouldMove || _pointerLocations.keys.length > 1) {
      acceptGesture(event.pointer);
    }
  }
}

typedef GestureTapDragZoomStartCallback = void Function(TapDragZoomStartDetails details);
typedef GestureTapDragZoomUpdateCallback = void Function(TapDragZoomUpdateDetails details);
typedef GestureTapDragZoomEndCallback = void Function();

class TapDragZoomStartDetails {
  TapDragZoomStartDetails({this.focalPoint = Offset.zero, Offset? localPoint}) : localPoint = localPoint ?? focalPoint;

  final Offset focalPoint;
  final Offset localPoint;

  @override
  String toString() {
    return 'TapDragZoomStartDetails{focalPoint: $focalPoint, localPoint: $localPoint}';
  }
}

class TapDragZoomUpdateDetails {
  TapDragZoomUpdateDetails({this.focalPoint = Offset.zero, Offset? localPoint, this.pointDelta = Offset.zero})
      : localPoint = localPoint ?? focalPoint;

  final Offset focalPoint;
  final Offset localPoint;
  final Offset pointDelta;

  @override
  String toString() {
    return 'TapDragZoomUpdateDetails{focalPoint: $focalPoint, localPoint: $localPoint, pointDelta: $pointDelta}';
  }
}

class DoubleTapAndTagDragZoomGestureRecognizer extends GestureRecognizer {
  DoubleTapAndTagDragZoomGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    this.onZoomStart,
    this.onZoomUpdate,
    this.onZoomEnd,
  });

  GestureTapDragZoomStartCallback? onZoomStart;
  GestureTapDragZoomUpdateCallback? onZoomUpdate;
  GestureTapDragZoomEndCallback? onZoomEnd;

  GestureTapDownCallback? onDoubleTapDown;
  GestureDoubleTapCallback? onDoubleTap;
  GestureTapCancelCallback? onDoubleTapCancel;

  Timer? _doubleTapTimer;
  _TapTracker? _firstTap;
  final Map<int, _TapTracker> _trackers = <int, _TapTracker>{};

  bool _isZooming = false;
  PointerMoveEvent? lastZoomingEvent;

  bool get enableDoubleTapZoom => onDoubleTapDown != null || onDoubleTap != null || onDoubleTapCancel != null;

  bool get enableTapDragZoom => onZoomStart != null || onZoomUpdate != null || onZoomEnd != null;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_firstTap == null) {
      if (!enableDoubleTapZoom && !enableTapDragZoom) {
        return false;
      }
    }

    // If second tap is not allowed, reset the state.
    final bool isPointerAllowed = super.isPointerAllowed(event);
    if (isPointerAllowed == false) {
      _reset();
    }
    return isPointerAllowed;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // Ignore new down event if we are zooming
    if (_isZooming) {
      return;
    }

    if (_firstTap != null) {
      if (!_firstTap!.isWithinGlobalTolerance(event, kDoubleTapSlop)) {
        // Ignore out-of-bounds second taps.
        return;
      } else if (!_firstTap!.hasElapsedMinTime() || !_firstTap!.hasSameButton(event)) {
        // Restart when the second tap is too close to the first (touch screens
        // often detect touches intermittently), or when buttons mismatch.
        _reset();
        return _trackTap(event);
      } else {
        _checkDown(event);
        _checkZoomStart();
      }
    }
    _trackTap(event);
  }

  void _trackTap(PointerDownEvent event) {
    _stopDoubleTapTimer();
    final _TapTracker tracker = _TapTracker(
      event: event,
      entry: GestureBinding.instance.gestureArena.add(event.pointer, this),
      doubleTapMinTime: kDoubleTapMinTime,
      gestureSettings: gestureSettings,
    );
    _trackers[event.pointer] = tracker;
    tracker.startTrackingPointer(_handleEvent, event.transform);
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker tracker = _trackers[event.pointer]!;
    if (event is PointerUpEvent) {
      if (_firstTap == null) {
        _registerFirstTap(tracker);
      } else if (_isZooming) {
        _endZooming(tracker);
      } else if (enableDoubleTapZoom) {
        _registerSecondTap(tracker);
      } else if (enableTapDragZoom) {
        /// use this new event as first tap and release the older one
        _reset();
        _registerFirstTap(tracker);
      }
    } else if (event is PointerMoveEvent) {
      if (_firstTap == null) {
        if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop)) {
          _reject(tracker);
        }
      } else if (_isZooming) {
        _updateZooming(event);
      } else if (enableTapDragZoom) {
        _beginZooming(tracker, event);
      } else {
        _reject(tracker);
      }
    } else if (event is PointerCancelEvent) {
      _reject(tracker);
    }
  }

  void _reject(_TapTracker tracker) {
    _trackers.remove(tracker.pointer);
    tracker.entry.resolve(GestureDisposition.rejected);
    _freezeTracker(tracker);
    if (_firstTap != null) {
      if (tracker == _firstTap) {
        _reset();
      } else {
        _checkCancel();
        if (_trackers.isEmpty) {
          _reset();
        }
      }
    }
  }

  void _reset() {
    _stopDoubleTapTimer();
    if (_firstTap != null) {
      if (_trackers.isNotEmpty) {
        _checkCancel();
      }
      // Note, order is important below in order for the resolve -> reject logic
      // to work properly.
      final _TapTracker tracker = _firstTap!;
      _firstTap = null;
      _reject(tracker);
      GestureBinding.instance.gestureArena.release(tracker.pointer);
    }
    _clearTrackers();
    _isZooming = false;
    lastZoomingEvent = null;
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _TapTracker? tracker = _trackers[pointer];
    // If tracker isn't in the list, check if this is the first tap tracker
    if (tracker == null && _firstTap != null && _firstTap!.pointer == pointer) {
      tracker = _firstTap;
    }
    // If tracker is still null, we rejected ourselves already
    if (tracker != null) {
      _reject(tracker);
    }
  }

  void _registerFirstTap(_TapTracker tracker) {
    _startDoubleTapTimer();
    GestureBinding.instance.gestureArena.hold(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _clearTrackers();
    _firstTap = tracker;
  }

  void _registerSecondTap(_TapTracker tracker) {
    _firstTap!.entry.resolve(GestureDisposition.accepted);
    tracker.entry.resolve(GestureDisposition.accepted);
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _checkUp(tracker.initialButtons);
    _reset();
  }

  void _beginZooming(_TapTracker tracker, PointerMoveEvent pointerMoveEvent) {
    _firstTap!.entry.resolve(GestureDisposition.accepted);
    tracker.entry.resolve(GestureDisposition.accepted);
    _trackers.values.toList().where((t) => t != tracker).forEach(_reject);
    _checkCancel();
    _isZooming = true;
    _checkZoomUpdate(pointerMoveEvent);
  }

  void _updateZooming(PointerMoveEvent pointerMoveEvent) {
    _checkZoomUpdate(pointerMoveEvent);
  }

  void _endZooming(_TapTracker tracker) {
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _checkZoomEnd();
    _reset();
  }

  void _clearTrackers() {
    _trackers.values.toList().forEach(_reject);
    assert(_trackers.isEmpty);
  }

  void _freezeTracker(_TapTracker tracker) {
    tracker.stopTrackingPointer(_handleEvent);
  }

  void _startDoubleTapTimer() {
    _doubleTapTimer ??= Timer(const Duration(milliseconds: 200), _reset);
  }

  void _stopDoubleTapTimer() {
    if (_doubleTapTimer != null) {
      _doubleTapTimer!.cancel();
      _doubleTapTimer = null;
    }
  }

  void _checkDown(PointerDownEvent pointerDownEvent) {
    if (onDoubleTapDown != null) {
      final TapDownDetails details = TapDownDetails(
        globalPosition: pointerDownEvent.position,
        localPosition: pointerDownEvent.localPosition,
        kind: getKindForPointer(pointerDownEvent.pointer),
      );
      invokeCallback<void>('onDoubleTapDown', () => onDoubleTapDown!(details));
    }
  }

  void _checkUp(int buttons) {
    assert(buttons == kPrimaryButton);
    if (onDoubleTap != null) {
      invokeCallback<void>('onDoubleTap', onDoubleTap!);
    }
  }

  void _checkCancel() {
    if (onDoubleTapCancel != null) {
      invokeCallback<void>('onDoubleTapCancel', onDoubleTapCancel!);
    }
  }

  void _checkZoomStart() {
    if (onZoomStart != null) {
      final TapDragZoomStartDetails details = TapDragZoomStartDetails(
        focalPoint: _firstTap!._initialGlobalPosition,
        localPoint: _firstTap!._initialLocalPosition,
      );
      invokeCallback<void>('onZoomStart', () => onZoomStart!(details));
    }
  }

  void _checkZoomUpdate(PointerMoveEvent pointerMoveEvent) {
    if (onZoomUpdate != null) {
      final TapDragZoomUpdateDetails details = TapDragZoomUpdateDetails(
        focalPoint: pointerMoveEvent.position,
        localPoint: pointerMoveEvent.localPosition,
        pointDelta: lastZoomingEvent == null ? Offset.zero : pointerMoveEvent.localPosition - lastZoomingEvent!.localPosition,
      );

      invokeCallback<void>('onZoomUpdate', () => onZoomUpdate!(details));
    }
    lastZoomingEvent = pointerMoveEvent;
  }

  void _checkZoomEnd() {
    if (onZoomEnd != null) {
      invokeCallback<void>('onZoomEnd', onZoomEnd!);
    }
  }

  @override
  String get debugDescription => 'double tap and tap drag zoom';
}

class _TapTracker {
  _TapTracker({
    required PointerDownEvent event,
    required this.entry,
    required Duration doubleTapMinTime,
    required this.gestureSettings,
  })  : assert(doubleTapMinTime != null),
        assert(event != null),
        assert(event.buttons != null),
        pointer = event.pointer,
        _initialGlobalPosition = event.position,
        _initialLocalPosition = event.localPosition,
        initialButtons = event.buttons,
        _doubleTapMinTimeCountdown = _CountdownZoned(duration: doubleTapMinTime);

  final DeviceGestureSettings? gestureSettings;
  final int pointer;
  final GestureArenaEntry entry;
  final Offset _initialGlobalPosition;
  final Offset _initialLocalPosition;
  final int initialButtons;
  final _CountdownZoned _doubleTapMinTimeCountdown;

  bool _isTrackingPointer = false;

  void startTrackingPointer(PointerRoute route, Matrix4? transform) {
    if (!_isTrackingPointer) {
      _isTrackingPointer = true;
      GestureBinding.instance.pointerRouter.addRoute(pointer, route, transform);
    }
  }

  void stopTrackingPointer(PointerRoute route) {
    if (_isTrackingPointer) {
      _isTrackingPointer = false;
      GestureBinding.instance.pointerRouter.removeRoute(pointer, route);
    }
  }

  bool isWithinGlobalTolerance(PointerEvent event, double tolerance) {
    final Offset offset = event.position - _initialGlobalPosition;
    return offset.distance <= tolerance;
  }

  bool hasElapsedMinTime() {
    return _doubleTapMinTimeCountdown.timeout;
  }

  bool hasSameButton(PointerDownEvent event) {
    return event.buttons == initialButtons;
  }
}

class _CountdownZoned {
  _CountdownZoned({required Duration duration}) : assert(duration != null) {
    Timer(duration, _onTimeout);
  }

  bool _timeout = false;

  bool get timeout => _timeout;

  void _onTimeout() {
    _timeout = true;
  }
}

/// An [InheritedWidget] responsible to give a axis aware scope to [PhotoViewGestureRecognizer].
///
/// When using this, PhotoView will test if the content zoomed has hit edge every time user pinches,
/// if so, it will let parent gesture detectors win the gesture arena
///
/// Useful when placing PhotoView inside a gesture sensitive context,
/// such as [PageView], [Dismissible], [BottomSheet].
///
/// Usage example:
/// ```
/// PhotoViewGestureDetectorScope(
///   axis: Axis.vertical,
///   child: PhotoView(
///     imageProvider: AssetImage("assets/pudim.jpg"),
///   ),
/// );
/// ```
class PhotoViewGestureDetectorScope extends InheritedWidget {
  PhotoViewGestureDetectorScope({
    this.axis,
    required Widget child,
  }) : super(child: child);

  static PhotoViewGestureDetectorScope? of(BuildContext context) {
    final PhotoViewGestureDetectorScope? scope = context.dependOnInheritedWidgetOfExactType<PhotoViewGestureDetectorScope>();
    return scope;
  }

  final Axis? axis;

  @override
  bool updateShouldNotify(PhotoViewGestureDetectorScope oldWidget) {
    return axis != oldWidget.axis;
  }
}
