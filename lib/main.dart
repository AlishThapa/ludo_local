import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'game/ludo_engine.dart';

void main() => runApp(const LudoApp());

const navy = Color(0xFF15213A);
const panel = Color(0xFF233654);
const cream = Color(0xFFFFFDF5);
const palette = <Color>[
  Color(0xFFEF445A), Color(0xFF318AF7),
  Color(0xFFFFB82E), Color(0xFF25B878),
];
const colorNames = ['Red', 'Blue', 'Yellow', 'Green'];

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'Ludo Local', debugShowCheckedModeBanner: false,
    home: LudoHome(),
  );
}

class LudoHome extends StatefulWidget {
  const LudoHome({super.key});
  @override
  State<LudoHome> createState() => _LudoHomeState();
}

class _LudoHomeState extends State<LudoHome> {
  LudoEngine engine = LudoEngine();
  bool playing = false;
  bool darkMode = false;
  bool music = false;
  bool effects = true;
  bool haptics = true;
  bool rolling = false;
  bool botQueued = false;
  int players = 4;
  int session = 0;
  final bots = <bool>[false, true, true, true];
  final colorIds = <int>[0, 1, 2, 3];
  final AudioPlayer _fx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  int openingRoll = 6;
  int tokensPerPlayer = 4;
  final rules = <String, bool>{
    'Bonus turn on six': true,
    'Bonus turn on capture': true,
    'Bonus turn on finishing a token': false,
    'Exact roll to finish': true,
    'Capture opponent tokens': true,
    'Safe squares': true,
    'Three sixes lose turn': true,
    'Must capture if possible': false,
    'Auto-move when only one option': true,
  };

  List<Color> get colors => [
    for (var i = 0; i < 4; i++) palette[colorIds[i]],
  ];
  Color get active => colors[engine.state.currentPlayer];
  Color get background => darkMode ? navy : const Color(0xFFF2F6FF);
  Color get surface => darkMode ? panel : Colors.white;
  Color get foreground => darkMode ? Colors.white : navy;

  @override
  void dispose() {
    _fx.dispose();
    _music.dispose();
    super.dispose();
  }

  void _sound() {
    if (!effects) return;
    unawaited(_fx.stop().then((_) =>
      _fx.play(AssetSource('audio/dice_roll.wav'), volume: .9))
      .catchError((Object _) {}));
  }

  void _toggleMusic(bool value) {
    setState(() => music = value);
    if (value) {
      unawaited(_music.setReleaseMode(ReleaseMode.loop).then((_) =>
        _music.play(AssetSource('audio/music_loop.wav'), volume: .2))
        .catchError((Object _) {}));
    } else {
      unawaited(_music.stop());
    }
  }

  void _vibrate() {
    if (haptics) unawaited(HapticFeedback.selectionClick());
  }

  void _roll() async {
    if (!playing || rolling || bots[engine.state.currentPlayer] ||
        engine.state.needsMove || engine.state.winner != null) { return; }
    await _performRoll();
  }

