import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocket {
  late String url;
  late WebSocketChannel? _channel;
  late StreamController<bool> streamController = StreamController<bool>.broadcast();
  String get getUrl {
    return url;
  }
  set setUrl(String url) {
    this.url = url;
  }
  Stream<dynamic> get stream {
    if (_channel != null) {
      return _channel!.stream;
    } else {
      throw WebSocketChannelException("The connection was not established!");
    }
  }
  WebSocket(this.url);
  Future<void> connect() async {
    _channel = IOWebSocketChannel.connect(Uri.parse(url));
    streamController.add(true);
  }
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
    }
  }
  Future<void> sendCameraData(String cameraUrl, int minAngle, int maxAngle) async {
    await _sendCameraData(cameraUrl, minAngle, maxAngle, 'default');
  }
  Future<void> sendCameraDataWithView(String cameraUrl, int minAngle, int maxAngle, String view) async {
    await _sendCameraData(cameraUrl, minAngle, maxAngle, view);
  }
  Future<void> _sendCameraData(String cameraUrl, int minAngle, int maxAngle, String view) async {
    if (_channel != null) {
      final data = {
        'camera_url': cameraUrl,
        'min_angle': minAngle,
        'max_angle': maxAngle,
        'view': view,
      };
      _channel!.sink.add(jsonEncode(data));
    } else {
      throw WebSocketChannelException("The connection was not established!");
    }
  }
}
class WebSocketChannelException implements Exception {
  final String message;
  WebSocketChannelException(this.message);
}
void main() async {
  final webSocket = WebSocket('ws://192.168.1.13:5000');
  await webSocket.connect();
  try {
    await webSocket.sendCameraData('camera_url', 0, 90);
  } catch (e) {
    print(e);
  }
}
Future<void> _saveCroppedImageToBackend(String imagePath) async {
  try {
    final File imageFile = File(imagePath);
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);
    final response = await http.post(
      Uri.parse('http://192.168.1.13:5001/api/save_cropped_image'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'image': base64Image,
      }),
    );
    if (response.statusCode == 200) {
      print('Image saved to backend successfully');
    } else {
      print('Failed to save image to backend: ${response.statusCode}');
    }
  } catch (e) {
    print('Error saving image to backend: $e');
  }
}


