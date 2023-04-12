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
    this.onTapDragZoomStart,
    this.onTapDragZoomUpdate,
    this.onTapDragZoomEnd,
    this.behavior,
  }) : super(key: key);

  final GestureTapDownCallback? onDoubleTapDown;
  final GestureDoubleTapCallback? onDoubleTap;
  final GestureTapCancelCallback? onDoubleTapCancel;

  final HitCornersDetector? hitDetector;

  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;

  final GestureTapUpCallback? onTapUp;
  final GestureTapDownCallback? onTapDown;

  final GestureTapDragZoomStartCallback? onTapDragZoomStart;
  final GestureTapDragZoomUpdateCallback? onTapDragZoomUpdate;
  final GestureTapDragZoomEndCallback? onTapDragZoomEnd;

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

    if (onDoubleTapDown != null || onDoubleTap != null || onDoubleTapCancel != null) {
      gestures[DoubleTapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
        () => DoubleTapGestureRecognizer(debugOwner: this),
        (DoubleTapGestureRecognizer instance) {
          instance
            ..onDoubleTapDown = onDoubleTapDown
            ..onDoubleTap = onDoubleTap
            ..onDoubleTapCancel = onDoubleTapCancel;
        },
      );
    }

    if (onTapDragZoomStart != null || onTapDragZoomUpdate != null || onTapDragZoomEnd != null) {
      gestures[TapDragZoomGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapDragZoomGestureRecognizer>(
            () => TapDragZoomGestureRecognizer(debugOwner: this),
            (TapDragZoomGestureRecognizer instance) {
          instance
            ..onStart = onTapDragZoomStart
            ..onUpdate = onTapDragZoomUpdate
            ..onEnd = onTapDragZoomEnd;
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
    final PhotoViewGestureDetectorScope? scope =
        context.dependOnInheritedWidgetOfExactType<PhotoViewGestureDetectorScope>();
    return scope;
  }

  final Axis? axis;

  @override
  bool updateShouldNotify(PhotoViewGestureDetectorScope oldWidget) {
    return axis != oldWidget.axis;
  }
}

typedef GestureTapDragZoomStartCallback = void Function(TapDragZoomStartDetails details);
typedef GestureTapDragZoomUpdateCallback = void Function(TapDragZoomUpdateDetails details);
typedef GestureTapDragZoomEndCallback = void Function(TapDragZoomEndDetails details);

class TapDragZoomStartDetails {
  TapDragZoomStartDetails({this.point = Offset.zero});

  final Offset point;

  @override
  String toString() {
    return 'TapDragZoomStartDetails{point: $point}';
  }
}

class TapDragZoomUpdateDetails {
  TapDragZoomUpdateDetails({this.point = Offset.zero, this.pointDelta = Offset.zero});

  final Offset point;
  final Offset pointDelta;

  @override
  String toString() {
    return 'TapDragZoomUpdateDetails{point: $point, pointDelta: $pointDelta}';
  }
}

class TapDragZoomEndDetails {
  TapDragZoomEndDetails({this.velocity = Velocity.zero});

  final Velocity velocity;

  @override
  String toString() => 'ScaleEndDetails(velocity: $velocity)';
}

class TapDragZoomGestureRecognizer extends GestureRecognizer {
  TapDragZoomGestureRecognizer({
    Object? debugOwner,
    PointerDeviceKind? kind,
    this.onStart,
    this.onUpdate,
    this.onEnd,
  }) : super(debugOwner: debugOwner);

  GestureTapDragZoomStartCallback? onStart;
  GestureTapDragZoomUpdateCallback? onUpdate;
  GestureTapDragZoomEndCallback? onEnd;

  final Map<int, PointerDownEvent> _trackedPointers = <int, PointerDownEvent>{};
  final Map<int, GestureArenaEntry> _entries = <int, GestureArenaEntry>{};

  PointerDownEvent? _firstTap;
  GestureArenaEntry? _firstTapEntry;
  Timer? _doubleTapDownTimer;

  VelocityTracker? _velocityTracker;
  final Map<Duration, Offset> _pendingDragOffset = <Duration, Offset>{};
  bool _isScaling = false;

  Offset? previousPosition;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_isScaling) {
      return;
    }

    if (_firstTap != null) {
      if (!_isWithinGlobalTolerance(_firstTap!.localPosition, event, kTouchSlop)) {
        return;
      } else {
        _checkStart();
        _velocityTracker = VelocityTracker.withKind(event.kind);
      }
    }

    _trackTap(event);
  }

  void _trackTap(PointerDownEvent event) {
    _stopSecondTapDownTimer();
    _trackedPointers[event.pointer] = event;
    _entries[event.pointer] = GestureBinding.instance.gestureArena.add(event.pointer, this);
    GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent, event.transform);
  }

  void _handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      if (_firstTap == null) {
        _registerFirstTap(event.pointer);
      } else {
        _checkEnd();
        _reset();
      }
    } else if (event is PointerMoveEvent) {
      if (_firstTap == null) {
        if (!_isWithinGlobalTolerance(_trackedPointers[event.pointer]!.localPosition, event, kTouchSlop)) {
          _reset();
        }
      } else {
        if (_isScaling) {
          _checkUpdate(event.localPosition);
          previousPosition = event.localPosition;
          _velocityTracker!.addPosition(event.timeStamp, event.localPosition);
        } else {
          _pendingDragOffset[event.timeStamp] = event.localPosition;
          _firstTapEntry!.resolve(GestureDisposition.accepted);
          _entries[event.pointer]!.resolve(GestureDisposition.accepted);
        }
      }
    } else if (event is PointerCancelEvent) {
      if (_isScaling) {
        _checkEnd();
      }
      _reset();
    }
  }

  void _registerFirstTap(int pointer) {
    _startDoubleTapTimer();

    GestureBinding.instance.gestureArena.hold(pointer);
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _handleEvent);
    _firstTap = _trackedPointers.remove(pointer);
    _firstTapEntry = _entries.remove(pointer);

    previousPosition = _firstTap!.localPosition;
  }

  void _reset() {
    _stopSecondTapDownTimer();

    if (_trackedPointers.isNotEmpty) {
      final Map<int, PointerDownEvent> trackedPointers = Map.from(_trackedPointers);
      final Map<int, GestureArenaEntry> entries = Map.from(_entries);

      _trackedPointers.clear();
      _entries.clear();

      for (int pointer in trackedPointers.keys) {
        GestureBinding.instance.pointerRouter.removeRoute(pointer, _handleEvent);
        entries[pointer]!.resolve(GestureDisposition.rejected);
      }
    }

    if (_firstTap != null) {
      final PointerDownEvent firstTap = _firstTap!;
      final GestureArenaEntry firstTapEntry = _firstTapEntry!;
      _firstTap = null;
      _firstTapEntry = null;

      firstTapEntry.resolve(GestureDisposition.rejected);
      GestureBinding.instance.gestureArena.release(firstTap.pointer);
    }

    _velocityTracker = null;
    _pendingDragOffset.clear();
    _isScaling = false;
    previousPosition = null;
  }

  void _startDoubleTapTimer() {
    _doubleTapDownTimer ??= Timer(kDoubleTapTimeout, _reset);
  }

  void _stopSecondTapDownTimer() {
    if (_doubleTapDownTimer != null) {
      _doubleTapDownTimer!.cancel();
      _doubleTapDownTimer = null;
    }
  }

  void _checkStart() {
    if (onStart != null) {
      final TapDragZoomStartDetails details = TapDragZoomStartDetails(point: _firstTap!.localPosition);
      invokeCallback<void>('onStart', () => onStart!(details));
    }
  }

  void _checkEnd() {
    final VelocityEstimate? estimate = _velocityTracker?.getVelocityEstimate();
    final Velocity velocity = Velocity(pixelsPerSecond: estimate?.pixelsPerSecond ?? Offset.zero)
        .clampMagnitude(kMinFlingVelocity, kMaxFlingVelocity);
    final TapDragZoomEndDetails details = TapDragZoomEndDetails(velocity: velocity);
    invokeCallback<void>('onEnd', () => onEnd!(details));
  }

  void _checkUpdate(Offset currentPosition) {
    if (onUpdate != null) {
      final TapDragZoomUpdateDetails details = TapDragZoomUpdateDetails(
        point: currentPosition,
        pointDelta: previousPosition != null ? currentPosition - previousPosition! : Offset.zero,
      );
      invokeCallback<void>('onUpdate', () => onUpdate!(details));
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (_firstTap == null) {
      return;
    }

    if (_pendingDragOffset.isEmpty) {
      return;
    }

    _isScaling = true;

    _checkUpdate(_pendingDragOffset.values.first);
    previousPosition = _pendingDragOffset.values.first;
    _pendingDragOffset.forEach((key, value) {
      _velocityTracker!.addPosition(key, value);
    });
    _pendingDragOffset.clear();
  }

  @override
  void rejectGesture(int pointer) {
    _reset();
  }

  bool _isWithinGlobalTolerance(Offset initialPosition, PointerEvent event, double tolerance) {
    final Offset offset = event.localPosition - initialPosition;
    return offset.distance <= tolerance;
  }

  @override
  String get debugDescription => 'My';
}
