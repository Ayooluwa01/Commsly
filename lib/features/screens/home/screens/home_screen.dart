import 'package:commsly/core/network/server/hosted_server_provider.dart';
import 'package:commsly/core/network/discovery/discovery_provider.dart';
import 'package:commsly/core/network/models/nearby_server.dart';
import 'package:commsly/core/network/server/server_controller.dart';
import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/core/widgets/logo.dart';
import 'package:commsly/themes/appText_styling.dart';
import 'package:commsly/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const double _radius = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverControllerProvider);
    final hostedName = ref.watch(hostedServerNameProvider);
    final nearbyServers = ref.watch(nearbyServersProvider);

    final hasHostedServer = serverState.isRunning && hostedName != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refreshServers(ref),
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
                    _buildActions(context, ref),
                    const SizedBox(height: 14),
                    _buildSectionHeader(
                      icon: Icons.wifi_rounded,
                      title: 'Nearby Servers',
                      action: 'Refresh',
                      actionIcon: Icons.refresh_rounded,
                      onAction: () => _refreshServers(ref),
                    ),
                    const SizedBox(height: 8),
                    if (hasHostedServer)
                      _buildMyServerCard(context, hostedName),
                    nearbyServers.when(
                      data: (servers) {
                        // Keeps the locally hosted server in its own card.
                        final remote = servers
                            .where(
                              (s) => !(hasHostedServer && s.name == hostedName),
                            )
                            .toList();
                        if (remote.isEmpty) {
                          return hasHostedServer
                              ? const SizedBox.shrink()
                              : _buildEmptyNearbyServer();
                        }
                        return Column(
                          children: remote
                              .map((s) => _buildNearbyServerCard(context, s))
                              .toList(),
                        );
                      },
                      loading: () => hasHostedServer
                          ? const SizedBox.shrink()
                          : const Center(child: CircularProgressIndicator()),
                      error: (error, _) => hasHostedServer
                          ? const SizedBox.shrink()
                          : _buildEmptyNearbyServer(),
                    ),
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

  Future<void> _refreshServers(WidgetRef ref) async {
    final discovery = ref.read(commslyDiscoveryProvider);
    await discovery.stopDiscovery();
    await discovery.startDiscovery();
  }

  Widget _buildNearbyServerCard(BuildContext context, DiscoveredServer server) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(Routenames.joinServer),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyling.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${server.address}:${server.port}',
                        style: AppTextStyling.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MY SERVER

  Widget _buildMyServerCard(BuildContext context, String serverName) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          context.go('/connected/server-dashboard');
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.softBlue),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.dns_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            serverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyling.labelLarge.copyWith(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF12BA82),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Running',
                          style: AppTextStyling.bodySmall.copyWith(
                            color: const Color(0xFF12BA82),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• My Server',
                          style: AppTextStyling.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.primary,
                size: 17,
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

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;

        final createButton = _buildButton(
          "Create Server",
          "Start a new server",
          () {
            final current = ref.read(serverControllerProvider);
            if (current.isRunning) {
              context.go('/connected/server-dashboard');
              return;
            }
            if (current.isBusy) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Server is starting or stopping.'),
                ),
              );
              return;
            }
            context.push(Routenames.createServer);
          },
          icon: Icons.add,
          gradient: AppColors.primaryGradient,
        );

        final joinButton = _buildButton(
          "Join Server",
          "Connect to existing",
          () {
            final current = ref.read(serverControllerProvider);
            if (current.isRunning) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'End your current server before joining another.',
                  ),
                ),
              );
              return;
            }
            if (current.isBusy) return;
            context.push(Routenames.joinServer);
          },
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
