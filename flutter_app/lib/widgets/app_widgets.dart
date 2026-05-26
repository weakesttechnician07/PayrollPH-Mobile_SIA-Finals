// ============================================================
// lib/widgets/app_widgets.dart
// ============================================================
import 'package:flutter/material.dart';

const kAccent    = Color(0xFFE94560);
const kSurface   = Color(0xFF16213E);
const kCardBg    = Color(0xFF1A2744);
const kBorder    = Color(0xFF2A3A5C);
const kTextMuted = Color(0xFF8892A4);
const kSuccess   = Color(0xFF2ECC71);
const kDanger    = Color(0xFFE74C3C);
const kWarning   = Color(0xFFF39C12);
const kBlue      = Color(0xFF4A9EFF);
const kPurple    = Color(0xFFA29BFE);

// ── Stat Card ────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.color = kAccent, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 14)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: kTextMuted, letterSpacing: 0.5)),
        if (subtitle != null) ...[const SizedBox(height: 1), Text(subtitle!, style: const TextStyle(fontSize: 8, color: kTextMuted))],
      ]),
    );
  }
}

// ── Section Card ─────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
            if (trailing != null) trailing!,
          ])),
        child,
      ]),
    );
  }
}

// ── App Badge ────────────────────────────────────────────────
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  const AppBadge({super.key, required this.label, this.color = kSuccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch(status) {
      'Approved' || 'Active'  => kSuccess,
      'Rejected' || 'Inactive'=> kDanger,
      'Pending'               => kWarning,
      _                       => kTextMuted,
    };
    return AppBadge(label: status, color: color);
  }
}

// ── Loading ───────────────────────────────────────────────────
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});
  @override Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: kAccent));
}

// ── Error ─────────────────────────────────────────────────────
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: kDanger, size: 48),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: kTextMuted)),
      if (onRetry != null) ...[const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: kAccent), child: const Text('Retry'))],
    ])));
  }
}

// ── Empty ─────────────────────────────────────────────────────
class EmptyView extends StatelessWidget {
  final String message;
  const EmptyView({super.key, required this.message});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.inbox_outlined, color: kTextMuted, size: 48),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: kTextMuted), textAlign: TextAlign.center),
    ])));
}

// ── Primary Button ────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, height: 46,
      child: ElevatedButton(onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ])));
  }
}

// ── Dark Input Decoration ─────────────────────────────────────
InputDecoration darkInput(String label, {String? hint, Widget? suffix}) => InputDecoration(
  labelText: label, hintText: hint, suffixIcon: suffix,
  filled: true, fillColor: const Color(0xFF1A1A2E),
  labelStyle: const TextStyle(color: kTextMuted, fontSize: 12),
  hintStyle: const TextStyle(color: kTextMuted),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccent)),
);

// ── Pending count badge widget ────────────────────────────────
class PendingBadge extends StatelessWidget {
  final int count;
  const PendingBadge({super.key, required this.count});
  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
