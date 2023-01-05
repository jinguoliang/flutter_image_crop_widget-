import 'dart:typed_data';

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_crop_widget/flutter_image_crop_widget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uint8List? imageData;
  bool editMode = false;

  @override
  void initState() {
    super.initState();
    rootBundle.load('assets/pasted_image.png').then((data) {
      setState(() {
        imageData = data.buffer.asUint8List();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
                onPressed: () {
                  setState(() {
                    editMode = !editMode;
                  });
                },
                icon: editMode ? Icon(Icons.edit) : Icon(Icons.visibility))
          ],
        ),
        body: SizedBox.expand(
            child: imageData == null
                ? Placeholder()
                : editMode
                    ? ImageCropWidget.justView(
                        imageData!,
                      )
                    : ImageCropWidget.memory(
                        imageData!,
                        onUpdate: (originImage, rectInImage) async {
                          // 这里获取到原图片和裁剪区域
                          ui.PictureRecorder recorder = ui.PictureRecorder();
                          final canvas = Canvas(recorder);
                          canvas.drawImageRect(
                              originImage,
                              rectInImage,
                              Rect.fromLTWH(
                                  0, 0, rectInImage.width, rectInImage.height),
                              Paint());
                          final p = recorder.endRecording();
                          final image = await p.toImage(rectInImage.width.toInt(),
                              rectInImage.height.toInt());
                          // final f = File('./hello.jpg');
                          // final png = i.PngEncoder().encodeImage(i.Image.fromBytes(image.width, image.height,(await image.toByteData())!.buffer.asUint8List()));
                          // print('path: ${f.absolute}');
                          // f.writeAsBytes(png);
                        },
                      )));
  }
}
