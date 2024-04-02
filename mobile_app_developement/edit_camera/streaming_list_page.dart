import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StreamingListPage extends StatefulWidget {
  const StreamingListPage({Key? key}) : super(key: key);

  @override
  _StreamingListPageState createState() => _StreamingListPageState();
}

class _StreamingListPageState extends State<StreamingListPage> {
  List<Map<String, dynamic>> _cameraData = [];

  @override
  void initState() {
    super.initState();
    _fetchCameraData();
  }

  Future<void> _fetchCameraData() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.29.151:5001/api/cameras'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['cameras'];
        setState(() {
          _cameraData = List<Map<String, dynamic>>.from(data);
        });
      } else {
        throw Exception('Failed to fetch camera data');
      }
    } catch (e) {
      print('Error fetching camera data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Streaming List'),
        backgroundColor: Colors.blue,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCameraData,
        child: _cameraData.isEmpty
            ? Center(
          child: CircularProgressIndicator(),
        )
            : ListView.builder(
          itemCount: _cameraData.length,
          itemBuilder: (context, index) {
            final cameraId = _cameraData[index]['camera_id'];
            final cameraUrl = _cameraData[index]['camera_url'];
            final minAngle = _cameraData[index]['min_angle'];
            final maxAngle = _cameraData[index]['max_angle'];
            final view = _cameraData[index]['view'];
            return Card(
              elevation: 3,
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: Icon(Icons.videocam),
                title: Text('Camera ID: $cameraId'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('URL: $cameraUrl'),
                    Text('Min Angle: $minAngle'),
                    Text('Max Angle: $maxAngle'),
                    Text('View: $view'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () {
                        _editCamera(context, index);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        _deleteCamera(context, cameraId);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _editCamera(BuildContext context, int index) {
    int cameraId = _cameraData[index]['camera_id'];
    String cameraUrl = _cameraData[index]['camera_url'];
    int minAngle = _cameraData[index]['min_angle'];
    int maxAngle = _cameraData[index]['max_angle'];
    String view = _cameraData[index]['view'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Camera'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: cameraUrl,
                decoration: InputDecoration(labelText: 'Camera URL'),
                onChanged: (value) {
                  cameraUrl = value;
                },
              ),
              TextFormField(
                initialValue: minAngle.toString(),
                decoration: InputDecoration(labelText: 'Min Angle'),
                onChanged: (value) {
                  minAngle = int.parse(value);
                },
              ),
              TextFormField(
                initialValue: maxAngle.toString(),
                decoration: InputDecoration(labelText: 'Max Angle'),
                onChanged: (value) {
                  maxAngle = int.parse(value);
                },
              ),
              TextFormField(
                initialValue: view,
                decoration: InputDecoration(labelText: 'View'),
                onChanged: (value) {
                  view = value;
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                _updateCamera(cameraId, cameraUrl, minAngle, maxAngle, view);
                Navigator.pop(context); // Close the dialog
              },
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _updateCamera(int cameraId, String cameraUrl, int minAngle, int maxAngle, String view) async {
    try {
      final response = await http.put(
        Uri.parse('http://192.168.29.151:5001/api/camera/$cameraId'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'camera_url': cameraUrl,
          'min_angle': minAngle,
          'max_angle': maxAngle,
          'view': view,
        }),
      );

      if (response.statusCode == 200) {
        print('Camera details updated successfully');
        // Refresh the camera data after updating
        _fetchCameraData();
      } else {
        print('Failed to update camera details. Error: ${response.body}');
      }
    } catch (e) {
      print('Error updating camera details: $e');
    }
  }

  void _deleteCamera(BuildContext context, int cameraId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this camera?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Dismiss the dialog
              },
              child: Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Dismiss the dialog
                _performDelete(cameraId); // Perform the delete operation
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  void _performDelete(int cameraId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://192.168.29.151:5001/api/delete_camera_url/$cameraId'),
      );
      if (response.statusCode == 200) {
        print('Camera ID $cameraId deleted successfully');
        // Refresh the camera data after deleting
        _fetchCameraData();
      } else {
        print('Failed to delete camera. Error: ${response.body}');
      }
    } catch (e) {
      print('Error deleting camera: $e');
    }
  }
}
