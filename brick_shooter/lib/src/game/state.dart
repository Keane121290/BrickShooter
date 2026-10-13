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

  void reset() {
    score = 0;
    newBest = false;
  }

  void add(int v) => score += v;
}
