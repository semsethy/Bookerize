import 'package:flutter/material.dart';

import '../theme.dart';

/// Everything that isn't the page: a way back, where you are, and a way to jump.
///
/// Hidden by default — the page is the whole screen — and revealed by tapping
/// the middle of it. Both bars slide out of the way rather than fading, so it
/// reads as chrome moving aside rather than the page changing.
class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    required this.visible,
    required this.title,
    required this.pageNumber,
    required this.pageCount,
    required this.onSeek,
    super.key,
  });

  final bool visible;
  final String title;
  final int pageNumber;
  final int pageCount;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return IgnorePointer(
      ignoring: !visible,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            top: visible ? 0 : -(topInset + 62),
            child: _TopBar(title: title, topInset: topInset),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: visible ? 0 : -(bottomInset + 96),
            child: _BottomBar(
              pageNumber: pageNumber,
              pageCount: pageCount,
              bottomInset: bottomInset,
              onSeek: onSeek,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.topInset});

  final String title;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return _Frosted(
      padding: EdgeInsets.fromLTRB(6, topInset + 4, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left),
            color: Paper.ink,
            tooltip: 'Back to your library',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Paper.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.pageNumber,
    required this.pageCount,
    required this.bottomInset,
    required this.onSeek,
  });

  final int pageNumber;
  final int pageCount;
  final double bottomInset;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    // A one-page book would give the slider an empty range.
    final canSeek = pageCount > 1;

    return _Frosted(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canSeek)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: Paper.ink,
                inactiveTrackColor: Paper.rule,
                thumbColor: Paper.ink,
                overlayColor: Paper.pen.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: pageNumber.clamp(1, pageCount).toDouble(),
                min: 1,
                max: pageCount.toDouble(),
                onChanged: (v) => onSeek(v.round()),
              ),
            ),
          Text(
            'Page $pageNumber of $pageCount',
            style: const TextStyle(
              fontSize: 12,
              color: Paper.soft,
              letterSpacing: 0.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Frosted extends StatelessWidget {
  const _Frosted({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Paper.ground.withValues(alpha: 0.94),
      child: Padding(padding: padding, child: child),
    );
  }
}
