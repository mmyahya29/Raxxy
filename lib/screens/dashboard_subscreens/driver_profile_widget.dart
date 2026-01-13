import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/driver_profile_provider.dart';

Widget driverProfileWidget(BuildContext context) {
  return Container(
    width: MediaQuery.of(context).size.width - 40,
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(30.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 4,
          spreadRadius: 3,
        ),
      ],
    ),
    padding: EdgeInsets.all(16.r),
    child: Consumer(
      builder: (context, ref, _) {
        final profileAsync = ref.watch(driverProfileProvider);

        return profileAsync.when(
          data: (profile) {
            final badge = profile['badge'] as Map<String, dynamic>;

            // FIX: Use Map.from to safely convert dynamic map to int map
            final scores = Map<String, int>.from(profile['scores'] ?? {});

            final traits = List<String>.from(profile['secondaryTraits'] ?? []);
            final recommendations = List<String>.from(profile['recommendations'] ?? []);

            // NEW: Display Stress Triggers
            final stressTriggers = List<String>.from(profile['stressTriggers'] ?? []);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile['primaryProfile']}',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${badge['emoji']} ${badge['tier']}',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.emoji_events, size: 50.r, color: Colors.amber),
                  ],
                ),
                SizedBox(height: 10.h),

                // Stress Triggers (New Section)
                if (stressTriggers.isNotEmpty) ...[
                  Text(
                    '⚠️ Stress Triggers:',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.redAccent),
                  ),
                  Wrap(
                    spacing: 8,
                    children: stressTriggers
                        .map(
                          (trigger) => Chip(
                        label: Text(trigger, style: const TextStyle(color: Colors.white)),
                        backgroundColor: Colors.redAccent,
                      ),
                    )
                        .toList(),
                  ),
                  SizedBox(height: 10.h),
                ],

                // Secondary traits
                if (traits.isNotEmpty) ...[
                  Text(
                    'Traits:',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                  Wrap(
                    spacing: 8,
                    children: traits
                        .map(
                          (trait) => Chip(
                        label: Text(trait),
                        backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      ),
                    )
                        .toList(),
                  ),
                  SizedBox(height: 10.h),
                ],

                // Scores
                Text(
                  'Performance Scores:',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 5.h),
                _buildScoreBar('Overall', scores['overall'] ?? 0, Colors.purple),
                _buildScoreBar('Smoothness', scores['smoothness'] ?? 0, Colors.green),
                _buildScoreBar('Safety', scores['safety'] ?? 0, Colors.blue),
                _buildScoreBar('Efficiency', scores['efficiency'] ?? 0, Colors.orange),

                SizedBox(height: 10.h),

                // Recommendations
                if (recommendations.isNotEmpty) ...[
                  Text(
                    'Recommendations:',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                  ...recommendations.map(
                        (rec) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb, size: 16.r, color: Colors.amber),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              rec,
                              style: TextStyle(fontSize: 14.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        );
      },
    ),
  );
}

Widget _buildScoreBar(String label, int score, Color color) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14.sp)),
            Text('$score/100', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 4.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey[300],
            color: color,
            minHeight: 8.h,
          ),
        ),
      ],
    ),
  );
}