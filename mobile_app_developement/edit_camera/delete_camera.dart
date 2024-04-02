import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DeleteCameraPage extends StatelessWidget {
  final int cameraId;
  final Function onDelete;
  const DeleteCameraPage({Key? key, required this.cameraId, required this.onDelete,}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delete Camera'),
        backgroundColor: Colors.blue, // Set the app bar color to blue
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Are you sure you want to delete this camera?'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _confirmDelete(context);
              },
              child: Text('Yes'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the delete page
              },
              child: Text('No'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    try {
      final response = await http.delete(
        Uri.parse('http://192.168.29.152:5001/api/delete_camera_url/$cameraId'),
      );
      print("Response ${response}");

      if (response.statusCode == 200) {
        print("response ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera deleted successfully.'), duration: Duration(seconds: 2),
          ),
        );
        onDelete(); // Trigger the onDelete callback
        Navigator.of(context).pop(true); // Navigate back with success flag
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete the camera.'),
          duration: Duration(seconds: 2),
        ),
        );
      }
    } catch (e) {
      print('Error deleting camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deleddte the camera.'),
        duration: Duration(seconds: 2),
      ),
      );
    }
  }
}
