import 'dart:math';

/// Optional house rules. Defaults preserve familiar classic Ludo behavior.
class LudoRules {
  const LudoRules({
    this.openingRoll = 6,
    this.extraTurnOnSix = true,
    this.extraTurnOnCapture = true,
    this.extraTurnOnFinish = false,
    this.exactFinish = true,
    this.captures = true,
    this.safeSquares = true,
    this.threeSixesPenalty = true,
    this.mustCapture = false,
    this.autoMoveSingle = true,
    this.tokensPerPlayer = 4,
  }) : assert(openingRoll >= 1 && openingRoll <= 6),
       assert(tokensPerPlayer >= 1 && tokensPerPlayer <= 4);

  final int openingRoll;
  final bool extraTurnOnSix;
  final bool extraTurnOnCapture;
  final bool extraTurnOnFinish;
  final bool exactFinish;
  final bool captures;
  final bool safeSquares;
  final bool threeSixesPenalty;
  final bool mustCapture;
  final bool autoMoveSingle;
  final int tokensPerPlayer;
}

class LudoState {
  final List<List<int>> tokens;
  final int currentPlayer;
  final int? dice;
  final int? lastRoll;
  final bool needsMove;
  final int? winner;
  final int turnNumber;
  final int consecutiveSixes;
  final String message;

  const LudoState({
    required this.tokens,
    required this.currentPlayer,
    required this.dice,
    required this.lastRoll,
    required this.needsMove,
    required this.winner,
    required this.turnNumber,
    required this.consecutiveSixes,
    required this.message,
  });
}

class LudoEngine {
  LudoEngine({this.playerCount = 4, this.rules = const LudoRules(), Random? random})
      : assert(playerCount >= 2 && playerCount <= 4),
        _random = random ?? Random.secure() {
    reset();
  }

  final int playerCount;
  final LudoRules rules;
  final Random _random;
  late LudoState state;

  static const starts = [0, 13, 26, 39];
  static const safeSquares = <int>{0, 8, 13, 21, 26, 34, 39, 47};

  void reset() {
    state = LudoState(
      tokens: List.generate(playerCount, (_) => List.filled(4, -1)),
      currentPlayer: 0,
      dice: null,
      lastRoll: null,
      needsMove: false,
      winner: null,
      turnNumber: 0,
      consecutiveSixes: 0,
      message: 'Player 1 · Roll the dice',
    );
  }

  int boardPosition(int player, int progress) =>
      (starts[player] + progress) % 52;

  bool _canMove(int progress, int dice) {
    if (progress == 56) return false;
    if (progress == -1) return dice == rules.openingRoll;
    return !rules.exactFinish || progress + dice <= 56;
  }

  List<int> get movableTokens {
    if (!state.needsMove || state.dice == null || state.winner != null) {
      return const [];
    }
    final candidates = <int>[];
    final dice = state.dice!;
    for (var i = 0; i < rules.tokensPerPlayer; i++) {
      if (_canMove(state.tokens[state.currentPlayer][i], dice)) {
        candidates.add(i);
      }
    }
    if (rules.mustCapture && candidates.any(_wouldCapture)) {
      return candidates.where(_wouldCapture).toList();
    }
    return candidates;
  }

  bool _wouldCapture(int index) {
    final old = state.tokens[state.currentPlayer][index];
    final next = old == -1 ? 0 : min(56, old + state.dice!);
    if (!rules.captures || next > 50) return false;
    final landing = boardPosition(state.currentPlayer, next);
    if (rules.safeSquares && safeSquares.contains(landing)) return false;
    for (var p = 0; p < playerCount; p++) {
      if (p == state.currentPlayer) continue;
      for (final progress in state.tokens[p].take(rules.tokensPerPlayer)) {
        if (progress >= 0 && progress <= 50 &&
            boardPosition(p, progress) == landing) {
          return true;
        }
      }
    }
    return false;
  }

  bool roll({int? forcedValue}) {
    if (state.needsMove || state.winner != null) return false;
    if (forcedValue != null && (forcedValue < 1 || forcedValue > 6)) {
      throw ArgumentError.value(forcedValue, 'forcedValue', 'Must be 1..6');
    }
    final dice = forcedValue ?? _random.nextInt(6) + 1;
    final sixes = dice == 6 ? state.consecutiveSixes + 1 : 0;
    state = _copy(
      dice: dice, lastRoll: dice, consecutiveSixes: sixes, needsMove: true,
      message: 'Rolled $dice · Pick a token',
    );
    if (rules.threeSixesPenalty && sixes >= 3) {
      _nextTurn(message: 'Three sixes · Turn forfeited');
      return true;
    }
    if (movableTokens.isEmpty) {
      if (dice == 6 && rules.extraTurnOnSix) {
        state = _copy(dice: null, needsMove: false,
            message: 'No move · Roll again');
      } else {
        _nextTurn(message: 'No valid moves');
      }
    }
    return true;
  }

  bool move(int tokenIndex) {
    if (!movableTokens.contains(tokenIndex)) return false;
    final player = state.currentPlayer;
    final dice = state.dice!;
    final updated = [for (final row in state.tokens) [...row]];
    final before = updated[player][tokenIndex];
    final next = before == -1 ? 0 : min(56, before + dice);
    updated[player][tokenIndex] = next;
    var captured = false;
    if (rules.captures && next <= 50) {
      final landing = boardPosition(player, next);
      if (!rules.safeSquares || !safeSquares.contains(landing)) {
        for (var opponent = 0; opponent < playerCount; opponent++) {
          if (opponent == player) continue;
          for (var token = 0; token < rules.tokensPerPlayer; token++) {
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
    final finished = next == 56;
    final won = updated[player].take(rules.tokensPerPlayer)
        .every((progress) => progress == 56);
    state = _copy(tokens: updated, dice: null, needsMove: false,
        winner: won ? player : null,
        message: won ? 'Player ${player + 1} wins!' : 'Token moved');
    if (!won) {
      if ((dice == 6 && rules.extraTurnOnSix) ||
          (captured && rules.extraTurnOnCapture) ||
          (finished && rules.extraTurnOnFinish)) {
        state = _copy(message: 'Bonus turn · Roll again');
      } else {
        _nextTurn(message: 'Next player');
      }
    }
    return true;
  }

  void _nextTurn({required String message}) {
    final next = (state.currentPlayer + 1) % playerCount;
    state = _copy(currentPlayer: next, dice: null, needsMove: false,
        consecutiveSixes: 0, turnNumber: state.turnNumber + 1,
        message: '$message · Player ${next + 1} to roll');
  }

  LudoState _copy({
    List<List<int>>? tokens,
    int? currentPlayer,
    int? dice,
    int? lastRoll,
    bool? needsMove,
    int? winner,
    int? turnNumber,
    int? consecutiveSixes,
    String? message,
  }) => LudoState(
    tokens: tokens ?? state.tokens,
    currentPlayer: currentPlayer ?? state.currentPlayer,
    dice: dice,
    lastRoll: lastRoll ?? state.lastRoll,
    needsMove: needsMove ?? state.needsMove,
    winner: winner ?? state.winner,
    turnNumber: turnNumber ?? state.turnNumber,
    consecutiveSixes: consecutiveSixes ?? state.consecutiveSixes,
    message: message ?? state.message,
  );
}
