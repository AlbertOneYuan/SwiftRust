import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Touch-only trackpad. Physical mice continue through the outer input region.
class TrackpadRegion extends StatefulWidget {
  const TrackpadRegion({
    super.key,
    required this.child,
    required this.onMove,
    required this.onClick,
    required this.onDoubleClick,
    required this.onSecondaryClick,
    required this.onDragDown,
    required this.onDragUp,
    required this.onScroll,
    required this.onScale,
  });

  final Widget child;
  final void Function(Offset delta, Offset position) onMove;
  final VoidCallback onClick;
  final VoidCallback onDoubleClick;
  final VoidCallback onSecondaryClick;
  final VoidCallback onDragDown;
  final VoidCallback onDragUp;
  final void Function(int x, int y) onScroll;
  final void Function(double scale, Offset focalPoint) onScale;

  @override
  State<TrackpadRegion> createState() => _TrackpadRegionState();
}

class _TrackpadRegionState extends State<TrackpadRegion> {
  final Map<int, Offset> _pointers = {};
  final Map<int, Offset> _positions = {};
  bool _pinching = false;
  bool _scrolling = false;
  double _lastScale = 1;
  int _maxPointers = 0;
  Duration _started = Duration.zero;
  bool _tap = false;
  bool _dragging = false;
  Offset _dragPosition = Offset.zero;
  Offset _scroll = Offset.zero;

  void _releaseDrag() {
    if (!_dragging) return;
    _dragging = false;
    widget.onDragUp();
  }

  void _down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    if (_pointers.isEmpty) {
      _maxPointers = 0;
      _started = event.timeStamp;
      _tap = true;
      _scroll = Offset.zero;
    }
    _pointers[event.pointer] = event.position;
    _positions[event.pointer] = event.position;
    if (_pointers.length > _maxPointers) _maxPointers = _pointers.length;
    if (_maxPointers > 1) _releaseDrag();
  }

  void _move(PointerMoveEvent event) {
    if (_positions.containsKey(event.pointer)) {
      _positions[event.pointer] = event.position;
    }
    final origin = _pointers[event.pointer];
    if (origin != null && (event.position - origin).distance > kTouchSlop) {
      _tap = false;
    }
  }

  void _up(PointerEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    if (event is PointerCancelEvent) _tap = false;
    _pointers.remove(event.pointer);
    _positions.remove(event.pointer);
    if (_pointers.isEmpty) {
      _releaseDrag();
      if (_tap &&
          _maxPointers == 2 &&
          event.timeStamp - _started < kLongPressTimeout) {
        widget.onSecondaryClick();
      }
    }
  }

  @override
  void dispose() {
    _releaseDrag();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        supportedDevices: const {PointerDeviceKind.touch},
        onTap: () {
          if (_maxPointers == 1) widget.onClick();
        },
        onDoubleTap: () {
          if (_maxPointers == 1) {
            widget.onDoubleClick();
          }
        },
        onLongPressStart: (details) {
          if (_maxPointers != 1 || _pointers.length != 1) return;
          _tap = false;
          _dragPosition = details.localPosition;
          _dragging = true;
          widget.onDragDown();
        },
        onLongPressMoveUpdate: (details) {
          if (!_dragging) return;
          final delta = details.localPosition - _dragPosition;
          _dragPosition = details.localPosition;
          widget.onMove(delta, details.localPosition);
        },
        onLongPressEnd: (_) => _releaseDrag(),
        onScaleStart: (_) {
          _pinching = false;
          _scrolling = false;
          _lastScale = 1;
          _scroll = Offset.zero;
        },
        onScaleUpdate: (details) {
          if (_maxPointers == 1 && details.pointerCount == 1) {
            widget.onMove(details.focalPointDelta, details.localFocalPoint);
          } else if (details.pointerCount == 2) {
            if (!_pinching && !_scrolling && _pointers.length == 2) {
              final ids = _pointers.keys.toList();
              final a = _positions[ids[0]]! - _pointers[ids[0]]!;
              final b = _positions[ids[1]]! - _pointers[ids[1]]!;
              final bothMoved = a.distance > 4 && b.distance > 4;
              final opposite = a.dx * b.dx + a.dy * b.dy < 0;
              final anchored =
                  (a.distance < 4 && b.distance > kTouchSlop * 2) ||
                      (b.distance < 4 && a.distance > kTouchSlop * 2);
              // Wait for both fingers before classifying sequential pointer events.
              _pinching = (details.scale - 1).abs() > 0.08 &&
                  ((bothMoved && opposite) || anchored);
              _scrolling = bothMoved && !opposite;
            }
            if (_pinching) {
              _tap = false;
              widget.onScale(details.scale / _lastScale, details.focalPoint);
              _lastScale = details.scale;
              return;
            }
            if (!_scrolling) return;
            // Keep sub-step motion so slow scrolling is not lost.
            _scroll += details.focalPointDelta / 20;
            final x = _scroll.dx.truncate();
            final y = _scroll.dy.truncate();
            _scroll -= Offset(x.toDouble(), y.toDouble());
            if (x != 0 || y != 0) widget.onScroll(x, y);
          }
        },
        child: widget.child,
      ),
    );
  }
}
