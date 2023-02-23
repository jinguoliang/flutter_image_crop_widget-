import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// just use this widget to display an image and a crop rect area
class ImageCropWidget extends StatefulWidget {
  /// load an image
  ImageCropWidget.editMode(ui.Image data,
      {required this.onUpdate, this.cropRatio = 0, this.cropAreaMinSize})
      : _imageData = data,
        canCrop = true,
        originImageSize = Size(data.width.toDouble(), data.height.toDouble());

  ImageCropWidget.justView(ui.Image data)
      : _imageData = data,
        canCrop = false,
        cropRatio = 1,
        cropAreaMinSize = null,
        onUpdate = null,
        originImageSize = Size(data.width.toDouble(), data.height.toDouble());

  /// After doing some operation, call onUpdate do update the crop rect
  final void Function(ui.Image, Rect)? onUpdate;

  final bool canCrop;

  final double cropRatio;
  final double? cropAreaMinSize;
  final ui.Image _imageData;
  final Size originImageSize;

  final _handleWidth = 40.0;
  final _handleLength = 40.0;
  final _minSize = 30;
  final _padding = 30;

  @override
  State<StatefulWidget> createState() {
    return _ImageCropWidgetState();
  }
}

/// touch operation type
enum TouchOperation { leftHandle, rightHandle, topHandle, bottomHandle, none }

