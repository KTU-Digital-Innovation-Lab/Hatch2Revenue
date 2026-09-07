import 'package:flutter/material.dart';

import '../../services/feedback_service.dart';
import '../../utils/app_colors.dart';

/// "Rate this app" — a 1–5 star rating and an optional written review.
/// Submissions go to the h2r_feedback table in Supabase, which the
/// developer reads from the dashboard.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  final _reviewCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  bool _queued = false;

  static const _prompts = <int, String>{
    0: 'Tap the stars to rate Hatch2Revenue',
    1: 'Sorry it fell short. What went wrong?',
    2: 'What is giving you trouble?',
    3: 'Thanks. What would make it better?',
    4: 'Glad it helps. Anything we could improve?',
    5: 'Wonderful! Tell us what you love (optional).',
  };

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_rating == 0 || _sending) return;
    setState(() => _sending = true);
    final delivered = await FeedbackService.instance
        .submit(rating: _rating, review: _reviewCtrl.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
      _queued = !delivered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Rate this app')),
      body: SafeArea(child: _sent ? _thankYou() : _form()),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 8),
        Text('How is Hatch2Revenue working for your farm?',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Your rating helps us make it better for poultry farmers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 24),

        // Stars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _rating;
            return IconButton(
              iconSize: 44,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: () => setState(() => _rating = i + 1),
              icon: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled ? AppColors.amber : AppColors.textMuted),
              tooltip: '${i + 1} star${i == 0 ? '' : 's'}',
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(_prompts[_rating]!,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _rating == 0 ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: _rating == 0 ? FontWeight.normal : FontWeight.w600)),
        const SizedBox(height: 24),

        // Review
        TextField(
          controller: _reviewCtrl,
          maxLines: 5,
          maxLength: 1000,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Write a review (optional) — what works, what to fix, '
                'what to add.',
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.green, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _rating == 0 || _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              disabledBackgroundColor: AppColors.textMuted.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Text('Send feedback',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your review reaches the developer directly. Nothing on your '
          'phone leaves except this rating and message.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _thankYou() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 72, color: AppColors.green),
            const SizedBox(height: 18),
            Text('Thank you!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              _queued
                  ? 'You are offline, so your feedback is saved and will send '
                      'automatically the next time you have internet.'
                  : 'Your feedback has been sent to the Hatch2Revenue team. '
                      'We read every review.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              width: 160,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
