import 'package:flutter/material.dart';
import 'event_roster_detail_screen.dart';

class RaceEventDetailScreen extends StatelessWidget {
  const RaceEventDetailScreen(
      {super.key, this.eventId, this.title = 'Etkinlik'});
  final String? eventId;
  final String title;

  @override
  Widget build(BuildContext context) =>
      EventRosterDetailScreen(eventId: eventId, title: title);
}
