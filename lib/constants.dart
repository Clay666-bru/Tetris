import 'package:flutter/material.dart';

// Dimensiones del tablero de Tetris
const int rowLength = 20;
const int colLength = 10;

// Tipos de piezas disponibles
enum Tetrimino { L, J, I, O, S, Z, T }

// Colores asignados a cada pieza para identificarlas visualmente
const Map<Tetrimino, Color> tetriminoColors = {
  Tetrimino.L: Colors.orange,
  Tetrimino.J: Colors.blue,
  Tetrimino.I: Colors.cyan,
  Tetrimino.O: Colors.yellow,
  Tetrimino.S: Colors.green,
  Tetrimino.Z: Colors.red,
  Tetrimino.T: Colors.purple,
};
