import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; // ✅ For MainMenuScreen

/// =====================
/// GAME SCREEN
/// =====================
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final Random rng = Random();
  final List<String> alphabet =
  List.generate(26, (i) => String.fromCharCode(65 + i));

  late ConfettiController confetti;
  Timer? spawner;

  int nextLetterIndex = 0;
  List<Balloon> balloons = [];
  bool showHow = false;
  bool showMenu = false;
  bool isPaused = false;
  bool gameCompleted = false; // ✅ for completed popup
  Offset? confettiPosition;

  @override
  void initState() {
    super.initState();
    confetti = ConfettiController(duration: const Duration(milliseconds: 700));
    _spawnBalloon();
    spawner = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!isPaused && !gameCompleted) _spawnBalloon();
    });
  }

  @override
  void dispose() {
    confetti.dispose();
    spawner?.cancel();
    for (var b in balloons) {
      b.controller.dispose();
    }
    super.dispose();
  }

  void _spawnBalloon() {
    if (!mounted || isPaused || gameCompleted) return;

    bool hasLetter = rng.nextBool();
    String? letter;
    if (hasLetter && nextLetterIndex < alphabet.length) {
      letter = alphabet[nextLetterIndex];
    }

    final controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 6 + rng.nextInt(3)),
    );

    final images = [
      'assets/images/balloon.png',
      'assets/images/balloon1.png',
      'assets/images/balloon2.png',
      'assets/images/balloon3.png',
    ];
    final balloonAsset = images[rng.nextInt(images.length)];

    final balloon = Balloon(
      controller: controller,
      startX: rng.nextDouble(),
      letter: letter,
      balloonAsset: balloonAsset,
    );

    controller.forward();
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => balloons.remove(balloon));
      }
    });

    setState(() => balloons.add(balloon));
  }

  void _onBalloonTap(Balloon b, TapDownDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    confettiPosition = localPosition;
    confetti.play();

    if (b.letter == null) {
      _popBalloon(b);
      return;
    }

    if (b.letter == alphabet[nextLetterIndex]) {
      _popBalloon(b);
      nextLetterIndex++;
    } else {
      _popBalloon(b);
    }

    if (nextLetterIndex >= alphabet.length &&
        balloons.every((b) => b.letter == null)) {
      Future.delayed(const Duration(milliseconds: 800), _showCompletedPopup);
    }
  }

  void _popBalloon(Balloon b) {
    setState(() => balloons.remove(b));
    _showFloatingLetter(b);
  }

  void _showFloatingLetter(Balloon b) async {
    if (b.letter == null) return;
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) => AnimatedLetter(letter: b.letter!, startX: b.startX),
    );

    overlay.insert(entry);
    await Future.delayed(const Duration(seconds: 2));
    entry.remove();
  }

  void _showCompletedPopup() {
    setState(() {
      gameCompleted = true;
      isPaused = true;
      for (var b in balloons) {
        b.controller.stop();
      }
    });
  }

  void _restartGame() {
    setState(() {
      gameCompleted = false;
      nextLetterIndex = 0;
      balloons.clear();
      isPaused = false;
    });
    _spawnBalloon();
  }

  void _pauseGame() {
    setState(() {
      isPaused = true;
      for (var b in balloons) {
        b.controller.stop();
      }
      showMenu = true;
    });
  }

  void _resumeGame() {
    setState(() {
      isPaused = false;
      for (var b in balloons) {
        b.controller.forward();
      }
      showMenu = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ✅ Background
          Positioned.fill(
            child: Image.asset('assets/images/bg2.png', fit: BoxFit.cover),
          ),

          // ✅ Confetti
          if (confettiPosition != null)
            Positioned(
              left: confettiPosition!.dx - 25,
              top: confettiPosition!.dy - 25,
              child: ConfettiWidget(
                confettiController: confetti,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.1,
                numberOfParticles: 10,
                maxBlastForce: 20,
                minBlastForce: 10,
                blastDirection: -pi / 2,
                gravity: 0.5,
                shouldLoop: false,
                colors: const [
                  Colors.redAccent,
                  Colors.lightBlueAccent,
                  Colors.greenAccent,
                  Colors.orangeAccent,
                  Colors.purpleAccent,
                ],
              ),
            ),

          // ✅ Balloons
          ...balloons.map((b) {
            return AnimatedBuilder(
              animation: b.controller,
              builder: (context, child) {
                final progress = b.controller.value;
                final top = size.height - (progress * (size.height + 200));
                final left = b.startX * (size.width - 100);
                return Positioned(
                  top: top,
                  left: left,
                  child: GestureDetector(
                    onTapDown: (details) => _onBalloonTap(b, details),
                    child: Image.asset(
                      b.balloonAsset,
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            );
          }).toList(),

          // ✅ Menu button
          if (!gameCompleted)
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: _pauseGame,
                child:
                Image.asset('assets/images/menu.png', width: 50, height: 70),
              ),
            ),

          // ✅ Pause Menu
          if (showMenu)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _popupButton('assets/images/continue.png', _resumeGame),
                      const SizedBox(width: 40),
                      _popupButton('assets/images/htp.png', () {
                        setState(() {
                          showHow = true;
                          showMenu = false;
                        });
                      }),
                      const SizedBox(width: 40),
                      _popupButton('assets/images/quit.png', () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MainMenuScreen(
                              isMuted: false,
                              onToggleMute: () {},
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

          // ✅ How-to-play Overlay
          if (showHow)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.asset('assets/images/how.png',
                          width: size.width * 0.7),
                      Positioned(
                        top: 80,
                        right: 140,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            showHow = false;
                            showMenu = true;
                          }),
                          child:
                          Image.asset('assets/images/close.png', width: 56),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ✅ COMPLETED POPUP
          if (gameCompleted)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/complete.png', // 🪵 Wooden board
                        width: size.width * 0.30,
                      ),
                      Positioned(
                        top: size.height * 0.44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ✅ Home button → go to Main Menu
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MainMenuScreen(
                                      isMuted: false,
                                      onToggleMute: () {},
                                    ),
                                  ),
                                );
                              },
                              child: Image.asset('assets/images/home.png',
                                  width: 70, height: 90),
                            ),
                            const SizedBox(width: 30),
                            // ✅ Restart button
                            GestureDetector(
                              onTap: _restartGame,
                              child: Image.asset('assets/images/restart.png',
                                  width: 70, height: 90),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _popupButton(String asset, VoidCallback cb,
      {double width = 200, double height = 120}) {
    return GestureDetector(
      onTap: cb,
      child:
      Image.asset(asset, width: width, height: height, fit: BoxFit.contain),
    );
  }
}

/// =====================
/// BALLOON CLASS
/// =====================
class Balloon {
  final AnimationController controller;
  final double startX;
  final String? letter;
  final String balloonAsset;

  Balloon({
    required this.controller,
    required this.startX,
    required this.letter,
    required this.balloonAsset,
  });
}

/// =====================
/// FLOATING LETTER EFFECT
/// =====================
class AnimatedLetter extends StatefulWidget {
  final String letter;
  final double startX;

  const AnimatedLetter({super.key, required this.letter, required this.startX});

  @override
  State<AnimatedLetter> createState() => _AnimatedLetterState();
}

class _AnimatedLetterState extends State<AnimatedLetter>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = controller.value;
        final top = size.height / 2 - progress * 300;
        final left = widget.startX * (size.width - 100);
        final opacity = 1 - progress;

        return Positioned(
          top: top,
          left: left,
          child: Opacity(
            opacity: opacity,
            child: Image.asset(
              'assets/images/${widget.letter.toLowerCase()}.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}
