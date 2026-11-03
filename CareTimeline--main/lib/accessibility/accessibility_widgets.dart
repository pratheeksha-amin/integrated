import 'package:flutter/material.dart';
import 'font_size_service.dart';
import 'tts_service.dart';

/// Font Size Adjustment Control Row
class FontSizeControls extends StatelessWidget {
  final bool compact;
  final Color? color;

  const FontSizeControls({
    super.key,
    this.compact = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: FontSizeService.instance.fontSizeNotifier,
      builder: (context, fontSize, _) {
        final currentPt = fontSize.toInt();
        return Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(140),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                tooltip: 'Decrease font size',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: fontSize <= FontSizeService.minFontSize
                    ? null
                    : () => FontSizeService.instance.decreaseFontSize(),
              ),
              InkWell(
                onTap: () => FontSizeService.instance.resetFontSize(),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'A',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color ?? colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${currentPt}pt',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: 'Increase font size',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: fontSize >= FontSizeService.maxFontSize
                    ? null
                    : () => FontSizeService.instance.increaseFontSize(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Text-to-Speech Control Bar with Read Aloud, Pause, Resume, and Stop
class TtsControlBar extends StatelessWidget {
  final String textToRead;
  final String languageCode;
  final String label;

  const TtsControlBar({
    super.key,
    required this.textToRead,
    this.languageCode = 'en',
    this.label = 'Read Aloud',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<TtsState>(
      valueListenable: TtsService.instance.stateNotifier,
      builder: (context, state, _) {
        final isPlaying = state == TtsState.playing;
        final isPaused = state == TtsState.paused;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.primary.withAlpha(80)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPlaying ? Icons.volume_up : Icons.record_voice_over,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isPlaying && !isPaused)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Play', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        TtsService.instance.speak(textToRead, languageCode: languageCode);
                      },
                    ),
                  if (isPlaying) ...[
                    IconButton.filledTonal(
                      icon: const Icon(Icons.pause, size: 16),
                      tooltip: 'Pause Speech',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        TtsService.instance.pause();
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.stop, size: 16),
                      tooltip: 'Stop Speech',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        TtsService.instance.stop();
                      },
                    ),
                  ],
                  if (isPaused) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Resume', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        TtsService.instance.resume();
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.stop, size: 16),
                      tooltip: 'Stop Speech',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        TtsService.instance.stop();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
