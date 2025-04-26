// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // For Timer and StreamSubscription

class LocationSenderScreen extends StatefulWidget {
  const LocationSenderScreen({super.key});

  @override
  State<LocationSenderScreen> createState() => _LocationSenderScreenState();
}

class _LocationSenderScreenState extends State<LocationSenderScreen> {
  // --- State Variables ---
  Position? _currentPosition; // Holds the latest position from the stream
  String _statusMessage = 'Press Start Tracking to begin.';
  bool _isTracking = false; // Tracks if continuous sending is active
  bool _isUploading = false; // Tracks if an upload is currently in progress
  final String _firebasePath = 'locations/'; // Firebase path to write to

  // --- Firebase Database Reference ---
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref(
    'locations',
  );

  // --- Location Stream Subscription & Timer ---
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _sendTimer; // Timer to trigger sending every 5 seconds

  // --- Settings ---
  final LocationSettings _locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high, // Desired accuracy
    // distanceFilter: 0 means the stream updates on any minor change.
    // The timer will still control the 5-second send interval.
    distanceFilter: 0,
  );

  // --- Permission Handling (Same as before) ---
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Check mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are disabled. Please enable the services',
            ),
          ),
        );
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Check mounted before showing SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Check mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied, we cannot request permissions.',
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  // --- Start Continuous Tracking ---
  Future<void> _startTracking() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      // Check mounted before setState
      if (mounted) {
        setState(() {
          _statusMessage = 'Permission denied. Cannot start tracking.';
        });
      }
      return;
    }

    // Check mounted before setState
    if (mounted) {
      setState(() {
        _isTracking = true;
        _statusMessage = 'Tracking started. Waiting for location updates...';
      });
    } else {
      // If not mounted, still update the state variable but don't call setState
      _isTracking = true;
    }

    // --- Start Location Stream Listener ---
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null; // Explicitly nullify

    // Listen to the location stream ONLY to update _currentPosition
    _positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings: _locationSettings,
        )
        .handleError((error) {
          print("Location Stream Error: $error");
          if (mounted) {
            setState(() {
              _statusMessage = 'Error receiving location: $error';
            });
          }
          _stopTracking(); // Stop tracking on stream error
        })
        .listen((Position position) {
          // Update the current position whenever the stream emits
          print(
            "Position Updated by Stream: ${position.latitude}, ${position.longitude}",
          );
          if (mounted) {
            setState(() {
              _currentPosition = position;
              // Don't update status message here, let timer/send handle it
            });
          }
          // DO NOT send to Firebase here directly
        });

    // --- Start Periodic Send Timer ---
    _sendTimer?.cancel(); // Cancel previous timer if any
    _sendTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (!_isTracking) {
        timer.cancel(); // Stop timer if tracking was stopped externally
        print("Send Timer Cancelled: Tracking stopped.");
        return;
      }
      if (_currentPosition != null) {
        print("5 Second Timer Fired: Attempting to send location.");
        _sendLocationToFirebase(
          _currentPosition!,
        ); // Send the last known position
      } else {
        print("5 Second Timer Fired: No location data yet to send.");
        if (mounted) {
          setState(() {
            _statusMessage = "Waiting for initial location fix...";
          });
        }
      }
    });
  }

  // --- Stop Continuous Tracking ---
  Future<void> _stopTracking() async {
    // Cancel location stream
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Cancel the send timer
    _sendTimer?.cancel();
    _sendTimer = null;

    if (mounted) {
      // Check only if state update is needed
      setState(() {
        _isTracking = false;
        _statusMessage = 'Tracking stopped.';
        _isUploading = false; // Reset upload state when stopping
      });
    } else {
      _isTracking = false; // Update state even if not mounted to prevent leaks
      _isUploading = false;
    }
    print("Tracking stopped (stream and timer).");
  }

  // --- Send Location Data to Firebase (with added feedback) ---
  Future<void> _sendLocationToFirebase(Position position) async {
    // Prevent overlapping uploads if the previous one hasn't finished
    if (_isUploading) {
      print("Upload already in progress, skipping this send cycle.");
      return;
    }

    // --- Prepare data for Firebase ---
    // Create data with CSV format for easier parsing
    final csvString = '${position.latitude},${position.longitude},${position.altitude.toStringAsFixed(2)},${position.speed.toStringAsFixed(2)}';
    
    // Still keep the structured data for Firebase
    Map<String, dynamic> locationData = {
      'csv': csvString,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'altitude': position.altitude,
      'speed': position.speed,
      'accuracy': position.accuracy,
      'timestamp': position.timestamp.millisecondsSinceEpoch ?? 
        DateTime.now().millisecondsSinceEpoch,
      'source': 'FlutterApp_TimedSend_v2',
      'lastUpdated': ServerValue.timestamp,
    };

    // Use a fixed reference instead of push()
    final fixedRef = _databaseRef.child('current_location');
    final csvRef = _databaseRef.child('current_location_csv');

    try {
      if (mounted) {
        setState(() {
          _isUploading = true;
          _statusMessage = 'Updating location...';
        });
      } else {
        _isUploading = true;
      }
      // Second update - CSV data
      try {
        await csvRef.set({'value': csvString});
        print('CSV data updated successfully at: ${csvRef.path}');
      } catch (csvError) {
        print('Error updating CSV data: $csvError');
        rethrow; // Rethrow to be caught by outer try/catch
      }

      // First update - main data
      try {
        await fixedRef.set(locationData);
        print('Main location data updated successfully');
      } catch (mainError) {
        print('Error updating main location data: $mainError');
        rethrow; // Rethrow to be caught by outer try/catch
      }
      

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _statusMessage = 'Location updated successfully.';
        });
      }
      print('Location data updated at fixed endpoint: current_location');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update location: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _statusMessage = 'Error updating: ${error.toString()}';
        });
      }
      print('Error updating location data: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      } else {
        _isUploading = false;
      }
    }
  }

  @override
  void dispose() {
    // Ensure resources are released when the widget is removed
    _positionStreamSubscription?.cancel();
    _sendTimer?.cancel(); // Cancel the send timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI Build method remains largely the same
    return Scaffold(
      appBar: AppBar(
        // Updated title slightly for clarity
        title: const Text('Location Sender (5s Interval)'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // --- Firebase Info ---
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Firebase Info:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Database Path: $_firebasePath'),
                      const SizedBox(height: 8),
                      Text(
                        // Show more dynamic status based on tracking and uploading state
                        'Status: ${_isTracking ? (_isUploading ? 'Sending...' : _statusMessage) : "Tracking stopped."}',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color:
                              _statusMessage.startsWith('Error')
                                  ? Colors.red
                                  : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- GPS Info ---
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device GPS Info (Last Update):',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentPosition == null
                            ? 'Waiting for location...'
                            // Removed unnecessary null check hint
                            : 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                                'Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}\n'
                                'Alt: ${_currentPosition!.altitude.toStringAsFixed(2)} m\n'
                                'Speed: ${_currentPosition!.speed.toStringAsFixed(2)} m/s\n'
                                'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(2)} m\n'
                                'Time: ${_currentPosition!.timestamp != null ? DateTime.fromMillisecondsSinceEpoch(_currentPosition!.timestamp.millisecondsSinceEpoch).toLocal().toString() : 'N/A'}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- Action Button ---
              ElevatedButton.icon(
                icon:
                    _isTracking
                        ? (_isUploading
                            ? Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(right: 8),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(Icons.stop))
                        : const Icon(Icons.play_arrow),
                label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
                onPressed: () {
                  if (_isTracking) {
                    _stopTracking();
                  } else {
                    _startTracking();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTracking ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
