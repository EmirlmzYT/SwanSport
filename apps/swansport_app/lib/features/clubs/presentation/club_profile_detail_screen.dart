import 'package:flutter/material.dart';
import '../../social/presentation/profile_screen.dart';

class ClubProfileDetailScreen extends StatelessWidget {
  const ClubProfileDetailScreen(
      {super.key, this.clubId, this.clubName = 'Kulüp'});
  final String? clubId;
  final String clubName;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final id = clubId ??
        (args is String
            ? args
            : args is Map
                ? args['id'] as String?
                : null);
    return ProfileScreen(id: id, isClub: true);
  }
}
