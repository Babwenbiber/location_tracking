import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location_tracking/calc/locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShowLocationPage extends StatefulWidget {
  const ShowLocationPage({Key? key}) : super(key: key);

  @override
  _ShowLocationPageState createState() => _ShowLocationPageState();
}

class _ShowLocationPageState extends State<ShowLocationPage> {
  final List<Position> positions = [];
  final Stream<Position> posStream =
      Geolocator.getPositionStream(distanceFilter: 0);
  double sum = 0;
  Position? initPos;
  int posNodes = 0;
  final Set<Marker> markers = {};
  final Set<Polyline> lines = {};
  bool started = false;
  late StreamSubscription<Position> streamSubscription;

  void addPosition(Position position) {
    debugPrint("new pos $position");
    bool isValidPos = true;
    positions.add(position);
    posNodes++;
    if (positions.length >= 2) {
      isValidPos = isValidPosition(
          positions[positions.length - 1], positions[positions.length - 2]);
      lines.add(Polyline(
          polylineId: PolylineId(positions.length.toString()),
          points: [
            LatLng(positions[positions.length - 2].latitude,
                positions[positions.length - 2].longitude),
            LatLng(positions[positions.length - 1].latitude,
                positions[positions.length - 1].longitude)
          ]));
      sum += Geolocator.distanceBetween(
          positions[positions.length - 2].latitude,
          positions[positions.length - 2].longitude,
          positions[positions.length - 1].latitude,
          positions[positions.length - 1].longitude);
    }

    getMarker(isValidPos ? Colors.blue : Colors.red)
        .then((color) => setState(() => markers.add(Marker(
            markerId: MarkerId(
              positions.length.toString(),
            ),
            icon: color,
            position: LatLng(position.latitude, position.longitude)))));
  }

  bool isValidPosition(Position currentPos, Position lastPos) {
    Duration timeDiff = currentPos.timestamp!.difference(lastPos.timestamp!);
    double locDiff = Geolocator.distanceBetween(currentPos.latitude,
        currentPos.longitude, lastPos.latitude, lastPos.longitude);
    if (timeDiff.inMicroseconds * max(currentPos.speed, lastPos.speed) / 1000 >
        0.3 * locDiff) {
      return true;
    }
    return false;
  }

  void setPropsFromPositions() {
    sum = 0;
    posNodes = positions.length;
    markers.clear();
    lines.clear();
    for (int i = 0; i < positions.length; i++) {
      bool isValidPos = true;
      if (i >= 1) {
        isValidPos = isValidPosition(positions[i], positions[i - 1]);
      }
      getMarker(isValidPos ? Colors.blue : Colors.red).then((color) => setState(
          () => markers.add(Marker(
              infoWindow: InfoWindow(
                  title: DateFormat('hh:mm:ss').format(positions[i].timestamp!),
                  snippet:
                      "${(positions[i].speed * 3.6).toStringAsFixed(1)} km/h"),
              markerId: MarkerId(
                i.toString(),
              ),
              icon: color,
              position:
                  LatLng(positions[i].latitude, positions[i].longitude)))));

      if (i >= 1) {
        lines.add(Polyline(polylineId: PolylineId(i.toString()), points: [
          LatLng(positions[i - 1].latitude, positions[i - 1].longitude),
          LatLng(positions[i].latitude, positions[i].longitude)
        ]));
        sum += Geolocator.distanceBetween(
            positions[i - 1].latitude,
            positions[i - 1].longitude,
            positions[i].latitude,
            positions[i].longitude);
      }
    }
    setState(() {});
  }

  @override
  void initState() {
    getLocationPermissions();
    streamSubscription = posStream.listen((position) {
      addPosition(position);
    }, onDone: () {
      print("new pos: DONE");
    }, onError: (err) {
      print("new pos: $err");
    }, cancelOnError: false);
    streamSubscription.pause();
    Geolocator.getLastKnownPosition().then((value) => initPos = value);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: getActionIcons(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              "Data-Nodes: $posNodes",
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            Text(
              "Total-Distance: ${sum.toStringAsFixed(0)} m",
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            if (positions.isNotEmpty)
              Text(
                "Velocity: ${(positions[positions.length - 1].speed * 3.6).toStringAsFixed(1)} km/h",
                style: const TextStyle(fontSize: 20),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  MaterialButton(
                    onPressed: () {
                      setState(() {
                        streamSubscription.pause();
                      });
                    },
                    child: Container(
                        height: 50,
                        width: 100,
                        color: Colors.red,
                        child: const Center(
                            child: Text("Stop",
                                style: TextStyle(color: Colors.white)))),
                  ),
                  MaterialButton(
                    onPressed: () {
                      setState(() {
                        streamSubscription.resume();
                      });
                    },
                    child: Container(
                        height: 50,
                        width: 100,
                        color: streamSubscription.isPaused
                            ? Colors.green
                            : Colors.orange,
                        child: Center(
                          child: Text(
                            streamSubscription.isPaused ? "Start" : "Running",
                            style: const TextStyle(color: Colors.white),
                          ),
                        )),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GoogleMap(
                  markers: markers,
                  // polylines: lines,
                  initialCameraPosition: CameraPosition(
                      target: initPos == null
                          ? const LatLng(52, 10)
                          : LatLng(initPos!.latitude, initPos!.longitude))),
            )
          ],
        ),
      ),
    );
  }

  List<Widget> getActionIcons() {
    return [
      Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
              onTap: () async {
                var pref = await SharedPreferences.getInstance();
                String? track = pref.getString("track");
                if (track != null) {
                  positions.clear();
                  for (var pos in json.decode(track)["list"]) {
                    positions.add(Position.fromMap(pos));
                  }
                  setPropsFromPositions();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text("reloaded")));
                }
              },
              child: const Icon(
                Icons.book,
                size: 40,
              ))),
      Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
              onTap: () async {
                var pref = await SharedPreferences.getInstance();
                pref.setString(
                    "track",
                    json.encode(
                        {"list": positions.map((e) => e.toJson()).toList()}));
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text("saved")));
              },
              child: const Icon(
                Icons.save,
                size: 40,
              ))),
      Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () {
            setState(() {
              positions.clear();
              sum = 0;
              lines.clear();
              markers.clear();
              posNodes = 0;
            });
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text("cleared")));
          },
          child: const Icon(Icons.refresh, size: 40),
        ),
      ),
    ];
  }

  Future<BitmapDescriptor> getMarker(
    Color color,
  ) async {
    final PictureRecorder pictureRecorder = PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    const double radius = 20;
    canvas.drawCircle(
      const Offset(radius, radius),
      radius,
      paint,
    );

    final image = await pictureRecorder.endRecording().toImage(
          radius.toInt() * 2,
          radius.toInt() * 2,
        );
    final data = await image.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}
