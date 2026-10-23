import 'package:commsly/core/network/server/commsly_client_provider.dart';
import 'package:commsly/core/network/server/hosted_server_provider.dart';
import 'package:commsly/core/network/server/server_controller.dart';
import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/themes/app_colors.dart';
import 'package:commsly/themes/appText_styling.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ServerDashboardScreen extends ConsumerStatefulWidget {
  const ServerDashboardScreen({super.key});

  @override
  ConsumerState<ServerDashboardScreen> createState() =>
      _ServerDashboardScreenState();
}

class _ServerDashboardScreenState extends ConsumerState<ServerDashboardScreen> {
  bool _ending = false;
  bool _leaving = false;

  Future<void> _confirmEndServer() async {
    if (_ending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End server?'),
        content: const Text(
          'All connected members will be disconnected '
          'and active communication will stop. '
          'Are you sure you want to end this server?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Server'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _ending = true);

    try {
      await ref.read(serverControllerProvider.notifier).stopServer();

      if (!mounted) return;

      final serverState = ref.read(serverControllerProvider);

      // Confirm that shutdown actually succeeded.
      if (serverState.status != ServerStatus.stopped) {
        throw StateError(serverState.error ?? 'Unable to stop the server.');
      }

      // No need to clear hostedServerNameProvider here.
      // Your ServerController.stopServer() already clears it.

      context.go(Routenames.homescreen);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server ended successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not end server: $error')));
    } finally {
      if (mounted) {
        setState(() => _ending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(serverControllerProvider);
    final hostedName = ref.watch(hostedServerNameProvider);
    final client = ref.watch(commslyClientProvider);

    final isHosting = server.isRunning && hostedName != null;
    final isJoined = client.isConnected;

    final hasActiveServer = isHosting || isJoined;
    final serverName = isHosting
        ? hostedName!
        : (client.server?.name ?? 'Server');

    if (!hasActiveServer) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Server Dashboard'),
          backgroundColor: AppColors.background,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.dns_outlined,
                size: 54,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No active server connection',
                style: AppTextStyling.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(Routenames.homescreen),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go('/connected'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        centerTitle: true,
        title: Text(
          'Server Dashboard',
          style: AppTextStyling.labelLarge.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _serverHero(serverName, isHosting: isHosting),
              const SizedBox(height: 20),
              _quickStats(),
              const SizedBox(height: 28),
              _sectionHeading('Rooms', Icons.grid_view_rounded),
              const SizedBox(height: 14),
              _roomsCard(context),
              const SizedBox(height: 28),
              _sectionHeading('Members', Icons.people_outline_rounded),
              const SizedBox(height: 14),
              _membersCard(),
              const SizedBox(height: 28),
              _sectionHeading('Server Information', Icons.info_outline_rounded),
              const SizedBox(height: 14),
              _informationCard(serverName, isHosting: isHosting),
              // const SizedBox(height: 24),
              // _serverManagementCard(context),
              const SizedBox(height: 16),
              if (isHosting) _endServerButton() else _leaveServerButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serverHero(String name, {required bool isHosting}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.dns_rounded, size: 31, color: Colors.white),
          ),

          const SizedBox(height: 20),

          Text(
            name,
            style: AppTextStyling.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            isHosting
                ? 'Your local communication server'
                : 'Connected to a local server',
            style: AppTextStyling.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),

          const SizedBox(height: 20),

          // Row(
          //   children: [
          //     _heroChip(Icons.circle, 'Running', const Color(0xFF20D8B4)),
          //     const SizedBox(width: 10),
          //     _heroChip(
          //       Icons.admin_panel_settings_outlined,
          //       'Host',
          //       Colors.white,
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppTextStyling.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.meeting_room_outlined,
            title: 'Rooms',
            value: '—',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.groups_rounded,
            title: 'Members',
            value: '—',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.softBlue),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyling.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                title,
                style: AppTextStyling.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 23),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTextStyling.headlineMedium.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _roomsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.meeting_room_outlined,
            size: 44,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Your server rooms',
            style: AppTextStyling.labelLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create rooms for Media, Production, '
            'Stage Crew and other teams.',
            textAlign: TextAlign.center,
            style: AppTextStyling.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Room creation will be connected next.'),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Room'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _membersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.group_outlined, size: 38, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            'Connected members will appear here',
            textAlign: TextAlign.center,
            style: AppTextStyling.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationCard(String name, {required bool isHosting}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _infoRow('Server Name', name),
          const Divider(height: 26),
          _infoRow('Connection', 'Local Wi-Fi / Hotspot'),
          const Divider(height: 26),
          _infoRow('Role', isHosting ? 'Host' : 'Member'),
          const Divider(height: 26),
          _infoRow('Status', isHosting ? 'Running' : 'Connected'),
          const Divider(height: 26),
          _infoRow('PIN Protection', 'Disabled'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyling.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyling.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // Widget _serverManagementCard(BuildContext context) {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: AppColors.softBlue,
  //       borderRadius: BorderRadius.circular(18),
  //     ),
  //     child: Row(
  //       children: [
  //         const Icon(Icons.info_outline_rounded, color: AppColors.primary),
  //         const SizedBox(width: 12),
  //         // Expanded(
  //         //   child: Text(
  //         //     'This device is hosting the server. '
  //         //     'Return to Home at any time without '
  //         //     'creating another server.',
  //         //     style: AppTextStyling.bodySmall.copyWith(
  //         //       color: AppColors.textPrimary,
  //         //       height: 1.5,
  //         //     ),
  //         //   ),
  //         // ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _confirmLeaveServer() async {
    if (_leaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave server?'),
        content: const Text('You will disconnect from this server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave Server'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await ref.read(commslyClientProvider.notifier).leaveServer();
      if (!mounted) return;
      context.go(Routenames.homescreen);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not leave server: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Widget _leaveServerButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _leaving ? null : _confirmLeaveServer,
        icon: _leaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(_leaving ? 'Leaving...' : 'Leave Server'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade700,
          side: BorderSide(color: Colors.red.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _endServerButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _ending ? null : _confirmEndServer,
        icon: _ending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.power_settings_new_rounded),
        label: Text(_ending ? 'Ending Server...' : 'End Server'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade700,
          side: BorderSide(color: Colors.red.shade300),
          textStyle: AppTextStyling.labelLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.softBlue),
      boxShadow: [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