  Future<void> _performRoll() async {
    if (rolling || engine.state.needsMove || engine.state.winner != null) return;
    final ticket = session;
    setState(() => rolling = true);
    _sound();
    _vibrate();
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted || !playing || session != ticket) return;
    setState(() {
      rolling = false;
      engine.roll();
    });
    _advance();
  }

  void _move(int token) {
    if (!playing || rolling || bots[engine.state.currentPlayer]) return;
    if (engine.move(token)) {
      _vibrate();
      setState(() {});
      _advance();
    }
  }

  void _advance() {
    if (!playing || engine.state.winner != null || botQueued) return;
    final ticket = session;
    if (engine.state.needsMove && !bots[engine.state.currentPlayer] &&
        engine.rules.autoMoveSingle && engine.movableTokens.length == 1) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted || !playing || session != ticket ||
            engine.state.winner != null || !engine.state.needsMove) { return; }
        _move(engine.movableTokens.first);
      });
      return;
    }
    if (!bots[engine.state.currentPlayer]) return;
    botQueued = true;
    Future<void>.delayed(const Duration(milliseconds: 650), () async {
      botQueued = false;
      if (!mounted || !playing || session != ticket ||
          engine.state.winner != null || !bots[engine.state.currentPlayer]) {
        return;
      }
      if (!engine.state.needsMove) {
        await _performBotRoll();
      } else {
        _botMove();
      }
    });
  }

  Future<void> _performBotRoll() async {
    if (!mounted || !playing || engine.state.winner != null) return;
    final ticket = session;
    setState(() => rolling = true);
    _sound();
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted || !playing || session != ticket) return;
    setState(() {
      rolling = false;
      engine.roll();
    });
    if (engine.state.needsMove && bots[engine.state.currentPlayer]) {
      _advance();
    } else if (engine.state.winner == null) {
      _advance();
    }
  }

  void _botMove() {
    final moves = engine.movableTokens;
    if (moves.isEmpty) return;
    // Prefer reaching home or capturing, then advancing the furthest token.
    moves.sort((a, b) {
      final p = engine.state.currentPlayer;
      final av = engine.state.tokens[p][a];
      final bv = engine.state.tokens[p][b];
      return bv.compareTo(av);
    });
    setState(() => engine.move(moves.first));
    _advance();
  }

  LudoRules _configuredRules() => LudoRules(
    openingRoll: openingRoll,
    tokensPerPlayer: tokensPerPlayer,
    extraTurnOnSix: rules['Bonus turn on six']!,
    extraTurnOnCapture: rules['Bonus turn on capture']!,
    extraTurnOnFinish: rules['Bonus turn on finishing a token']!,
    exactFinish: rules['Exact roll to finish']!,
    captures: rules['Capture opponent tokens']!,
    safeSquares: rules['Safe squares']!,
    threeSixesPenalty: rules['Three sixes lose turn']!,
    mustCapture: rules['Must capture if possible']!,
    autoMoveSingle: rules['Auto-move when only one option']!,
  );

  void _start() {
    session++;
    setState(() {
      engine = LudoEngine(playerCount: players, rules: _configuredRules());
      rolling = false;
      botQueued = false;
      playing = true;
    });
    _advance();
  }

  Future<void> _exit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this game?'),
        content: const Text('Your current match will be lost. Return to the home screen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep playing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave game')),
        ],
      ),
    );
    if (exit == true && mounted) {
      session++;
      setState(() {
        playing = false;
        rolling = false;
        botQueued = false;
      });
    }
  }

  Future<void> _showRules() => showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: const Text('House rules'),
      content: SizedBox(width: 370, child: SingleChildScrollView(child:
        Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Roll to enter')),
            DropdownButton<int>(value: openingRoll,
              items: [1,2,3,4,5,6].map((n) =>
                DropdownMenuItem(value: n, child: Text(n.toString()))).toList(),
              onChanged: (n) { if (n != null) update(() => setState(() => openingRoll = n)); }),
          ]),
          Row(children: [
            const Expanded(child: Text('Tokens per player')),
            DropdownButton<int>(value: tokensPerPlayer,
              items: [1,2,3,4].map((n) =>
                DropdownMenuItem(value: n, child: Text(n.toString()))).toList(),
              onChanged: (n) { if (n != null) update(() => setState(() => tokensPerPlayer = n)); }),
          ]),
          for (final label in rules.keys)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(label, style: const TextStyle(fontSize: 13)),
              value: rules[label]!,
              onChanged: (value) => update(() => setState(() => rules[label] = value)),
            ),
        ]),
      )),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
      ],
    )),
  );

  Future<void> _showSettings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, update) => SafeArea(
      child: Padding(padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('GAME SETTINGS',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
          SwitchListTile(title: const Text('Bright theme'),
            secondary: const Icon(Icons.light_mode_outlined),
            value: !darkMode, onChanged: (v) =>
                update(() => setState(() => darkMode = !v))),
          SwitchListTile(title: const Text('Background music'),
            secondary: const Icon(Icons.music_note_outlined),
            value: music, onChanged: (v) => update(() => _toggleMusic(v))),
          SwitchListTile(title: const Text('Dice & effects sound'),
            secondary: const Icon(Icons.volume_up_outlined),
            value: effects, onChanged: (v) =>
                update(() => setState(() => effects = v))),
          SwitchListTile(title: const Text('Haptic feedback'),
            secondary: const Icon(Icons.vibration_outlined),
            value: haptics, onChanged: (v) =>
                update(() => setState(() => haptics = v))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () { Navigator.pop(ctx); _exit(); },
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Exit match'),
          ),
        ]),
      ),
    )),
  );

  void _chooseColor(int seat, int index) {
    final previous = colorIds.indexOf(index);
    setState(() {
      colorIds[previous] = colorIds[seat];
      colorIds[seat] = index;
    });
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4D79E7),
        brightness: darkMode ? Brightness.dark : Brightness.light),
      scaffoldBackgroundColor: background,
    ),
    child: Builder(builder: (ctx) => Scaffold(
      backgroundColor: background,
      body: SafeArea(child: playing ? _game() : _menu()),
    )),
  );

  Widget _menu() => LayoutBuilder(builder: (context, constraints) =>
    SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🎲 LUDO LOCAL', style: TextStyle(
                  fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: .7)),
                IconButton(
                  tooltip: 'Switch theme',
                  onPressed: () => setState(() => darkMode = !darkMode),
                  icon: Icon(darkMode ? Icons.light_mode : Icons.dark_mode),
                ),
              ]),
            Text('Play together, anywhere · No internet required',
              style: TextStyle(color: foreground.withValues(alpha: .66))),
            const SizedBox(height: 18),
            Card(
              elevation: 0, color: surface,
              child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('PLAYERS', style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                        ButtonSegment(value: 4, label: Text('4')),
                      ],
                      selected: {players},
                      onSelectionChanged: (s) => setState(() => players = s.first),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < players; i++)
                      Padding(padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          CircleAvatar(radius: 14,
                            backgroundColor: colors[i],
                            child: const Icon(Icons.person,
                              size: 16, color: Colors.white)),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Player ${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                          DropdownButton<int>(
                            value: colorIds[i],
                            underline: const SizedBox.shrink(),
                            items: [
                              for (var c = 0; c < 4; c++)
                                DropdownMenuItem(value: c, child:
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(width: 11, height: 11,
                                      decoration: BoxDecoration(
                                        color: palette[c], shape: BoxShape.circle)),
                                    const SizedBox(width: 5),
                                    Text(colorNames[c]),
                                  ])),
                            ],
                            onChanged: (value) {
                              if (value != null) _chooseColor(i, value);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(bots[i] ? 'BOT' : 'HUMAN'),
                            selected: bots[i],
                            onSelected: (selected) =>
                              setState(() => bots[i] = selected),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _showRules,
                      icon: const Icon(Icons.tune_rounded),
                      label: Text('Customize rules (${rules.length + 2} options)'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('START MATCH'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Local multiplayer via Wi-Fi and Bluetooth is planned.',
              textAlign: TextAlign.center,
              style: TextStyle(color: foreground.withValues(alpha: .65),
                fontSize: 12)),
          ],
        ),
      )),
    ),
  );

  Widget _game() {
    final state = engine.state;
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxHeight < 660;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: _exit,
              tooltip: 'Back / leave game',
              icon: const Icon(Icons.arrow_back_ios_new)),
            const Expanded(child: Text('LUDO LOCAL',
              style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w900, letterSpacing: 1))),
            IconButton(onPressed: _showSettings,
              tooltip: 'Game settings',
              icon: const Icon(Icons.settings_rounded)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            for (var p = 0; p < players; p++)
              Expanded(child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: EdgeInsets.symmetric(vertical: narrow ? 6 : 10),
                decoration: BoxDecoration(
                  color: state.currentPlayer == p ?
                      colors[p].withValues(alpha: .2) : surface,
                  border: Border.all(
                    color: state.currentPlayer == p ?
                        colors[p] : Colors.transparent, width: 2),
                  borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Icon(bots[p] ? Icons.smart_toy_outlined : Icons.person,
                    size: 16, color: colors[p]),
                  Text(bots[p] ? 'Bot ${p + 1}' :
                    'P${p + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 11)),
                  Text('${state.tokens[p].take(engine.rules.tokensPerPlayer).where((v) => v == 56).length}/${engine.rules.tokensPerPlayer}',
                    style: TextStyle(fontSize: 10,
                      color: foreground.withValues(alpha: .6))),
                ]),
              )),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: active.withValues(alpha: .25),
                blurRadius: 18, spreadRadius: 1)]),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth - 8,
                maxHeight: math.min(constraints.maxWidth - 8,
                  constraints.maxHeight * .58)),
              child: AspectRatio(aspectRatio: 1,
                child: RepaintBoundary(
                  child: LayoutBuilder(builder: (_, bounds) =>
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (tap) {
                        if (bots[engine.state.currentPlayer]) return;
                        final token = LudoBoard.hit(engine,
                          tap.localPosition, bounds.maxWidth);
                        if (token != null) _move(token);
                      },
                      child: CustomPaint(
                        painter: LudoBoard(engine, colors,
                          engine.state.currentPlayer),
                        size: Size.square(bounds.maxWidth)),
                    )),
                )),
            ),
          ),
          const Spacer(),
          Text(state.message, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: foreground)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Container(
                key: ValueKey(rolling ? 'rolling' :
                  '${state.lastRoll ?? 0}-${state.turnNumber}'),
                alignment: Alignment.center,
                height: 60, width: 60,
                decoration: BoxDecoration(
                  color: surface, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .1),
                    blurRadius: 8)]),
                child: Text(rolling ? '🎲' :
                  (state.lastRoll?.toString() ?? '⚄'),
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                    color: foreground)),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: active,
                foregroundColor: Colors.white,
                minimumSize: const Size(154, 56)),
              onPressed: !rolling && !bots[state.currentPlayer] &&
                !state.needsMove && state.winner == null ? _roll : null,
              icon: const Icon(Icons.casino_rounded),
              label: Text(rolling ? 'ROLLING...' :
                state.winner != null ? 'FINISHED' :
                bots[state.currentPlayer] ? 'BOT TURN' :
                state.needsMove ? 'MOVE TOKEN' : 'ROLL DICE',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Tap a glowing token to move · Settings ⚙ at top',
            style: TextStyle(fontSize: 11,
              color: foreground.withValues(alpha: .6))),
          SizedBox(height: narrow ? 2 : 10),
        ]),
      );
    });
  }
}

