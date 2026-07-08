class ReplayControl {
  var running = false;
  var paused = false;
  var resetRequested = false;

  bool get canAdvance => running && !paused;

  void start() {
    running = true;
    paused = false;
    resetRequested = false;
  }

  void pause() {
    if (running) {
      paused = true;
    }
  }

  void resume() {
    if (running) {
      paused = false;
    }
  }

  void reset() {
    running = false;
    paused = false;
    resetRequested = false;
  }

  void requestReset() {
    running = false;
    paused = false;
    resetRequested = true;
  }
}
