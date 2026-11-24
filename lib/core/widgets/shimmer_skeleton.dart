import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: const [
                AppColors.card,
                AppColors.cardHover,
                AppColors.card,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal row of skeleton cards for trending charts
class ShimmerHorizontalCharts extends StatelessWidget {
  const ShimmerHorizontalCharts({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 148,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerSkeleton(width: 148, height: 148, borderRadius: 8),
                SizedBox(height: 8),
                ShimmerSkeleton(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerSkeleton(width: 80, height: 12, borderRadius: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for track rows in Search and Library
class ShimmerTrackRow extends StatelessWidget {
  const ShimmerTrackRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: const [
          ShimmerSkeleton(width: 48, height: 48, borderRadius: 6),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(width: double.infinity, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerSkeleton(width: 140, height: 12, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 20),
          ShimmerSkeleton(width: 40, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}
