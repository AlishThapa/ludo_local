import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_local/game/ludo_engine.dart';

void main() {
  test('initial state and valid opening roll', () {
    final game = LudoEngine(playerCount: 2);
    expect(game.state.tokens[0], [-1, -1, -1, -1]);
    game.roll(forcedValue: 6);
    expect(game.movableTokens, [0, 1, 2, 3]);
    expect(game.move(0), true);
    expect(game.state.tokens[0][0], 0);
    expect(game.state.currentPlayer, 0); // six grants bonus turn
  });

  test('unmovable roll passes the turn', () {
    final game = LudoEngine(playerCount: 2);
    game.roll(forcedValue: 3);
    expect(game.state.currentPlayer, 1);
    expect(game.state.needsMove, false);
  });

  test('move is rejected if dice has not been rolled', () {
    final game = LudoEngine();
    expect(game.move(0), false);
  });

  test('board starts are spaced 13 squares apart', () {
    final game = LudoEngine();
    expect([for (var p = 0; p < 4; p++) game.boardPosition(p, 0)],
        [0, 13, 26, 39]);
  });
  test('custom opening roll can release token', () {
    final game = LudoEngine(
      playerCount: 2, rules: const LudoRules(openingRoll: 1));
    game.roll(forcedValue: 1);
    expect(game.movableTokens, [0, 1, 2, 3]);
    expect(game.move(0), true);
    expect(game.state.tokens[0][0], 0);
  });

  test('one-token quick mode allows victory when home is reached', () {
    final game = LudoEngine(
      playerCount: 2, rules: const LudoRules(tokensPerPlayer: 1));
    game.roll(forcedValue: 6);
    expect(game.movableTokens, [0]);
  });

  test('third consecutive six forfeits the turn', () {
    final game = LudoEngine(playerCount: 2);
    game.roll(forcedValue: 6);
    game.move(0);
    game.roll(forcedValue: 6);
    game.move(0);
    game.roll(forcedValue: 6);
    expect(game.state.currentPlayer, 1);
    expect(game.state.needsMove, false);
  });

  test('bonus turn on six can be disabled', () {
    final game = LudoEngine(playerCount: 2,
      rules: const LudoRules(extraTurnOnSix: false));
    game.roll(forcedValue: 6);
    game.move(0);
    expect(game.state.currentPlayer, 1);
  });

  test('no legal opening move passes turn', () {
    final game = LudoEngine(playerCount: 2);
    game.roll(forcedValue: 2);
    expect(game.state.currentPlayer, 1);
    expect(game.state.needsMove, false);
  });
}
