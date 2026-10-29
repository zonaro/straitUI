import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Stateless request/response protocol over a single local stdio process.
/// No listening port, remote host, shell interpolation or network dependency.
class BridgeClient {
  Process? _process;
  int _sequence = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  Future<void> start() async {
    if (_process != null) return;
    final script = _resolveScript();
    final node = Platform.environment['STRAIT_UI_NODE_BIN'] ?? 'node';
    _process = await Process.start(node, [script], runInShell: false);
    _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_handleLine);
    _process!.stderr.transform(utf8.decoder).listen((_) {});
    unawaited(_process!.exitCode.then((code) {
      for (final waiting in _pending.values) {
        if (!waiting.isCompleted) waiting.completeError(StateError('Bridge exited ($code)'));
      }
      _pending.clear();
      _process = null;
    }));
  }

  String _resolveScript() {
    final explicit = Platform.environment['STRAIT_UI_BRIDGE_PATH'];
    final candidates = [
      if (explicit != null) explicit,
      '${Directory.current.path}/bridge/bin/bridge.mjs',
      '${File(Platform.resolvedExecutable).parent.path}/bridge/bin/bridge.mjs',
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    throw StateError('Bridge not found. Start the app from its repository root or configure STRAIT_UI_BRIDGE_PATH.');
  }

  void _handleLine(String line) {
    try {
      final data = jsonDecode(line) as Map<String, dynamic>;
      final id = data['id'] as int?;
      final waiting = _pending.remove(id);
      if (waiting == null) return;
      if (data.containsKey('error')) {
        waiting.completeError(StateError(data['error'].toString()));
      } else {
        waiting.complete(Map<String, dynamic>.from(data['result'] as Map));
      }
    } catch (_) {
      // Ignore non-protocol diagnostics without poisoning other requests.
    }
  }

  Future<Map<String, dynamic>> call(String method, [Map<String, dynamic> params = const {}]) async {
    await start();
    final id = ++_sequence;
    final future = Completer<Map<String, dynamic>>();
    _pending[id] = future;
    _process!.stdin.writeln(jsonEncode({'id': id, 'method': method, 'params': params}));
    try {
      return await future.future.timeout(const Duration(minutes: 3));
    } finally {
      _pending.remove(id);
    }
  }

  void dispose() {
    _process?.stdin.close();
    _process?.kill();
    _process = null;
    for (final waiting in _pending.values) {
      if (!waiting.isCompleted) waiting.completeError(StateError('Bridge disposed'));
    }
    _pending.clear();
  }
}
