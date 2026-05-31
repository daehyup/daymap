import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InputScreen extends StatefulWidget {
  final VoidCallback? onSuccess;

  const InputScreen({super.key, this.onSuccess});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  static const _examples = [
    '정보처리기사 실기 7월 20일',
    '기말고사 6월 25일',
    '알바 매주 수·토·일',
    '매일 운동 1시간',
  ];

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = '일정을 입력해주세요.');
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.generateSchedule(text);
      if (!mounted) return;
      widget.onSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '분석에 실패했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _appendExample(String example) {
    final current = _controller.text;
    _controller.text = current.isEmpty ? example : '$current, $example';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    setState(() => _errorMessage = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('일정 입력'),
            centerTitle: false,
          ),
          body: GestureDetector(
            onTap: _focusNode.unfocus,
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(),
                  const SizedBox(height: 24),
                  _InputField(
                    controller: _controller,
                    focusNode: _focusNode,
                    errorMessage: _errorMessage,
                    onChanged: (_) => setState(() => _errorMessage = null),
                  ),
                  const SizedBox(height: 16),
                  _ExampleChips(
                    examples: _examples,
                    onTap: _appendExample,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '일정 분석하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading) _LoadingOverlay(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어떤 일정이 있나요?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'AI가 일정을 분석해서 오늘 할일을 자동으로 배분해드려요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorMessage;
  final ValueChanged<String> onChanged;

  const _InputField({
    required this.controller,
    required this.focusNode,
    required this.errorMessage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      maxLines: 7,
      minLines: 5,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: '예: 정보처리기사 실기 7월 20일, 기말고사 6월 25일,\n알바 매주 수·토·일, 매일 운동 1시간',
        hintStyle: TextStyle(color: Colors.grey.shade400, height: 1.6),
        errorText: errorMessage,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}

class _ExampleChips extends StatelessWidget {
  final List<String> examples;
  final ValueChanged<String> onTap;

  const _ExampleChips({required this.examples, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '예시 추가',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: examples
              .map(
                (e) => GestureDetector(
                  onTap: () => onTap(e),
                  child: Chip(
                    label: Text(e, style: const TextStyle(fontSize: 13)),
                    avatar: const Icon(Icons.add, size: 16),
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'AI가 일정을 분석중이에요...',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                '잠깐만 기다려주세요',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
