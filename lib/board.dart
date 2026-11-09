import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'constants.dart';
import 'pixel.dart';

/// Widget principal del tablero de juego de Tetris
class GameBoard extends StatefulWidget {
  final bool isSoundOn;
  const GameBoard({super.key, required this.isSoundOn});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  List<List<Tetrimino?>> gameGrid = List.generate(
    rowLength,
    (index) => List.generate(colLength, (index) => null),
  );

  List<List<bool>> fadingGrid = List.generate(
    rowLength,
    (index) => List.generate(colLength, (index) => false),
  );

  Tetrimino currentPiece = Tetrimino.I;
  List<int> currentPosition = [];
  int rotationState = 0;

  int score = 0;
  bool isGameOver = false;
  bool isPaused = false;
  bool isAnimating = false;

  Timer? gameTimer;
  Timer? gravityTimer;

  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _videoController = VideoPlayerController.asset('assets/fondo.mp4')
      ..initialize()
          .then((_) {
            setState(() {
              _isVideoInitialized = true;
            });
            _videoController.setLooping(true);
            _videoController.setVolume(0.0);
            if (!isPaused && !isGameOver) {
              _videoController.play();
            }
          })
          .catchError((_) {});

    startGame();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    gravityTimer?.cancel();
    _videoController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void startGame() async {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}

    setState(() {
      gameGrid = List.generate(
        rowLength,
        (index) => List.generate(colLength, (index) => null),
      );
      fadingGrid = List.generate(
        rowLength,
        (index) => List.generate(colLength, (index) => false),
      );

      isGameOver = false;
      isPaused = false;
      isAnimating = false;
      score = 0;

      spawnPiece();
    });

    if (_isVideoInitialized) {
      _videoController.seekTo(Duration.zero);
      _videoController.play();
    }

