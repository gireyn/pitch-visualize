import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/app_theme.dart';

class GraphWatermarks extends StatelessWidget {
  const GraphWatermarks({
    super.key,
    required this.scaleName,
    required this.bpm,
  });

  final String scaleName;
  final int bpm;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: AppColors.muted.withValues(alpha: .8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.scaleName(scaleName),
                semanticsLabel: context.l10n.graphCurrentTuning(
                  context.l10n.scaleName(scaleName),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text('$bpm BPM', semanticsLabel: context.l10n.graphTempo(bpm)),
          ],
        ),
      ),
    ),
  );
}
