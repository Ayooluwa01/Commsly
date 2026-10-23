import 'package:commsly/core/network/server/commsly_client_provider.dart';
import 'package:commsly/core/network/server/server_controller.dart';
import 'package:commsly/themes/app_colors.dart';
import 'package:commsly/themes/appText_styling.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Member presence model for this screen.
// Later, these values will come from the WebSocket voice events.
class RoomMember {
  final String id;
  final String name;
  final bool isSpeaking;
  final bool isMuted;
  final bool isHost;

  const RoomMember({
    required this.id,
    required this.name,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isHost = false,
  });
}

class RoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;

  // Pass actual remote members when presence tracking is ready.
  final List<RoomMember> members;

  const RoomDetailScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.members = const [],
  });

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  bool _micEnabled = false;
  bool _leaving = false;

  static const Color _green = Color(0xFF12BA82);
  static const Color _red = Color(0xFFFF4569);

  @override
  Widget build(BuildContext context) {
    final hosting = ref.watch(serverControllerProvider).isRunning;
    final client = ref.watch(commslyClientProvider);

    final hostRoom = hosting
        ? ref
              .read(commslyServerProvider)
              .rooms
              .where((r) => r.id == widget.roomId)
              .firstOrNull
        : null;

    final clientRoom = !hosting
        ? client.rooms.where((r) => r.id == widget.roomId).firstOrNull
        : null;

    final isJoined = hosting
        ? (hostRoom?.hostJoined ?? false)
        : (clientRoom?.isJoined ?? false);

    final memberCount = hosting
        ? (hostRoom?.memberCount ?? 0)
        : (clientRoom?.memberCount ?? 0);

    final isHost = hosting;

    // The local user is known. Other members come from the
    // optional members input until real presence is implemented.
    final members = <RoomMember>[
      RoomMember(
        id: 'local-user',
        name: 'You',
        isSpeaking: _micEnabled,
        isMuted: !_micEnabled,
        isHost: isHost,
      ),
      ...widget.members.where((member) => member.id != 'local-user'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(context, memberCount),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _roomBanner(memberCount: memberCount, isJoined: isJoined),

                    const SizedBox(height: 27),

                    _sectionHeader(
                      'Members ($memberCount)',
                      Icons.groups_rounded,
                    ),

                    const SizedBox(height: 16),

                    _membersGrid(members),

                    const SizedBox(height: 30),

                    _microphoneSection(isJoined),

                    const SizedBox(height: 22),

                    _microphoneInfo(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _bottomAction(isJoined: isJoined),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _appBar(BuildContext context, int memberCount) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 78,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.navy,
          size: 20,
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              _roomIcon(widget.roomName),
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
                  widget.roomName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyling.labelLarge.copyWith(
                    fontSize: 17,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      height: 7,
                      width: 7,
                      decoration: const BoxDecoration(
                        // color: _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '$memberCount active',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyling.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          color: AppColors.surface,
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.navy),
          onSelected: (value) {
            if (value == 'leave') {
              _confirmLeaveRoom();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'leave',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: _red, size: 19),
                  SizedBox(width: 10),
                  Text('Leave Room'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ============================================================
  // ROOM BANNER
  // ============================================================

  Widget _roomBanner({required int memberCount, required bool isJoined}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              _roomIcon(widget.roomName),
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.roomName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyling.labelLarge.copyWith(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Team communication room',
                  style: AppTextStyling.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              // color: isJoined
              //     ? const Color(0xFFDEF8EE)
              //     : const Color(0xFFE8EDF5),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 7,
                  width: 7,
                  decoration: BoxDecoration(
                    // color: isJoined ? _green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isJoined ? 'Joined' : 'Left',
                  style: AppTextStyling.labelMedium.copyWith(
                    // color: isJoined
                    //     ? const Color(0xFF0A986A)
                    //     : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
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
  // MEMBERS
  // ============================================================

  Widget _sectionHeader(String title, IconData icon) {
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

  Widget _membersGrid(List<RoomMember> members) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const columns = 3;
              const spacing = 9.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 24,
                children: members
                    .map(
                      (member) =>
                          SizedBox(width: width, child: _memberTile(member)),
                    )
                    .toList(),
              );
            },
          ),
          if (widget.members.isEmpty) ...[
            const SizedBox(height: 23),
            Text(
              'Other member details will appear here '
              'when presence tracking is enabled.',
              textAlign: TextAlign.center,
              style: AppTextStyling.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberTile(RoomMember member) {
    final speaking = member.isSpeaking;
    final color = speaking ? AppColors.primary : AppColors.textSecondary;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.all(speaking ? 5 : 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: speaking ? AppColors.primary : AppColors.softBlue,
                  width: speaking ? 3 : 2,
                ),
                boxShadow: speaking
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 17,
                        ),
                      ]
                    : [],
              ),
              child: CircleAvatar(
                radius: 33,
                backgroundColor: AppColors.softBlue,
                child: Text(
                  _initials(member.name),
                  style: AppTextStyling.headlineMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: speaking ? AppColors.primary : AppColors.textSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Icon(
                  member.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyling.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            if (member.isHost) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.primary,
                size: 15,
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 7,
              width: 7,
              decoration: BoxDecoration(
                color: speaking
                    ? _green
                    : AppColors.textSecondary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                speaking
                    ? 'Speaking'
                    : member.isMuted
                    ? 'Muted'
                    : 'Listening',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyling.bodySmall.copyWith(
                  color: speaking ? color : AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // MICROPHONE
  // ============================================================

  Widget _microphoneSection(bool isJoined) {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: isJoined
                ? () {
                    setState(() {
                      _micEnabled = !_micEnabled;
                    });
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 230),
              width: 190,
              height: 190,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _micEnabled
                    ? _red.withValues(alpha: 0.08)
                    : AppColors.softBlue.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _micEnabled
                      ? _red.withValues(alpha: 0.20)
                      : AppColors.primary.withValues(alpha: 0.10),
                  width: 5,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _micEnabled
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6684), Color(0xFFFF3158)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (_micEnabled ? _red : AppColors.primary)
                          .withValues(alpha: 0.24),
                      blurRadius: 25,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Icon(
                  _micEnabled ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 78,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            !isJoined
                ? 'You are not in this room'
                : _micEnabled
                ? 'Microphone is active'
                : 'Tap to start speaking',
            key: ValueKey('$_micEnabled-$isJoined'),
            textAlign: TextAlign.center,
            style: AppTextStyling.headlineMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _micEnabled
              ? 'Tap again to turn off your microphone'
              : 'Tap once to turn on your microphone',
          textAlign: TextAlign.center,
          style: AppTextStyling.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: _micEnabled
                ? _red.withValues(alpha: 0.08)
                : AppColors.softBlue,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: _micEnabled ? _red : AppColors.primary,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                _micEnabled ? 'Mic On' : 'Mic Off',
                style: AppTextStyling.labelMedium.copyWith(
                  color: _micEnabled ? _red : AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _microphoneInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 23,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Everyone in this room can speak at the same time. '
              'No push-to-talk or speaking queue.',
              style: AppTextStyling.bodySmall.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LEAVE ROOM
  // ============================================================

  Widget _bottomAction({required bool isJoined}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.035),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton.icon(
          onPressed: _leaving || !isJoined ? null : _confirmLeaveRoom,
          icon: _leaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: Text(_leaving ? 'Leaving...' : 'Leave Room'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _red,
            side: const BorderSide(color: _red),
            backgroundColor: _red.withValues(alpha: 0.035),
            textStyle: AppTextStyling.labelLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeaveRoom() async {
    if (_leaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Leave this room?'),
        content: Text(
          'You will leave ${widget.roomName} and stop '
          'participating in its communication.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: const Text('Leave Room'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _leaving = true;
      _micEnabled = false;
    });

    final isHosting = ref.read(serverControllerProvider).isRunning;

    final success = isHosting
        ? ref.read(commslyServerProvider).hostLeaveRoom(widget.roomId)
        : ref.read(commslyClientProvider.notifier).leaveRoom(widget.roomId);

    if (!mounted) return;

    setState(() => _leaving = false);

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to leave room.')));
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) return '?';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  IconData _roomIcon(String name) {
    final value = name.toLowerCase();

    if (value.contains('camera') || value.contains('media')) {
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
