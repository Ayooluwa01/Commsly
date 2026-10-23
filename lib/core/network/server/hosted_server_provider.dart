import 'package:flutter_riverpod/flutter_riverpod.dart';

class HostedServerNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setName(String name) {
    state = name.trim();
  }

  void clear() {
    state = null;
  }
}

final hostedServerNameProvider =
    NotifierProvider<HostedServerNotifier, String?>(HostedServerNotifier.new);
