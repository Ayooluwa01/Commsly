import 'package:commsly/core/network/server/hosted_server_provider.dart';
import 'package:commsly/core/network/server/server_controller.dart';
import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/themes/appText_styling.dart';
import 'package:commsly/themes/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum CreateServerStep { form, creating, created }

class CreateServerScreen extends ConsumerStatefulWidget {
  const CreateServerScreen({super.key});

  @override
  ConsumerState<CreateServerScreen> createState() => _CreateServerScreenState();
}

class _CreateServerScreenState extends ConsumerState<CreateServerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pinController = TextEditingController();

  CreateServerStep _step = CreateServerStep.form;

  bool _requirePin = false;
  bool _showPin = false;

  String? _serverName;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _createServer() async {
    if (!_formKey.currentState!.validate()) return;

    final server = ref.read(serverControllerProvider);
    if (server.isRunning || server.isBusy) {
      _showMessage('A server is already running or starting.');
      return;
    }
    final name = _nameController.text.trim();
    setState(() {
      _serverName = name;
      _step = CreateServerStep.creating;
    });
    try {
      final success = await ref
          .read(serverControllerProvider.notifier)
          .startServer(
            deviceName: name,
            pin: _requirePin ? _pinController.text.trim() : null,
          );

      if (!mounted) return;
      if (success) {
        ref.read(hostedServerNameProvider.notifier).setName(name);
        setState(() {
          _step = CreateServerStep.created;
        });
      } else {
        final error = ref.read(serverControllerProvider).error;
        setState(() {
          _step = CreateServerStep.form;
        });
        _showMessage(error ?? 'Unable to create server. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = CreateServerStep.form;
      });

      _showMessage('Could not start the server: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != CreateServerStep.creating,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: switch (_step) {
                CreateServerStep.form => _buildForm(),
                CreateServerStep.creating => _buildCreating(),
                CreateServerStep.created => _buildSuccess(),
              },
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final title = switch (_step) {
      CreateServerStep.form => 'Create Server',
      CreateServerStep.creating => 'Creating Server',
      CreateServerStep.created => 'Server Created',
    };

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: _step == CreateServerStep.creating
            ? null
            : () {
                if (_step == CreateServerStep.created) {
                  context.go('/connected');
                } else {
                  context.pop();
                }
              },
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        color: AppColors.textPrimary,
      ),
      title: Text(
        title,
        style: AppTextStyling.labelLarge.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // ==========================================
  // STEP 1: CREATE SERVER FORM
  // ==========================================

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _screenTitle(),

                  const SizedBox(height: 24),

                  _label('Server Name'),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _nameController,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    style: AppTextStyling.bodyMedium,
                    decoration: _inputDecoration(
                      'e.g. Sunday Media',
                      icon: Icons.dns_outlined,
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';

                      if (name.isEmpty) {
                        return 'Enter a server name';
                      }

                      if (name.length < 3) {
                        return 'Use at least 3 characters';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  _label('Description (Optional)'),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 120,
                    maxLines: 2,
                    style: AppTextStyling.bodyMedium,
                    decoration: _inputDecoration(
                      'e.g. Church media team communication',
                    ),
                  ),

                  const SizedBox(height: 18),

                  _securitySection(),

                  const SizedBox(height: 20),

                  _networkCard(),
                ],
              ),
            ),
          ),

          _bottomButton(
            label: 'Create Server',
            icon: Icons.add_circle_outline,
            onPressed: _createServer,
          ),
        ],
      ),
    );
  }

  Widget _screenTitle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _serverIcon(),

          const SizedBox(height: 18),

          Text(
            'Create a New Server',
            textAlign: TextAlign.center,
            style: AppTextStyling.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Start your own server and invite your team '
            'to join. You can create multiple rooms afterwards.',
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

  Widget _serverIcon({double size = 72}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.dns_rounded,
        color: AppColors.primary,
        size: size * 0.48,
      ),
    );
  }

  Widget _securitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            _label('Security (Optional)'),
          ],
        ),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.04),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.primary),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Require PIN to join',
                          style: AppTextStyling.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Members will need a PIN to connect',
                          style: AppTextStyling.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Switch.adaptive(
                    value: _requirePin,
                    activeTrackColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() {
                        _requirePin = value;

                        if (!value) {
                          _pinController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),

              if (_requirePin) ...[
                const SizedBox(height: 14),

                TextFormField(
                  controller: _pinController,
                  obscureText: !_showPin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      _inputDecoration(
                        'e.g. 1234',
                        icon: Icons.password_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPin
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() => _showPin = !_showPin);
                          },
                        ),
                      ),
                  validator: (value) {
                    if (!_requirePin) return null;

                    if (value == null || value.length != 4) {
                      return 'Enter a 4-digit PIN';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 6),

                Text(
                  'PIN-protected hosting is not yet '
                  'supported by the local server.',
                  style: AppTextStyling.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _networkCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_rounded, color: AppColors.primary, size: 28),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local network required',
                  style: AppTextStyling.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'The server will be available to devices '
                  'connected to the same Wi-Fi or hotspot.',
                  style: AppTextStyling.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: CREATING SERVER
  // ==========================================

  Widget _buildCreating() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              children: [
                const SizedBox(height: 20),

                _animatedServer(),

                const SizedBox(height: 35),

                Text(
                  'Starting your server...',
                  style: AppTextStyling.headlineMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Setting up the server and making it '
                  'discoverable on your local network.',
                  textAlign: TextAlign.center,
                  style: AppTextStyling.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 38),

                _progressRow(
                  Icons.settings_outlined,
                  'Initializing local server',
                  isActive: true,
                ),

                _progressRow(
                  Icons.wifi_rounded,
                  'Preparing network connection',
                ),

                _progressRow(
                  Icons.cell_tower_rounded,
                  'Advertising on local network',
                ),

                _progressRow(Icons.dns_outlined, 'Finalizing setup'),

                const SizedBox(height: 30),

                _keepOpenCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _animatedServer() {
    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 225,
            height: 225,
            decoration: BoxDecoration(
              color: AppColors.softBlue.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
          ),

          Container(
            width: 165,
            height: 165,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(
            width: 210,
            height: 210,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
              backgroundColor: Colors.transparent,
            ),
          ),

          _serverIcon(size: 88),
        ],
      ),
    );
  }

  Widget _progressRow(IconData icon, String title, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),

          const SizedBox(width: 18),

          Expanded(
            child: Text(
              title,
              style: AppTextStyling.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          isActive
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Icon(Icons.circle, size: 14, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  Widget _keepOpenCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Colors.orange,
            size: 28,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep this screen open',
                  style: AppTextStyling.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Please keep Commsly in the foreground '
                  'while your local server starts.',
                  style: AppTextStyling.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 3: SERVER CREATED
  // ==========================================

  Widget _buildSuccess() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 30),

                _successIllustration(),

                const SizedBox(height: 28),

                Text(
                  'Server is ready!',
                  textAlign: TextAlign.center,
                  style: AppTextStyling.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Your local server has started successfully.',
                  textAlign: TextAlign.center,
                  style: AppTextStyling.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 30),

                _serverDetails(),
              ],
            ),
          ),
        ),

        _successActions(),
      ],
    );
  }

  Widget _successIllustration() {
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFE5FBF2),
              shape: BoxShape.circle,
            ),
          ),

          Container(
            width: 130,
            height: 130,
            decoration: const BoxDecoration(
              color: Color(0xFFC9F7E5),
              shape: BoxShape.circle,
            ),
          ),

          _serverIcon(size: 82),

          Positioned(
            right: 35,
            bottom: 42,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0xFF12BA82),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverDetails() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          _detailRow(
            icon: Icons.dns_rounded,
            label: 'Server Name',
            value: _serverName ?? 'Unnamed server',
          ),

          const Divider(),

          _detailRow(
            icon: Icons.lan_outlined,
            label: 'Server IP (Local)',
            value: 'Not yet available',
          ),

          const Divider(),

          _detailRow(
            icon: Icons.lock_outline,
            label: 'PIN Protection',
            value: 'Disabled',
          ),

          const Divider(),

          _detailRow(
            icon: Icons.wifi_rounded,
            label: 'Server Status',
            value: 'Running',
            valueColor: const Color(0xFF12BA82),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
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
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyling.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: AppTextStyling.labelLarge.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _successActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      color: AppColors.background,
      child: Column(
        children: [
          _primaryButton(
            label: 'Go to Server Dashboard',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              context.go(Routenames.serverDashboard);
            },
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton.icon(
              onPressed: () async {
                final details =
                    'Commsly Server: ${_serverName ?? ""}\n'
                    'Connect to the same Wi-Fi or hotspot '
                    'and open Commsly to discover this server.';

                await Clipboard.setData(ClipboardData(text: details));

                if (!mounted) return;

                _showMessage('Server details copied');
              },
              style: TextButton.styleFrom(
                backgroundColor: AppColors.softBlue,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.share_outlined),
              label: Text(
                'Share Server Details',
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

  // ==========================================
  // SHARED WIDGETS
  // ==========================================

  Widget _label(String title) {
    return Text(
      title,
      style: AppTextStyling.labelLarge.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyling.bodyMedium.copyWith(
        color: AppColors.textSecondary,
      ),
      prefixIcon: icon == null ? null : Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.surface,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: AppColors.softBlue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _bottomButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: _primaryButton(label: label, icon: icon, onPressed: onPressed),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(15),
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          iconAlignment: IconAlignment.end,
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: AppTextStyling.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