class _ImageCropWidgetState extends State<ImageCropWidget>
    with TickerProviderStateMixin {
  ui.Image? _currentImage;

  var _imageRect = Rect.zero;

  bool _isAnimating = false;

  Rect _areaRect = Rect.zero;

  Rect _leftHandle() {
    return Rect.fromLTWH(
        _areaRect.left - widget._handleWidth / 2,
        _areaRect.center.dy - widget._handleLength / 2,
        widget._handleWidth,
        widget._handleLength);
  }

  Rect _rightHandle() {
    return Rect.fromLTWH(
        _areaRect.right - widget._handleWidth / 2,
        _areaRect.center.dy - widget._handleLength / 2,
        widget._handleWidth,
        widget._handleLength);
  }

  Rect _topHandle() {
    return Rect.fromLTWH(
        _areaRect.center.dx - widget._handleLength / 2,
        _areaRect.top - widget._handleWidth / 2,
        widget._handleLength,
        widget._handleWidth);
  }

  Rect _bottomHandle() {
    return Rect.fromLTWH(
        _areaRect.center.dx - widget._handleLength / 2,
        _areaRect.bottom - widget._handleWidth / 2,
        widget._handleLength,
        widget._handleWidth);
  }

  bool _isInLeftHandle(Offset offset) {
    return _leftHandle().contains(offset);
  }

  bool _isInRightHandle(Offset offset) {
    return _rightHandle().contains(offset);
  }

  bool _isInTopHandle(Offset offset) {
    return _topHandle().contains(offset);
  }

  bool _isInBottomHandle(Offset offset) {
    return _bottomHandle().contains(offset);
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant ImageCropWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._imageData != oldWidget._imageData) {
      _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ImageCropGestureDetect(
      state: this,
      onAreaRectUpdate: (area) {
        setState(() {
          _areaRect = area;
        });
      },
      onImageRectUpdate: (rect) {
        setState(() {
          _imageRect = rect;
        });
      },
      onEnd: (touchWhat) {
        if (touchWhat != TouchOperation.none) {
          _animScaleArea();
        } else {
          _animScaleImage();
        }
      },
      child: ClipRect(
        child: CustomPaint(
          painter: _CropperPainter(
              leftHandle: _leftHandle(),
              rightHandle: _rightHandle(),
              topHandle: _topHandle(),
              bottomHandle: _bottomHandle(),
              area: _areaRect,
              image: _currentImage,
              imageArea: _imageRect,
              imageRotation: 0,
              rotationFocalPoint: Offset.zero,
              canCrop: widget.canCrop),
        ),
      ),
    );
  }

  void _animScaleArea() async {
    final padding = widget._padding;
    final currentArea = _areaRect;
    final areaRatio = currentArea.width / currentArea.height;
    final containerSize = Size(context.size!.width - 2.0 * padding,
        context.size!.height - 2.0 * padding);
    final containerSizeRatio = (containerSize.width) / (containerSize.height);
    final dstRect;
    if (areaRatio > containerSizeRatio) {
      final destHeight = (containerSize.width) / areaRatio;
      dstRect = Rect.fromLTWH(
          padding.toDouble(),
          (containerSize.height - destHeight) / 2 + padding.toDouble(),
          containerSize.width,
          destHeight);
    } else {
      final destWidth = (containerSize.height) * areaRatio;
      dstRect = Rect.fromLTWH(
        (containerSize.width - destWidth) / 2 + padding.toDouble(),
        padding.toDouble(),
        destWidth,
        containerSize.height,
      );
    }

    var _lastImageRect = _imageRect;
    var _lastAreaRect = _areaRect;

    if (currentArea != dstRect) {
      _animScaleRect(
          begin: currentArea,
          end: dstRect,
          onUpdate: (c) {
            setState(() {
              final scale = c.width / _lastAreaRect.width;
              _areaRect = c;

              final cropRectMinSize = widget.cropAreaMinSize;
              // 一旦裁切图片的最小边＜ minSize, 就不在放大图片
              final cropWidthPercent = _areaRect.width / _lastImageRect.width;
              final cropImageWidth = cropWidthPercent * _imageOriginalWidth;
              final cropImageHeight =
                  cropImageWidth / (_areaRect.width / _areaRect.height);
              final fitMinSize = cropRectMinSize == null ||
                  cropImageWidth >= cropRectMinSize &&
                      cropImageHeight >= cropRectMinSize;
              if (fitMinSize) {
                _imageRect = _scaleRect(_lastImageRect, scale,
                    anchor: _lastAreaRect.center, newAnchor: c.center);
                _lastImageRect = _imageRect;
              }

              _lastAreaRect = _areaRect;
            });
          },
          onFinish: () {
            _animScaleImage();
          });

      _isAnimating = true;
    } else {
      _isAnimating = false;
      _updateCropImage();
    }
  }

  void _animScaleRect(
      {required Rect begin,
      required Rect end,
      required Function(Rect) onUpdate,
      required Function() onFinish}) {
    final anim = AnimationController(vsync: this);
    RectTween rectTween = RectTween(begin: begin, end: end);
    var rectAnim = rectTween.animate(anim);
    rectAnim.addListener(() {
      onUpdate(rectAnim.value!);
    });
    anim.duration = Duration(milliseconds: 200);
    anim.forward().then((value) {
      onFinish();
    });
  }

  /// 对一个 rect 缩放，可以指定缩放中心，缩放前后的中心可以不一样
  Rect _scaleRect(Rect rect, double scale,
      {Offset? anchor, Offset? newAnchor}) {
    anchor = anchor ?? rect.center;
    newAnchor = newAnchor ?? rect.center;
    return Rect.fromLTRB(
        newAnchor.dx - (anchor.dx - rect.left) * scale,
        newAnchor.dy - (anchor.dy - rect.top) * scale,
        newAnchor.dx - (anchor.dx - rect.right) * scale,
        newAnchor.dy - (anchor.dy - rect.bottom) * scale);
  }

  int _imageOriginalWidth = 0;

  void _loadImage() async {
    final padding = widget._padding;
    final image = widget._imageData;
    _imageOriginalWidth = image.width;
    final imageRatio = image.width / image.height;

    await Future.delayed(Duration.zero);
    final containerSize = context.size!;

    final containerSizeRatio = (containerSize.width - 2 * padding) /
        (containerSize.height - 2 * padding);
    final Rect imageRect;
    if (imageRatio > containerSizeRatio) {
      final destHeight = (containerSize.width - 2 * padding) / imageRatio;
      imageRect = Rect.fromLTWH(
          padding.toDouble(),
          (containerSize.height - destHeight) / 2,
          containerSize.width - 2 * padding,
          destHeight);
    } else {
      final destWidth = (containerSize.height - 2 * padding) * imageRatio;
      imageRect = Rect.fromLTWH(
        (containerSize.width - destWidth) / 2,
        padding.toDouble(),
        destWidth,
        containerSize.height - 2 * padding,
      );
    }

    var areaRect = imageRect;
    final cropRatio = widget.cropRatio;
    if (cropRatio != 0 && cropRatio != imageRatio) {
      if (cropRatio > imageRatio) {
        final destHeight = imageRect.width / cropRatio;
        areaRect = Rect.fromLTWH(
            imageRect.left,
            imageRect.top + (imageRect.height - destHeight) / 2,
            imageRect.width,
            destHeight);
      } else {
        final destWidth = imageRect.height * cropRatio;
        areaRect = Rect.fromLTWH(
          imageRect.left + (imageRect.width - destWidth) / 2,
          imageRect.top,
          destWidth,
          imageRect.height,
        );
      }
    }

    setState(() {
      _currentImage = image;
      _areaRect = areaRect;
      _imageRect = imageRect;
    });
  }

  void _updateCropImage() {
    final scale = _imageOriginalWidth / _imageRect.width;
    final rect = _imageRect;
    final area = _areaRect;
    final rectInImage = Rect.fromLTRB(
        (area.left - rect.left) * scale,
        (area.top - rect.top) * scale,
        (area.right - rect.left) * scale,
        (area.bottom - rect.top) * scale);
    widget.onUpdate?.call(_currentImage!, rectInImage);
  }

  void _animScaleImage() {
    final imageRatio = _imageRect.width / _imageRect.height;
    var area = _areaRect;
    final areaRatio = area.width / area.height;

    Rect targetImageRect = _imageRect;

    if (_imageRect.width - area.width < -0.001 ||
        _imageRect.height - area.height < -0.001) {
      if (imageRatio < areaRatio) {
        targetImageRect = _scaleRect(_imageRect, area.width / _imageRect.width);
      } else {
        targetImageRect =
            _scaleRect(_imageRect, area.height / _imageRect.height);
      }
    }
    final cropRectMinSize = widget.cropAreaMinSize;
    // 一旦裁切图片的最小边＜ minSize, 就不在放大图片
    final cropWidthPercent = area.width / _imageRect.width;
    final cropImageWidth = cropWidthPercent * _imageOriginalWidth;
    final cropImageHeight =
        cropImageWidth / (_areaRect.width / _areaRect.height);
    final fitMinSize = cropRectMinSize == null ||
        cropImageWidth >= cropRectMinSize && cropImageHeight >= cropRectMinSize;
    if (!fitMinSize) {
      final minEdge = min(cropImageWidth, cropImageHeight);
      final scaleCrop = cropRectMinSize! / minEdge;
      targetImageRect = _scaleRect(_imageRect, 1 / scaleCrop,
          anchor: area.center, newAnchor: area.center);
    }

    double offsetX = 0;
    double offsetY = 0;
    if (targetImageRect.left > area.left) {
      offsetX = area.left - targetImageRect.left;
    } else if (targetImageRect.right < area.right) {
      offsetX = area.right - targetImageRect.right;
    }
    if (targetImageRect.top > area.top) {
      offsetY = area.top - targetImageRect.top;
    } else if (targetImageRect.bottom < area.bottom) {
      offsetY = area.bottom - targetImageRect.bottom;
    }
    targetImageRect = targetImageRect.translate(offsetX, offsetY);

    if (_imageRect != targetImageRect) {
      _animScaleRect(
          begin: _imageRect,
          end: targetImageRect,
          onUpdate: (v) {
            setState(() {
              _imageRect = v;
            });
          },
          onFinish: () {
            _isAnimating = false;
            _updateCropImage();
          });
      _isAnimating = true;
    } else {
      _isAnimating = false;
      _updateCropImage();
    }
  }
}

