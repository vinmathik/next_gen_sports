import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:web_socket_channel/io.dart';
import 'package:untitled2/VideoStream/streaming_list_page.dart';
void main() {
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live streaming application',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: VideoStream(),
      routes: {
        '/streamingList': (context) => StreamingListPage(),
      },
    );
  }
}
class VideoStream extends StatefulWidget {
  const VideoStream({Key? key}) : super(key: key);
  @override
  State<VideoStream> createState() => _VideoStreamState();
}
class _VideoStreamState extends State<VideoStream> {
  // late WebSocketChannel _liveStreamChannel;
  late List<IOWebSocketChannel> _channels;
  late List<bool> _isConnected;
  late List<CameraController> _cameraControllers;
  int? _selectedCardIndex;
  @override
  void initState() {
    super.initState();
    _channels = [];
    _isConnected = [];
    _cameraControllers = [];
    _initializeCameras();
    _selectedCardIndex = null;
  }
  void cameraSetup(){
  }
  Future<void> _initializeCameras() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final response = await http.get(Uri.parse('http://192.168.29.151:5001/api/get_data'));
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map && responseBody.containsKey('data')) {
          final List<dynamic> cameraData = responseBody['data'];
          if (cameraData != null && cameraData is List) {
            final cameras = await availableCameras();
            _cameraControllers = List.generate(
              4,
                  (index) {
                final cameraDescription = cameras[index % cameras.length];
                return CameraController(
                  cameraDescription,
                  ResolutionPreset.medium,
                );
              },
            );
            _channels = List.generate(
              4,
                  (index) => IOWebSocketChannel.connect('ws://192.168.29.151:5000/$index'),
            );
            for (var i = 0; i < _cameraControllers.length; i++) {
              await _cameraControllers[i].initialize();
            }
            _isConnected = List.generate(4, (index) => true);
            print("@@@@@@@@@@@@,${_isConnected}");
            setState(() {});
          } else {
            print('Error: Camera data is not a valid List.');
          }
        } else {
          print('Error: Response body does not contain data.');
        }
      } else {
        throw Exception('Failed to fetch data');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }
  void _connectAndHideIcon(int index) {
    // Connect to camera stream
    _connectToCameraStream(index);
    // Hide (+) icon by updating the state
    setState(() {
      _isConnected[index] = true;
    });
  }
  void _connectToCameraStream(int index) {
    print("Function to connect the camera");
    try {
      _channels[index].sink.add('connect');
      setState(() {
        _isConnected[index] = true;
        print("the camera index is connected${_isConnected[index]}");
      });
      // }
    } catch (e) {
      print('Error connecting camera $index: $e');
    }
  }
  void _disconnectFromCameraStream(int index) {
    try {
      _channels[index].sink.add('disconnect');
      _channels[index].sink.close();
      _channels[index] = IOWebSocketChannel.connect("ws://192.168.29.151:5000/$index");
      setState(() {
        _isConnected[index] = false;
      });
    } catch (e) {
      print('Error disconnecting camera $index: $e');
    }
  }
  void connect(int index) {
    try {
      _channels[index].sink.add('connect');
      setState(() {
        _isConnected[index] = true;
      });
    } catch (e) {
      print('Error connecting camera $index: $e');
    }
  }
  void disconnect(int index) {
    try {
      _channels[index].sink.add('disconnect');
      _channels[index].sink.close();
      _channels[index] = IOWebSocketChannel.connect("ws://192.168.29.151:5000/$index");
      setState(() {
        _isConnected[index] = false;
      });
    } catch (e) {
      print('Error disconnecting camera $index: $e');
    }
  }
  void connectAll() {
    for (int i = 0; i < _channels.length; i++) {
      _connectToCameraStream(i);
    }
  }
  void disconnectAll() {
    for (int i = 0; i < _channels.length; i++) {
      _disconnectFromCameraStream(i);
    }
  }
  Future<void> captureImage(int index) async {
    try {
      if (index >= 0 && index < _cameraControllers.length) {
        final image = await _cameraControllers[index].takePicture();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CropImagePage(imagePath: image.path),
          ),
        );
      } else {
        print('Invalid camera index: $index');
      }
    } catch (e) {
      print('Error capturing image: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Stream'),
        actions: [
          PopupMenuButton(
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  child: Text('Connect all cameras'),
                  value: 'option1',
                ),
                PopupMenuItem(
                  child: Text('Disconnect all cameras'),
                  value: 'option2',
                ),
                PopupMenuItem(
                  child: Text("Streaming List Page"),
                  value: 'option3',
                ),
                PopupMenuItem(
                  child: Text("Add 2 more cameras"),
                  value: 'option4',
                ),
              ];
            },
            onSelected: (String value) {
              if (value == 'option1') {
                connectAll();
              } else if (value == 'option2') {
                disconnectAll();
              } else if (value == 'option3') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StreamingListPage(),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: List.generate(_cameraControllers.length, (index) {
                bool isConnected = _isConnected[index] ?? false;
                return Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCardIndex = index;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green : Colors.transparent,
                        border: Border.all(
                          color: _selectedCardIndex == index
                              ? Colors.red
                              : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                      child: Card(
                        elevation: 5,
                        margin: EdgeInsets.all(10),
                        color: Colors.white,
                        child: AspectRatio(
                          aspectRatio: 6 / 5,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isConnected && _isConnected[index]) // Show streaming UI if connected
                                StreamBuilder(
                                  stream: _channels[index].stream,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Text('Error: ${snapshot.error}');
                                    }

                                    if (!snapshot.hasData) {
                                      return const CircularProgressIndicator();
                                    }

                                    if (snapshot.connectionState == ConnectionState.done) {
                                      return const Center(
                                        child: Text("Connection Closed!"),
                                      );
                                    }
                                    Uint8List decompressedBytes = base64Decode(snapshot.data.toString());
                                    return Image.memory(
                                      decompressedBytes,
                                      gaplessPlayback: true,
                                      excludeFromSemantics: true,
                                    );
                                  },
                                ),
                              GestureDetector(
                                onTap: () {
                                  _showCameraSettingsDialog(context, index);
                                },
                                child: !isConnected
                                    ? Icon(
                                  Icons.add,
                                  size: 20,
                                  color: Colors.blue,
                                )
                                    : SizedBox(), // Hide add icon if connected
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: GestureDetector(
                onTap: () {
                  if (_selectedCardIndex != null) {
                    captureImage(_selectedCardIndex!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select a camera card first'),
                      ),
                    );
                  }
                },
                child: Icon(
                  Icons.camera_alt,
                  size: 50,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _showCameraSettingsDialog(BuildContext context, int index) async {
    TextEditingController urlController = TextEditingController();
    TextEditingController minAngleController = TextEditingController();
    TextEditingController maxAngleController = TextEditingController();
    TextEditingController viewController = TextEditingController();
    // Pre-fill the camera details if already connected
    if (_isConnected[index]) {
      urlController.text = ''; // Fill with appropriate camera URL
      minAngleController.text = ''; // Fill with appropriate min angle
      maxAngleController.text = ''; // Fill with appropriate max angle
      viewController.text = ''; // Fill with appropriate view
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text('Add Camera'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: urlController,
                      decoration: InputDecoration(labelText: 'Camera URL'),
                    ),
                    TextFormField(
                      controller: minAngleController,
                      decoration: InputDecoration(labelText: 'Min Angle'),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: maxAngleController,
                      decoration: InputDecoration(labelText: 'Max Angle'),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: viewController,
                      decoration: InputDecoration(labelText: 'View'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    // Save the camera settings without existence checks
                    await _saveCameraSettings(
                      context,
                      urlController.text,
                      minAngleController.text,
                      maxAngleController.text,
                      viewController.text,
                      index,
                    );
                    // Hide the "+" symbol after saving camera settings
                    setState(() {
                      _isConnected[index] = true;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _saveCameraSettings(
      BuildContext context,
      String cameraUrl,
      String minAngle,
      String maxAngle,
      String view,
      int index,
      ) async {
    try {
      var response = await http.post(
        Uri.parse('http://192.168.29.151:5001/api/save_camera_settings'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'camera_url': cameraUrl,
          'min_angle': int.parse(minAngle),
          'max_angle': int.parse(maxAngle),
          'view': view,
          'index': index,
        }),
      );
      // Check the status code of the response
      if (response.statusCode == 201) {
        // Camera settings saved successfully
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera settings saved successfully'),
          ),
        );
        // Connect to camera stream after saving settings
        _connectAndHideIcon(index);
        // Additional actions after saving the settings
      } else if (response.statusCode == 400) {
        // Handle bad request error
        final responseData = jsonDecode(response.body);
        final String error = responseData['error'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
          ),
        );
      } else {
        // Show error message for other status codes
        print('Failed to save camera settings: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save camera settings'),
          ),
        );
      }
    } catch (e) {
      // Handle network errors
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }
}

class CropImagePage extends StatelessWidget {
  final String imagePath;
  const CropImagePage({Key? key, required this.imagePath}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crop Image"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.file(File(imagePath)),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () async {
                final croppedFile = await ImageCropper().cropImage(
                  sourcePath: imagePath,
                  aspectRatioPresets: [
                    CropAspectRatioPreset.square,
                    CropAspectRatioPreset.ratio3x2,
                    CropAspectRatioPreset.original,
                    CropAspectRatioPreset.ratio4x3,
                    CropAspectRatioPreset.ratio16x9
                  ],
                  androidUiSettings: AndroidUiSettings(
                    toolbarTitle: 'Cropper',
                    toolbarColor: Colors.deepOrange,
                    toolbarWidgetColor: Colors.white,
                    initAspectRatio: CropAspectRatioPreset.original,
                    lockAspectRatio: false,
                  ),
                  iosUiSettings: IOSUiSettings(
                    title: 'Cropper',
                  ),
                );
                if (croppedFile != null) {
                  print('Cropped image path: ${croppedFile.path}');
                  await _saveCroppedImageToBackend(
                      context, croppedFile.path);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DisplayCroppedImage(
                        croppedImagePath: croppedFile.path,
                      ),
                    ),
                  );
                }
              },
              child: const Text("Crop Image"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCroppedImageToBackend(
      BuildContext context, String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('http://192.168.29.151:5001/api/save_cropped_image'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'image': base64Image,
        }),
      );
      if (response.statusCode == 200) {
        print('Image saved to backend successfully');
        await generatePdfWithImage(context, imageFile);
      } else {
        print('Failed to save image to backend: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving image to backend: $e');
    }
  }

  Future<void> generatePdfWithImage(
      BuildContext context, File imageFile) async {
    final pdf = pw.Document();
    final Uint8List imageBytes = await imageFile.readAsBytes();
    final pw.MemoryImage image = pw.MemoryImage(imageBytes);
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Center(
        child: pw.Image(image),
      );
    }));

    Future<void> _viewPdf() async {
      try {
        final response = await http.get(
          Uri.parse('http://192.168.29.151:5001/api/download_pdf'),
        );
        if (response.statusCode == 200) {
          final directory = await getApplicationDocumentsDirectory();
          final pdfFile = File('${directory.path}/results/result.pdf');
          await pdfFile.writeAsBytes(response.bodyBytes);
        } else {
          print('Failed to fetch result.pdf: ${response.statusCode}');
        }
      } catch (e) {
        print('Error viewing PDF: $e');
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/generated_pdf_with_image.pdf');
    await file.writeAsBytes(await pdf.save());
    await _viewPdf();
  }
}

class DisplayCroppedImage extends StatelessWidget {
  final String croppedImagePath;
  const DisplayCroppedImage({Key? key, required this.croppedImagePath})
      : super(key: key);

  Future<void> _viewPdfResults(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.29.151:5001/api/download_pdf'),
      );
      if (response.statusCode == 200) {
        final Uint8List pdfBytes = response.bodyBytes;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(pdfBytes: pdfBytes),
          ),
        );
      } else {
        print('Failed to fetch result.pdf: ${response.statusCode}');
      }
    } catch (e) {
      print('Error viewing PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cropped Image"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(File(croppedImagePath)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ElevatedButton(
                onPressed: () {
                  _viewPdfResults(context);
                },
                child: const Text("Result"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PdfViewerPage extends StatelessWidget {
  final Uint8List pdfBytes;
  const PdfViewerPage({Key? key, required this.pdfBytes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Viewer"),
      ),
      body: PDFView(
        pdfData: pdfBytes,
      ),
    );
  }
}