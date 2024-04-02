import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:edge_detection/edge_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:web_socket_channel/io.dart';
import 'package:untitled2/VideoStream/streaming_list_page.dart';
import 'package:image/image.dart' as img;
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
        title: const Text("Detect Edges"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.file(File(imagePath)),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () async {
                await performEdgeDetection(context, imagePath);
              },
              child: const Text("Detect Edges"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> performEdgeDetection(BuildContext context, String imagePath) async {
    // Check camera permission
    bool isCameraGranted = await Permission.camera.request().isGranted;
    if (!isCameraGranted) {
      isCameraGranted = await Permission.camera.request() == PermissionStatus.granted;
    }

    if (!isCameraGranted) {
      // Handle case when camera permission is not granted
      print("Camera permission not granted");
      return;
    }

    try {
      // Perform edge detection
      bool success = await EdgeDetection.detectEdge(imagePath,
        canUseGallery: false, // Disable gallery option
        androidScanTitle: 'Scanning',
        androidCropTitle: 'Crop',
        androidCropBlackWhiteTitle: 'Black White',
        androidCropReset: 'Reset',
      );

      if (success) {
        print('Edge detected successfully');
        // If edge detection is successful, navigate to the next page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CroppedImagePage(imagePath: imagePath),
          ),
        );
      } else {
        print('Failed to detect edges');
        // Handle failure to detect edges
      }
    } catch (e) {
      print(e);
      // Handle edge detection error
    }
  }
}

class CroppedImagePage extends StatelessWidget {
  final String imagePath;

  const CroppedImagePage({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cropped Image with Edges Detected"),
      ),
      body: Center(
        child: FutureBuilder<Uint8List>(
          future: _detectEdges(imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData) {
              return Image.memory(snapshot.data!);
            } else {
              return Text('No data available');
            }
          },
        ),
      ),
    );
  }

  Future<Uint8List> _detectEdges(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(Uint8List.fromList(bytes));

    if (originalImage != null) {
      // Perform edge detection here
      // Example: You can use any edge detection algorithm on the originalImage

      // For demonstration, let's just return the original image
      return Uint8List.fromList(img.encodePng(originalImage));
    } else {
      throw Exception('Failed to decode image');
    }
  }
}

Future<void> saveEdgeDetectedImageToBackend(
    BuildContext context, Uint8List edgeDetectedImage) async {
  try {
    final String base64Image = base64Encode(edgeDetectedImage);
    final response = await http.post(
      Uri.parse('http://192.168.29.151/api/save_edge_detected_image'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'image': base64Image,
      }),
    );
    if (response.statusCode == 200) {
      print('Edge-detected image saved to backend successfully');
    } else {
      print('Failed to save edge-detected image to backend: ${response.statusCode}');
    }
  } catch (e) {
    print('Error saving edge-detected image to backend: $e');
  }
}

Future<void> generatePdfWithImage(
    BuildContext context, Uint8List imageBytes) async {
  final pdf = pw.Document();
  final pw.MemoryImage image = pw.MemoryImage(imageBytes);
  pdf.addPage(pw.Page(build: (pw.Context context) {
    return pw.Center(
      child: pw.Image(image),
    );
  }));
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/generated_pdf_with_image.pdf');
  await file.writeAsBytes(await pdf.save());
  await viewPdf(context, file);
}

Future<void> viewPdf(BuildContext context, File pdfFile) async {
  try {
    final response = await http.get(
      Uri.parse('http://192.168.29.151/api/download_pdf'),
    );
    if (response.statusCode == 200) {
      final directory = await getApplicationDocumentsDirectory();
      final pdfFile = File('${directory.path}/results/result.pdf');
      await pdfFile.writeAsBytes(response.bodyBytes);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(pdfFile: pdfFile),
        ),
      );
    } else {
      print('Failed to fetch result.pdf: ${response.statusCode}');
    }
  } catch (e) {
    print('Error viewing PDF: $e');
  }
}


class PdfViewerPage extends StatelessWidget {
  final File pdfFile;

  const PdfViewerPage({Key? key, required this.pdfFile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Viewer"),
      ),
      body: PDFView(
        filePath: pdfFile.path,
      ),
    );
  }
}