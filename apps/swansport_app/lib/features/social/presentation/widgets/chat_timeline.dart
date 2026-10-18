import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import 'chat_message_bubble.dart';
import 'chat_presentation.dart';

class ChatTimeline extends StatefulWidget {
  const ChatTimeline(
      {super.key,
      required this.items,
      this.query = '',
      this.searching = false,
      this.onVisible,
      this.onRetry,
      required this.empty});
  final List<ChatItem> items;
  final String query;
  final bool searching;
  final ValueChanged<List<ChatItem>>? onVisible;
  final ValueChanged<String>? onRetry;
  final Widget empty;

  @override
  State<ChatTimeline> createState() => _ChatTimelineState();
}

class _ChatTimelineState extends State<ChatTimeline>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _keys = <String, GlobalKey>{};
  String? _selectedId;
  int _navigation = 0;
  bool _newMessages = false;
  bool _queued = false;
  bool _foreground = true;
  bool get _atEnd => !_scroll.hasClients || _scroll.offset <= SwanSpace.xl * 2;

  List<ChatItem> get _matches => widget.query.trim().isEmpty
      ? []
      : widget.items
          .where((item) =>
              chatMatchRanges(item.message.body, widget.query).isNotEmpty)
          .toList();

  @override
  void initState() {
    super.initState();
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _scheduleVisible();
  }

  @override
  void didUpdateWidget(ChatTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.items.map((e) => e.message.id).toSet();
    final added =
        widget.items.where((e) => !oldIds.contains(e.message.id)).toList();
    final follow = _atEnd;
    if (added.isNotEmpty && !follow) _newMessages = true;
    final oldOffset = _scroll.hasClients ? _scroll.offset : 0.0;
    final oldExtent =
        _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final anchor = _visibleAnchor();
    _keys.removeWhere((id, _) => !widget.items.any((e) => e.message.id == id));
    if (added.isNotEmpty)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        if (follow && !widget.searching) {
          _scroll.jumpTo(0);
        } else if (anchor != null && _box(anchor.$1) != null) {
          final dy = _box(anchor.$1)!.localToGlobal(Offset.zero).dy - anchor.$2;
          _scroll.jumpTo(
              (_scroll.offset - dy).clamp(0, _scroll.position.maxScrollExtent));
        } else {
          _scroll.jumpTo(
              (oldOffset + _scroll.position.maxScrollExtent - oldExtent)
                  .clamp(0, _scroll.position.maxScrollExtent));
        }
        _scheduleVisible();
      });
    if (oldWidget.query != widget.query ||
        oldWidget.searching != widget.searching) {
      _navigation++;
      final matches = _matches;
      _selectedId = matches.isEmpty ? null : matches.first.message.id;
      if (_selectedId != null) _jumpTo(_selectedId!);
    } else if (_selectedId != null &&
        !_matches.any((e) => e.message.id == _selectedId)) {
      final matches = _matches;
      _selectedId = matches.isEmpty ? null : matches.first.message.id;
    }
    _scheduleVisible();
  }

  RenderBox? _box(String id) {
    final object = _keys[id]?.currentContext?.findRenderObject();
    return object is RenderBox && object.attached && object.hasSize
        ? object
        : null;
  }

  (String, double)? _visibleAnchor() {
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    for (final item in widget.items) {
      final box = _box(item.message.id);
      if (box != null) {
        final at = box.localToGlobal(Offset.zero);
        if ((at & box.size).overlaps(bounds)) return (item.message.id, at.dy);
      }
    }
    return null;
  }

  void _onScroll() {
    if (_atEnd && _newMessages) setState(() => _newMessages = false);
    _scheduleVisible();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _scheduleVisible();
  }

  void _scheduleVisible() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted ||
          !_foreground ||
          ModalRoute.of(context)?.isCurrent == false) return;
      final viewport = _viewport.currentContext?.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
      final visible = widget.items.where((item) {
        final box = _box(item.message.id);
        if (box == null) return false;
        return bounds.overlaps(box.localToGlobal(Offset.zero) & box.size);
      }).toList();
      widget.onVisible?.call(visible);
    });
  }

  Future<void> _jumpTo(String id) async {
    final operation = ++_navigation;
    // Rows stay lazy. Walk viewport-sized steps until the selected variable-
    // height row is mounted, then use exact geometry instead of guessed offsets.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || operation != _navigation || !_scroll.hasClients) return;
    final target = widget.items.indexWhere((e) => e.message.id == id);
    if (target < 0) return;
    while (mounted && operation == _navigation) {
      if (!mounted || operation != _navigation || !_scroll.hasClients) return;
      final rowContext = _keys[id]?.currentContext;
      if (rowContext != null) {
        await Scrollable.ensureVisible(rowContext,
            alignment: .4,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180));
        return;
      }
      final mountedIndices = <int>[];
      for (var i = 0; i < widget.items.length; i++) {
        if (_box(widget.items[i].message.id) != null) mountedIndices.add(i);
      }
      final older = mountedIndices.isEmpty || target < mountedIndices.first;
      final next = (_scroll.offset +
              (older ? 1 : -1) * _scroll.position.viewportDimension * .8)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      if (next == _scroll.offset) return;
      _scroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _select(int delta) {
    final matches = _matches;
    if (matches.isEmpty) return;
    final index = matches.indexWhere((e) => e.message.id == _selectedId);
    setState(() =>
        _selectedId = matches[(index + delta) % matches.length].message.id);
    _jumpTo(_selectedId!);
  }

  @override
  void dispose() {
    _navigation++;
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final matches = _matches;
    final selected = matches.indexWhere((e) => e.message.id == _selectedId);
    _scheduleVisible();
    return Column(children: [
      if (widget.searching)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
            child: Row(children: [
              Expanded(
                  child: Text(
                      widget.query.trim().isEmpty
                          ? 'Yüklenen mesajlarda ara'
                          : matches.isEmpty
                              ? 'Sonuç bulunamadı'
                              : '${selected + 1}/${matches.length} sonuç',
                      style: SwanType.caption(c.inkMuted))),
              IconButton(
                  tooltip: 'Önceki sonuç',
                  onPressed: matches.isEmpty ? null : () => _select(-1),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded)),
              IconButton(
                  tooltip: 'Sonraki sonuç',
                  onPressed: matches.isEmpty ? null : () => _select(1),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded)),
            ])),
      Expanded(
          child: Stack(key: _viewport, children: [
        if (widget.items.isEmpty)
          Center(child: widget.empty)
        else
          ListView.builder(
              controller: _scroll,
              reverse: true,
              padding: const EdgeInsets.all(SwanSpace.lg),
              itemCount: widget.items.length,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final index =
                    widget.items.indexWhere((e) => e.message.id == key.value);
                return index < 0 ? null : widget.items.length - 1 - index;
              },
              itemBuilder: (context, reverseIndex) {
                final index = widget.items.length - 1 - reverseIndex;
                final item = widget.items[index];
                final start = index == 0 ||
                    !sameChatDay(widget.items[index - 1].message.createdAt,
                        item.message.createdAt);
                final grouped =
                    index > 0 && groupsWith(widget.items[index - 1], item);
                return Column(
                    key: ValueKey(item.message.id),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (start)
                        Padding(
                            padding: const EdgeInsets.all(SwanSpace.lg),
                            child: Text(chatDayLabel(item.message.createdAt),
                                style: SwanType.caption(c.inkMuted))),
                      ChatMessageBubble(
                          key:
                              _keys.putIfAbsent(item.message.id, GlobalKey.new),
                          item: item,
                          grouped: grouped,
                          query: widget.query,
                          selected: item.message.id == _selectedId,
                          onRetry: item.message.status.name == 'failed' &&
                                  widget.onRetry != null
                              ? () => widget.onRetry!(item.message.id)
                              : null),
                    ]);
              }),
        if (_newMessages)
          Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                  padding: const EdgeInsets.all(SwanSpace.md),
                  child: FilledButton.icon(
                      onPressed: () {
                        _navigation++;
                        if (_scroll.hasClients) _scroll.jumpTo(0);
                        setState(() => _newMessages = false);
                      },
                      icon: const Icon(Icons.arrow_downward_rounded),
                      label: const Text('Yeni mesajlar')))),
      ])),
    ]);
  }
}
