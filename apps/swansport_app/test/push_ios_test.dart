import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/push/push_io.dart' as io;
import 'package:swansport_app/app/push/push_token_gate.dart';
import 'package:swansport_app/app/push/push.dart';
void main(){
  test('native support admits Android/iOS but not unrelated desktop platforms',(){
    addTearDown(()=>debugDefaultTargetPlatformOverride=null);
    for(final platform in TargetPlatform.values){debugDefaultTargetPlatformOverride=platform;
      expect(io.pushSupported,platform==TargetPlatform.android||platform==TargetPlatform.iOS);}
  });
  test('APNs gate waits until token exists before permitting subsequent FCM work',()async{
    var reads=0;final delays=<Duration>[];
    final token=await waitForApnsToken(read:()async=>++reads==3?'fixture-apns':null,delay:(d)async=>delays.add(d));
    expect(token,'fixture-apns');expect(reads,3);expect(delays.length,2);
  });
  test('missing APNs token is bounded and has actionable diagnostic',()async{
    var reads=0;final token=await waitForApnsToken(read:()async{reads++;return null;},delay:(_)async{},attempts:3);
    expect(token,isNull);expect(reads,3);expect(const PushException(PushFailure.apnsUnavailable).toString(),contains('İmza'.toLowerCase()));
  });
}
