enum GamePhase {
  menu,
  tutorialDrop, // rows fall to red line
  tutorialHold, // paused at red line; show hint; wait for correct tap
  playing,
  paused, // Spillet er pauset
  gameOver,
}

class ScoreState {
  int score = 0;
  int best = 0;
  bool newBest = false;
  int podiumPlace = 0;

  void reset() {
    score = 0;
    newBest = false;
    podiumPlace = 0;
  }

  void add(int v) => score += v;
}
