# ManeGa - Maneuver Gadjah Mada

## Overview

ManeGa is a Flutter application developed to provide real-time location tracking and reporting. The app collects GPS data from mobile devices and transmits it to a Firebase Realtime Database, making it ideal for movement tracking applications.

## Features

- **Real-time Location Tracking**: Captures device GPS location at 5-second intervals
- **Background Operation**: Continues to track location when the app is minimized
- **Firebase Integration**: Stores location data in structured and CSV formats
- **Efficient Battery Usage**: Optimized for longer battery life during tracking
- **User-friendly Interface**: Simple controls for starting and stopping tracking

## Technology Stack

- **Frontend**: Flutter 3.x
- **Backend**: Firebase Realtime Database
- **Location Services**: Geolocator package
- **State Management**: Flutter's built-in state management

## Installation

1. Clone the repository
2. Navigate to the project directory
3. Install dependencies
4. Set up Firebase:
    - Create a Firebase project at Firebase Console
    - Add Android/iOS apps in Firebase project settings
    - Download and add the configuration files (google-services.json for Android, GoogleService-Info.plist for iOS)
5. Run the app

## Configuration

### Firebase Setup

The app requires Firebase Realtime Database. Make sure to set up the correct security rules.

### Permissions

The app requires the following permissions:

#### Android

- ACCESS_FINE_LOCATION
- ACCESS_COARSE_LOCATION
- FOREGROUND_SERVICE
- WAKE_LOCK (for background operation)

#### iOS

- Location When In Use
- Location Always

## Usage

1. Open the app
2. Tap "Start Tracking" to begin sending location data
3. The app will display current coordinates, altitude, speed, and connection status
4. Tap "Stop Tracking" to end the location updates

## Architecture

The app follows a straightforward architecture:

- **LocationSenderScreen**: Main UI component for displaying location data and controls
- **Firebase Integration**: Direct integration with Firebase Realtime Database
- **Geolocator Integration**: Handles retrieving device location information

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for providing an excellent cross-platform framework
- Geolocator package for simplified location services
- Firebase for real-time data storage capabilities

Developed with ❤️ by Godean Engineering
