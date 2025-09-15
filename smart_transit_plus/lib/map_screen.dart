import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;

  // Controllers for search fields
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  final List<List<LatLng>> busRoutes = [
    [
      LatLng(8.5241, 76.9366), // Statue Junction
      LatLng(8.5280, 76.9420), // Thampanoor
      LatLng(8.5325, 76.9470), // PMG
    ],
    [LatLng(8.5260, 76.9350), LatLng(8.5290, 76.9380), LatLng(8.5315, 76.9410)],
    [LatLng(8.5210, 76.9300), LatLng(8.5250, 76.9340), LatLng(8.5280, 76.9370)],
  ];

  final Map<String, Marker> _markers = {};
  final Map<String, int> _busRouteIndex = {};

  late BitmapDescriptor busGreenIcon;
  late BitmapDescriptor busYellowIcon;
  late BitmapDescriptor busRedIcon;

  final Random _random = Random();
  List<Map<String, dynamic>> _availableBuses = [];

  @override
  void initState() {
    super.initState();
    _loadBusIcons();
  }

  Future<void> _loadBusIcons() async {
    busGreenIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/bus_green.png',
    );
    busYellowIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/bus_yellow.png',
    );
    busRedIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/bus_red.png',
    );

    _initializeBuses();
    _startBusMovement();
  }

  void _initializeBuses() {
    for (int i = 0; i < busRoutes.length; i++) {
      final route = busRoutes[i];
      final markerId = 'bus_$i';
      _busRouteIndex[markerId] = 0;

      _markers[markerId] = Marker(
        markerId: MarkerId(markerId),
        position: route[0],
        icon: busGreenIcon,
      );
    }
    setState(() {});
  }

  void _startBusMovement() {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      final newMarkers = <String, Marker>{};
      _markers.forEach((id, marker) {
        final index = _busRouteIndex[id]!;
        final route = busRoutes[int.parse(id.split('_')[1])];
        final nextIndex = (index + 1) % route.length;

        _busRouteIndex[id] = nextIndex;

        // Decide icon color based on simulated crowding
        int crowd = _random.nextInt(100); // random ppl
        BitmapDescriptor icon;
        if (crowd < 30) {
          icon = busGreenIcon;
        } else if (crowd < 50) {
          icon = busYellowIcon;
        } else {
          icon = busRedIcon;
        }

        newMarkers[id] = marker.copyWith(
          positionParam: route[nextIndex],
          iconParam: icon,
        );
      });

      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
      });
    });
  }

  void _searchBuses() {
    if (_sourceController.text.isEmpty || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter both source and destination")),
      );
      return;
    }

    // Simulate available buses
    final buses = List.generate(_markers.length, (i) {
      int crowd = _random.nextInt(60);
      int eta = 5 + _random.nextInt(15); // 5-20 minutes ETA
      return {"busId": "Bus ${i + 1}", "crowd": crowd, "eta": eta};
    });

    setState(() {
      _availableBuses = buses;
    });

    _showBusList();
  }

  void _showBusList() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: _availableBuses.length,
          itemBuilder: (context, index) {
            final bus = _availableBuses[index];
            Color color;
            if (bus["crowd"] < 20) {
              color = Colors.green;
            } else if (bus["crowd"] < 40) {
              color = Colors.orange;
            } else {
              color = Colors.red;
            }
            return ListTile(
              leading: Icon(Icons.directions_bus, color: color, size: 32),
              title: Text(bus["busId"]),
              subtitle: Text(
                "Crowd: ${bus["crowd"]} people\nETA: ${bus["eta"]} mins",
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(8.5241, 76.9366),
              zoom: 14,
            ),
            markers: _markers.values.toSet(),
            onMapCreated: (controller) {
              mapController = controller;
            },
          ),
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Column(
              children: [
                _buildTextField(_sourceController, "Enter Source"),
                const SizedBox(height: 8),
                _buildTextField(_destinationController, "Enter Destination"),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _searchBuses,
                  child: const Text("Search Buses"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint),
      ),
    );
  }
}
