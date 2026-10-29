"""Scoped mobile UI contracts; --syntax parses every repo Dart source, not types."""
import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FEATURES = ROOT / 'apps/swansport_app/lib/features'
SCREENS = (
    'profile_screen', 'notifications_screen', 'messages_screen', 'search_screen',
    'marketplace_screen', 'attendance_history_screen', 'finance_screen',
    'team_roster_screen', 'athlete_workspace_screen', 'explore_screen',
    'club_settings_screen',
)
REFEREE_SCREENS = (
    'referee_widgets', 'referee_duty_list_screen', 'referee_lineup_approval_screen',
    'referee_live_cockpit_screen', 'referee_match_report_screen',
    'club_staff_operations_screen',
    'mernis_verification_section',
    'live_match_widgets', 'live_match_hub_screen', 'live_match_detail_screen',
    'league_standings_view',
    'match_follow_button',
    'test_center_screen',
)


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument('--syntax', action='store_true')
    options = args.parse_args()
    failures = []
    sources = {}
    for name in SCREENS + REFEREE_SCREENS:
        paths = list(FEATURES.rglob(name + '.dart'))
        if len(paths) != 1:
            failures.append(f'{name}: expected exactly one source')
            continue
        path = paths[0]
        source = path.read_text(encoding='utf-8-sig')
        sources[name] = source
        for pattern in (r'GoogleFonts\.', r'\bfontSize\s*:', r'\bTextStyle\s*\(',
                        r'\bColor\s*\(\s*0x', r'Colors\.(?:black|white)\w*',
                        r'\bkTeal(?:Bright|Deep)?\b'):
            if re.search(pattern, source):
                failures.append(f'{name}: token violation {pattern}')
        if name in SCREENS and 'SwanSpace.xl * 5' not in source:
            failures.append(f'{name}: floating navigation clearance missing')
        if name in REFEREE_SCREENS and ('Supabase.instance' in source or '.from(' in source or '.rpc(' in source):
            failures.append(f'{name}: direct backend query in widget')
    notice = sources.get('notifications_screen', '')
    for required in ('ref.watch(unreadNotificationsProvider)', 'unreadCount > 0',
                     "'$unreadCount yeni'", 'c.accentFill', 'c.onAccent'):
        if required not in notice:
            failures.append(f'notifications: missing {required}')
    if "'3 yeni'" in notice.lower() or notice.count('Icons.done_all_rounded') != 1:
        failures.append('notifications: mock count or duplicate read action')
    profile = sources.get('profile_screen', '')
    if 'Icons.expand_more_rounded' in profile or '_highlightItem' in profile:
        failures.append('profile: dead dropdown/story rings')
    search = sources.get('search_screen', '')
    for mock in ('Barkod / QR Tarayıcı açılıyor', 'Arama filtreleri aktif'):
        if mock in search:
            failures.append(f'search: fake action {mock}')
    market = sources.get('marketplace_screen', '')
    for mock in ('%20', 'Doğrulama Garantisi', 'ÜCRETSİZ', 'Poligon onaylı'):
        if mock in market:
            failures.append(f'marketplace: unsupported promise {mock}')
    if options.syntax:
        try:
            from tree_sitter import Language, Parser
            import tree_sitter_dart
        except ImportError:
            raise SystemExit('Syntax check requires tree_sitter + tree_sitter_dart; no type checking implied.')
        parser = Parser(Language(tree_sitter_dart.language()))
        paths = subprocess.check_output(['rg', '--files', '-g', '*.dart'],
                                        cwd=ROOT, text=True).splitlines()
        for relative in paths:
            tree = parser.parse((ROOT / relative).read_bytes())
            if tree.root_node.has_error:
                failures.append(f'Dart syntax: {relative}')
        print(f'Dart syntax: {len(paths)} files, {sum(x.startswith("Dart syntax:") for x in failures)} errors')
    for failure in failures:
        print('FAIL:', failure)
    print(f'Mobile UI contracts: {len(sources)}/{len(SCREENS) + len(REFEREE_SCREENS)} sources; {len(failures)} errors')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
