import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_client.dart';
import '../data/providers.dart';
import '../theme.dart';
import 'dictionary.dart';

/// What a long-press turns up: the word, and what it means.
class WordLookup {
  const WordLookup({
    required this.word,
    required this.sentence,
    required this.definitions,
  });

  /// Exactly what was pressed, as printed on the page.
  final String word;

  /// The sentence it sits in. Phase 5 sends this to the model for "what does it
  /// mean *here*"; today it is what the card quotes.
  final String sentence;

  final List<Definition> definitions;

  bool get isKnown => definitions.isNotEmpty;
}

/// The definition card.
///
/// It rises from the bottom edge rather than hovering over the word. A popover
/// covers the sentence you were reading and sits where your thumb isn't; a card
/// at the bottom leaves the text visible and lands where your hand already is.
class WordCard extends ConsumerStatefulWidget {
  const WordCard({required this.lookup, required this.onDismiss, super.key});

  final WordLookup lookup;
  final VoidCallback onDismiss;

  @override
  ConsumerState<WordCard> createState() => _WordCardState();
}

class _WordCardState extends ConsumerState<WordCard> {
  StreamSubscription<String>? _subscription;
  final _answer = StringBuffer();
  bool _asked = false;
  bool _streaming = false;
  String? _error;

  WordLookup get lookup => widget.lookup;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _ask() {
    setState(() {
      _asked = true;
      _streaming = true;
      _error = null;
      _answer.clear();
    });

    final explainer = ref.read(explainerProvider);
    _subscription = explainer
        .wordInContext(word: lookup.word, sentence: lookup.sentence)
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, bottomInset > 0 ? 10 : 14),
        child: Material(
          color: const Color(0xFFFCFBF9),
          borderRadius: BorderRadius.circular(26),
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
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
                _Head(lookup: lookup),
                const SizedBox(height: 10),
                if (lookup.isKnown)
                  _Senses(definitions: lookup.definitions)
                else
                  const Text(
                    'Not in the dictionary. Names and foreign words usually '
                    "aren't.",
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 15.5,
                      height: 1.5,
                      color: Paper.soft,
                    ),
                  ),
                const SizedBox(height: 17),
                const Divider(height: 1, color: Paper.rule),
                const SizedBox(height: 15),
                _InContext(
                  asked: _asked,
                  streaming: _streaming,
                  answer: _answer.toString(),
                  error: _error,
                  available: ref.watch(explainerProvider).isAvailable,
                  onAsk: _ask,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.lookup});

  final WordLookup lookup;

  @override
  Widget build(BuildContext context) {
    final first = lookup.definitions.firstOrNull;
    // Say so when the definition is filed under a different form, so it is
    // never a mystery why "conversation" appears after pressing "conversations".
    final showLemma =
        first != null && first.lemma.toLowerCase() != lookup.word.toLowerCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            showLemma ? first.lemma : lookup.word.toLowerCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 25,
              height: 1.1,
              color: Paper.ink,
            ),
          ),
        ),
        if (first != null) ...[
          const SizedBox(width: 9),
          Text(
            first.partOfSpeech,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: Paper.soft,
            ),
          ),
        ],
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: Paper.rule),
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Text(
            'OFFLINE',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              color: Paper.soft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _Senses extends StatelessWidget {
  const _Senses({required this.definitions});

  final List<Definition> definitions;

  @override
  Widget build(BuildContext context) {
    // Two is enough on a card. The rest is what Phase 5's "what does it mean
    // here?" is for — picking the right one is a context problem, not a
    // list-length problem.
    final shown = definitions.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shown.length > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 3),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Paper.soft,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  shown[i].gloss,
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
        ],
      ],
    );
  }
}

/// The second question, and the one the whole app exists for: not what the word
/// means in general, but what it is doing *here*.
class _InContext extends StatelessWidget {
  const _InContext({
    required this.asked,
    required this.streaming,
    required this.answer,
    required this.error,
    required this.available,
    required this.onAsk,
  });

  final bool asked;
  final bool streaming;
  final String answer;
  final String? error;
  final bool available;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    // Offer nothing that cannot be delivered: on a build with no proxy, say so
    // once, quietly, instead of showing a button that fails when pressed.
    if (!available && !asked) {
      return const _QuietNote(
        'Meaning in context needs a connection. The definition above works '
        'either way.',
      );
    }

    if (!asked) {
      return _AskButton(onPressed: onAsk);
    }

    if (error != null) {
      return _QuietNote(error!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'IN THIS SENTENCE',
          style: TextStyle(
            fontSize: 9.5,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
            color: Paper.pen,
          ),
        ),
        const SizedBox(height: 7),
        _StreamingText(text: answer, streaming: streaming),
      ],
    );
  }
}

/// Text that arrives a piece at a time, with a caret while more is coming.
///
/// The words appearing is the point: three seconds behind a spinner feels
/// broken, and the same three seconds with words arriving feels quick.
class _StreamingText extends StatelessWidget {
  const _StreamingText({required this.text, required this.streaming});

  final String text;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (streaming)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _Caret(),
            ),
        ],
      ),
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 15.5,
        height: 1.5,
        color: Color(0xFF3A352C),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect a reader who has asked the system to stop things moving.
    if (MediaQuery.of(context).disableAnimations) {
      return const _CaretBar();
    }
    return FadeTransition(
      opacity: _controller.drive(
        TweenSequence([
          TweenSequenceItem(tween: ConstantTween(1.0), weight: 1),
          TweenSequenceItem(tween: ConstantTween(0.0), weight: 1),
        ]),
      ),
      child: const _CaretBar(),
    );
  }
}

class _CaretBar extends StatelessWidget {
  const _CaretBar();

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

class _AskButton extends StatelessWidget {
  const _AskButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Paper.pen,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '\u2726',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                SizedBox(width: 9),
                Text(
                  'What does it mean here?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A statement of fact, not an alarm. No red, no icon, no retry loop.
class _QuietNote extends StatelessWidget {
  const _QuietNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 6, right: 9),
          decoration: const BoxDecoration(
            color: Paper.soft,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Paper.soft,
            ),
          ),
        ),
      ],
    );
  }
}