class _ImageCropGestureDetect extends StatefulWidget {
  _ImageCropGestureDetect(
      {required this.child,
      required this.state,
      required this.onImageRectUpdate,
      required this.onAreaRectUpdate,
      required this.onEnd});

  final Widget child;
  final _ImageCropWidgetState state;
  final void Function(Rect) onImageRectUpdate;
  final void Function(Rect) onAreaRectUpdate;
  final void Function(TouchOperation) onEnd;

  @override
  State<StatefulWidget> createState() {
    return _ImageCropGestureDetectState();
  }
}

class _ImageCropGestureDetectState extends State<_ImageCropGestureDetect> {
  var touchWhat = TouchOperation.none;
  late Offset lastScaleFocal;
  late Rect lastImageRect;
  double lastScale = 1;
  int pointerCount = 0;
  bool onStartTrig = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onScaleStart: (startDetail) {
          if (widget.state._isAnimating) {
            return;
          }
          processScaleStart(
              startDetail.pointerCount, startDetail.localFocalPoint);
        },
        onScaleUpdate: (moveDetail) {
          if (!onStartTrig) {
            processScaleStart(
                moveDetail.pointerCount, moveDetail.localFocalPoint);
          }
          if (moveDetail.pointerCount != pointerCount) {
            pointerCount = moveDetail.pointerCount;
            lastScaleFocal = moveDetail.localFocalPoint;
            return;
          }
          final areaRect = widget.state._areaRect;
          final minSize = widget.state.widget._minSize;
          final padding = widget.state.widget._padding;

          if (touchWhat == TouchOperation.none) {
            // 拖拽移动
            final scale = moveDetail.scale / lastScale;
            final focalPoint = moveDetail.localFocalPoint;
            final newScale = scale;
            final imageRect = widget.state._scaleRect(lastImageRect, newScale,
                anchor: lastScaleFocal, newAnchor: focalPoint);
            widget.onImageRectUpdate(imageRect);
            lastImageRect = imageRect;
            lastScale = moveDetail.scale;
          } else {
            Rect area;
            final cropRatio = widget.state.widget.cropRatio;
            switch (touchWhat) {
              case TouchOperation.leftHandle:
                final newPos = areaRect.left +
                    (moveDetail.localFocalPoint.dx - lastScaleFocal.dx);
                area = areaRect.copy(left: newPos);
                if (cropRatio != 0) {
                  final h = area.width / cropRatio;
                  final dh = (h - area.height) / 2;
                  area =
                      area.copy(top: area.top - dh, bottom: area.bottom + dh);
                }
                break;
              case TouchOperation.rightHandle:
                final newPos = areaRect.right +
                    (moveDetail.localFocalPoint.dx - lastScaleFocal.dx);
                area = areaRect.copy(right: newPos);
                if (cropRatio != 0) {
                  final h = area.width / cropRatio;
                  final dh = (h - area.height) / 2;
                  area =
                      area.copy(top: area.top - dh, bottom: area.bottom + dh);
                }
                break;
              case TouchOperation.topHandle:
                final newPos = areaRect.top +
                    (moveDetail.localFocalPoint.dy - lastScaleFocal.dy);
                area = areaRect.copy(top: newPos);
                if (cropRatio != 0) {
                  final w = area.height * cropRatio;
                  final dw = (w - area.width) / 2;
                  area =
                      area.copy(left: area.left - dw, right: area.right + dw);
                }
                break;
              case TouchOperation.bottomHandle:
                final newPos = areaRect.bottom +
                    (moveDetail.localFocalPoint.dy - lastScaleFocal.dy);
                area = areaRect.copy(bottom: newPos);
                if (cropRatio != 0) {
                  final w = area.height * cropRatio;
                  final dw = (w - area.width) / 2;
                  area =
                      area.copy(left: area.left - dw, right: area.right + dw);
                }
                break;
              default:
                throw Exception("no such operation");
            }

            if (area.width >= minSize &&
                area.height >= minSize &&
                area.left >= padding &&
                area.top >= padding &&
                area.right <= context.size!.width - padding &&
                area.bottom <= context.size!.height - padding) {
              widget.onAreaRectUpdate(area);
            }
          }

          lastScaleFocal = moveDetail.localFocalPoint;
        },
        onScaleEnd: (endDetail) {
          if (widget.state._isAnimating) {
            return;
          }
          onStartTrig = false;
          widget.onEnd(touchWhat);
          touchWhat = TouchOperation.none;
        },
        child: widget.child);
  }

  void processScaleStart(int pointerCount, Offset localFocalPoint) {
    if (pointerCount == 1) {
      if (widget.state._isInLeftHandle(localFocalPoint)) {
        touchWhat = TouchOperation.leftHandle;
      }
      if (widget.state._isInRightHandle(localFocalPoint)) {
        touchWhat = TouchOperation.rightHandle;
      }
      if (widget.state._isInTopHandle(localFocalPoint)) {
        touchWhat = TouchOperation.topHandle;
      }
      if (widget.state._isInBottomHandle(localFocalPoint)) {
        touchWhat = TouchOperation.bottomHandle;
      }
    }
    lastScale = 1;
    lastImageRect = widget.state._imageRect;
    lastScaleFocal = localFocalPoint;
    pointerCount = pointerCount;
    onStartTrig = true;
  }
}

