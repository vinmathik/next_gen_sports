import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditCameraPage extends StatefulWidget {
  final int cameraId;
  final String initialUrl;
  final int initialMinAngle;
  final int initialMaxAngle;
  final String initialView;

  const EditCameraPage({
    required this.cameraId,
    required this.initialUrl,
    required this.initialMinAngle,
    required this.initialMaxAngle,
    required this.initialView,
  });

  @override
  _EditCameraPageState createState() => _EditCameraPageState();
}

class _EditCameraPageState extends State<EditCameraPage> {
  late TextEditingController _urlController;
  late TextEditingController _minAngleController;
  late TextEditingController _maxAngleController;
  late TextEditingController _viewController;
  bool _isUpdating = false; // Track the state of the button

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _minAngleController =
        TextEditingController(text: widget.initialMinAngle.toString());
    _maxAngleController =
        TextEditingController(text: widget.initialMaxAngle.toString());
    _viewController = TextEditingController(text: widget.initialView);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Camera'),
        backgroundColor: Colors.blue, // Set the app bar color to blue
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Camera URL',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _minAngleController,
              decoration: InputDecoration(
                labelText: 'Minimum Angle',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _maxAngleController,
              decoration: InputDecoration(
                labelText: 'Maximum Angle',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _viewController,
              decoration: InputDecoration(
                labelText: 'View',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUpdating ? null : _updateCamera, // Disable button if updating
              child: _isUpdating ? CircularProgressIndicator() : Text('Update Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCamera() async {
    setState(() {
      _isUpdating = true; // Set button state to updating
    });

    String url = _urlController.text;
    int minAngle = int.tryParse(_minAngleController.text) ?? 0;
    int maxAngle = int.tryParse(_maxAngleController.text) ?? 0;
    String view = _viewController.text;

    try {
      final response = await http.put(
        Uri.parse(
            'http://192.168.29.152:5001/api/camera/${widget.cameraId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'camera_url': url,
          'min_angle': minAngle,
          'max_angle': maxAngle,
          'view': view,
        }),
      );

      if (response.statusCode == 200) {
        print('Camera details updated successfully');
        Navigator.pop(
            context); // Pop the edit camera page after successful update
      } else {
        print(
            'Failed to update camera details. Error: ${response.body}');
        // Show an error message or handle the error as needed
      }
    } catch (e) {
      print('Error updating camera details: $e');
      // Show an error message or handle the error as needed
    } finally {
      setState(() {
        _isUpdating = false; // Reset button state after update
      });
    }
  }
  @override
  void dispose() {
    _urlController.dispose();
    _minAngleController.dispose();
    _maxAngleController.dispose();
    _viewController.dispose();
    super.dispose();
  }
}
