import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/roll_notice.dart';

class RollNoticeStack extends StatelessWidget {
  final List<RollNotice> notices;

  const RollNoticeStack({super.key, required this.notices});

  static const double noticeHeight = 68;
  static const double noticeSpacing = 6;

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) return const SizedBox.shrink();

    final width = math.min(MediaQuery.sizeOf(context).width - 24, 272.0);
    final step = noticeHeight + noticeSpacing;

    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: notices.length * step,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < notices.length; index++)
              AnimatedPositioned(
                key: ValueKey('roll-notice-position-${notices[index].id}'),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                top: index * step,
                right: 0,
                width: width,
                height: noticeHeight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  opacity: notices[index].visible ? 1 : 0,
                  child: _RollNoticeCard(
                    key: ValueKey('roll-notice-${notices[index].id}'),
                    notice: notices[index],
                    isLatest: index == 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RollNoticeCard extends StatelessWidget {
  final RollNotice notice;
  final bool isLatest;

  const _RollNoticeCard({
    super.key,
    required this.notice,
    required this.isLatest,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = switch (notice.tone) {
      RollNoticeTone.criticalSuccess => Colors.greenAccent,
      RollNoticeTone.criticalFailure => colorScheme.error,
      RollNoticeTone.damage => colorScheme.tertiary,
      RollNoticeTone.normal => colorScheme.primary,
    };

    return Material(
      key: isLatest ? const ValueKey('latest-roll-notice') : null,
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notice.calculation,
                    key: isLatest
                        ? const ValueKey('latest-roll-calculation')
                        : null,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  if (notice.detail case final detail?)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${notice.total}',
              key: isLatest ? const ValueKey('latest-roll-total') : null,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
