import 'package:flutter/material.dart';

import '../design/garra_spacing.dart';
import '../theme/garra_semantic_colors.dart';

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
              color: context.garraColors.textSecondary,
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
              color: context.garraColors.brandPrestige,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: context.garraColors.border, height: 1),
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
          color: context.garraColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

InputDecoration garraControlDecoration(
  BuildContext context, {
  String? helper,
  String? error,
}) {
  final colors = context.garraColors;
  final radius = BorderRadius.circular(12);
  return InputDecoration(
    helperText: helper,
    helperMaxLines: 3,
    errorText: error,
    errorMaxLines: 3,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    isDense: true,
    filled: true,
    fillColor: colors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    constraints: const BoxConstraints(minHeight: 52),
    hintStyle: TextStyle(color: colors.textSecondary, fontSize: 16),
    helperStyle: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3),
    errorStyle: TextStyle(color: colors.danger, fontSize: 12, height: 1.3),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.brandPrimary, width: 1.4),
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
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

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
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          validator: validator,
          style: TextStyle(color: context.garraColors.textPrimary, fontSize: 16),
          decoration: garraControlDecoration(context, helper: helper),
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
          style: TextStyle(color: context.garraColors.textPrimary, fontSize: 16),
          decoration: garraControlDecoration(context, helper: helper).copyWith(
            constraints: const BoxConstraints(minHeight: 96),
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
          dropdownColor: context.garraColors.surfaceRaised,
          style: TextStyle(color: context.garraColors.textPrimary, fontSize: 16),
          iconEnabledColor: context.garraColors.textSecondary,
          decoration: garraControlDecoration(context),
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
            style: TextStyle(
              color: context.garraColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
