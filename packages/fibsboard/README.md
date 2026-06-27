# overview
utilities for going back and forth between board model data structure and text rep for board

# board Dart representation
```dart
final board = <List<int>>[

  // player1 off, player2 bar
  [-14, -13, -12, -11, -10, -9, -8], // 0: 7x player1

  // player1 home board
  [-2, -1], // 1: 2x player1
  [-7, -6, -5, -4, -3], // 2: 5x player1
  [-15], // 3: 1x player1
  [], // 4: 
  [], // 5: 
  [], // 6: 

  // player1 outer board
  [], // 7: 
  [], // 8: 
  [], // 9: 
  [], // 10: 
  [], // 11: 
  [], // 12: 

  // player2 outer board
  [], // 13: 
  [], // 14: 
  [], // 15: 
  [], // 16: 
  [], // 17: 
  [], // 18: 

  // player2 home board
  [1, 2, 3, 4, 5, 6], // 19: 6x player2
  [7], // 20: 1x player2
  [8, 9], // 21: 2x player2
  [], // 22: 
  [], // 23: 
  [], // 24: 

  // player1 off, player2 bar
  [10, 11, 12, 13, 14, 15], // 25: 6x player2

];
```

# board text representation
```
+13-14-15-16-17-18-+BAR+-19-20-21-22-23-24-+OFF+
|                  |   |  O  O  O          | O |
|                  |   |  O     O          | O |
|                  |   |  O                | O |
|                  |   |  O                | O |
|                  |   |  6                | 6 |
|                  |   |                   |   |
|                  |   |              X    | 7 |
|                  |   |              X    | X |
|                  |   |              X    | X |
|                  |   |              X  X | X |
|                  |   |           X  X  X | X |
+12-11-10--9--8--7-+---+--6--5--4--3--2--1-+---+
```