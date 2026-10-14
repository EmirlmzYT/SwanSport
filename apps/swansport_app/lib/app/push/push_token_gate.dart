/// APNs registration is asynchronous. Never request an FCM token before it
/// exists; missing signing/capabilities must fail clearly, not loop forever.
Future<String?> waitForApnsToken({required Future<String?> Function() read,
  Future<void> Function(Duration)? delay,int attempts=10}) async {
  final Future<void> Function(Duration) pause=delay??((Duration duration)=>Future<void>.delayed(duration));
  for(var i=0;i<attempts;i++){
    final token=await read();if(token?.isNotEmpty==true)return token;
    if(i+1<attempts)await pause(const Duration(milliseconds:250));
  }
  return null;
}
