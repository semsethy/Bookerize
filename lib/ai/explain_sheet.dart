import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../theme.dart';
import 'ai_client.dart';

/// A sentence, put in plainer words.
///
/// Shows the author's sentence at the top and the simpler version beneath it,
/// so you can read the plain one and then go back to the original and finally
/// see it. Not a summary and not a translation: the same meaning, easier words.
class ExplainSheet extends ConsumerStatefulWidget {
  const ExplainSheet({required this.sentence, super.key});

  final String sentence;

  static Future<void> show(BuildContext context, String sentence) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExplainSheet(sentence: sentence),
    );
  }

  @override
  ConsumerState<ExplainSheet> createState() => _ExplainSheetState();
}

class _ExplainSheetState extends ConsumerState<ExplainSheet> {
  StreamSubscription<String>? _subscription;
  final _answer = StringBuffer();
  bool _streaming = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Asked for the moment the sheet opens: the reader already said what they
    // wanted by tapping Explain, so making them tap again would be a toll.
    _ask();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _ask() {
    _subscription = ref
        .read(explainerProvider)
        .explainSentence(sentence: widget.sentence)
        .listen(
          (chunk) => setState(() => _answer.write(chunk)),
          onError: (Object error) => setState(() {
            _streaming = false;
            _error = error is AiException
                ? error.message
                : 'Something went wrong.';
          }),
          onDone: () {
            if (mounted) setState(() => _streaming = false);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottomInset > 0 ? 10 : 14),
      child: Material(
        color: const Color(0xFFFCFBF9),
        borderRadius: BorderRadius.circular(26),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFC8BB),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'In plain words',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.25,
                      color: Paper.ink,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Paper.rule),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'GEMINI',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: Paper.soft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // The author's own sentence, kept in view.
              Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Paper.marker, width: 2),
                  ),
                ),
                child: Text(
                  widget.sentence,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 14,
                    height: 1.45,
                    color: Paper.soft,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Paper.soft,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 60),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: _answer.toString()),
                        if (_streaming)
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _SheetCaret(),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 15.5,
                      height: 1.5,
                      color: Color(0xFF3A352C),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetCaret extends StatelessWidget {
  const _SheetCaret();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 15,
      margin: const EdgeInsets.only(left: 2),
      color: Paper.pen,
    );
  }
}
