import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageCropWidget extends StatefulWidget {
  ImageCropWidget.asset(this.assetPath, {required this.onUpdate})
      : imageFile = null;

  ImageCropWidget.file(this.imageFile, {required this.onUpdate})
      : assetPath = null;

  final void Function(ui.Image, Rect) onUpdate;

  final String? assetPath;
  final File? imageFile;

  final handleWidth = 20.0;
  final handleLength = 30.0;
  final minSize = 30;
  final padding = 20;

  @override
  State<StatefulWidget> createState() {
    return ImageCropWidgetState();
  }
}

enum TouchOperation { leftHandle, rightHandle, topHandle, bottomHandle, none }

class ImageCropWidgetState extends State<ImageCropWidget>
    with TickerProviderStateMixin {
  ui.Image? currentImage;

  var imageRect = Rect.zero;
  var imageRotation = 0.0;

  bool isAnimating = false;

  Rect areaRect = Rect.zero;

  Rect leftHandle() {
    return Rect.fromLTWH(
        areaRect.left - widget.handleWidth / 2,
        areaRect.center.dy - widget.handleLength / 2,
        widget.handleWidth,
        widget.handleLength);
  }

  Rect rightHandle() {
    return Rect.fromLTWH(
        areaRect.right - widget.handleWidth / 2,
        areaRect.center.dy - widget.handleLength / 2,
        widget.handleWidth,
        widget.handleLength);
  }

  Rect topHandle() {
    return Rect.fromLTWH(
        areaRect.center.dx - widget.handleLength / 2,
        areaRect.top - widget.handleWidth / 2,
        widget.handleLength,
        widget.handleWidth);
  }

  Rect bottomHandle() {
    return Rect.fromLTWH(
        areaRect.center.dx - widget.handleLength / 2,
        areaRect.bottom - widget.handleWidth / 2,
        widget.handleLength,
        widget.handleWidth);
  }

  bool isInLeftHandle(Offset offset) {
    return leftHandle().contains(offset);
  }

  bool isInRightHandle(Offset offset) {
    return rightHandle().contains(offset);
  }

  bool isInTopHandle(Offset offset) {
    return topHandle().contains(offset);
  }

  bool isInBottomHandle(Offset offset) {
    return bottomHandle().contains(offset);
  }

  @override
  void initState() {
    super.initState();
    loadImage();
  }

  @override
  void didUpdateWidget(covariant ImageCropWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageFile != oldWidget.imageFile) {
      loadImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ImageCropGestureDetect(
      state: this,
      onAreaRectUpdate: (area) {
        setState(() {
          areaRect = area;
        });
      },
      onImageRectUpdate: (rect) {
        setState(() {
          imageRect = rect;
        });
      },
      onEnd: (touchWhat) {
        if (touchWhat != TouchOperation.none) {
          animScaleArea();
        } else {
          animScaleImage();
        }
      },
      child: ClipRect(
        child: CustomPaint(
          painter: CropperPainter(
              leftHandle: leftHandle(),
              rightHandle: rightHandle(),
              topHandle: topHandle(),
              bottomHandle: bottomHandle(),
              area: areaRect,
              image: currentImage,
              imageArea: imageRect,
              imageRotation: 0,
              rotationFocalPoint: Offset.zero),
        ),
      ),
    );
  }

  void animScaleArea() async {
    final padding = widget.padding;
    final currentArea = areaRect;
    final ratio = currentArea.width / currentArea.height;
    final containerSize = context.size!;
    final containerSizeRatio = (containerSize.width - 2 * padding) /
        (containerSize.height - 2 * padding);
    final dstRect;
    if (ratio > containerSizeRatio) {
      final destHeight = (containerSize.width - 2 * padding) / ratio;
      dstRect = Rect.fromLTWH(
          padding.toDouble(),
          (containerSize.height - destHeight) / 2,
          containerSize.width - 2 * padding,
          destHeight);
    } else {
      final destWidth = (containerSize.height - 2 * padding) * ratio;
      dstRect = Rect.fromLTWH(
        (containerSize.width - destWidth) / 2,
        padding.toDouble(),
        destWidth,
        containerSize.height - 2 * padding,
      );
    }

    var lastImageRect = imageRect;
    var lastAreaRect = areaRect;

    animScaleRect(
        begin: currentArea,
        end: dstRect,
        onUpdate: (c) {
          setState(() {
            final scale = c.width / lastAreaRect.width;
            areaRect = c;

            bool isTooLarge =
                lastImageRect.width * scale / imageOriginalWidth > 5;
            if (!isTooLarge) {
              imageRect = scaleRect(lastImageRect, scale,
                  anchor: lastAreaRect.center, newAnchor: c.center);
              lastImageRect = imageRect;
            }
            lastAreaRect = areaRect;
          });
        },
        onFinish: () {
          animScaleImage();
        });

    isAnimating = true;
  }

  void animScaleRect(
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

  Rect scaleRect(Rect rect, double scale, {Offset? anchor, Offset? newAnchor}) {
    anchor = anchor ?? rect.center;
    newAnchor = newAnchor ?? rect.center;
    return Rect.fromLTRB(
        newAnchor.dx - (anchor.dx - rect.left) * scale,
        newAnchor.dy - (anchor.dy - rect.top) * scale,
        newAnchor.dx - (anchor.dx - rect.right) * scale,
        newAnchor.dy - (anchor.dy - rect.bottom) * scale);
  }

  int imageOriginalWidth = 0;

  void loadImage() async {
    final padding = widget.padding;
    final image = widget.assetPath != null
        ? await loadImageAsset(widget.assetPath!)
        : await loadImageFile(widget.imageFile!);
    imageOriginalWidth = image.width;
    final ratio = image.width / image.height;
    print('ratio: $ratio');
    final containerSize = context.size!;
    print('container: ${context.size!}');
    final containerSizeRatio = (containerSize.width - 2 * padding) /
        (containerSize.height - 2 * padding);
    final c;
    if (ratio > containerSizeRatio) {
      final destHeight = (containerSize.width - 2 * padding) / ratio;
      c = Rect.fromLTWH(
          padding.toDouble(),
          (containerSize.height - destHeight) / 2,
          containerSize.width - 2 * padding,
          destHeight);
    } else {
      final destWidth = (containerSize.height - 2 * padding) * ratio;
      c = Rect.fromLTWH(
        (containerSize.width - destWidth) / 2,
        padding.toDouble(),
        destWidth,
        containerSize.height - 2 * padding,
      );
    }
    setState(() {
      currentImage = image;
      areaRect = c;
      imageRect = c;
    });
  }

  void updateCropImage() {
    final scale = imageOriginalWidth / imageRect.width;
    final rect = imageRect;
    final area = areaRect;
    final rectInImage = Rect.fromLTRB(
        (area.left - rect.left) * scale,
        (area.top - rect.top) * scale,
        (area.right - rect.left) * scale,
        (area.bottom - rect.top) * scale);
    widget.onUpdate(currentImage!, rectInImage);
  }

  void animScaleImage() {
    final imageRatio = imageRect.width / imageRect.height;
    var area = areaRect;
    final areaRatio = area.width / area.height;

    Rect targetImageRect = imageRect;

    if (imageRect.width - area.width < -0.001 ||
        imageRect.height - area.height < -0.001) {
      if (imageRatio < areaRatio) {
        targetImageRect = scaleRect(imageRect, area.width / imageRect.width);
      } else {
        targetImageRect = scaleRect(imageRect, area.height / imageRect.height);
      }
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

    animScaleRect(
        begin: imageRect,
        end: targetImageRect,
        onUpdate: (v) {
          setState(() {
            imageRect = v;
          });
        },
        onFinish: () {
          isAnimating = false;
          updateCropImage();
        });
    isAnimating = true;
  }
}

Future<ui.Image> loadImageAsset(String path) async {
  final imageData = (await rootBundle.load(path)).buffer.asUint8List();
  final codec = await ui.instantiateImageCodec(imageData);
  final image = (await codec.getNextFrame()).image;
  return image;
}

Future<ui.Image> loadImageFile(File path) async {
  print('path:  $path');
  final imageData = path.readAsBytesSync();
  final codec = await ui.instantiateImageCodec(imageData);
  final image = (await codec.getNextFrame()).image;
  print('image: $image');
  return image;
}

class ImageCropGestureDetect extends StatefulWidget {
  ImageCropGestureDetect(
      {required this.child,
      required this.state,
      required this.onImageRectUpdate,
      required this.onAreaRectUpdate,
      required this.onEnd});

  final Widget child;
  final ImageCropWidgetState state;
  final void Function(Rect) onImageRectUpdate;
  final void Function(Rect) onAreaRectUpdate;
  final void Function(TouchOperation) onEnd;

  @override
  State<StatefulWidget> createState() {
    return ImageCropGestureDetectState();
  }
}

class ImageCropGestureDetectState extends State<ImageCropGestureDetect> {
  var touchWhat = TouchOperation.none;
  late Offset lastScaleFocal;
  late Rect lastImageRect;
  double lastScale = 1;
  int pointerCount = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onScaleStart: (startDetail) {
          if (widget.state.isAnimating) {
            return;
          }
          if (startDetail.pointerCount == 1) {
            if (widget.state.isInLeftHandle(startDetail.localFocalPoint)) {
              touchWhat = TouchOperation.leftHandle;
            }
            if (widget.state.isInRightHandle(startDetail.localFocalPoint)) {
              touchWhat = TouchOperation.rightHandle;
            }
            if (widget.state.isInTopHandle(startDetail.localFocalPoint)) {
              touchWhat = TouchOperation.topHandle;
            }
            if (widget.state.isInBottomHandle(startDetail.localFocalPoint)) {
              touchWhat = TouchOperation.bottomHandle;
            }
          }
          lastScale = 1;
          lastImageRect = widget.state.imageRect;
          lastScaleFocal = startDetail.localFocalPoint;
          pointerCount = startDetail.pointerCount;
        },
        onScaleUpdate: (moveDetail) {
          if (widget.state.isAnimating) {
            return;
          }

          if (moveDetail.pointerCount !=  pointerCount) {
            pointerCount = moveDetail.pointerCount;
            lastScaleFocal = moveDetail.localFocalPoint;
            return;
          }
          final areaRect = widget.state.areaRect;
          final minSize = widget.state.widget.minSize;
          final padding = widget.state.widget.padding;

          switch (touchWhat) {
            case TouchOperation.leftHandle:
              final newPos = areaRect.left +
                  (moveDetail.localFocalPoint.dx - lastScaleFocal.dx);
              var area = areaRect.copy(left: newPos);
              if (area.width >= minSize && newPos > padding) {
                widget.onAreaRectUpdate(area);
              }
              break;
            case TouchOperation.rightHandle:
              final newPos = areaRect.right +
                  (moveDetail.localFocalPoint.dx - lastScaleFocal.dx);
              var newArea = areaRect.copy(right: newPos);
              if (newArea.width >= minSize &&
                  newPos < context.size!.width - padding) {
                widget.onAreaRectUpdate(newArea);
              }
              break;
            case TouchOperation.topHandle:
              final newPos = areaRect.top +
                  (moveDetail.localFocalPoint.dy - lastScaleFocal.dy);
              var newArea = areaRect.copy(top: newPos);
              if (newPos > padding && newArea.height >= minSize) {
                widget.onAreaRectUpdate(newArea);
              }
              break;
            case TouchOperation.bottomHandle:
              final newPos = areaRect.bottom +
                  (moveDetail.localFocalPoint.dy - lastScaleFocal.dy);
              final newArea = areaRect.copy(bottom: newPos);
              if (newPos < context.size!.height - padding &&
                  newArea.height >= minSize) {
                widget.onAreaRectUpdate(newArea);
              }
              break;
            default:
              final scale = moveDetail.scale / lastScale;
              final focalPoint = moveDetail.localFocalPoint;
              bool isTooLarge =
                  lastImageRect.width * scale / widget.state.imageOriginalWidth >
                      5;
              final newScale = isTooLarge ? 1.0 : scale;
              final imageRect = widget.state.scaleRect(lastImageRect, newScale,
                  anchor: lastScaleFocal, newAnchor: focalPoint);
              widget.onImageRectUpdate(imageRect);
              lastImageRect = imageRect;
              lastScale = moveDetail.scale;
          }
          lastScaleFocal = moveDetail.localFocalPoint;
        },
        onScaleEnd: (endDetail) {
          if (widget.state.isAnimating) {
            return;
          }
          widget.onEnd(touchWhat);
          touchWhat = TouchOperation.none;
        },
        child: widget.child);
  }
}

