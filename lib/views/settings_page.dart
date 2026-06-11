/// 설정 화면 — 언어 / 레벨별 초기화 / 후리가나.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

import '../l10n/strings.dart';
import '../state/store.dart';
import '../theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    Store.instance.addListener(_on);
  }

  @override
  void dispose() {
    Store.instance.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final furi = Store.instance.getSettings().furigana;
    const level = 'N3';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(t('settings.title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16,
            32 + MediaQuery.of(context).viewPadding.bottom),
        children: [
          _section(t('settings.language')),
          _languagePicker(),
          const SizedBox(height: 20),

          _section(t('settings.furigana')),
          _switchTile(
            label: t('settings.furigana'),
            value: furi,
            onChanged: (v) => Store.instance
                .setSettings(Store.instance.getSettings().copyWith(furigana: v)),
          ),
          const SizedBox(height: 20),

          _section(t('settings.reset_section')),
          _resetTile(
            title: tx('settings.reset_level', {'level': level}),
            desc: t('settings.reset_level_desc'),
            confirmTitle: tx('reset.title', {'level': level}),
            action: () async {
              await Store.instance.clearAllProgress();
            },
          ),
          _resetTile(
            title: tx('settings.reset_wordbook', {'level': level}),
            desc: t('settings.reset_wordbook_desc'),
            confirmTitle: tx('reset.title', {'level': '$level — ★'}),
            action: () async {
              await Store.instance.clearWordbook();
            },
          ),
          _resetTile(
            title: tx('settings.reset_srs', {'level': level}),
            desc: t('settings.reset_srs_desc'),
            confirmTitle: tx('reset.title', {'level': '$level — SRS'}),
            action: () async {
              await Store.instance.clearSrs();
            },
          ),
          const SizedBox(height: 20),

          _section(t('settings.about')),
          _linkTile(t('settings.privacy_policy'),
              'https://coby5502.github.io/jlpt-app-docs/privacy.html'),
          _linkTile(t('settings.terms'),
              'https://coby5502.github.io/jlpt-app-docs/terms.html'),
          _linkTile(t('settings.support'),
              'https://coby5502.github.io/jlpt-app-docs/support.html'),
        ],
      ),
    );
  }

  // ── Building blocks ────────────────────────────────────
  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
        child: Text(label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textMuted,
              letterSpacing: 0.6,
            )),
      );

  Widget _languagePicker() {
    final cur = Store.instance.currentLanguage;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          for (final code in supportedLanguages)
            _radioTile(
              label: languageLabel(code),
              selected: code == cur,
              onTap: () => Store.instance.setLanguage(code),
              isLast: code == supportedLanguages.last,
            ),
        ],
      ),
    );
  }

  Widget _radioTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isLast,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF1F1F2))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: brandPrimary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        activeThumbColor: brandPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }

  Widget _resetTile({
    required String title,
    required String desc,
    required String confirmTitle,
    required Future<void> Function() action,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _confirmAndRun(confirmTitle, desc, action),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ink)),
                      const SizedBox(height: 2),
                      Text(desc,
                          style: const TextStyle(
                              fontSize: 12, color: textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linkTile(String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.open_in_new_rounded, color: textMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndRun(
      String title, String desc, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x29000000),
                  blurRadius: 30,
                  offset: Offset(0, 12)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: ink)),
              const SizedBox(height: 8),
              Text(desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: textMuted,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: ink2,
                        backgroundColor: const Color(0xFFF3F4F6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      child: Text(t('reset.cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      child: Text(t('reset.confirm')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await action();
  }
}
