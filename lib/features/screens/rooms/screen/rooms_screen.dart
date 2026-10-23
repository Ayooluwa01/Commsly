import 'package:commsly/core/network/server/commsly_client_provider.dart';
import 'package:commsly/core/network/server/server_controller.dart';
import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/core/widgets/logo.dart';
import 'package:commsly/themes/app_colors.dart';
import 'package:commsly/themes/appText_styling.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  final _searchController = TextEditingController();

  String _search = '';

  // Local UI mute preference. Actual audio muting will be
  // connected when we implement the voice engine.
  final Set<String> _mutedRoomIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _refresh({required bool isHosting}) async {
    if (isHosting) {
      // Rooms currently live in the host's in-memory server.
      setState(() {});
    } else {
      ref.read(commslyClientProvider.notifier).refreshRooms();
    }
  }

  void _joinRoom(String id, {required bool isHosting}) {
    final success = isHosting
        ? ref.read(commslyServerProvider).hostJoinRoom(id)
        : ref.read(commslyClientProvider.notifier).joinRoom(id);

    if (!success) {
      _message(
        isHosting
            ? 'Unable to join room.'
            : ref.read(commslyClientProvider).error ?? 'Unable to join room.',
      );
      return;
    }

    if (isHosting) {
      setState(() {});
    }
  }

  void _leaveRoom(String id, {required bool isHosting}) {
    final success = isHosting
        ? ref.read(commslyServerProvider).hostLeaveRoom(id)
        : ref.read(commslyClientProvider.notifier).leaveRoom(id);

    if (!success) {
      _message('Unable to leave room.');
      return;
    }

    _mutedRoomIds.remove(id);

    if (isHosting) {
      setState(() {});
    }
  }

  void _toggleMute(String id) {
    setState(() {
      if (_mutedRoomIds.contains(id)) {
        _mutedRoomIds.remove(id);
      } else {
        _mutedRoomIds.add(id);
      }
    });

    // The voice engine will use this state later.
  }

  void _openRoom({
    required String id,
    required String name,
    required bool isJoined,
  }) {
    if (!isJoined) {
      _message('Join this room before opening it.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomCommunicationScreen(roomId: id, roomName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverControllerProvider);
    final clientState = ref.watch(commslyClientProvider);

    final isHosting = serverState.isRunning;
    final isConnected = isHosting || clientState.isConnected;

    final hostRooms = isHosting ? ref.read(commslyServerProvider).rooms : null;

    final rooms = isHosting
        ? hostRooms!
              .map(
                (room) => _RoomView(
                  id: room.id,
                  name: room.name,
                  memberCount: room.memberCount,
                  isJoined: room.hostJoined,
                ),
              )
              .toList()
        : clientState.rooms
              .map(
                (room) => _RoomView(
                  id: room.id,
                  name: room.name,
                  memberCount: room.memberCount,
                  isJoined: room.isJoined,
                ),
              )
              .toList();

    final filteredRooms = rooms.where((room) {
      return room.name.toLowerCase().contains(_search.toLowerCase().trim());
    }).toList();

    final joinedRooms = filteredRooms.where((room) => room.isJoined).toList();

    final otherRooms = filteredRooms.where((room) => !room.isJoined).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(isHosting: isHosting),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _header(context),

                    const SizedBox(height: 25),

                    _title(
                      subtitle: isConnected
                          ? 'Your team communication spaces'
                          : 'Join a server to explore team rooms',
                    ),

                    const SizedBox(height: 22),

                    if (!isConnected)
                      _noServer(context)
                    else ...[
                      _serverBanner(
                        isHosting: isHosting,
                        name: isHosting
                            ? (serverState.deviceName ?? 'My Server')
                            : (clientState.server?.name ?? 'Server'),
                        roomCount: rooms.length,
                      ),

                      const SizedBox(height: 23),

                      if (rooms.isNotEmpty) ...[
                        _searchField(),
                        const SizedBox(height: 24),
                      ],

                      if (rooms.isEmpty)
                        _emptyRooms(isHosting: isHosting)
                      else ...[
                        if (joinedRooms.isNotEmpty) ...[
                          _sectionTitle(
                            'My Active Rooms',
                            '${joinedRooms.length} joined',
                            Icons.headset_mic_outlined,
                          ),
                          const SizedBox(height: 12),
                          for (final room in joinedRooms)
                            _roomCard(room, isHosting: isHosting),
                          const SizedBox(height: 18),
                        ],

                        _sectionTitle(
                          'Other Rooms',
                          '${otherRooms.length} available',
                          Icons.grid_view_rounded,
                        ),

                        const SizedBox(height: 12),

                        if (otherRooms.isEmpty)
                          _smallEmpty(
                            filteredRooms.isEmpty
                                ? 'No rooms match your search.'
                                : 'You have joined all available rooms.',
                          )
                        else
                          for (final room in otherRooms)
                            _roomCard(room, isHosting: isHosting),
                      ],
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER - SAME AS HOME
  // ============================================================

  Widget _header(BuildContext context) {
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
        Material(
          color: AppColors.softBlue,
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: () => context.go(Routenames.settings),
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => context.go(Routenames.settings),
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 42,
            width: 42,
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

  Widget _title({required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rooms',
          style: AppTextStyling.headlineLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: AppTextStyling.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NO SERVER
  // ============================================================

  Widget _noServer(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 38, 20, 25),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softBlue.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 94,
              height: 94,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.softBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cell_tower_rounded,
                size: 49,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 23),
          Text(
            'No Server Detected',
            style: AppTextStyling.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start a server on this device or join a nearby '
            'server to see and communicate in available rooms.',
            textAlign: TextAlign.center,
            style: AppTextStyling.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 27),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(15),
              ),
              child: ElevatedButton.icon(
                onPressed: () => context.push(Routenames.createServer),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Create Server'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => context.push(Routenames.joinServer),
              icon: const Icon(Icons.wifi_find_rounded),
              label: const Text('Find Nearby Servers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.softBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SERVER BANNER
  // ============================================================

  Widget _serverBanner({
    required bool isHosting,
    required String name,
    required int roomCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 53,
            height: 53,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.dns_rounded, size: 29, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyling.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${isHosting ? 'Hosting' : 'Connected'}  •  '
                  '$roomCount rooms',
                  style: AppTextStyling.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh rooms',
            onPressed: () => _refresh(isHosting: isHosting),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH AND SECTION HEADERS
  // ============================================================

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _search = value),
      style: AppTextStyling.bodyMedium,
      decoration: InputDecoration(
        hintText: 'Search rooms...',
        hintStyle: AppTextStyling.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
        ),
        suffixIcon: _search.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: AppColors.softBlue,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _sectionTitle(String title, String count, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.softBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppTextStyling.headlineMedium.copyWith(
              fontSize: 17,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          count,
          style: AppTextStyling.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ROOM CARDS
  // ============================================================

  Widget _roomCard(_RoomView room, {required bool isHosting}) {
    final muted = _mutedRoomIds.contains(room.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _openRoom(id: room.id, name: room.name, isJoined: room.isJoined),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 51,
                      height: 51,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.softBlue,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        _roomIcon(room.name),
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
                            '${room.memberCount} '
                            '${room.memberCount == 1 ? 'member' : 'members'}',
                            style: AppTextStyling.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (room.isJoined)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1F9F0),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          'Joined',
                          style: AppTextStyling.labelMedium.copyWith(
                            color: const Color(0xFF0AAE7A),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    if (room.isJoined) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleMute(room.id),
                          icon: Icon(
                            muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            size: 19,
                          ),
                          label: Text(muted ? 'Unmute' : 'Mute'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.softBlue),
                            backgroundColor: AppColors.softBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: room.isJoined
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  _leaveRoom(room.id, isHosting: isHosting),
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text('Leave'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                side: BorderSide(color: Colors.red.shade200),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: () =>
                                  _joinRoom(room.id, isHosting: isHosting),
                              icon: const Icon(Icons.login_rounded, size: 18),
                              label: const Text('Join Room'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _roomIcon(String name) {
    final value = name.toLowerCase();

    if (value.contains('media') || value.contains('camera')) {
      return Icons.videocam_rounded;
    }
    if (value.contains('production') || value.contains('stage')) {
      return Icons.movie_creation_rounded;
    }
    if (value.contains('security')) {
      return Icons.shield_outlined;
    }
    if (value.contains('audio') || value.contains('sound')) {
      return Icons.headphones_rounded;
    }

    return Icons.record_voice_over_rounded;
  }

  Widget _emptyRooms({required bool isHosting}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.meeting_room_outlined,
            size: 55,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No rooms created yet',
            style: AppTextStyling.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isHosting
                ? 'Create a room from your Server Dashboard '
                      'to get started.'
                : 'Rooms created by the host will '
                      'appear here automatically.',
            textAlign: TextAlign.center,
            style: AppTextStyling.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (isHosting) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.go(Routenames.serverDashboard),
              child: const Text('Open Server Dashboard'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallEmpty(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyling.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
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

class _RoomView {
  final String id;
  final String name;
  final int memberCount;
  final bool isJoined;

  const _RoomView({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.isJoined,
  });
}

// ============================================================
// TEMPORARY ROOM DETAIL SCREEN
// Replace this with the full voice communication screen next.
// ============================================================

class RoomCommunicationScreen extends StatelessWidget {
  final String roomId;
  final String roomName;

  const RoomCommunicationScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        centerTitle: true,
        title: Text(
          roomName,
          style: AppTextStyling.labelLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.softBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  size: 55,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                roomName,
                style: AppTextStyling.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Room communication controls will appear here '
                'when we implement the voice screen.',
                textAlign: TextAlign.center,
                style: AppTextStyling.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
