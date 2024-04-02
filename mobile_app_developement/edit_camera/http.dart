// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
class Camera {
  final int cameraId;
  final String cameraUrl;
  final int minAngle;
  final int maxAngle;
  final String view;
  Camera({
    required this.cameraId,
    required this.cameraUrl,
    required this.minAngle,
    required this.maxAngle,
    required this.view,
  });
  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      cameraId: json['camera_id'],
      cameraUrl: json['camera_url'],
      minAngle: json['min_angle'],
      maxAngle: json['max_angle'],
      view: json['view'],
    );
  }
}
class VideoStream extends StatefulWidget {
  const VideoStream({Key? key}) : super(key: key);
  @override
  State<VideoStream> createState() => _VideoStreamState();
}
class _VideoStreamState extends State<VideoStream> {
  late List<Camera> _cameras;
  @override
  void initState() {
    super.initState();
    _cameras = [];
    getDataFromApi();
  }
  void getDataFromApi() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.29.151:5001/api/get_data'));
      print("api call:$response");
      if (response.statusCode == 200) {
        print("response: ${response.statusCode}");
        final responseBody = jsonDecode(response.body);
        print("responsebody ${responseBody}");
        // Check if 'cameras' key exists in the response body
        if (responseBody is Map && responseBody.containsKey('cameras')) {
          final camerasData = responseBody['cameras'];
          print("camerasData ${camerasData}");
          // Ensure camerasData is not null and is a List
          if (camerasData != null && camerasData is List) {
            print("response body:${camerasData}");
            setState(() {
              _cameras = camerasData.map((cameraData) => Camera.fromJson(cameraData)).toList();
              print("@@@@${_cameras}");
            });
          } else {
            print('Error: cameras is null or not a List.');
          }
        } else {
          print('Error: Response body does not contain cameras.');
        }
      } else {
        throw Exception('Failed to fetch cameras');
      }
    } catch (e) {
      print('Error fetching camera data: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Video"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                // Display camera URLs
                if (_cameras.isEmpty)
                  Text('No cameras available')
                else
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _cameras.length,
                    itemBuilder: (context, index) {
                      final camera = _cameras[index];
                      return ListTile(
                        title: Text('Camera ${camera.cameraId}'),
                        subtitle: Text('URL: ${camera.cameraUrl}'),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
void main() {
  runApp(const MaterialApp(
    home: VideoStream(),
  ));
}
