import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_spacing.dart';

class GarraFormIntro extends StatelessWidget {
  const GarraFormIntro({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(GarraColors.creamMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared dark form language: label above the control, one primary action.
class GarraFormSection extends StatelessWidget {
  const GarraFormSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(GarraColors.gold),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          ..._withRhythm(children),
        ],
      ),
    );
  }

  List<Widget> _withRhythm(List<Widget> fields) {
    final spaced = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      spaced.add(fields[i]);
      if (i != fields.length - 1) {
        spaced.add(const SizedBox(height: 14));
      }
    }
    return spaced;
  }
}

class GarraFieldLabel extends StatelessWidget {
  const GarraFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(GarraColors.cream),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

InputDecoration garraControlDecoration({String? helper, String? error}) {
  return InputDecoration(
    helperText: helper,
    helperMaxLines: 3,
    errorText: error,
    errorMaxLines: 3,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    isDense: false,
    filled: true,
    fillColor: const Color(GarraColors.surface),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    constraints: const BoxConstraints(minHeight: 56),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x33C7A45B)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x33C7A45B)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(GarraColors.gold)),
    ),
  );
}

class GarraTextField extends StatelessWidget {
  const GarraTextField({
    super.key,
    required this.label,
    required this.controller,
    this.helper,
    this.validator,
    this.keyboardType,
    this.maxLength,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GarraFieldLabel(label),
        TextFormField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(color: Color(GarraColors.textPrimary)),
          decoration: garraControlDecoration(helper: helper),
        ),
      ],
    );
  }
}

class GarraTextArea extends StatelessWidget {
  const GarraTextArea({
    super.key,
    required this.label,
    required this.controller,
    this.helper,
    this.validator,
    this.maxLength,
    this.minLines = 4,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GarraFieldLabel(label),
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: minLines + 2,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(color: Color(GarraColors.textPrimary)),
          decoration: garraControlDecoration(helper: helper).copyWith(
            constraints: const BoxConstraints(minHeight: 120),
          ),
        ),
      ],
    );
  }
}

class GarraSelectField<T> extends StatelessWidget {
  const GarraSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GarraFieldLabel(label),
        DropdownButtonFormField<T>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: const Color(GarraColors.surfaceRaised),
          style: const TextStyle(color: Color(GarraColors.textPrimary)),
          decoration: garraControlDecoration(),
        ),
      ],
    );
  }
}

class GarraFormActionBar extends StatelessWidget {
  const GarraFormActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.footnote,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        FilledButton(
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 10),
          Text(
            footnote!,
            style: const TextStyle(
              color: Color(GarraColors.creamMuted),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
