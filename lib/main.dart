import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/bridge_client.dart';
import 'src/i18n.dart';
import 'src/models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StraitUiApp());
}

class StraitUiApp extends StatelessWidget {
  const StraitUiApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData createTheme(Brightness brightness) {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7655DF), brightness: brightness);
      return ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: scheme.surface,
        cardTheme: CardThemeData(color: scheme.surfaceContainerLow, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))));
    }

    return MaterialApp(
      title: 'StraitUI', debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, theme: createTheme(Brightness.light), darkTheme: createTheme(Brightness.dark),
      home: const SessionHome(),
    );
  }
}

class SessionHome extends StatefulWidget {
  const SessionHome({super.key});

  @override
  State<SessionHome> createState() => _SessionHomeState();
}

class _SessionHomeState extends State<SessionHome> {
  final BridgeClient _bridge = BridgeClient();
  final TextEditingController _search = TextEditingController();
  List<SessionItem> _sessions = [];
  final Set<String> _enabled = {'claude', 'codex', 'opencode'};
  String? _runtimeFilter;
  SessionItem? _selected;
  Conversation? _conversation;
  String? _error;
  bool _loading = true;
  bool _reading = false;
  bool _busy = false;
  bool _straitInstalled = false;
  Map<String, int> _counts = {};

  I18n get _l => I18n(WidgetsBinding.instance.platformDispatcher.locale);

