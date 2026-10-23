import 'package:commsly/core/widgets/logo.dart';
import 'package:commsly/themes/appText_styling.dart';
import 'package:commsly/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            // Connect to your Riverpod discovery
            // controller when it is ready.
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(context),

                    const SizedBox(height: 24),

                    _buildBanner(),

                    const SizedBox(height: 10),

                    _buildActions(context),

                    const SizedBox(height: 14),

                    _buildSectionHeader(
                      icon: Icons.wifi_rounded,
                      title: 'Nearby Servers',
                      action: 'Refresh',
                      actionIcon: Icons.refresh_rounded,
                      onAction: () {
                        // Trigger Bonsoir refresh.
                      },
                    ),

                    const SizedBox(height: 8),

                    _buildEmptyNearbyServer(),

                    const SizedBox(height: 14),

                    _buildSectionHeader(
                      icon: Icons.history_rounded,
                      title: 'Recent Activity',
                      action: 'See All',
                      actionIcon: Icons.chevron_right_rounded,
                      onAction: () {
                        // Open activity history
                        // when implemented.
                      },
                    ),

                    const SizedBox(height: 8),

                    _buildNoRecentActivity(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // HEADER
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Logo(),

        const SizedBox(width: 6),

        RichText(
          text: TextSpan(
            style: AppTextStyling.headlineLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
            children: const [
              TextSpan(text: 'Comms'),
              TextSpan(
                text: 'ly',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),

        const Spacer(),

        _buildHeaderAction(
          icon: Icons.settings_outlined,
          onTap: () => context.go('/settings'),
        ),

        const SizedBox(width: 12),

        InkWell(
          onTap: () => context.go('/settings'),
          borderRadius: BorderRadius.circular(100),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Text(
              'S',
              style: AppTextStyling.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.softBlue,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.primary, size: 23),
        ),
      ),
    );
  }

  // HERO BANNER
  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.asset(
        'assets/images/banner.png',
        width: double.infinity,
        fit: BoxFit.fitWidth,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 175,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              'Connect. Coordinate.\nStay in Sync.',
              textAlign: TextAlign.center,
              style: AppTextStyling.headlineLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        },
      ),
    );
  }

  // PRIMARY ACTIONS

  Widget _buildActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;

        final createButton = _buildButton(
          "Create Server",
          "Start a new server",
          () => context.push('/create-server'),
          icon: Icons.add,
          gradient: AppColors.primaryGradient,
        );

        final joinButton = _buildButton(
          "Join Server",
          "Connect to existing",
          () => context.push('/join-server'),
          icon: Icons.qr_code_scanner_sharp,
          gradient: AppColors.whiteGradient,
          textColor: AppColors.textPrimary,
        );

        if (isCompact) {
          return Column(
            children: [createButton, const SizedBox(height: 12), joinButton],
          );
        }

        return Row(
          children: [
            Expanded(child: createButton),
            const SizedBox(width: 12),
            Expanded(child: joinButton),
          ],
        );
      },
    );
  }

  Widget _buildButton(
    String title,
    String subtitle,
    VoidCallback onClick, {
    IconData icon = Icons.add,
    Gradient gradient = AppColors.primaryGradient,
    Color iconColor = AppColors.primary,
    Color iconBackgroundColor = AppColors.surface,
    Color textColor = Colors.white,
  }) {
    final isSecondary = gradient == AppColors.whiteGradient;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClick,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            border: isSecondary
                ? Border.all(color: Colors.grey.shade200)
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: isSecondary ? 0.05 : 0.15,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyling.labelLarge.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2),

                      Text(
                        subtitle,
                        style: AppTextStyling.bodySmall.copyWith(
                          color: textColor.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios_sharp,
                  color: isSecondary ? AppColors.primary : Colors.white,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // SECTION HEADER
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String action,
    required IconData actionIcon,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.softBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style: AppTextStyling.headlineMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),

        TextButton.icon(
          onPressed: onAction,
          iconAlignment: IconAlignment.end,
          icon: Icon(actionIcon, size: 18),
          label: Text(action),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            textStyle: AppTextStyling.labelMedium,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // NEARBY SERVERS EMPTY STATE
  Widget _buildEmptyNearbyServer() {
    return _buildEmptyCard(
      icon: Icons.wifi_find_rounded,
      title: 'No nearby servers found',
      description:
          'Connect to the same Wi-Fi or hotspot as your team to discover available Commsly servers.',
    );
  }

  // RECENT ACTIVITY EMPTY STATE
  Widget _buildNoRecentActivity() {
    return _buildEmptyCard(
      icon: Icons.history_rounded,
      title: 'No Recent Activity',
      description:
          'Your server and room activity will appear here once you create or join a server.',
      iconColor: AppColors.textSecondary,
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String description,
    Color iconColor = AppColors.primary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.softBlue),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 32, color: iconColor),
          ),

          const SizedBox(height: 16),

          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyling.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTextStyling.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
