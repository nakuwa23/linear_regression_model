import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Public prediction endpoint (FastAPI on Render).
const String predictUrl = 'https://digital-skills-pay-api.onrender.com/predict';

const Color brandColor = Color(0xFF6E6480);

void main() => runApp(const PayEstimatorApp());

class PayEstimatorApp extends StatelessWidget {
  const PayEstimatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Skills Pay Estimator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brandColor)
            .copyWith(primary: brandColor, onPrimary: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

/// Brand colour

enum InputKind { number, wholeNumber, yesNo, option }

class InputField {
  const InputField({
    required this.key,
    required this.label,
    required this.hint,
    required this.section,
    required this.kind,
    this.min,
    this.max,
    this.options,
    this.initialValue = '',
  });

  final String key;
  final String label;
  final String hint;
  final String section;
  final InputKind kind;
  final num? min;
  final num? max;
  final List<String>? options;
  final String initialValue;
}

/// The 11 inputs, with the same names, limits and options as the API's PayInput model.
const List<InputField> inputFields = [
  // Experience
  InputField(
    key: 'YearsCode',
    label: 'Years of coding',
    section: 'Experience',
    hint: 'Total years coding, including learning (0-30)',
    kind: InputKind.number,
    min: 0,
    max: 30,
  ),
  InputField(
    key: 'WorkExp',
    label: 'Years of work experience',
    section: 'Experience',
    hint: 'Professional experience (0-20)',
    kind: InputKind.number,
    min: 0,
    max: 20,
  ),
  InputField(
    key: 'OnlineCourses',
    label: 'Learned through online courses?',
    section: 'Experience',
    hint: 'Type Yes or No',
    kind: InputKind.yesNo,
  ),
  // Background
  InputField(
    key: 'Country',
    label: 'Country',
    section: 'Background',
    hint: 'Start typing to see options',
    kind: InputKind.option,
    options: [
      'Algeria',
      'Egypt',
      'Ethiopia',
      'Ghana',
      'Kenya',
      'Morocco',
      'Nigeria',
      'South Africa',
      'Tunisia',
      'Other African country',
    ],
  ),
  InputField(
    key: 'AgeGroup',
    label: 'Age group',
    section: 'Background',
    hint: 'Start typing to see options',
    kind: InputKind.option,
    options: ['18-24', '25-34'],
  ),
  InputField(
    key: 'Education',
    label: 'Education',
    section: 'Background',
    hint: 'Start typing to see options',
    kind: InputKind.option,
    options: [
      'Secondary or less',
      'Some university, no degree',
      'Associate degree',
      "Bachelor's degree",
      "Master's degree",
      'Doctorate or professional degree',
    ],
  ),
  // Job
  InputField(
    key: 'RoleGroup',
    label: 'Developer role',
    section: 'Job',
    hint: 'Start typing to see options',
    kind: InputKind.option,
    options: [
      'Full-stack developer',
      'Back-end developer',
      'Front-end developer',
      'Mobile developer',
      'Data or AI',
      'Other tech role',
    ],
  ),
  InputField(
    key: 'EmploymentType',
    label: 'Employment type',
    section: 'Job',
    hint: 'Start typing to see options',
    kind: InputKind.option,
    options: [
      'Employed',
      'Freelancer or self-employed',
      'Employed and freelancing',
    ],
  ),
  InputField(
    key: 'WorkMode',
    label: 'Work mode',
    section: 'Job',
    hint: 'Start typing to see options',
    kind: InputKind.option,
    options: ['Remote', 'Hybrid', 'In-person'],
  ),
  InputField(
    key: 'OrgSize',
    label: 'Organisation size',
    section: 'Job',
    hint: 'Start typing to see options',
    kind: InputKind.option,
    options: [
      'Freelancer (just me)',
      'Under 20',
      '20-99',
      '100-499',
      '500-4,999',
      '5,000+',
    ],
  ),
  InputField(
    key: 'SurveyYear',
    label: 'Pay reference year',
    section: 'Job',
    hint: 'Year of the pay data to compare against (2023-2026)',
    kind: InputKind.wholeNumber,
    min: 2023,
    max: 2026,
    initialValue: '2026',
  ),
];

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    for (final field in inputFields)
      field.key: TextEditingController(text: field.initialValue),
  };
  final Map<String, FocusNode> _focusNodes = {
    for (final field in inputFields) field.key: FocusNode(),
  };

  String? _message;
  bool _isError = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String? _matchOption(InputField field, String text) {
    for (final option in field.options!) {
      if (option.toLowerCase() == text.toLowerCase()) return option;
    }
    return null;
  }

  int? _yesNoToInt(String text) {
    switch (text.toLowerCase()) {
      case 'yes':
      case 'y':
      case '1':
        return 1;
      case 'no':
      case 'n':
      case '0':
        return 0;
    }
    return null;
  }

  String? _validate(InputField field, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '${field.label} is required';

    switch (field.kind) {
      case InputKind.option:
        return _matchOption(field, text) == null
            ? 'Use one of: ${field.options!.join(', ')}'
            : null;
      case InputKind.yesNo:
        return _yesNoToInt(text) == null ? 'Type yes or no' : null;
      case InputKind.number:
      case InputKind.wholeNumber:
        final number = num.tryParse(text);
        if (number == null) return 'Enter a number';
        if (field.kind == InputKind.wholeNumber && number % 1 != 0) {
          return 'Enter a whole number';
        }
        if (number < field.min! || number > field.max!) {
          return 'Must be between ${field.min} and ${field.max}';
        }
        return null;
    }
  }

  Map<String, dynamic> _buildRequestBody() {
    final body = <String, dynamic>{};
    for (final field in inputFields) {
      final text = _controllers[field.key]!.text.trim();
      switch (field.kind) {
        case InputKind.option:
          body[field.key] = _matchOption(field, text);
        case InputKind.yesNo:
          body[field.key] = _yesNoToInt(text);
        case InputKind.wholeNumber:
          body[field.key] = num.parse(text).toInt();
        case InputKind.number:
          body[field.key] = double.parse(text);
      }
    }
    return body;
  }

  void _show(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _isError = isError;
    });
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _show(
        'Some values are missing, have the wrong type or are out of range. '
        'Fix the highlighted fields and try again.',
        isError: true,
      );
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(predictUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(_buildRequestBody()),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final pay = (data['predicted_annual_pay_usd'] as num).toDouble();
        _show('Estimated annual pay: USD ${_formatMoney(pay)}', isError: false);
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final first = (data['detail'] as List).first as Map<String, dynamic>;
        final fieldName = (first['loc'] as List).last;
        _show('Invalid value for $fieldName: ${first['msg']}', isError: true);
      } else {
        _show(
          'Server error (${response.statusCode}). Please try again.',
          isError: true,
        );
      }
    } on TimeoutException {
      _show(
        'The server took too long to respond. It may be waking up, so please try again.',
        isError: true,
      );
    } catch (_) {
      _show(
        'Could not reach the prediction service. Check your internet connection.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatMoney(double value) => value
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  InputDecoration _decoration(InputField field) => InputDecoration(
    labelText: field.label,
    helperText: field.hint,
    helperMaxLines: 2,
    errorMaxLines: 4,
    isDense: true,
    border: const OutlineInputBorder(),
  );

  Widget _textField(InputField field) {
    return TextFormField(
      controller: _controllers[field.key],
      focusNode: _focusNodes[field.key],
      decoration: _decoration(field),
      keyboardType: field.kind == InputKind.yesNo
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      validator: (value) => _validate(field, value),
    );
  }

  Widget _optionField(InputField field) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: _controllers[field.key]!,
        focusNode: _focusNodes[field.key]!,
        optionsBuilder: (TextEditingValue value) {
          final query = value.text.trim().toLowerCase();
          if (query.isEmpty) return field.options!;
          return field.options!.where((o) => o.toLowerCase().contains(query));
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
            TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: _decoration(field),
              textInputAction: TextInputAction.next,
              validator: (value) => _validate(field, value),
            ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 220,
                maxWidth: constraints.maxWidth,
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      dense: true,
                      title: Text(option),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields(BuildContext context) {
    final widgets = <Widget>[];
    String? currentSection;
    for (final field in inputFields) {
      if (field.section != currentSection) {
        currentSection = field.section;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              currentSection,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
      widgets.add(
        field.kind == InputKind.option
            ? _optionField(field)
            : _textField(field),
      );
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Color boxColor = _message == null
        ? colors.surfaceContainerHighest
        : (_isError ? colors.errorContainer : colors.primaryContainer);
    final Color textColor = _message == null
        ? colors.onSurfaceVariant
        : (_isError ? colors.onErrorContainer : colors.onPrimaryContainer);

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Skills Pay Estimator')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Estimate the annual pay of a young African developer (18-34) '
                  'from their skills and work situation.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ..._buildFields(context),
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: _loading ? null : _predict,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: brandColor.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Predict'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _message ?? 'Your predicted annual pay will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: textColor),
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
