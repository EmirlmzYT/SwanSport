Map<String, dynamic> pair(int home, int away) => {'home': home, 'away': away};

Map<String, dynamic> basketball({bool tied = false}) => {
      'status': 'finished',
      'periods': <dynamic>[
        for (var i = 1; i <= 4; i++)
          {
            'label': 'Q$i',
            ...pair(20, tied ? 20 : 18),
            'team_fouls': pair(4, 3),
          },
      ],
    };

Map<String, dynamic> football({bool knockout = false}) => {
      'status': 'finished',
      'knockout': knockout,
      'halves': [pair(1, 0), pair(0, 1)],
    };

Map<String, dynamic> tennis({int bestOf = 3}) => {
      'status': 'finished',
      'best_of': bestOf,
      'sets': [for (var i = 0; i < bestOf ~/ 2 + 1; i++) pair(6, 4)],
    };

Map<String, dynamic> performance(
  String id,
  int lane,
  int? time,
  int? rank, {
  int heat = 1,
  bool dq = false,
  bool dnf = false,
}) =>
    {
      'athlete_ref': id,
      'lane': lane,
      'heat': heat,
      if (time != null) 'time_ms': time,
      if (rank != null) 'rank': rank,
      'dq': dq,
      'dnf': dnf,
    };

Map<String, dynamic> race() => {
      'status': 'finished',
      'performances': [
        performance('a', 1, 10000, 1),
        performance('b', 2, 11000, 2),
      ],
    };
