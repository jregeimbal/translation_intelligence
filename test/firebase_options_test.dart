import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/firebase_options.dart';

void main() {
  group('DefaultFirebaseOptions', () {
    test('has currentPlatform getter', () {
      expect(DefaultFirebaseOptions, isA<dynamic>());
      expect(DefaultFirebaseOptions.currentPlatform, isNotNull);
    });

    test('web platform returns correct options', () {
      final webOptions = DefaultFirebaseOptions.web;

      expect(webOptions.apiKey, 'AIzaSyDrDpfy_ZwGXz0my-SxDHj9dwDV3Q_coKc');
      expect(webOptions.appId, '1:807627897911:web:0881cbefcc13b9af4813b2');
      expect(webOptions.messagingSenderId, '807627897911');
      expect(webOptions.projectId, 'tutti-lingo');
      expect(webOptions.authDomain, 'tutti-lingo.firebaseapp.com');
      expect(webOptions.storageBucket, 'tutti-lingo.firebasestorage.app');
      expect(webOptions.measurementId, 'G-S0X5GBT0F3');
    });

    test('android platform returns correct options', () {
      final androidOptions = DefaultFirebaseOptions.android;

      expect(androidOptions.apiKey, 'AIzaSyBDCTRkDbXpsnLzfpewRaOEo3-LOgxv-p8');
      expect(androidOptions.appId, '1:807627897911:android:3b03bc1d57cbfb264813b2');
      expect(androidOptions.messagingSenderId, '807627897911');
      expect(androidOptions.projectId, 'tutti-lingo');
      expect(androidOptions.storageBucket, 'tutti-lingo.firebasestorage.app');
      expect(androidOptions.authDomain, isNull);
      expect(androidOptions.measurementId, isNull);
    });

    test('ios platform returns correct options', () {
      final iosOptions = DefaultFirebaseOptions.ios;

      expect(iosOptions.apiKey, 'AIzaSyBlxM7iI7AT6w-wkFq8smY2COViRQ0Y3sQ');
      expect(iosOptions.appId, '1:807627897911:ios:6a7fc172d14770d94813b2');
      expect(iosOptions.messagingSenderId, '807627897911');
      expect(iosOptions.projectId, 'tutti-lingo');
      expect(iosOptions.storageBucket, 'tutti-lingo.firebasestorage.app');
      expect(iosOptions.iosBundleId, 'com.example.translationIntelligence');
      expect(iosOptions.authDomain, isNull);
      expect(iosOptions.measurementId, isNull);
    });

    test('macos platform returns correct options', () {
      final macosOptions = DefaultFirebaseOptions.macos;

      expect(macosOptions.apiKey, 'AIzaSyBlxM7iI7AT6w-wkFq8smY2COViRQ0Y3sQ');
      expect(macosOptions.appId, '1:807627897911:ios:6a7fc172d14770d94813b2');
      expect(macosOptions.messagingSenderId, '807627897911');
      expect(macosOptions.projectId, 'tutti-lingo');
      expect(macosOptions.storageBucket, 'tutti-lingo.firebasestorage.app');
      expect(macosOptions.iosBundleId, 'com.example.translationIntelligence');
      expect(macosOptions.authDomain, isNull);
      expect(macosOptions.measurementId, isNull);
    });

    test('windows platform returns correct options', () {
      final windowsOptions = DefaultFirebaseOptions.windows;

      expect(windowsOptions.apiKey, 'AIzaSyDrDpfy_ZwGXz0my-SxDHj9dwDV3Q_coKc');
      expect(windowsOptions.appId, '1:807627897911:web:5f363a7f798da4ab4813b2');
      expect(windowsOptions.messagingSenderId, '807627897911');
      expect(windowsOptions.projectId, 'tutti-lingo');
      expect(windowsOptions.authDomain, 'tutti-lingo.firebaseapp.com');
      expect(windowsOptions.storageBucket, 'tutti-lingo.firebasestorage.app');
      expect(windowsOptions.measurementId, 'G-G5JLK9PT9T');
    });

    test('linux platform throws UnsupportedError', () {

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      try {
        expect(
           () => DefaultFirebaseOptions.currentPlatform,
          throwsUnsupportedError,
         );
       } finally {
         // Restore original platform
        debugDefaultTargetPlatformOverride = null;
       }
     });

    test('all platforms share same projectId', () {
       // Test web
      final webOptions = DefaultFirebaseOptions.web;

       // Test android
      final androidOptions = DefaultFirebaseOptions.android;

       // Test ios
      final iosOptions = DefaultFirebaseOptions.ios;

       // Test macos
      final macosOptions = DefaultFirebaseOptions.macos;

       // Test windows
      final windowsOptions = DefaultFirebaseOptions.windows;

       // All should have the same projectId
      expect(webOptions.projectId, 'tutti-lingo');
      expect(androidOptions.projectId, 'tutti-lingo');
      expect(iosOptions.projectId, 'tutti-lingo');
      expect(macosOptions.projectId, 'tutti-lingo');
      expect(windowsOptions.projectId, 'tutti-lingo');
     });

    test('web and windows share same apiKey', () {
       // Test web
      final webOptions = DefaultFirebaseOptions.web;

       // Test windows
      final windowsOptions = DefaultFirebaseOptions.windows;

      expect(webOptions.apiKey, windowsOptions.apiKey);
      expect(webOptions.apiKey, 'AIzaSyDrDpfy_ZwGXz0my-SxDHj9dwDV3Q_coKc');
     });

    test('ios and macos share same apiKey', () {
       // Test ios
      final iosOptions = DefaultFirebaseOptions.ios;

       // Test macos
      final macosOptions = DefaultFirebaseOptions.macos;

      expect(iosOptions.apiKey, macosOptions.apiKey);
      expect(iosOptions.apiKey, 'AIzaSyBlxM7iI7AT6w-wkFq8smY2COViRQ0Y3sQ');
     });
   });
}
