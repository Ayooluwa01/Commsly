import 'package:commsly/core/network/models/nearby_server.dart';
import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/themes/app_colors.dart';
import 'package:commsly/themes/appText_styling.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class EnterPinScreen extends StatefulWidget {
  final DiscoveredServer server;
  final bool Function() hasActiveConnection;
  final Future<bool> Function(DiscoveredServer server, String? pin) onJoin;

  const EnterPinScreen({
    super.key,
    required this.server,
    required this.hasActiveConnection,
    required this.onJoin,
  });

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  final _pinController = TextEditingController();

  bool _isJoining = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();

    if (pin.length != 4) {
      _showMessage('Enter the 4-digit server PIN.');
      return;
    }

    if (widget.hasActiveConnection()) {
      _showMessage('Leave your current server before joining another.');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final success = await widget.onJoin(widget.server, pin);

      if (!mounted) return;

      if (success) {
        context.go(Routenames.serverDashboard);
      } else {
        _showMessage('Unable to join. Check the server PIN.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Connection failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Enter PIN',
          style: AppTextStyling.labelLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: _isJoining ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
          child: Column(
            children: [
              Container(
                width: 94,
                height: 94,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 45,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Server requires a PIN',
                textAlign: TextAlign.center,
                style: AppTextStyling.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Enter the PIN provided by the host '
                'to join ${widget.server.name}.',
                textAlign: TextAlign.center,
                style: AppTextStyling.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: _pinController,
                maxLength: 4,
                autofocus: true,
                obscureText: _obscurePin,
                obscuringCharacter: '•',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyling.headlineLarge.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: 14,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surface,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePin = !_obscurePin);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.softBlue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.softBlue),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isJoining ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Join Server',
                          style: AppTextStyling.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
