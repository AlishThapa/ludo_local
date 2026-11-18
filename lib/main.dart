import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game/ludo_engine.dart';

void main() => runApp(const LudoApp());

const navy = Color(0xFF10182B);
const panel = Color(0xFF1B2942);
const cream = Color(0xFFF6F3E9);
const palette = [
  Color(0xFFF05C62),
  Color(0xFF46A6FF),
  Color(0xFFFFC75E),
  Color(0xFF53D6A4),
];

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ludo Local',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: navy,
          colorScheme: ColorScheme.fromSeed(
              seedColor: palette[1], brightness: Brightness.dark),
        ),
        home: const LudoHome(),
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
  int players = 4;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: playing ? _game() : _menu(),
          ),
        ),
      );

  Widget _menu() => Column(
        children: [
          const Spacer(),
          Icon(Icons.casino_rounded, color: palette[2], size: 72),
          const SizedBox(height: 14),
          const Text('LUDO LOCAL',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                  letterSpacing: 1.6)),
          const SizedBox(height: 8),
          const Text('Offline by design. Made to play together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 42),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: panel,
                borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('PASS & PLAY',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Play on one device. Nearby multiplayer is coming.',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 22),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 3, label: Text('3')),
                    ButtonSegment(value: 4, label: Text('4')),
                  ],
                  selected: {players},
                  onSelectionChanged: (values) =>
                      setState(() => players = values.first),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Game'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54)),
                  onPressed: () => setState(() {
                    engine = LudoEngine(playerCount: players);
                    playing = true;
                  }),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text('NO ACCOUNT · NO INTERNET',
              style: TextStyle(color: Colors.white54, letterSpacing: 1.2)),
          const SizedBox(height: 16),
        ],
      );

  Widget _game() {
    final state = engine.state;
    return Column(
      children: [
        Row(children: [
          IconButton(
            tooltip: 'Back to menu',
            onPressed: () => setState(() => playing = false),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          const Expanded(child: Text('LUDO LOCAL',
              style: TextStyle(fontWeight: FontWeight.w900,
                  letterSpacing: 1.3, fontSize: 18))),
          IconButton(
            tooltip: 'Restart game',
            onPressed: () => setState(engine.reset),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < players; i++)
            Expanded(child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: state.currentPlayer == i
                    ? palette[i].withValues(alpha: .2) : panel,
                border: Border.all(
                    color: state.currentPlayer == i
                        ? palette[i] : Colors.transparent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                CircleAvatar(radius: 8, backgroundColor: palette[i]),
                const SizedBox(height: 5),
                Text('P${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${state.tokens[i].where((v) => v == 56).length}/4',
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ]),
            )),
        ]),
        const Spacer(),
        AspectRatio(
          aspectRatio: 1,
          child: RepaintBoundary(
            child: LayoutBuilder(builder: (context, constraints) {
              final side = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (tap) {
                  final index = LudoBoard.hit(engine, tap.localPosition, side);
                  if (index != null) setState(() => engine.move(index));
                },
                child: CustomPaint(painter: LudoBoard(engine),
                    size: Size.square(side)),
              );
            }),
          ),
        ),
        const Spacer(),
        Text(state.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 62, height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cream,
                borderRadius: BorderRadius.circular(14)),
            child: Text(state.dice == null ? '⚄' : '${state.dice}',
                style: const TextStyle(color: navy, fontSize: 36,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 15),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(146, 58),
              foregroundColor: navy,
              backgroundColor: palette[state.currentPlayer],
            ),
            onPressed: state.needsMove || state.winner != null
                ? null : () => setState(engine.roll),
            child: Text(state.winner == null ? 'ROLL DICE' : 'GAME OVER',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('Tap a highlighted token to move',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class LudoBoard extends CustomPainter {
  LudoBoard(this.engine);
  final LudoEngine engine;

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
      canvas.drawRect(homeRects[p], Paint()..color = palette[p]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(homeRects[p].deflate(unit*.8),
            Radius.circular(unit*.3)),
        Paint()..color = cream,
      );
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(position(p,-1,i,side),unit*.57,
            Paint()..color = palette[p].withValues(alpha: .22));
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
        Paint()..color = palette[p],
      );
    }
    for (var n = 1; n <= 5; n++) {
      final tiles = [(7,14-n),(n,7),(7,n),(14-n,7)];
      for (var p = 0; p < 4; p++) {
        final tile = tiles[p];
        final rect = Rect.fromLTWH(tile.$1*unit,tile.$2*unit,unit,unit);
        canvas.drawRect(rect,
            Paint()..color = palette[p].withValues(alpha: .85));
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
      for (var i = 0; i < 4; i++) {
        final center = position(p,engine.state.tokens[p][i],i,side);
        final movable = p == engine.state.currentPlayer &&
            engine.movableTokens.contains(i);
        final radius = unit*.39;
        if (movable) { canvas.drawCircle(center,radius*1.5,
            Paint()..color = palette[p].withValues(alpha: .35)); }
        canvas.drawCircle(center+const Offset(0,1.2),radius+1,
            Paint()..color = Colors.black26);
        canvas.drawCircle(center,radius,Paint()..color = palette[p]);
        canvas.drawCircle(center,radius*.54,
            Paint()..color = Colors.white.withValues(alpha: .8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant LudoBoard oldDelegate) => true;
}
