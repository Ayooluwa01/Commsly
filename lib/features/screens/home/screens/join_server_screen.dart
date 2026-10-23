import 'dart:developer' as developer;

import 'package:commsly/core/network/models/nearby_server.dart';
import 'package:commsly/core/network/discovery/discovery_provider.dart';
import 'package:commsly/core/network/server/server_controller.dart';
import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/themes/app_colors.dart';
import 'package:commsly/themes/appText_styling.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'enter_pin_screen.dart';

typedef ServerJoin =
    Future<bool> Function(DiscoveredServer server, String? pin);

class JoinServerScreen extends ConsumerStatefulWidget {
  final ServerJoin? joinServer;
  final bool hasJoinedServer;
  const JoinServerScreen({
    super.key,
    this.joinServer,
    this.hasJoinedServer = false,
  });

  @override
  ConsumerState<JoinServerScreen> createState() => _JoinServerScreenState();
}

class _JoinServerScreenState extends ConsumerState<JoinServerScreen> {
  DiscoveredServer? _selectedServer;

  bool _isRefreshing = false;
  bool _isJoining = false;

  bool get _hasActiveServer {
    return ref.read(serverControllerProvider).isRunning ||
        widget.hasJoinedServer;
  }

  Future<void> _refreshServers() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final discovery = ref.read(commslyDiscoveryProvider);
      await discovery.stopDiscovery();
      await discovery.startDiscovery();
    } catch (_) {
      if (mounted) _showMessage('Could not refresh nearby servers.');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _joinSelectedServer({bool forcePin = false}) async {
    final selected = _selectedServer;
    developer.log('IP ADDRESS ${selected!.address}');

    if (_hasActiveServer) {
      _showMessage(
        'You are already connected to a server. '
        'End or leave it before joining another.',
      );
      return;
    }
    final currentlyAvailable = ref.read(nearbyServersProvider).value ?? [];
    if (!currentlyAvailable.any((s) => s.id == selected.id)) {
      _showMessage('This server is no longer available.');
      return;
    }

    if (forcePin || selected.requiresPin) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EnterPinScreen(
            server: selected,
            hasActiveConnection: () => _hasActiveServer,
            onJoin: _performJoin,
          ),
        ),
      );
      return;
    }

    final success = await _performJoin(selected, null);

    if (!mounted) return;

    if (success) {
      context.go(Routenames.serverDashboard);
    }
  }

  Future<bool> _performJoin(DiscoveredServer server, String? pin) async {
    if (_hasActiveServer) {
      _showMessage('Only one server can be connected at a time.');
      return false;
    }

    if (widget.joinServer == null) {
      _showMessage(
        'The local server connection service '
        'has not been connected yet.',
      );
      return false;
    }

    if (_isJoining) return false;

    setState(() => _isJoining = true);

    try {
      // This callback must perform the actual
      // WebSocket connection, authentication,
      // and session state update.
      final success = await widget.joinServer!(server, pin);

      if (!mounted) return false;

      if (!success) {
        _showMessage(
          'Unable to join this server. '
          'Check your connection or PIN.',
        );
      }

      return success;
    } catch (error) {
      if (mounted) {
        _showMessage('Server connection failed: $error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearbyServers = ref.watch(nearbyServersProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Join Server',
          style: AppTextStyling.labelLarge.copyWith(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshServers,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    _discoveryHero(_isRefreshing || nearbyServers.isLoading),

                    const SizedBox(height: 24),

                    _sectionHeader(),

                    const SizedBox(height: 14),

                    nearbyServers.when(
                      data: (servers) {
                        if (servers.isEmpty) {
                          return _messageCard(
                            Icons.wifi_find_rounded,
                            'No nearby servers found',
                            'Connect to the same Wi-Fi or hotspot and tap Refresh.',
                          );
                        }
                        return Column(
                          children: servers.map(_serverCard).toList(),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) => _messageCard(
                        Icons.error_outline_rounded,
                        'Discovery failed',
                        error.toString(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _bottomActions(),
          ],
        ),
      ),
    );
  }

  // DISCOVERY HERO
  Widget _discoveryHero(bool isSearching) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 116,
            width: 116,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),

                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),

                Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: Colors.white,
                    size: 35,
                  ),
                ),

                if (isSearching)
                  const SizedBox(
                    width: 112,
                    height: 112,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Text(
            isSearching
                ? 'Searching for nearby servers...'
                : 'Discover Nearby Servers',
            textAlign: TextAlign.center,
            style: AppTextStyling.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Make sure you are on the same network '
            'as the server host.',
            textAlign: TextAlign.center,
            style: AppTextStyling.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // SECTION HEADER
  Widget _sectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Available Servers',
            style: AppTextStyling.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),

        IconButton(
          onPressed: _isRefreshing ? null : _refreshServers,
          tooltip: 'Refresh servers',
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
      ],
    );
  }

  // SERVER LIST
  Widget _serverCard(DiscoveredServer server) {
    final isSelected = _selectedServer?.id == server.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isJoining
              ? null
              : () {
                  setState(() => _selectedServer = server);
                },
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.softBlue,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.035),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: AppColors.primary,
                    size: 27,
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

                      const SizedBox(height: 5),

                      Text(
                        server.memberCount == null
                            ? server.address
                            : '${server.memberCount} members',
                        style: AppTextStyling.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0FAF0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Found',
                    style: AppTextStyling.labelMedium.copyWith(
                      color: const Color(0xFF0AAE7A),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),

                const SizedBox(width: 7),

                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageCard(IconData icon, String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.softBlue),
      ),
      child: Column(
        children: [
          Icon(icon, size: 45, color: AppColors.primary),

          const SizedBox(height: 12),

          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyling.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyling.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // BOTTOM ACTIONS
  Widget _bottomActions() {
    final servers = ref.watch(nearbyServersProvider).value ?? [];
    final selectionAvailable = servers.any((s) => s.id == _selectedServer?.id);
    final canJoin = selectionAvailable && !_isJoining && !_hasActiveServer;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(15),
              ),
              child: ElevatedButton(
                onPressed: canJoin ? () => _joinSelectedServer() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isJoining
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Join Server',
                        style: AppTextStyling.labelLarge.copyWith(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton.icon(
              onPressed: canJoin
                  ? () => _joinSelectedServer(forcePin: true)
                  : null,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.softBlue,
                foregroundColor: AppColors.primary,
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                'Join with PIN',
                style: AppTextStyling.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