class LudoBoard extends CustomPainter {
  LudoBoard(this.engine, this.colors, this.activeSeat);
  final LudoEngine engine;
  final List<Color> colors;
  final int activeSeat;

  static const route = <(int, int)>[
    (6,13),(6,12),(6,11),(6,10),(6,9),(5,8),(4,8),(3,8),(2,8),
    (1,8),(0,8),(0,7),(0,6),(1,6),(2,6),(3,6),(4,6),(5,6),
    (6,5),(6,4),(6,3),(6,2),(6,1),(6,0),(7,0),(8,0),(8,1),
    (8,2),(8,3),(8,4),(8,5),(9,6),(10,6),(11,6),(12,6),
    (13,6),(14,6),(14,7),(14,8),(13,8),(12,8),(11,8),
    (10,8),(9,8),(8,9),(8,10),(8,11),(8,12),(8,13),(8,14),
    (7,14),(6,14),
  ];
  static const homes = [
    (2.5,12.5),(2.5,2.5),(12.5,2.5),(12.5,12.5),
  ];

  static Offset position(int player, int progress, int token, double side) {
    final cell = side / 15;
    if (progress == -1) {
      final home = homes[player];
      return Offset(
          (home.$1 + (token.isEven ? -.85 : .85)) * cell,
          (home.$2 + (token < 2 ? -.85 : .85)) * cell);
    }
    if (progress == 56) return Offset(7.5 * cell, 7.5 * cell);
    if (progress >= 51) {
      final step = progress - 50;
      const lanes = [(7,13),(1,7),(7,1),(13,7)];
      final lane = lanes[player];
      final x = player == 0 || player == 2
          ? 7.0 : lane.$1 + (player == 1 ? step : -step);
      final y = player == 1 || player == 3
          ? 7.0 : lane.$2 + (player == 0 ? -step : step);
      return Offset((x + .5) * cell, (y + .5) * cell);
    }
    final tile = route[(LudoEngine.starts[player] + progress) % 52];
    return Offset((tile.$1 + .5) * cell, (tile.$2 + .5) * cell);
  }

