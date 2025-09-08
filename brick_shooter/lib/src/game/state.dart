enum GameState { menu, playing, gameOver }

class ScoreState {
  int score = 0;
  int best = 0;

  void reset() => score = 0;

  void add(int v) => score += v;
}
