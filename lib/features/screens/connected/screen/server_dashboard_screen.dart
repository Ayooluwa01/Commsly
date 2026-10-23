import 'package:commsly/core/network/server/commsly_client_provider.dart';
import 'package:commsly/core/network/server/hosted_server_provider.dart';
import 'package:commsly/core/network/server/server_controller.dart';
import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/core/widgets/create_room_modal.dart';
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

  // ============================================================
  // CREATE ROOM
  // ============================================================

  Future<void> _showCreateRoomModal() async {
    final serverState = ref.read(serverControllerProvider);

    if (!serverState.isRunning) {
      _showMessage('Only the server host can create rooms.');
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.navy.withValues(alpha: 0.5),
      builder: (modalContext) {
        return CreateRoomModal(
          onCreate: (roomName) async {
            final server = ref.read(commslyServerProvider);

            final roomId = DateTime.now().microsecondsSinceEpoch.toString();

            return server.createRoom(roomId: roomId, roomName: roomName);
          },
        );
      },
    );

    if (!mounted || created != true) return;

    setState(() {});

    _showMessage('Room created successfully!');
  }

  // ============================================================
  // ROOM ACTIONS
  // ============================================================

  void _joinRoom(String roomId) {
    final joined = ref.read(commslyClientProvider.notifier).joinRoom(roomId);

    if (!joined) {
      final error = ref.read(commslyClientProvider).error;

      _showMessage(error ?? 'Unable to join room.');
    }
  }

  void _leaveRoom(String roomId) {
    final left = ref.read(commslyClientProvider.notifier).leaveRoom(roomId);

    if (!left) {
      final error = ref.read(commslyClientProvider).error;

      _showMessage(error ?? 'Unable to leave room.');
    }
  }

  // host joining and leaving room

  void _hostJoinRoom(String roomId) {
    final success = ref.read(commslyServerProvider).hostJoinRoom(roomId);
    if (!mounted) return;
    if (success) {
      setState(() {});
      _showMessage('You joined the room.');
    } else {
      _showMessage('Unable to join room.');
    }
  }

  void _hostLeaveRoom(String roomId) {
    final success = ref.read(commslyServerProvider).hostLeaveRoom(roomId);
    if (!mounted) return;

    if (success) {
      setState(() {});
      _showMessage('You left the room.');
    } else {
      _showMessage('Unable to leave room.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // END SERVER
  // ============================================================

  Future<void> _confirmEndServer() async {
    if (_ending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
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
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _ending = true);

    try {
      await ref.read(serverControllerProvider.notifier).stopServer();

      if (!mounted) return;

      final serverState = ref.read(serverControllerProvider);

      if (serverState.status != ServerStatus.stopped) {
        throw StateError(serverState.error ?? 'Unable to stop the server.');
      }

      context.go(Routenames.homescreen);

      _showMessage('Server ended successfully.');
    } catch (error) {
      _showMessage('Could not end server: $error');
    } finally {
      if (mounted) {
        setState(() => _ending = false);
      }
    }
  }

  // ============================================================
  // LEAVE SERVER
  // ============================================================

  Future<void> _confirmLeaveServer() async {
    if (_leaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Leave server?'),
          content: const Text(
            'You will disconnect from this server '
            'and leave all joined rooms.',
          ),
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
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _leaving = true);

    try {
      await ref.read(commslyClientProvider.notifier).leaveServer();

      if (!mounted) return;

      context.go(Routenames.homescreen);
    } catch (error) {
      _showMessage('Could not leave server: $error');
    } finally {
      if (mounted) {
        setState(() => _leaving = false);
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverControllerProvider);
    final hostedName = ref.watch(hostedServerNameProvider);
    final clientState = ref.watch(commslyClientProvider);

    final isHosting = serverState.isRunning && hostedName != null;

    final isJoined = clientState.isConnected;

    final hasActiveServer = isHosting || isJoined;

    final serverName = isHosting
        ? hostedName
        : (clientState.server?.name ?? 'Server');

    if (!hasActiveServer) {
      return _noActiveServer();
    }

    final hostServer = isHosting ? ref.read(commslyServerProvider) : null;

    final roomCount = isHosting
        ? hostServer!.rooms.length
        : clientState.rooms.length;

    final memberCount = isHosting ? hostServer!.memberCount : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.go(Routenames.connected),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _serverHero(serverName, isHosting: isHosting),

              const SizedBox(height: 20),

              _quickStats(roomCount: roomCount, memberCount: memberCount),

              const SizedBox(height: 28),

              _sectionHeading('Rooms', Icons.grid_view_rounded),

              const SizedBox(height: 14),

              _roomsCard(isHosting: isHosting),

              const SizedBox(height: 28),

              _sectionHeading('Members', Icons.people_outline_rounded),

              const SizedBox(height: 14),

              _membersCard(isHosting: isHosting, memberCount: memberCount),

              const SizedBox(height: 28),

              _sectionHeading('Server Information', Icons.info_outline_rounded),

              const SizedBox(height: 14),

              _informationCard(serverName, isHosting: isHosting),

              const SizedBox(height: 24),

              isHosting ? _endServerButton() : _leaveServerButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NO ACTIVE SERVER
  // ============================================================

  Widget _noActiveServer() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Server Dashboard'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.dns_outlined,
                  color: AppColors.primary,
                  size: 45,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'No active server',
                style: AppTextStyling.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Create or join a Commsly server to '
                'start communicating with your team.',
                textAlign: TextAlign.center,
                style: AppTextStyling.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 22),

              FilledButton.icon(
                onPressed: () => context.go(Routenames.homescreen),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Back to Home'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SERVER HERO
  // ============================================================

  Widget _serverHero(String name, {required bool isHosting}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.dns_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),

              const Spacer(),

              _heroChip(
                Icons.circle,
                isHosting ? 'Running' : 'Connected',
                const Color(0xFF65FFD2),
              ),

              const SizedBox(width: 8),

              _heroChip(
                Icons.verified_user_outlined,
                isHosting ? 'Host' : 'Member',
                Colors.white,
              ),
            ],
          ),

          const SizedBox(height: 23),

          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyling.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            isHosting
                ? 'Your local communication server'
                : 'Connected to a local communication server',
            style: AppTextStyling.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),

          const SizedBox(height: 17),

          Row(
            children: [
              const Icon(Icons.wifi_rounded, color: Colors.white70, size: 17),
              const SizedBox(width: 7),
              Text(
                'Local Wi-Fi / Hotspot',
                style: AppTextStyling.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),

          const SizedBox(width: 6),

          Text(
            label,
            style: AppTextStyling.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK STATS
  // ============================================================

  Widget _quickStats({required int roomCount, required int? memberCount}) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.meeting_room_outlined,
            title: 'Rooms',
            value: roomCount.toString(),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _statCard(
            icon: Icons.groups_rounded,
            title: 'Members',
            value: memberCount?.toString() ?? '—',
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
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 23),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyling.headlineMedium.copyWith(
                    fontSize: 22,
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
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION HEADING
  // ============================================================

  Widget _sectionHeading(String title, IconData icon) {
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
          child: Icon(icon, color: AppColors.primary, size: 21),
        ),

        const SizedBox(width: 11),

        Text(
          title,
          style: AppTextStyling.headlineMedium.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ROOMS
  // ============================================================

  Widget _roomsCard({required bool isHosting}) {
    if (isHosting) {
      final rooms = ref.read(commslyServerProvider).rooms;

      return Column(
        children: [
          if (rooms.isEmpty)
            _emptyRoomsCard(isHosting: true)
          else
            ...rooms.map(
              (room) => _hostRoomCard(
                roomId: room.id,
                name: room.name,
                memberCount: room.memberCount,
                isJoined: room.hostJoined,
              ),
            ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _showCreateRoomModal,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 21),
              label: Text(
                'Create Room',
                style: AppTextStyling.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final clientState = ref.watch(commslyClientProvider);
    final rooms = clientState.rooms;

    if (rooms.isEmpty) {
      return _emptyRoomsCard(isHosting: false);
    }

    return Column(children: [for (final room in rooms) _memberRoomCard(room)]);
  }

  // ============================================================
  // HOST ROOM CARD
  // ============================================================

  Widget _hostRoomCard({
    required String roomId,
    required String name,
    required int memberCount,
    required bool isJoined,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isJoined
                  ? Icons.headset_mic_rounded
                  : Icons.meeting_room_outlined,
              color: AppColors.primary,
              size: 25,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyling.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  isJoined
                      ? 'Joined • $memberCount members'
                      : '$memberCount members',
                  style: AppTextStyling.bodySmall.copyWith(
                    color: isJoined
                        ? const Color(0xFF0AAE7A)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          if (isJoined)
            OutlinedButton(
              onPressed: () => _hostLeaveRoom(roomId),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Leave'),
            )
          else
            FilledButton(
              onPressed: () => _hostJoinRoom(roomId),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Join'),
            ),

          PopupMenuButton<String>(
            tooltip: 'Room options',
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteRoom(roomId: roomId, roomName: name);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete Room')),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MEMBER ROOM CARD
  // ============================================================

  Widget _memberRoomCard(ClientRoom room) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: room.isJoined
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.softBlue,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              room.isJoined
                  ? Icons.headset_mic_rounded
                  : Icons.meeting_room_outlined,
              color: AppColors.primary,
              size: 25,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyling.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  room.isJoined
                      ? 'Joined • ${room.memberCount} members'
                      : '${room.memberCount} members',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyling.bodySmall.copyWith(
                    color: room.isJoined
                        ? const Color(0xFF0AAE7A)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          if (room.isJoined)
            OutlinedButton(
              onPressed: () => _leaveRoom(room.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Leave'),
            )
          else
            FilledButton(
              onPressed: () => _joinRoom(room.id),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Join'),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY ROOMS
  // ============================================================

  Widget _emptyRoomsCard({required bool isHosting}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(23),
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              size: 37,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 17),

          Text(
            isHosting ? 'A space for every team' : 'No rooms available yet',
            textAlign: TextAlign.center,
            style: AppTextStyling.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            isHosting
                ? 'Create rooms for Media, Production, '
                      'Stage Crew, and other teams.'
                : 'The host has not created any rooms. '
                      'Available rooms will appear here automatically.',
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

  // ============================================================
  // DELETE ROOM
  // ============================================================

  Future<void> _confirmDeleteRoom({
    required String roomId,
    required String roomName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Delete room?'),
          content: Text(
            'Are you sure you want to delete "$roomName"? '
            'All members will be removed from this room.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Room'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final deleted = ref.read(commslyServerProvider).deleteRoom(roomId);

    if (!mounted) return;

    if (deleted) {
      setState(() {});
      _showMessage('Room deleted successfully.');
    } else {
      _showMessage('Unable to delete room.');
    }
  }

  // ============================================================
  // MEMBERS
  // ============================================================

  Widget _membersCard({required bool isHosting, required int? memberCount}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.groups_outlined,
              color: AppColors.primary,
              size: 32,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            isHosting
                ? '${memberCount ?? 1} connected members'
                : 'Connected members',
            textAlign: TextAlign.center,
            style: AppTextStyling.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Member details and their room activity '
            'will appear here when presence tracking is enabled.',
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

  // ============================================================
  // SERVER INFORMATION
  // ============================================================

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
          _infoRow('Network', 'Offline / Local'),
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

  // ============================================================
  // SERVER BUTTONS
  // ============================================================

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

  // ============================================================
  // SHARED CARD DECORATION
  // ============================================================

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
