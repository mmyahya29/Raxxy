import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
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
            padding: EdgeInsets.all(20.w),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final data = tracks[index].data() as Map<String, dynamic>;
              return _buildTrackCard(data, tracks[index].id);
            },
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 50).r,
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF00E5FF),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackMappingScreen()));
          },
          icon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF0A0E27)),
          label: const Text(
            'MAP NEW TRACK',
            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0A0E27), letterSpacing: 1),
          ),
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
          Text(
            'NO TRACKS MAPPED',
            style: TextStyle(color: Colors.white54, fontSize: 14.sp, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          SizedBox(height: 10.h),
          Text(
            'Walk the boundary to create your first track layout.',
            style: TextStyle(color: Colors.white30, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackCard(Map<String, dynamic> data, String docId) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.route_rounded, color: const Color(0xFF00E5FF), size: 24.r),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['trackName'] ?? 'Unknown Track').toString().toUpperCase(),
                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Length: ${(data['estimatedLengthKm'] ?? 0.0).toStringAsFixed(2)} km',
                  style: TextStyle(color: Colors.white54, fontSize: 11.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 24.r),
        ],
      ),
    );
  }
}