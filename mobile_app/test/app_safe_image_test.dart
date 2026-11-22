import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/widgets/app_image.dart';

/// Builds a minimal valid 1x1 24-bit BMP image payload (58 bytes).
Uint8List _createValid1x1BmpBytes() {
  return Uint8List.fromList([
    // BMP Header (14 bytes)
    0x42, 0x4D, // 'BM'
    0x3A, 0x00, 0x00, 0x00, // File size = 58 bytes
    0x00, 0x00, 0x00, 0x00, // Reserved
    0x36, 0x00, 0x00, 0x00, // Pixel data offset = 54
    // DIB Header (40 bytes)
    0x28, 0x00, 0x00, 0x00, // Header size = 40
    0x01, 0x00, 0x00, 0x00, // Width = 1
    0x01, 0x00, 0x00, 0x00, // Height = 1
    0x01, 0x00, // Color planes = 1
    0x18, 0x00, // Bits per pixel = 24
    0x00, 0x00, 0x00, 0x00, // Compression = BI_RGB
    0x04, 0x00, 0x00, 0x00, // Image size = 4 bytes
    0x00, 0x00, 0x00, 0x00, // X pixels/meter
    0x00, 0x00, 0x00, 0x00, // Y pixels/meter
    0x00, 0x00, 0x00, 0x00, // Colors used
    0x00, 0x00, 0x00, 0x00, // Important colors
    // Pixel Row (BGR + 1 byte padding)
    0xFF, 0x00, 0x00, 0x00,
  ]);
}

/// Builds a valid raw base64 string longer than 80 characters.
String _createLongRawBase64() {
  final bytes = Uint8List(72); // 72 bytes -> 96 base64 chars (> 80)
  final bmp = _createValid1x1BmpBytes();
  bytes.setRange(0, bmp.length, bmp);
  return base64Encode(bytes);
}

