import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late GoogleMapController mapController;

  String? _selectedSource;
  String? _selectedDestination;
  String? _selectedBusId; // currently selected bus id

  final Map<String, Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  late BitmapDescriptor busGreenIcon;
  late BitmapDescriptor busYellowIcon;
  late BitmapDescriptor busRedIcon;

  StreamSubscription? _busSubscription;
  PersistentBottomSheetController<dynamic>? _bottomSheetController;

  List<String> _allStops = [];
  Map<String, LatLng> _stopCoords = {}; // map stopName → coordinates

  @override
  void initState() {
    super.initState();
    _loadStops();
    _loadBusIcons();
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
    _bottomSheetController?.close();
    super.dispose();
  }

  Future<void> _loadStops() async {
    final snapshot = await FirebaseFirestore.instance.collection("stops").get();

    final Set<String> uniqueStops = {};
    final Map<String, LatLng> coordsMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final name = data['name'];
      final coord = data['coordinates'];

      if (name == null || coord == null) continue;

      uniqueStops.add(name);

      coordsMap[name] = LatLng(
        (coord['lat'] as num).toDouble(),
        (coord['lng'] as num).toDouble(),
      );
    }

    setState(() {
      _allStops = uniqueStops.toList()..sort();
      _stopCoords = coordsMap;
      _selectedSource = null;
      _selectedDestination = null;
    });
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

    _listenToBuses();
  }

  void _listenToBuses() {
    _busSubscription = FirebaseFirestore.instance
        .collection("buses")
        .snapshots()
        .listen((snapshot) {
          final newMarkers = <String, Marker>{};

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final coords = data["coordinates"] ?? {};
            final lat = (coords["lat"] as num?)?.toDouble() ?? 0.0;
            final lng = (coords["lng"] as num?)?.toDouble() ?? 0.0;
            final crowd = (data["passengerCount"] as num?)?.toInt() ?? 0;

            BitmapDescriptor icon;
            if (crowd < 20) {
              icon = busGreenIcon;
            } else if (crowd < 40) {
              icon = busYellowIcon;
            } else {
              icon = busRedIcon;
            }

            newMarkers[doc.id] = Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              icon: icon,
              infoWindow: InfoWindow(
                title: data["busNumber"] ?? doc.id,
                snippet:
                    "Passengers: $crowd\nNext stop: ${data["nextStop"]}\nETA: ${data["etaToNextStop"]} min",
              ),
            );
          }

          setState(() {
            _markers
              ..clear()
              ..addAll(newMarkers);
          });
        });
  }

  Future<void> _searchBuses() async {
    if (_selectedSource == null || _selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select both source and destination")),
      );
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection("routes")
        .get();

    String? sourceRoute;
    String? destRoute;
    List<String> stops = [];

    for (var doc in snapshot.docs) {
      final routeStops = List<String>.from(doc["stops"]);
      if (routeStops.contains(_selectedSource)) {
        sourceRoute = doc.id;
      }
      if (routeStops.contains(_selectedDestination)) {
        destRoute = doc.id;
      }
      if (sourceRoute != null &&
          destRoute != null &&
          sourceRoute == destRoute) {
        stops = routeStops;
        break;
      }
    }

    if (sourceRoute == null || destRoute == null || sourceRoute != destRoute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Source and destination must be on the same route"),
        ),
      );
      return;
    }

    final srcIndex = stops.indexOf(_selectedSource!);
    final destIndex = stops.indexOf(_selectedDestination!);

    if (srcIndex == -1 || destIndex == -1 || srcIndex >= destIndex) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid stop selection")));
      return;
    }

    final busIds = List<String>.from(
      (await FirebaseFirestore.instance
                  .collection("routes")
                  .doc(sourceRoute)
                  .get())
              .data()?["buses"] ??
          [],
    );

    final buses = _markers.values
        .where((m) => busIds.contains(m.markerId.value))
        .toList();

    if (buses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No buses available for this route")),
      );
      return;
    }

    final selectedRouteStops = stops.sublist(srcIndex, destIndex + 1);
    _drawPolyline(selectedRouteStops);

    _showBusList(buses);
  }

  void _drawPolyline(List<String> stopNames) {
    if (stopNames.isEmpty) return;

    final points = stopNames
        .where((name) => _stopCoords.containsKey(name))
        .map((name) => _stopCoords[name]!)
        .toList();

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: points,
          color: Colors.blue,
          width: 5,
        ),
      );
    });

    if (points.isNotEmpty) {
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(_boundsFromLatLngList(points), 60),
      );
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double x0 = list.first.latitude,
        x1 = list.first.latitude,
        y0 = list.first.longitude,
        y1 = list.first.longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }

    return LatLngBounds(southwest: LatLng(x0, y0), northeast: LatLng(x1, y1));
  }

  void _showBusList(List<Marker> buses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.6,
            child: ListView.builder(
              itemCount: buses.length,
              itemBuilder: (context, index) {
                final marker = buses[index];
                return ListTile(
                  leading: const Icon(Icons.directions_bus, size: 32),
                  title: Text(marker.infoWindow.title ?? "Bus"),
                  subtitle: Text(marker.infoWindow.snippet ?? ""),
                  onTap: () {
                    final busId = marker.markerId.value;
                    mapController.animateCamera(
                      CameraUpdate.newLatLngZoom(marker.position, 16),
                    );
                    Navigator.pop(context);
                    _openPersistentBusPanel(busId);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openPersistentBusPanel(String busId) {
    _selectedBusId = busId;
    _bottomSheetController?.close();

    _bottomSheetController = _scaffoldKey.currentState?.showBottomSheet(
      (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("buses")
              .doc(busId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final coords = data["coordinates"] ?? {};
            final lat = (coords["lat"] as num?)?.toDouble() ?? 0.0;
            final lng = (coords["lng"] as num?)?.toDouble() ?? 0.0;
            final passengerCount =
                (data["passengerCount"] as num?)?.toInt() ?? 0;
            final eta = (data["etaToNextStop"] as num?)?.toInt() ?? 0;
            final nextStop = data["nextStop"] ?? "-";
            final busNumber = data["busNumber"] ?? busId;

            return Container(
              height: 180,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    busNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Passengers: $passengerCount"),
                  Text("Next Stop: $nextStop"),
                  Text("ETA: $eta min"),
                  const Spacer(),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          mapController.animateCamera(
                            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
                          );
                        },
                        icon: const Icon(Icons.my_location),
                        label: const Text("Center on bus"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          _bottomSheetController?.close();
                          _selectedBusId = null;
                        },
                        icon: const Icon(Icons.close),
                        label: const Text("Close"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      backgroundColor: Colors.white,
      elevation: 8.0,
    );

    _bottomSheetController?.closed.then((_) {
      if (mounted) {
        setState(() {
          _selectedBusId = null;
          _bottomSheetController = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(8.5241, 76.9366),
              zoom: 13,
            ),
            markers: _markers.values.toSet(),
            polylines: _polylines,
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
                _buildDropdown(
                  value: _selectedSource,
                  hint: "Select Source",
                  onChanged: (val) {
                    setState(() => _selectedSource = val);
                  },
                ),
                const SizedBox(height: 8),
                _buildDropdown(
                  value: _selectedDestination,
                  hint: "Select Destination",
                  onChanged: (val) {
                    setState(() => _selectedDestination = val);
                  },
                ),
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

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    final bool disabled = _allStops.isEmpty;
    final String? safeValue = (value != null && _allStops.contains(value))
        ? value
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        items: _allStops
            .map((stop) => DropdownMenuItem(value: stop, child: Text(stop)))
            .toList(),
        onChanged: disabled ? null : onChanged,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint),
        hint: Text(disabled ? 'Loading stops...' : hint),
      ),
    );
  }
}
