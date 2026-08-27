import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// The caption that sits above a form control.
///
/// Controls only line up in a two-column row if they agree on where the label
/// goes. Material's `InputDecoration.labelText` floats it inside the border
/// and shows nothing at all until the field has focus or a value, while
/// `AppSelect` and the multi-selects draw a caption above the control. Mixing
/// the two is what left custom-attribute rows ragged, with a bare text box
/// beside a labelled select. This is the one caption those fields draw.
class FieldLabel extends StatelessWidget {
  final String text;

  /// Appends an asterisk. Kept as a flag rather than left to callers so the
  /// marker cannot drift between `Name *` and `Name*`.
  final bool isRequired;

  const FieldLabel(this.text, {super.key, this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      isRequired ? '$text *' : text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: context.colors.textSecondary),
    );
  }
}

/// [child] with a [FieldLabel] above it, at the gap forms use.
///
/// Every field in a column of a two-column row should be built through this,
/// so each column starts with a line of caption and the controls beneath it
/// share a top edge whatever they are.
class LabelledField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final Widget child;

  const LabelledField({
    super.key,
    required this.label,
    required this.child,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, isRequired: isRequired),
        const SizedBox(height: Spacing.xs + 2),
        child,
      ],
    );
  }
}