void main() {
  final sampleBytes = _createValid1x1BmpBytes();
  final sampleBase64 = base64Encode(sampleBytes);
  final sampleDataUriJpeg = 'data:image/jpeg;base64,$sampleBase64';
  final longRawBase64 = _createLongRawBase64();

  group('getSafeImageProvider unit tests', () {
    test('returns null for null, empty, and whitespace-only strings', () {
      expect(getSafeImageProvider(null), isNull);
      expect(getSafeImageProvider(''), isNull);
      expect(getSafeImageProvider('   \n\t  '), isNull);
    });

    test('returns NetworkImage for valid https and http URLs and trims input', () {
      final httpsProvider =
          getSafeImageProvider('  https://cdn.example.com/logo.png  ');
      expect(httpsProvider, isA<NetworkImage>());
      expect(
        (httpsProvider as NetworkImage).url,
        'https://cdn.example.com/logo.png',
      );

      final httpProvider =
          getSafeImageProvider('http://example.org/avatar.jpg');
      expect(httpProvider, isA<NetworkImage>());
      expect(
        (httpProvider as NetworkImage).url,
        'http://example.org/avatar.jpg',
      );
    });

    test('returns null for invalid URLs and unsupported schemes', () {
      expect(getSafeImageProvider('not-a-url'), isNull);
      expect(getSafeImageProvider('https://'), isNull);
      expect(getSafeImageProvider('http://'), isNull);
      expect(getSafeImageProvider('ftp://example.com/image.png'), isNull);
      expect(getSafeImageProvider('/tmp/local_image.png'), isNull);
    });

    test('decodes valid base64 data URIs case-insensitively with whitespace', () {
      final provider = getSafeImageProvider(sampleDataUriJpeg);
      expect(provider, isA<MemoryImage>());
      expect((provider as MemoryImage).bytes, equals(sampleBytes));

      final multilineUri =
          'DATA:IMAGE/PNG;BASE64, ${sampleBase64.substring(0, 12)}\n${sampleBase64.substring(12)}  ';
      final cleanedProvider = getSafeImageProvider(multilineUri);
      expect(cleanedProvider, isA<MemoryImage>());
      expect((cleanedProvider as MemoryImage).bytes, equals(sampleBytes));
    });

    test('returns null safely for malformed data URIs without throwing', () {
      // Missing comma separator
      expect(getSafeImageProvider('data:image/jpeg;base64'), isNull);
      // Malformed base64 characters after comma
      expect(
        getSafeImageProvider('data:image/jpeg;base64,!!!not-valid-base64!!!'),
        isNull,
      );
    });

    test('supports raw base64 fallback only when length > 80 and valid', () {
      final rawProvider = getSafeImageProvider(longRawBase64);
      expect(rawProvider, isA<MemoryImage>());
      expect((rawProvider as MemoryImage).bytes.length, 72);

      // Short base64 (< 80 chars) without data URI prefix is ignored
      expect(getSafeImageProvider(sampleBase64.substring(0, 40)), isNull);

      // Invalid raw base64 (> 80 chars) fails cleanly
      final invalidRaw = '!' * 90;
      expect(getSafeImageProvider(invalidRaw), isNull);
    });

    test('returns AssetImage for assets/ paths', () {
      final assetProvider =
          getSafeImageProvider('  assets/images/company_logo.png  ');
      expect(assetProvider, isA<AssetImage>());
      expect(
        (assetProvider as AssetImage).assetName,
        'assets/images/company_logo.png',
      );
    });
  });

  group('AppSafeImage widget tests', () {
    Widget wrapWithApp(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    testWidgets('renders broken image fallback for null or empty URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(const AppSafeImage(url: null, width: 48, height: 48)),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.broken_image_outlined));
      expect(icon.size, 20);

      await tester.pumpWidget(
        wrapWithApp(const AppSafeImage(url: '   ', width: 24, height: 24)),
      );

      final smallIcon = tester.widget<Icon>(
        find.byIcon(Icons.broken_image_outlined),
      );
      expect(smallIcon.size, 14);
    });

    testWidgets('renders custom placeholder for empty or invalid URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          const AppSafeImage(
            url: 'invalid-url-without-scheme',
            placeholder: Text('No Image'),
          ),
        ),
      );

      expect(find.text('No Image'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);

      // Missing comma in data URI falls back to placeholder cleanly
      await tester.pumpWidget(
        wrapWithApp(
          const AppSafeImage(
            url: 'data:image/jpeg;base64',
            placeholder: Text('Missing Comma Fallback'),
          ),
        ),
      );

      expect(find.text('Missing Comma Fallback'), findsOneWidget);
    });

    testWidgets('renders Image.memory for valid data:image/jpeg;base64 URI', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AppSafeImage(
            url: sampleDataUriJpeg,
            width: 64,
            height: 64,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(12));

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<MemoryImage>());
      expect((imageWidget.image as MemoryImage).bytes, equals(sampleBytes));
      expect(imageWidget.width, 64);
      expect(imageWidget.height, 64);
      expect(imageWidget.fit, BoxFit.contain);
    });

    testWidgets(
      'renders Image.network for valid https URL and recovers on HTTP error',
      (tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AppSafeImage(
            url: 'https://example.com/avatar.png',
            width: 50,
            height: 50,
            errorBuilder: (context, error, stack) =>
                const Text('Network Error Handled'),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      expect(
        (imageWidget.image as NetworkImage).url,
        'https://example.com/avatar.png',
      );

      // Flutter test HttpClient returns HTTP 400; Image.network errorBuilder handles it cleanly
      await tester.pumpAndSettle();
      expect(find.text('Network Error Handled'), findsOneWidget);
    });

    testWidgets('invokes errorBuilder synchronously for malformed base64 URI', (
      tester,
    ) async {
      Object? capturedError;

      await tester.pumpWidget(
        wrapWithApp(
          AppSafeImage(
            url: 'data:image/jpeg;base64,!!!malformed_base64!!!',
            borderRadius: BorderRadius.circular(8),
            errorBuilder: (context, error, stack) {
              capturedError = error;
              return const Text('Base64 Error Fallback');
            },
          ),
        ),
      );

      expect(find.text('Base64 Error Fallback'), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(capturedError, isA<FormatException>());
    });

    testWidgets('supports raw base64 (> 80 chars) valid and malformed fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AppSafeImage(
            url: longRawBase64,
            width: 40,
            height: 40,
          ),
        ),
      );

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<MemoryImage>());

      await tester.pumpWidget(
        wrapWithApp(
          AppSafeImage(
            url: '!' * 90,
            errorBuilder: (context, error, stack) =>
                const Text('Malformed Raw Base64'),
          ),
        ),
      );

      expect(find.text('Malformed Raw Base64'), findsOneWidget);
    });

    testWidgets('renders Image.asset for assets/ path and falls back if missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithApp(
          AppSafeImage(
            url: 'assets/images/non_existent.png',
            errorBuilder: (context, error, stack) =>
                const Text('Asset Error Handled'),
          ),
        ),
      );

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<AssetImage>());
      expect(
        (imageWidget.image as AssetImage).assetName,
        'assets/images/non_existent.png',
      );

      await tester.pumpAndSettle();
      expect(find.text('Asset Error Handled'), findsOneWidget);
    });
  });
}
