import 'dart:math';

/// Immutable snapshots are the source of truth, making network synchronization
/// possible later without coupling game rules to a transport.
class LudoState {
  final List<List<int>> tokens; // -1 at home, 0..50 track, 51..56 finish lane.
  final int currentPlayer;
  final int? dice;
  final bool needsMove;
  final int? winner;
  final int turnNumber;
  final String message;

  const LudoState({
    required this.tokens,
    required this.currentPlayer,
    required this.dice,
    required this.needsMove,
    required this.winner,
    required this.turnNumber,
    required this.message,
  });
}

class LudoEngine {
  LudoEngine({this.playerCount = 4, Random? random})
      : assert(playerCount >= 2 && playerCount <= 4),
        _random = random ?? Random.secure() {
    reset();
  }

  final int playerCount;
  final Random _random;
  late LudoState state;
  static const List<int> starts = [0, 13, 26, 39];
  static const Set<int> safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

  void reset() {
    state = LudoState(
      tokens: List.generate(playerCount, (_) => List.filled(4, -1)),
      currentPlayer: 0,
      dice: null,
      needsMove: false,
      winner: null,
      turnNumber: 0,
      message: 'Player 1: roll the dice',
    );
  }

  int boardPosition(int player, int progress) =>
      (starts[player] + progress) % 52;

  List<int> get movableTokens {
    if (!state.needsMove || state.dice == null || state.winner != null) {
      return const [];
    }
    final dice = state.dice!;
    final tokens = state.tokens[state.currentPlayer];
    return [
      for (var i = 0; i < tokens.length; i++)
        if ((tokens[i] == -1 && dice == 6) ||
            (tokens[i] >= 0 && tokens[i] < 56 && tokens[i] + dice <= 56))
          i,
    ];
  }

  bool roll({int? forcedValue}) {
    if (state.needsMove || state.winner != null) return false;
    if (forcedValue != null && (forcedValue < 1 || forcedValue > 6)) {
      throw ArgumentError.value(forcedValue, 'forcedValue', 'Must be 1..6');
    }
    final dice = forcedValue ?? _random.nextInt(6) + 1;
    state = _copy(dice: dice, needsMove: true, message: 'Tap a highlighted token');
    if (movableTokens.isEmpty) {
      _nextTurn(message: 'No legal moves — next player');
    }
    return true;
  }

  bool move(int tokenIndex) {
    if (!movableTokens.contains(tokenIndex)) return false;
    final player = state.currentPlayer;
    final dice = state.dice!;
    final updated = [for (final row in state.tokens) [...row]];
    final previous = updated[player][tokenIndex];
    final next = previous == -1 ? 0 : previous + dice;
    updated[player][tokenIndex] = next;
    var captured = false;

    if (next <= 50) {
      final landing = boardPosition(player, next);
      if (!safeSquares.contains(landing)) {
        for (var opponent = 0; opponent < playerCount; opponent++) {
          if (opponent == player) continue;
          for (var token = 0; token < 4; token++) {
            final progress = updated[opponent][token];
            if (progress >= 0 && progress <= 50 &&
                boardPosition(opponent, progress) == landing) {
              updated[opponent][token] = -1;
              captured = true;
            }
          }
        }
      }
    }
    final won = updated[player].every((progress) => progress == 56);
    state = _copy(
      tokens: updated,
      needsMove: false,
      dice: null,
      winner: won ? player : null,
      message: won ? 'Player ${player + 1} wins!' : 'Move complete',
    );
    if (!won) {
      if (dice == 6 || captured) {
        state = _copy(message: 'Player ${player + 1}: bonus roll!');
      } else {
        _nextTurn(message: 'Next player');
      }
    }
    return true;
  }

  void _nextTurn({required String message}) {
    final next = (state.currentPlayer + 1) % playerCount;
    state = _copy(
      currentPlayer: next,
      dice: null,
      needsMove: false,
      turnNumber: state.turnNumber + 1,
      message: '$message · Player ${next + 1} to roll',
    );
  }

  LudoState _copy({
    List<List<int>>? tokens,
    int? currentPlayer,
    int? dice,
    bool? needsMove,
    int? winner,
    int? turnNumber,
    String? message,
  }) => LudoState(
        tokens: tokens ?? state.tokens,
        currentPlayer: currentPlayer ?? state.currentPlayer,
        dice: dice,
        needsMove: needsMove ?? state.needsMove,
        winner: winner ?? state.winner,
        turnNumber: turnNumber ?? state.turnNumber,
        message: message ?? state.message,
      );
}
