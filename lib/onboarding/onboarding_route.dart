import 'package:flutter/material.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/storage_config_page.dart';
import 'package:img_syncer/state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingRoute extends StatefulWidget {
  const OnboardingRoute({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingRoute> createState() => _OnboardingRouteState();
}

class _OnboardingRouteState extends State<OnboardingRoute> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  int _currentPage = 0;
  bool _showStorageForm = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });
  }

  void _goToNextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _goToStep(4);
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_onboarded', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_currentStep == 4) {
      return _buildStorageStep(l10n, colorScheme);
    }
    return _buildIntroPages(l10n, colorScheme);
  }

  Widget _buildIntroPages(AppLocalizations l10n, ColorScheme colorScheme) {
    final pages = <Widget>[
      _OnboardingPage(
        icon: Image.asset('assets/icon/pho_icon.png', width: 120),
        title: l10n.onboardingWelcome,
        description: l10n.onboardingWelcomeDesc,
      ),
      _OnboardingPage(
        icon: Icon(Icons.cloud_sync_outlined, size: 120, color: colorScheme.primary),
        title: l10n.onboardingSyncTitle,
        description: l10n.onboardingSyncDesc,
      ),
      _OnboardingPage(
        icon: Icon(Icons.lock_outlined, size: 120, color: colorScheme.primary),
        title: l10n.onboardingPrivacyTitle,
        description: l10n.onboardingPrivacyDesc,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onComplete,
                    child: Text(l10n.onboardingSkip),
                  ),
                  _PageIndicator(count: pages.length, currentIndex: _currentPage),
                  TextButton(
                    onPressed: _goToNextPage,
                    child: Text(
                      _currentPage == pages.length - 1
                          ? l10n.onboardingGetStarted
                          : l10n.onboardingNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageStep(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_showStorageForm) {
      return Navigator(
        onDidRemovePage: (page) {
          if (page.name == 'storage_form') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (settingModel.isRemoteStorageSetted) {
                _finishOnboarding();
              } else {
                setState(() => _showStorageForm = false);
              }
            });
          }
        },
        pages: const [
          MaterialPage(
            key: ValueKey('storage_form'),
            name: 'storage_form',
            child: _StorageFormPage(),
          ),
        ],
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_outlined, size: 120, color: colorScheme.primary),
                const SizedBox(height: 32),
                Text(
                  l10n.onboardingStorageTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.onboardingStorageDesc,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _showStorageForm = true;
                    });
                  },
                  child: Text(l10n.onboardingSetupStorage),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(l10n.onboardingComplete),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final Widget icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: 32),
          Text(
            title,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          width: 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == currentIndex
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
          ),
        );
      }),
    );
  }
}

/// 引导流程中的储存设置表单包装页。
/// 放在嵌套 Navigator 中，隔离表单内部的 Navigator.pop 调用，
/// 防止 pop 掉整个 OnboardingRoute 导致黑屏 crash。
class _StorageFormPage extends StatelessWidget {
  const _StorageFormPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingStorageTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const StorageConfigPage(),
    );
  }
}