  @override
  void initState() {
    super.initState();
    _search.addListener(() { if (mounted) setState(() {}); });
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    _bridge.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final scan = await _bridge.call('scan');
      final list = await _bridge.call('list');
      final sessions = (list['sessions'] as List).map((item) => SessionItem.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      final counts = <String, int>{};
      for (final item in scan['providers'] as List) {
        counts[item['id'].toString()] = (item['count'] as num).toInt();
      }
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _counts = counts;
        _straitInstalled = scan['straitInstalled'] == true;
        _loading = false;
      });
      if (_selected != null) {
        final matches = sessions.where((item) => item.id == _selected!.id && item.runtime == _selected!.runtime);
        if (matches.isNotEmpty) await _open(matches.first);
      }
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _open(SessionItem session) async {
    setState(() { _selected = session; _reading = true; _conversation = null; });
    try {
      final json = await _bridge.call('read', {'runtime': session.runtime, 'id': session.id});
      if (!mounted || _selected?.id != session.id || _selected?.runtime != session.runtime) return;
      setState(() { _conversation = Conversation.fromJson(json); _reading = false; });
    } catch (error) {
      if (mounted) {
        setState(() { _reading = false; });
        _showError(error.toString());
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_l.t('error')}: $message'), duration: const Duration(seconds: 8)));
  }

  Future<void> _chooseDestination() async {
    final current = _selected;
    final conversation = _conversation;
    if (current == null || conversation == null || _busy) return;
    if (!_straitInstalled) {
      _showError(_l.t('notInstalled'));
      return;
    }
    final targets = _enabled.where((runtime) => runtime != current.runtime).toList();
    if (targets.isEmpty) { _showError(_l.t('noTarget')); return; }
    final destination = await showDialog<String>(context: context, builder: (context) => SimpleDialog(
      title: Text(_l.t('destination')),
      children: targets.map((runtime) => SimpleDialogOption(
        onPressed: () => Navigator.pop(context, runtime),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
          Icon(_runtimeIcon(runtime), color: _runtimeColor(runtime)), const SizedBox(width: 12), Text(_runtimeLabel(runtime)),
        ])),
      )).toList(),
    ));
    if (destination == null || !mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(_l.t('confirm')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_runtimeLabel(current.runtime)} → ${_runtimeLabel(destination)}'),
        const SizedBox(height: 14), Text(_l.t('confirmHint')),
        if (conversation.droppedBlocks > 0) ...[
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange), const SizedBox(width: 8),
            Expanded(child: Text('${_l.t('loss')} (${conversation.droppedBlocks})')),
          ]),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_l.t('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_l.t('go'))),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _bridge.call('sync', {'from': current.runtime, 'to': destination, 'sessionId': current.id});
      if (!mounted) return;
      final resume = (result['resume'] ?? '').toString();
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text(_l.t('success')),
        content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_l.t('resume')), const SizedBox(height: 10),
          SelectableText(resume.isNotEmpty ? resume : (result['stdout'] ?? '').toString()),
        ])),
        actions: [
          if (resume.isNotEmpty) TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: resume)),
            icon: const Icon(Icons.copy), label: Text(_l.t('copy'))),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(_l.t('close'))),
        ],
      ));
      await _refresh();
    } catch (error) { _showError(error.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  List<SessionItem> get _visibleSessions {
    final search = _search.text.toLowerCase().trim();
    return _sessions.where((item) => _enabled.contains(item.runtime) &&
        (_runtimeFilter == null || _runtimeFilter == item.runtime) &&
        (search.isEmpty || '${item.title} ${item.preview} ${item.cwd} ${item.id}'.toLowerCase().contains(search))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.compare_arrows), SizedBox(width: 10), Text('StraitUI')]),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 12), child: Chip(
            avatar: Icon(_straitInstalled ? Icons.check_circle : Icons.warning_amber, size: 18,
              color: _straitInstalled ? Colors.green : Colors.orange),
            label: Text(_l.t(_straitInstalled ? 'ready' : 'offline')),
          )),
          IconButton(tooltip: _l.t('refresh'), onPressed: _loading || _busy ? null : _refresh, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 12),
        ],
      ),
      body: _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48), const SizedBox(height: 12),
          SelectableText(_error!, textAlign: TextAlign.center), const SizedBox(height: 16),
          FilledButton(onPressed: _refresh, child: Text(_l.t('refresh'))),
        ],
      ))) : LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 1050;
        return Row(children: [
          if (wide) SizedBox(width: 228, child: _sourceSidebar(colors)),
          SizedBox(width: wide ? 340 : size.maxWidth < 650 ? size.maxWidth * .45 : 360,
            child: _sessionSidebar(showSources: !wide)),
          VerticalDivider(width: 1, color: colors.outlineVariant),
          Expanded(child: _conversationPanel()),
        ]);
      }),
    );
  }

  Widget _sourceSidebar(ColorScheme colors) {
    return Container(color: colors.surfaceContainerLow, padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_l.t('sources').toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 12),
        for (final runtime in ['claude', 'codex', 'opencode']) CheckboxListTile(
          contentPadding: EdgeInsets.zero, dense: true, value: _enabled.contains(runtime),
          secondary: Icon(_runtimeIcon(runtime), color: _runtimeColor(runtime)),
          title: Text(_runtimeLabel(runtime), style: const TextStyle(fontSize: 13)),
          subtitle: Text('${_counts[runtime] ?? 0} ${_l.t('sessions').toLowerCase()}', style: const TextStyle(fontSize: 11)),
          onChanged: (checked) => setState(() {
            if (checked == true) { _enabled.add(runtime); } else { _enabled.remove(runtime); }
            if (!_enabled.contains(_runtimeFilter)) _runtimeFilter = null;
          }),
        ),
        const Spacer(),
        Row(children: [Icon(Icons.lock_outline, size: 15, color: colors.onSurfaceVariant), const SizedBox(width: 7),
          Text(_l.t('local'), style: Theme.of(context).textTheme.bodySmall)]),
        Text('Node.js • ${Platform.operatingSystem}', style: Theme.of(context).textTheme.labelSmall),
      ],
    ));
  }

  Widget _sessionSidebar({required bool showSources}) {
    final sessions = _visibleSessions;
    final colors = Theme.of(context).colorScheme;
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _search, decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
          hintText: _l.t('search'), isDense: true, suffixIcon: _search.text.isNotEmpty
              ? IconButton(onPressed: _search.clear, icon: const Icon(Icons.close)) : null)),
        if (showSources) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final runtime in ['claude', 'codex', 'opencode']) FilterChip(
              label: Text(_runtimeLabel(runtime), style: const TextStyle(fontSize: 11)),
              selected: _enabled.contains(runtime),
              onSelected: (value) => setState(() { if (value) { _enabled.add(runtime); } else { _enabled.remove(runtime); } }),
            ),
          ]),
        ],
      ])),
      Divider(height: 1, color: colors.outlineVariant),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      Expanded(child: sessions.isEmpty ? Center(child: Text(_loading ? _l.t('loading') : _l.t('empty'), textAlign: TextAlign.center))
          : ListView.builder(itemCount: sessions.length, itemBuilder: (context, index) {
              final item = sessions[index];
              final selected = _selected?.id == item.id && _selected?.runtime == item.runtime;
              return Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 0), child: Material(
                color: selected ? colors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => _open(item),
                  title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
                    Icon(_runtimeIcon(item.runtime), size: 15, color: _runtimeColor(item.runtime)),
                    const SizedBox(width: 5), Expanded(child: Text(_runtimeLabel(item.runtime), maxLines: 1,
                        style: const TextStyle(fontSize: 11))),
                    Text(_date(item.updatedAt), style: const TextStyle(fontSize: 10)),
                  ])),
                ),
              ));
            })),
    ]);
  }

  Widget _conversationPanel() {
    final conversation = _conversation;
    final selected = _selected;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (selected == null) return _placeholder(Icons.forum_outlined, _l.t('select'), _l.t('selectHint'));
    if (_reading || conversation == null) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
        child: Row(children: [
          Icon(_runtimeIcon(selected.runtime), color: _runtimeColor(selected.runtime)), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(selected.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
            Text('${_runtimeLabel(selected.runtime)} • ${conversation.messages.length} ${_l.t('messages')}', style: theme.textTheme.bodySmall),
            if (conversation.cwd.isNotEmpty) Tooltip(message: conversation.cwd,
              child: Text('${_l.t('path')}: ${conversation.cwd}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall)),
          ])),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: _busy ? null : _chooseDestination,
            icon: _busy ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.copy_all),
            label: Text(_l.t('transfer'))),
        ])),
      for (final warning in conversation.warnings) Container(
        color: colors.tertiaryContainer,
        padding: const EdgeInsets.all(10),
        child: Row(children: [const Icon(Icons.warning_amber, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(warning, style: theme.textTheme.bodySmall))]),
      ),
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: conversation.messages.length,
        itemBuilder: (context, index) => _messageCard(conversation.messages[index]))),
    ]);
  }

  Widget _messageCard(ConversationMessage message) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.role == 'user';
    return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Card(color: isUser ? colors.primaryContainer.withValues(alpha: .55) : colors.surfaceContainerLow,
        margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isUser ? Icons.person_outline : message.role == 'tool' ? Icons.build_outlined : Icons.smart_toy_outlined, size: 16),
              const SizedBox(width: 7), Text(message.role.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
              if (message.timestamp != null) ...[const SizedBox(width: 10), Text(_date(message.timestamp!), style: Theme.of(context).textTheme.labelSmall)],
            ]),
            const SizedBox(height: 10),
            for (final block in message.blocks) Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (block.type != 'text') Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(
                  block.type == 'tool_call' ? '${_l.t('tools')}: ${block.name}' :
                  block.type == 'tool_result' ? _l.t('result') :
                  block.type == 'thinking' ? _l.t('thinking') : _l.t('image'),
                  style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                )),
                SelectableText(block.text, style: TextStyle(fontSize: block.type == 'text' ? 13 : 12,
                  fontFamily: block.type == 'text' ? null : 'monospace', height: 1.45)),
              ],
            )),
          ],
        ))),
    ));
  }

  Widget _placeholder(IconData icon, String title, String subtitle) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12),
      Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
    ]));
  }

  String _date(DateTime d) {
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _runtimeLabel(String runtime) => switch (runtime) {
    'claude' => 'Claude Code', 'codex' => 'Codex', 'opencode' => 'OpenCode', _ => runtime,
  };

  IconData _runtimeIcon(String runtime) => switch (runtime) {
    'claude' => Icons.auto_awesome, 'codex' => Icons.code, 'opencode' => Icons.terminal, _ => Icons.chat,
  };

  Color _runtimeColor(String runtime) => switch (runtime) {
    'claude' => const Color(0xFFD9845B), 'codex' => const Color(0xFF3C9B7A),
    'opencode' => const Color(0xFF8664E5), _ => Colors.grey,
  };
}
