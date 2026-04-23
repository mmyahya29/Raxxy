import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/screens/track_screens/track_dashboard_screen.dart';
import '../../providers/provider.dart';
import 'track_mapping_screen.dart';

class TrackManagementScreen extends ConsumerWidget {
  const TrackManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(firebaseAuthProvider);
    final userId = auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'TRACK MANAGEMENT',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: userId == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('tracks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final tracks = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 100.h),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final data = tracks[index].data() as Map<String, dynamic>;
              return _ExpandableTrackCard(trackData: data, docId: tracks[index].id);
            },
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 60.h),
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF00E5FF),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackMappingScreen()));
          },
          icon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF0A0E27)),
          label: const Text('MAP NEW TRACK', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0A0E27), letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 80.r, color: Colors.white24),
          SizedBox(height: 20.h),
          Text('NO TRACKS MAPPED', style: TextStyle(color: Colors.white54, fontSize: 14.sp, fontWeight: FontWeight.bold, letterSpacing: 2)),
          SizedBox(height: 10.h),
          Text('Walk the boundary to create your first track layout.', style: TextStyle(color: Colors.white30, fontSize: 12.sp)),
        ],
      ),
    );
  }
}

class _ExpandableTrackCard extends StatefulWidget {
  final Map<String, dynamic> trackData;
  final String docId;

  const _ExpandableTrackCard({required this.trackData, required this.docId});

  @override
  State<_ExpandableTrackCard> createState() => _ExpandableTrackCardState();
}

class _ExpandableTrackCardState extends State<_ExpandableTrackCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final trackName = (widget.trackData['trackName'] ?? 'Unknown Track').toString().toUpperCase();
    final length = (widget.trackData['estimatedLengthKm'] ?? 0.0) as double;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(bottom: 15.h),
      decoration: BoxDecoration(
        color: _isExpanded ? const Color(0xFF1A1F3A).withOpacity(0.8) : const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _isExpanded ? const Color(0xFFFF9800) : const Color(0xFF00E5FF).withOpacity(0.3), width: 1.5),
        boxShadow: [
          if (_isExpanded) BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.2), blurRadius: 15)
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: _isExpanded ? const Color(0xFFFF9800).withOpacity(0.15) : const Color(0xFF00E5FF).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.flag_circle_rounded, color: _isExpanded ? const Color(0xFFFF9800) : const Color(0xFF00E5FF), size: 24.r),
                  ),
                  SizedBox(width: 15.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trackName, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        SizedBox(height: 4.h),
                        Text('Length: ${length.toStringAsFixed(2)} km', style: TextStyle(color: Colors.white54, fontSize: 11.sp, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white30, size: 28.r),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Column(
                children: [
                  Divider(color: Colors.white10, height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStat('CORNERS', 'N/A'),
                      _buildStat('BEST LAP', '--:--'),
                      _buildStat('TOP SPEED', '--'),
                    ],
                  ),
                  SizedBox(height: 15.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RacingDashboardScreen(trackData: widget.trackData),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_score_rounded, color: const Color(0xFF0A0E27), size: 22.r),
                          SizedBox(width: 8.w),
                          Text('START TRACK MODE', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0A0E27), letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white30, fontSize: 9.sp, fontWeight: FontWeight.bold, letterSpacing: 1)),
        SizedBox(height: 4.h),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900)),
      ],
    );
  }
}