import 'dart:math';

import 'package:flutter/material.dart';

class GammonState extends ChangeNotifier {
  static final _rand = Random();

  var points = GammonRules.initialPoints();
  var hits = [0, 0]; // Checkers hit per player
  var dice = [0, 0]; // Dice roll
  var sideSign = 1; // Either -1, or 1, or 0 if no game is playing
  var turnCount = 0;
  int selectedIndex = -1; // -1 if no selection.

  void rollDice() {
    dice[0] = _rand.nextInt(6) + 1;
    dice[1] = _rand.nextInt(6) + 1;
    notifyListeners();
  }
}

class GammonRules {
  // The total number of points on the table.
  static const numPoints = 24;

  // The initial position tuples - [index, count]
  static const initialPointTuples = const [
    [0, 2],
    [11, 5],
    [16, 3],
    [18, 5]
  ];

  static List<int> initialPoints() {
    var points = List<int>.filled(numPoints, 0);
    for (var indexCount in initialPointTuples) {
      var pointIndex = indexCount[0];
      var checkerCount = indexCount[1];

      // White checkers are positive.
      points[pointIndex] = checkerCount;

      // Black checkers are negative, placed mirrorwise.
      points[numPoints - pointIndex - 1] = -checkerCount;
    }
    return points;
  }

  // Returns true if a checker can be moved, without hitting.
  static bool canMove(int fromIndex, int toIndex, final List<int> points) {
    if (points[fromIndex] == 0) return false;
    if (points[toIndex] == 0) return true;
    return points[fromIndex].sign == points[toIndex].sign;
  }

  // Returns true, if a piece can be hit, and taken out.
  static bool canHit(int fromIndex, int toIndex, final List<int> points) {
    if (points[fromIndex] == 0) return false;
    if (points[fromIndex].sign == points[toIndex].sign) return false;
    return points[toIndex].abs() == 1;
  }

  // Moves a checker without hitting.
  static void doMove(int fromIndex, int toIndex, final List<int> points) {
    assert(canMove(fromIndex, toIndex, points));
    int sideSign = points[fromIndex].sign;
    points[fromIndex] = sideSign * (points[fromIndex].abs() - 1);
    points[toIndex] = sideSign * (points[toIndex].abs() + 1);
  }

  // Hits a lone checker.
  static void doHit(int fromIndex, int toIndex, final List<int> points, List<int> hits) {
    assert(canHit(fromIndex, toIndex, points));
    int sideSign = points[fromIndex].sign;
    points[fromIndex] = sideSign * (points[fromIndex].abs() - 1);
    points[toIndex] = sideSign;
  }

  static int sideIndex(int sideSign /* -1 or 1 */) {
    assert(sideSign.abs() == 1);
    return (sideSign + 1) >> 1;
  }

  // Returns true if the player has any hit checkers, false otherwise.
  static bool hasHit(int sideSign, final List<int> hits) {
    return hits[sideIndex(sideSign)] != 0;
  }

  // Adds a hit checker.
  static void addHit(int sideSign, final List<int> hits) {
    hits[sideIndex(sideSign)]++;
  }

  // Remove a hit checker.
  static void removeHit(int sideSign, List<int> hits) {
    hits[sideIndex(sideSign)]--;
  }
}
