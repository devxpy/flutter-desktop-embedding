import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_chooser/file_chooser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:pdfium/pdfium.dart';

void main() async {
  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  WidgetsFlutterBinding.ensureInitialized();
  var base = await path.getApplicationSupportDirectory();
  loadDylib('${base.path}/debug/libpdfium.dylib');
  initLibrary();

  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // See https://github.com/flutter/flutter/wiki/Desktop-shells#fonts
        fontFamily: 'Roboto',
      ),
      home: Scaffold(
        appBar: AppBar(title: Text('Flutter Pdfium')),
        body: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var settingsVisible = true;
  String selectedPdf;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        ExpansionPanelList(
          expansionCallback: (int index, bool isExpanded) {
            setState(() {
              settingsVisible = !settingsVisible;
            });
          },
          children: [
            ExpansionPanel(
              canTapOnHeader: true,
              headerBuilder: (context, isExpanded) {
                return ListTile(title: Text('Settings'));
              },
              body: Column(
                children: <Widget>[
                  RaisedButton(
                    child: Text('Choose PDF'),
                    onPressed: () {
                      showOpenPanel((result, files) {
                        if (files.isEmpty) return;
                        setState(() {
                          selectedPdf = files[0];
                        });
                      }, allowedFileTypes: ['pdf']);
                    },
                  ),
                  Text(
                    selectedPdf ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              isExpanded: settingsVisible,
            ),
          ],
        ),
        Container(
          child: PdfView(selectedPdf),
        ),
      ],
    );
  }
}

class PdfPainter extends CustomPainter {
  final ui.Image image;

  PdfPainter(this.image);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawCircle(Offset.zero, 20.0, Paint());
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(PdfPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}

class PdfView extends StatefulWidget {
  final String filePath;

  PdfView(this.filePath);

  @override
  _PdfViewState createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  ui.Image image;

  @override
  void didUpdateWidget(PdfView oldWidget) {
    int width;
    int height;
    Pointer<FPDF_PAGE> page;
    Pointer<FPDF_DOCUMENT> doc;
    Pointer<FPDF_BITMAP> bitmap;
    Uint8List buf;
    int ppi = 100;

    if (widget.filePath == null) return;

    doc = loadDocument(widget.filePath);
    page = fLoadPage(doc, 5);

    width = fGetPageWidth(page).toInt();
    height = fGetPageHeight(page).toInt();
    width = pointsToPixels(width, ppi).toInt();
    height = pointsToPixels(height, ppi).toInt();

    bitmap = fBitmapCreate(width, height, 1);
    fBitmapFillRect(bitmap, 0, 0, width, height, 0);
    fRenderPageBitmap(bitmap, page, 0, 0, width, height, 0, 0);

    buf = fBitmapGetBuffer(bitmap)
        .asTypedList(width * height)
        .buffer
        .asUint8List();

    ui.decodeImageFromPixels(
      buf,
      width,
      height,
      ui.PixelFormat.bgra8888,
          (img) {
        setState(() {
          image = img;
        });
      },
    );

    fCloseDocument(doc);

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filePath == null) {
      return Container();
    }
    if (image == null) {
      return CircularProgressIndicator();
    }
    return CustomPaint(
      painter: PdfPainter(image),
    );
  }
}