class CropperPainter extends CustomPainter {
  CropperPainter({
    required this.leftHandle,
    required this.rightHandle,
    required this.topHandle,
    required this.bottomHandle,
    required this.area,
    required this.image,
    required this.imageArea,
    required this.imageRotation,
    required this.rotationFocalPoint,
  });

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
  final handlePaint = Paint()..color = Colors.white70;
  final areaPaint = Paint()..color = Colors.black26;

  @override
  void paint(Canvas canvas, Size size) {

    if (image != null) {
      canvas.save();
      canvas.translate(rotationFocalPoint.dx, rotationFocalPoint.dy);
      canvas.rotate(imageRotation);
      canvas.translate(-rotationFocalPoint.dx, -rotationFocalPoint.dy);
      canvas.drawImageRect(
          image!,
          Rect.fromLTWH(
              0, 0, image!.width.toDouble(), image!.height.toDouble()),
          imageArea,
          imagePaint);
      canvas.restore();
    }
    canvas.drawRect(area, areaPaint);
    canvas.drawRect(leftHandle, handlePaint);
    canvas.drawRect(rightHandle, handlePaint);
    canvas.drawRect(topHandle, handlePaint);
    canvas.drawRect(bottomHandle, handlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

extension RectExtension on Rect {
  Rect copy({double? left, double? top, double? right, double? bottom}) {
    return Rect.fromLTRB(left ?? this.left, top ?? this.top,
        right ?? this.right, bottom ?? this.bottom);
  }
}
