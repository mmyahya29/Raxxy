import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/provider.dart';
import '../../services/racing_telemetary_core.dart';

enum MappingState { idle, mappingLeft, mappingRight, processing }

class TrackMappingScreen extends ConsumerStatefulWidget {
  const TrackMappingScreen({super.key});

  @override
  ConsumerState<TrackMappingScreen> createState() => _TrackMappingScreenState();
}

class _TrackMappingScreenState extends ConsumerState<TrackMappingScreen> {
  MappingState _state = MappingState.idle;

  final List<Position> _leftBoundaryRaw = [];
  final List<Position> _rightBoundaryRaw = [];
  StreamSubscription<Position>? _positionSub;

  final TextEditingController _nameController = TextEditingController();

  void _toggleMapping(MappingState targetState) async {
    if (_state == targetState) {
      _positionSub?.cancel();
      setState(() => _state = MappingState.idle);
    } else {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      setState(() => _state = targetState);

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1),
      ).listen((Position position) {
        setState(() {
          if (_state == MappingState.mappingLeft) _leftBoundaryRaw.add(position);
          if (_state == MappingState.mappingRight) _rightBoundaryRaw.add(position);
        });
      });
    }
  }

  Future<void> _processAndSaveTrack() async {
    if (_leftBoundaryRaw.length < 4 || _rightBoundaryRaw.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please map more points for a valid track.')));
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please name the track first.')));
      return;
    }

    setState(() => _state = MappingState.processing);

    final auth = ref.read(firebaseAuthProvider);
    final userId = auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final anchor = _leftBoundaryRaw.first;
      final leftCartesian = _leftBoundaryRaw.map((p) => CoordinateConverter.latLonToCartesian(p.latitude, p.longitude, anchor.latitude, anchor.longitude)).toList();
      final rightCartesian = _rightBoundaryRaw.map((p) => CoordinateConverter.latLonToCartesian(p.latitude, p.longitude, anchor.latitude, anchor.longitude)).toList();

      final smoothedLeft = TrackBoundarySmoother.smoothBoundary(leftCartesian);
      final smoothedRight = TrackBoundarySmoother.smoothBoundary(rightCartesian);
      final centerline = TrackAnalyzer.calculateCenterline(smoothedLeft, smoothedRight);

      await FirebaseFirestore.instance.collection('users').doc(userId).collection('tracks').add({
        'trackName': _nameController.text.trim(),
        'anchorLat': anchor.latitude,
        'anchorLon': anchor.longitude,
        'leftBoundary': smoothedLeft.map((p) => p.toMap()).toList(),
        'rightBoundary': smoothedRight.map((p) => p.toMap()).toList(),
        'centerline': centerline.map((p) => p.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'estimatedLengthKm': (_leftBoundaryRaw.length * 1.5) / 1000.0,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _state = MappingState.idle);
      debugPrint("Error saving track: $e");
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _state == MappingState.processing;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('MAP TRACK BOUNDARIES', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
      ),
      body: SafeArea(
        child: isProcessing
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
            : Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Track Name (e.g. Silverstone)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: const Color(0xFF8B7CFF).withOpacity(0.5)), borderRadius: BorderRadius.circular(12.r)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF8B7CFF)), borderRadius: BorderRadius.circular(12.r)),
                  filled: true,
                  fillColor: const Color(0xFF1A1F3A),
                ),
              ),
              SizedBox(height: 20.h),

              _buildMappingCard(
                title: 'LEFT PERIMETER', subtitle: 'Walk the inner/left edge of the track.',
                pointCount: _leftBoundaryRaw.length, isActive: _state == MappingState.mappingLeft,
                color: const Color(0xFF00E5FF), onTap: () => _toggleMapping(MappingState.mappingLeft),
              ),
              SizedBox(height: 15.h),

              _buildMappingCard(
                title: 'RIGHT PERIMETER', subtitle: 'Walk the outer/right edge of the track.',
                pointCount: _rightBoundaryRaw.length, isActive: _state == MappingState.mappingRight,
                color: const Color(0xFFFF9800), onTap: () => _toggleMapping(MappingState.mappingRight),
              ),
              SizedBox(height: 20.h),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F3A), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.r),
                    child: Stack(
                      children: [
                        CustomPaint(
                          painter: TrackPreviewPainter(leftBoundary: _leftBoundaryRaw, rightBoundary: _rightBoundaryRaw),
                          child: const SizedBox.expand(),
                        ),
                        if (_leftBoundaryRaw.isEmpty && _rightBoundaryRaw.isEmpty)
                          Center(child: Text('Awaiting GPS Data...', style: TextStyle(color: Colors.white30, fontSize: 12.sp, fontWeight: FontWeight.bold))),
                        Positioned(
                          top: 10.h, left: 15.w,
                          child: Text('LIVE RADAR', style: TextStyle(color: Colors.white54, fontSize: 10.sp, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              SizedBox(
                width: double.infinity, height: 55.h,
                child: ElevatedButton(
                  onPressed: (_leftBoundaryRaw.isNotEmpty && _rightBoundaryRaw.isNotEmpty) ? _processAndSaveTrack : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B7CFF), disabledBackgroundColor: const Color(0xFF1A1F3A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                  child: Text('PROCESS & SAVE TRACK', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ),
              ),
              SizedBox(height: 15.h)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMappingCard({required String title, required String subtitle, required int pointCount, required bool isActive, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(15.r),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isActive ? color : Colors.white10, width: isActive ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(color: isActive ? color : color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(isActive ? Icons.stop_rounded : Icons.play_arrow_rounded, color: isActive ? const Color(0xFF0A0E27) : color, size: 24.r),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4.h),
                  Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
                ],
              ),
            ),
            Text('$pointCount pts', style: TextStyle(color: color, fontSize: 13.sp, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class TrackPreviewPainter extends CustomPainter {
  final List<Position> leftBoundary;
  final List<Position> rightBoundary;

  TrackPreviewPainter({required this.leftBoundary, required this.rightBoundary});

  @override
  void paint(Canvas canvas, Size size) {
    if (leftBoundary.isEmpty && rightBoundary.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0;
    double minLon = 180.0, maxLon = -180.0;

    void updateBounds(Position p) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    for (var p in leftBoundary) { updateBounds(p); }
    for (var p in rightBoundary) { updateBounds(p); }

    double latRange = maxLat - minLat;
    double lonRange = maxLon - minLon;
    if (latRange == 0) latRange = 0.0001;
    if (lonRange == 0) lonRange = 0.0001;

    minLat -= latRange * 0.1; maxLat += latRange * 0.1;
    minLon -= lonRange * 0.1; maxLon += lonRange * 0.1;
    latRange = maxLat - minLat; lonRange = maxLon - minLon;

    Offset getOffset(Position p) {
      double x = ((p.longitude - minLon) / lonRange) * size.width;
      double y = size.height - (((p.latitude - minLat) / latRange) * size.height);
      return Offset(x, y);
    }

    if (leftBoundary.isNotEmpty) {
      final leftPaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
      final leftPath = Path()..moveTo(getOffset(leftBoundary.first).dx, getOffset(leftBoundary.first).dy);
      for (int i = 1; i < leftBoundary.length; i++) leftPath.lineTo(getOffset(leftBoundary[i]).dx, getOffset(leftBoundary[i]).dy);
      canvas.drawPath(leftPath, leftPaint);
      canvas.drawCircle(getOffset(leftBoundary.last), 4, Paint()..color = const Color(0xFF00E5FF));
    }

    if (rightBoundary.isNotEmpty) {
      final rightPaint = Paint()..color = const Color(0xFFFF9800)..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
      final rightPath = Path()..moveTo(getOffset(rightBoundary.first).dx, getOffset(rightBoundary.first).dy);
      for (int i = 1; i < rightBoundary.length; i++) rightPath.lineTo(getOffset(rightBoundary[i]).dx, getOffset(rightBoundary[i]).dy);
      canvas.drawPath(rightPath, rightPaint);
      canvas.drawCircle(getOffset(rightBoundary.last), 4, Paint()..color = const Color(0xFFFF9800));
    }
  }

  @override
  bool shouldRepaint(covariant TrackPreviewPainter oldDelegate) {
    return leftBoundary.length != oldDelegate.leftBoundary.length || rightBoundary.length != oldDelegate.rightBoundary.length;
  }
}