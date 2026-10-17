"""Guard generated native Firebase registration before Xcode compiles it.

FlutterFire Messaging also accesses Firebase during native lifecycle callbacks.
Disabling Dart push alone is insufficient. Other plugin registrations are kept.
"""
from pathlib import Path
import re
import sys

MARKER = '// SwanSport: optional Firebase native registration guard'
GUARD = '''// SwanSport: optional Firebase native registration guard
static BOOL SwanFirebaseConfigured(void) {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info" ofType:@"plist"];
  if (path == nil) return NO;
  NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:path];
  return config[@"GOOGLE_APP_ID"] != nil && config[@"API_KEY"] != nil;
}

'''


def guarded_source(source: str) -> str:
    if MARKER in source:
        return source
    for plugin in ('FLTFirebaseCorePlugin', 'FLTFirebaseMessagingPlugin'):
        pattern = rf'(?m)^(\s*)(\[{plugin} registerWithRegistrar:[^\n]+;)$'
        source, count = re.subn(pattern,
                               r'\1if (SwanFirebaseConfigured()) { \2 }', source)
        if count != 1:
            raise ValueError(f'Expected exactly one {plugin} registration; found {count}')
    if '@implementation GeneratedPluginRegistrant' not in source:
        raise ValueError('GeneratedPluginRegistrant implementation missing')
    return source.replace('@implementation GeneratedPluginRegistrant',
                          GUARD + '@implementation GeneratedPluginRegistrant', 1)


if __name__ == '__main__':
    path = Path(sys.argv[1])
    original = path.read_text()
    guarded = guarded_source(original)
    if guarded != original:
        path.write_text(guarded)
    print('Native Firebase optional-registration guard verified.')