    if (widget.isSoundOn) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('musica_fondo.mp3'));
        _audioPlayer.setReleaseMode(ReleaseMode.loop);
      } catch (_) {}
    }

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (isGameOver) {
        timer.cancel();
        return;
      }
      if (isPaused) return;
      setState(() {});
    });

    // CAMBIO: se llama sin parámetros → usa velocidad normal por defecto
    resetGravityTimer();
  }

  // CAMBIO: se agrega el parámetro opcional [fast] para controlar la velocidad
  // del timer de gravedad. Si fast=true usa 80ms (caída rápida),
  // si fast=false (valor por defecto) usa 600ms (velocidad normal).
  void resetGravityTimer({bool fast = false}) {
    gravityTimer?.cancel();

    // CAMBIO: duración condicional según si se está en modo caída rápida o no
    final duration = fast
        ? const Duration(milliseconds: 80)   // velocidad acelerada (botón mantenido)
        : const Duration(milliseconds: 600); // velocidad normal

    gravityTimer = Timer.periodic(duration, (timer) {
      if (isGameOver) {
        timer.cancel();
        return;
      }
      if (isPaused || isAnimating) return;
      moveDown();
    });
  }

  // CAMBIO: nuevo método que activa la caída rápida al mantener presionado el botón.
  // Llama a resetGravityTimer con fast=true para reducir el intervalo a 80ms.
  void startFastDrop() {
    if (isPaused || isAnimating || isGameOver) return;
    resetGravityTimer(fast: true);
  }

  // CAMBIO: nuevo método que restaura la velocidad normal al soltar el botón.
  // Llama a resetGravityTimer con fast=false (600ms).
  void stopFastDrop() {
    resetGravityTimer(fast: false);
  }

  void togglePause() {
    if (isGameOver || isAnimating) return;

    setState(() {
      isPaused = !isPaused;
      if (isPaused) {
        _videoController.pause();
        _audioPlayer.pause();
      } else {
        _videoController.play();
        if (widget.isSoundOn) _audioPlayer.resume();
      }
    });
  }

  Future<void> _saveScore(int finalScore) async {
    final prefs = await SharedPreferences.getInstance();
    // Guardamos solo los 5 mejores puntajes, de mayor a menor
    final scores = (prefs.getStringList('high_scores') ?? [])
        .map((s) => int.tryParse(s) ?? 0)
        .toList()
      ..add(finalScore)
      ..sort((a, b) => b.compareTo(a));
    await prefs.setStringList(
      'high_scores',
      scores.take(5).map((s) => s.toString()).toList(),
    );
  }

  void spawnPiece() {
    if (isGameOver) return;

    final random = Random();
    currentPiece = Tetrimino.values[random.nextInt(Tetrimino.values.length)];
    rotationState = 0;

    switch (currentPiece) {
      case Tetrimino.I:
        currentPosition = [4, 14, 24, 34];
        break;
      case Tetrimino.O:
        currentPosition = [4, 5, 14, 15];
        break;
      case Tetrimino.T:
        currentPosition = [14, 4, 13, 15];
        break;
      case Tetrimino.L:
        currentPosition = [4, 14, 24, 25];
        break;
      case Tetrimino.J:
        currentPosition = [5, 15, 25, 24];
        break;
      case Tetrimino.S:
        currentPosition = [13, 14, 4, 5];
        break;
      case Tetrimino.Z:
        currentPosition = [3, 4, 14, 15];
        break;
    }

    if (checkGameOver()) {
      setState(() {
        isGameOver = true;
        gameTimer?.cancel();
        gravityTimer?.cancel();
        _videoController.pause();
        _audioPlayer.stop();
      });
      _saveScore(score);
    }
  }

  void moveDown() {
    if (isPaused || isAnimating || isGameOver) return;

    if (!checkCollision(1, currentPosition)) {
      setState(() {
        for (int i = 0; i < currentPosition.length; i++) {
          currentPosition[i] += colLength;
        }
      });
    } else {
      fixPiece();
    }
  }

  void moveLeft() {
    if (isPaused || isAnimating || isGameOver) return;
    if (!checkCollision(-1, currentPosition)) {
      setState(() {
        for (int i = 0; i < currentPosition.length; i++) {
          currentPosition[i] -= 1;
        }
      });
    }
  }

  void moveRight() {
    if (isPaused || isAnimating || isGameOver) return;
    if (!checkCollision(2, currentPosition)) {
      setState(() {
        for (int i = 0; i < currentPosition.length; i++) {
          currentPosition[i] += 1;
        }
      });
    }
  }

  void rotatePiece() {
    if (isPaused || isAnimating || isGameOver || currentPiece == Tetrimino.O) {
      return;
    }

    int pivot = currentPosition[1];
    int pivotRow = (pivot / colLength).floor();
    int pivotCol = pivot % colLength;

    List<int> rotatedRows = [];
    List<int> rotatedCols = [];

    for (int i = 0; i < currentPosition.length; i++) {
      int r = (currentPosition[i] / colLength).floor();
      int c = currentPosition[i] % colLength;
      int relativeRow = r - pivotRow;
      int relativeCol = c - pivotCol;
      int nextRow = pivotRow + relativeCol;
      int nextCol = pivotCol - relativeRow;
      rotatedRows.add(nextRow);
      rotatedCols.add(nextCol);
    }

    int minCol = rotatedCols.reduce(min);
    int maxCol = rotatedCols.reduce(max);
    int maxRow = rotatedRows.reduce(max);

    int pushX = 0;
    int pushY = 0;

    if (minCol < 0) {
      pushX = -minCol;
    } else if (maxCol >= colLength) {
      pushX = (colLength - 1) - maxCol;
    }
    if (maxRow >= rowLength) pushY = (rowLength - 1) - maxRow;

    List<int> finalCandidatePosition = [];
    bool isPositionValid = true;

    for (int i = 0; i < currentPosition.length; i++) {
      int correctedRow = rotatedRows[i] + pushY;
      int correctedCol = rotatedCols[i] + pushX;

      if (correctedRow < 0 ||
          correctedRow >= rowLength ||
          correctedCol < 0 ||
          correctedCol >= colLength) {
        isPositionValid = false;
        break;
      }
      if (gameGrid[correctedRow][correctedCol] != null) {
        isPositionValid = false;
        break;
      }
      finalCandidatePosition.add(correctedRow * colLength + correctedCol);
    }

    if (isPositionValid) {
      setState(() {
        currentPosition = finalCandidatePosition;
        rotationState = (rotationState + 1) % 4;
      });
    }
  }

  bool checkCollision(int direction, List<int> positionToCheck) {
    for (int i = 0; i < positionToCheck.length; i++) {
      int row = (positionToCheck[i] / colLength).floor();
      int col = positionToCheck[i] % colLength;

      if (direction == 1) row++;
      if (direction == -1) col--;
      if (direction == 2) col++;

      if (row >= rowLength || col < 0 || col >= colLength) return true;
      if (row >= 0 && gameGrid[row][col] != null) return true;
    }
    return false;
  }

  void fixPiece() {
    if (isGameOver) return;

    setState(() {
      for (int i = 0; i < currentPosition.length; i++) {
        int row = (currentPosition[i] / colLength).floor();
        int col = currentPosition[i] % colLength;
        if (row >= 0) {
          gameGrid[row][col] = currentPiece;
        }
      }
      checkAndClearLines();
    });
  }

  void checkAndClearLines() {
    List<int> linesToClear = [];

    for (int row = rowLength - 1; row >= 0; row--) {
      bool rowFull = true;
      for (int col = 0; col < colLength; col++) {
        if (gameGrid[row][col] == null) {
          rowFull = false;
          break;
        }
      }
      if (rowFull) {
        linesToClear.add(row);
      }
    }

    if (linesToClear.isNotEmpty) {
      isAnimating = true;
      int currentColumn = 0;

      Timer.periodic(const Duration(milliseconds: 35), (animationTimer) {
        setState(() {
          for (int row in linesToClear) {
            fadingGrid[row][currentColumn] = true;
          }
        });
        currentColumn++;
        if (currentColumn >= colLength) {
          animationTimer.cancel();

          Timer(const Duration(milliseconds: 150), () {
            setState(() {
              linesToClear.sort();
              for (int row in linesToClear) {
                for (int r = row; r > 0; r--) {
                  gameGrid[r] = List.from(gameGrid[r - 1]);
                  fadingGrid[r] = List.from(fadingGrid[r - 1]);
                }
                gameGrid[0] = List.generate(colLength, (index) => null);
                fadingGrid[0] = List.generate(colLength, (index) => false);
                score += 100;
              }
              isAnimating = false;
              spawnPiece();
              // CAMBIO: se llama sin parámetros → restaura velocidad normal
              // después de limpiar líneas, independientemente de si el botón
              // seguía presionado antes de la animación.
              resetGravityTimer();
            });
          });
        }
      });
    } else {
      setState(() {
        spawnPiece();
      });
    }
  }

  bool checkGameOver() {
    for (int index in currentPosition) {
      int row = (index / colLength).floor();
      int col = index % colLength;
      if (row >= 0 && gameGrid[row][col] != null) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    bool ignoreInputs = isGameOver || isPaused || isAnimating;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isVideoInitialized)
              Positioned.fill(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                ),
              ),

            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15.0,
                    vertical: 15.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      Text(
                        'PUNTOS: $score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (!isGameOver)
                            IconButton(
                              onPressed: togglePause,
                              icon: Icon(
                                isPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                color: isPaused
                                    ? Colors.greenAccent
                                    : Colors.amberAccent,
                                size: 32,
                              ),
                            ),
                          const SizedBox(width: 5),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isGameOver
                                  ? Colors.red
                                  : const Color.fromRGBO(66, 66, 66, 0.7),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: startGame,
                            child: Text(
                              isGameOver ? 'REINICIAR' : 'NUEVO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(flex: 5, child: Center(child: widgetGrid())),

                Expanded(
                  flex: 2,
                  child: AbsorbPointer(
                    absorbing: ignoreInputs,
                    child: GameControls(
                      onRotate: rotatePiece,
                      onMoveLeft: moveLeft,
                      onMoveDown: moveDown,
                      onMoveRight: moveRight,
                      // se pasan los nuevos callbacks al widget de controles
                      onFastDropStart: startFastDrop,
                      onFastDropStop: stopFastDrop,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget widgetGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: AspectRatio(
        aspectRatio: colLength / rowLength,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color.fromRGBO(0, 0, 0, 0.5),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rowLength * colLength,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: colLength,
                ),
                itemBuilder: (context, index) {
                  int row = (index / colLength).floor();
                  int col = index % colLength;

                  Widget pixelWidget;

                  if (gameGrid[row][col] != null) {
                    pixelWidget = Pixel(
                      color: tetriminoColors[gameGrid[row][col]]!,
                    );
                  } else if (currentPosition.contains(index)) {
                    pixelWidget = Pixel(color: tetriminoColors[currentPiece]!);
                  } else {
                    pixelWidget = const Pixel(color: Colors.transparent);
                  }

                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: fadingGrid[row][col] ? 0.0 : 1.0,
                    curve: Curves.easeInCubic,
                    child: pixelWidget,
                  );
                },
              ),
            ),

            if (isPaused)
              Container(
                color: const Color.fromRGBO(0, 0, 0, 0.74),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pause_circle_filled,
                        color: Colors.amber,
                        size: 64,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'JUEGO PAUSADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (isGameOver)
              Container(
                color: const Color.fromRGBO(0, 0, 0, 0.85),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sentiment_very_dissatisfied,
                        color: Colors.redAccent,
                        size: 64,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'FIN DEL JUEGO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GameControls extends StatelessWidget {
  final VoidCallback onRotate;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveDown;
  final VoidCallback onMoveRight;
  // nuevos callbacks para controlar la caída rápida desde el widget padre
  final VoidCallback onFastDropStart;
  final VoidCallback onFastDropStop;

  const GameControls({
    super.key,
    required this.onRotate,
    required this.onMoveLeft,
    required this.onMoveDown,
    required this.onMoveRight,
    // se declaran como requeridos en el constructor
    required this.onFastDropStart,
    required this.onFastDropStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onRotate,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(22),
                  backgroundColor: const Color.fromRGBO(33, 150, 243, 0.85),
                  elevation: 5,
                ),
                child: const Icon(
                  Icons.rotate_right,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onMoveLeft,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor: const Color.fromRGBO(66, 66, 66, 0.8),
                  elevation: 4,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 25),

              // CAMBIO: el botón de bajar ahora está envuelto en un GestureDetector
              // para detectar cuando se mantiene presionado
              // y cuando se suelta activando o desactivando
              // la caída rápida respectivamente
              // un solo paso hacia abajo al hacer tap simple.
              GestureDetector(
                onTap: onMoveDown,
                onLongPressStart: (_) => onFastDropStart(),
                onLongPressEnd: (_) => onFastDropStop(),
                child: ElevatedButton(
                  // onPressed se mantiene para conservar el feedback visual del botón
                  onPressed: onMoveDown,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                    backgroundColor: const Color.fromRGBO(66, 66, 66, 0.8),
                    elevation: 4,
                  ),
                  child: const Icon(
                    Icons.arrow_downward,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(width: 25),
              ElevatedButton(
                onPressed: onMoveRight,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor: const Color.fromRGBO(66, 66, 66, 0.8),
                  elevation: 4,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}