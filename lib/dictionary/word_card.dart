import 'package:flutter/material.dart';

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
class WordCard extends StatelessWidget {
  const WordCard({required this.lookup, required this.onDismiss, super.key});

  final WordLookup lookup;
  final VoidCallback onDismiss;

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
                const _ExplainButton(),
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

/// Phase 5 wires this to the model. It is deliberately present and visibly
/// inert rather than absent, so the shape of the finished card is settled now.
class _ExplainButton extends StatelessWidget {
  const _ExplainButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: 'What does it mean here? Coming in the next phase.',
      child: Opacity(
        opacity: 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Paper.pen,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('✦', style: TextStyle(color: Colors.white, fontSize: 13)),
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
    );
  }
}
