import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:next_gen_sports_analysis/VideoStream/websocket.dart'; // Import the WebSocket class

class AddCameraPage extends StatefulWidget {
  const AddCameraPage({Key? key}) : super(key: key);

  @override
  _AddCameraPageState createState() => _AddCameraPageState();
}

class _AddCameraPageState extends State<AddCameraPage> {
  final TextEditingController urlController = TextEditingController(text: 'http://');
  final TextEditingController minAngleController = TextEditingController();
  final TextEditingController maxAngleController = TextEditingController();
  String selectedView = 'default';
  WebSocket webSocket = WebSocket('ws://192.168.29.151:5000');
  bool isSubmitting = false;

  Future<void> _submitForm() async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    final String apiUrl = 'http://192.168.29.152:5001/api/add_camera';
    final Map<String, dynamic> data = {
      'camera_url': urlController.text,
      'min_angle': int.parse(minAngleController.text),
      'max_angle': int.parse(maxAngleController.text),
      'view': selectedView,
    };
    try {
      await webSocket.connect();
      final http.Response response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      print("Response ${http.Response}");
      if (response.statusCode == 201) {
        print("response:${response.statusCode}");
        await webSocket.sendCameraDataWithView(
          urlController.text,
          int.parse(minAngleController.text),
          int.parse(maxAngleController.text),
          selectedView,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera added successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context,true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add camera: ${response.body}'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('WebSocket connection error: $e');
    } finally {
      webSocket.disconnect();
      setState(() {
        isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Camera - Details'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTextField('Camera URL', urlController),
            const SizedBox(height: 10.0),
            _buildTextField('Min Angle', minAngleController, keyboardType: TextInputType.number),
            const SizedBox(height: 10.0),
            _buildTextField('Max Angle', maxAngleController, keyboardType: TextInputType.number),
            const SizedBox(height: 20.0),
            Container(
              width: double.infinity,
              child: _buildDropdownButton(),
            ),
            const SizedBox(height: 20.0),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitForm,
                child: Text('Submit'),
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String labelText, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildDropdownButton() {
    return DropdownButton<String>(
      value: selectedView,
      onChanged: (String? newValue) {
        setState(() {
          selectedView = newValue!;
        });
      },
      items: <String>['default', 'front view', 'side view', 'back view']
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }
}