  static int? hit(LudoEngine game, Offset tap, double side) {
    final player = game.state.currentPlayer;
    for (final index in game.movableTokens.reversed) {
      if ((tap - position(player, game.state.tokens[player][index],
          index, side)).distance <= side / 19) { return index; }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final unit = side / 15;
    final border = Paint()
      ..color = const Color(0xFFCED8E3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, side, side),
          const Radius.circular(10)),
      Paint()..color = cream,
    );
    final homeRects = [
      Rect.fromLTWH(0,unit*9,unit*6,unit*6),
      Rect.fromLTWH(0,0,unit*6,unit*6),
      Rect.fromLTWH(unit*9,0,unit*6,unit*6),
      Rect.fromLTWH(unit*9,unit*9,unit*6,unit*6),
    ];
    for (var p = 0; p < 4; p++) {
      if (p == activeSeat) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(homeRects[p].inflate(unit * .12),
            Radius.circular(unit * .5)),
          Paint()
            ..color = colors[p].withValues(alpha: .88)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .56),
        );
      }
      canvas.drawRect(homeRects[p], Paint()..color = colors[p]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(homeRects[p].deflate(unit*.8),
            Radius.circular(unit*.3)),
        Paint()..color = cream,
      );
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(position(p,-1,i,side),unit*.57,
            Paint()..color = colors[p].withValues(alpha: .22));
      }
    }
    for (final tile in route) {
      final rect = Rect.fromLTWH(tile.$1*unit,tile.$2*unit,unit,unit);
      canvas.drawRect(rect, Paint()..color = Colors.white);
      canvas.drawRect(rect,border);
    }
    for (var p = 0; p < 4; p++) {
      final tile = route[LudoEngine.starts[p]];
      canvas.drawRect(
        Rect.fromLTWH(tile.$1*unit,tile.$2*unit,unit,unit),
        Paint()..color = colors[p],
      );
    }
    for (var n = 1; n <= 5; n++) {
      final tiles = [(7,14-n),(n,7),(7,n),(14-n,7)];
      for (var p = 0; p < 4; p++) {
        final tile = tiles[p];
        final rect = Rect.fromLTWH(tile.$1*unit,tile.$2*unit,unit,unit);
        canvas.drawRect(rect,
            Paint()..color = colors[p].withValues(alpha: .85));
        canvas.drawRect(rect,border);
      }
    }
    final center = Rect.fromLTWH(unit*6,unit*6,unit*3,unit*3);
    canvas.drawRect(center,Paint()..color = panel);
    final star = TextPainter(
      text: const TextSpan(text: '★',
          style: TextStyle(fontSize: 28,color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    star.paint(canvas,center.center - Offset(star.width/2,star.height/2));
    for (var p = 0; p < engine.playerCount; p++) {
      for (var i = 0; i < engine.rules.tokensPerPlayer; i++) {
        final center = position(p,engine.state.tokens[p][i],i,side);
        final movable = p == engine.state.currentPlayer &&
            engine.movableTokens.contains(i);
        final radius = unit*.39;
        if (movable) { canvas.drawCircle(center,radius*1.5,
            Paint()..color = colors[p].withValues(alpha: .35)); }
        canvas.drawCircle(center+const Offset(0,1.2),radius+1,
            Paint()..color = Colors.black26);
        canvas.drawCircle(center,radius,Paint()..color = colors[p]);
        canvas.drawCircle(center,radius*.54,
            Paint()..color = Colors.white.withValues(alpha: .8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant LudoBoard oldDelegate) => true;
}