class _CropperPainter extends CustomPainter {
  _CropperPainter({
    required this.leftHandle,
    required this.rightHandle,
    required this.topHandle,
    required this.bottomHandle,
    required this.area,
    required this.image,
    required this.imageArea,
    required this.imageRotation,
    required this.rotationFocalPoint,
    required this.canCrop,
  });

  bool canCrop;
  Rect leftHandle;
  Rect rightHandle;
  Rect topHandle;
  Rect bottomHandle;
  Rect area;
  Rect imageArea;
  double imageRotation;
  Offset rotationFocalPoint;
  final ui.Image? image;

  final imagePaint = Paint()..color = Colors.tealAccent;
  final handlePaint = Paint()..color = Colors.white;
  final areaPaint = Paint()..color = Colors.black26;

  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      canvas.save();
      canvas.translate(rotationFocalPoint.dx, rotationFocalPoint.dy);
      canvas.rotate(imageRotation);
      canvas.translate(-rotationFocalPoint.dx, -rotationFocalPoint.dy);
      canvas.drawColor(Colors.black54, BlendMode.srcOver);

      canvas.drawImageRect(
          image!,
          Rect.fromLTWH(
              0, 0, image!.width.toDouble(), image!.height.toDouble()),
          imageArea,
          imagePaint);
      canvas.restore();
    }
    if (canCrop) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
      canvas.drawColor(Colors.black54, BlendMode.color);
      canvas.drawRect(area, areaPaint..blendMode = BlendMode.clear);
      canvas.restore();
      canvas.drawCircle(leftHandle.center, leftHandle.width / 2, handlePaint);
      canvas.drawCircle(rightHandle.center, rightHandle.width / 2, handlePaint);
      canvas.drawCircle(topHandle.center, topHandle.width / 2, handlePaint);
      canvas.drawCircle(
          bottomHandle.center, bottomHandle.width / 2, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

/// extension on rect
extension RectExtension on Rect {
  /// copy a rect
  Rect copy({double? left, double? top, double? right, double? bottom}) {
    return Rect.fromLTRB(left ?? this.left, top ?? this.top,
        right ?? this.right, bottom ?? this.bottom);
  }
}
