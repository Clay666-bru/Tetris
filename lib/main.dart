import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'board.dart';

void main() {
  // Aseguramos que los servicios de Flutter estén inicializados antes de correr la app
  WidgetsFlutterBinding.ensureInitialized();

  // Forzamos el modo vertical para evitar errores de layout al rotar el dispositivo
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MyApp());
}

/// Widget raíz de la aplicación
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tetris Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const WelcomeMenu(),
    );
  }
}

/// Pantalla de menú principal (Welcome Menu)
class WelcomeMenu extends StatefulWidget {
  const WelcomeMenu({super.key});

  @override
  State<WelcomeMenu> createState() => _WelcomeMenuState();
}

class _WelcomeMenuState extends State<WelcomeMenu> {
  late VideoPlayerController _menuVideoController;
  bool _isVideoInitialized = false;
  bool _isSoundOn = false;
  List<String> _highScores = [];

  @override
  void initState() {
    super.initState();
    _initVideoBackground();
    _loadHighScores();
  }

  /// Inicializa el video de fondo del menú
  void _initVideoBackground() {
    // Asegúrate de que este archivo 'assets/fondo.mp4' esté declarado en tu pubspec.yaml
    _menuVideoController = VideoPlayerController.asset('assets/fondo.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isVideoInitialized = true;
        });
        _menuVideoController.setLooping(true);
        _menuVideoController.setVolume(_isSoundOn ? 0.4 : 0.0);
        _menuVideoController.play();
      }).catchError((Object e) {
        // Si el video no se puede cargar, el menú sigue funcionando sin fondo
        debugPrint('No se pudo cargar el video de fondo: $e');
      });
  }

  /// Carga los mejores puntajes guardados en SharedPreferences
  Future<void> _loadHighScores() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _highScores = prefs.getStringList('high_scores') ?? [];
    });
  }

  /// Activa o desactiva el sonido
  void _toggleSound() {
    setState(() {
      _isSoundOn = !_isSoundOn;
      _menuVideoController.setVolume(_isSoundOn ? 0.4 : 0.0);
    });
  }

  @override
  void dispose() {
    _menuVideoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo de video
          if (_isVideoInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _menuVideoController.value.size.width,
                  height: _menuVideoController.value.size.height,
                  child: VideoPlayer(_menuVideoController),
                ),
              ),
            )
          else
            Container(color: Colors.black),

          // Capa oscura para mejorar la legibilidad del texto
          Container(color: Colors.black54),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Título del juego
                  const Text(
                    'TETRIS',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.blueAccent,
                          blurRadius: 15,
                          offset: Offset(2, 2),
                        ),
                        Shadow(
                          color: Colors.redAccent,
                          blurRadius: 15,
                          offset: Offset(-2, -2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Botón Iniciar Juego
                  _menuButton(
                    label: 'INICIAR JUEGO',
                    icon: Icons.play_arrow_rounded,
                    color: Colors.greenAccent,
                    onPressed: () async {
                      _menuVideoController.pause();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GameBoard(isSoundOn: _isSoundOn),
                        ),
                      );
                      _loadHighScores();
                      _menuVideoController.play();
                    },
                  ),
                  const SizedBox(height: 20),

                  // Botón de Puntajes
                  _menuButton(
                    label: 'SCORES',
                    icon: Icons.emoji_events_rounded,
                    color: Colors.amberAccent,
                    onPressed: () => _showScoresDialog(context),
                  ),
                  const SizedBox(height: 20),

                  // Botón de Sonido
                  _menuButton(
                    label: _isSoundOn ? 'SONIDO: ON' : 'SONIDO: OFF',
                    icon: _isSoundOn ? Icons.volume_up : Icons.volume_off,
                    color: Colors.blueAccent,
                    onPressed: _toggleSound,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget reutilizable para los botones del menú
  Widget _menuButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 240,
      height: 55,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white10,
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// Muestra el diálogo con los mejores 5 puntajes
  void _showScoresDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Top 5 Scores'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _highScores.length,
            itemBuilder: (context, index) => ListTile(
              leading: Text('${index + 1}'),
              title: Text('${_highScores[index]} puntos'),
            ),
          ),
        ),
      ),
    );
  }
}
