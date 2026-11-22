import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

final RegExp _whitespaceRegex = RegExp(r'\s+');
const int _maxDecodedCacheEntries = 40;
final LinkedHashMap<String, Uint8List> _decodedBase64Cache =
    LinkedHashMap<String, Uint8List>();

Uint8List _decodeBase64Cached(String cacheKey, String base64Payload) {
  final existing = _decodedBase64Cache.remove(cacheKey);
  if (existing != null) {
    // Re-insert at tail to preserve LRU order.
    _decodedBase64Cache[cacheKey] = existing;
    return existing;
  }
  final clean = base64Payload.replaceAll(_whitespaceRegex, '');
  final bytes = base64Decode(clean);
  if (_decodedBase64Cache.length >= _maxDecodedCacheEntries) {
    _decodedBase64Cache.remove(_decodedBase64Cache.keys.first);
  }
  _decodedBase64Cache[cacheKey] = bytes;
  return bytes;
}

/// Returns a safe [ImageProvider] that supports:
/// - Base64 Data URIs: `data:image/jpeg;base64,...`
/// - HTTP / HTTPS Network URLs
/// - Raw Base64 string fallback
///
/// Returns `null` if the URL is empty or cannot be resolved, avoiding any [ArgumentError].
ImageProvider? getSafeImageProvider(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final trimmed = url.trim();

  try {
    final lower = trimmed.toLowerCase();

    // 1. Base64 Data URI: data:image/...;base64,...
    if (lower.startsWith('data:')) {
      final commaIndex = trimmed.indexOf(',');
      if (commaIndex != -1) {
        final base64String = trimmed.substring(commaIndex + 1).trim();
        final bytes = _decodeBase64Cached(trimmed, base64String);
        return MemoryImage(bytes);
      }
      return null;
    }

    // 2. HTTP / HTTPS Network URL
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.hasAuthority && uri.host.isNotEmpty) {
        return NetworkImage(trimmed);
      }
      return null;
    }

    // 3. Raw Base64 String Fallback
    if (!trimmed.startsWith('/') && !trimmed.startsWith('assets/') && trimmed.length > 80) {
      try {
        final bytes = _decodeBase64Cached(trimmed, trimmed);
        return MemoryImage(bytes);
      } catch (_) {}
    }

    // 4. Flutter Asset Fallback
    if (trimmed.startsWith('assets/')) {
      return AssetImage(trimmed);
    }
  } catch (e) {
    debugPrint('⚠️ [getSafeImageProvider] Error decoding image: $e');
  }

  return null;
}

/// A robust image rendering widget that seamlessly displays:
/// - Base64 Data URIs (`data:image/jpeg;base64,...`) via [Image.memory]
/// - Network URLs (`https://...`) via [Image.network]
/// - Custom fallback error builders and placeholders
class AppSafeImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const AppSafeImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (url == null || url!.trim().isEmpty) {
      imageWidget = _buildEmptyOrInvalidFallback(context, StateError('Empty image url'));
    } else {
      final trimmed = url!.trim();
      final lower = trimmed.toLowerCase();

      try {
        // 1. Base64 Data URI
        if (lower.startsWith('data:')) {
          final commaIndex = trimmed.indexOf(',');
          if (commaIndex != -1) {
            final base64String = trimmed.substring(commaIndex + 1).trim();
            final bytes = _decodeBase64Cached(trimmed, base64String);
            imageWidget = Image.memory(
              bytes,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (ctx, err, stack) => _buildFallback(ctx, err, stack),
            );
          } else {
            imageWidget = _buildFallback(
              context,
              FormatException('Malformed base64 data URI'),
              null,
            );
          }
        }
        // 2. HTTP / HTTPS Network URL
        else if (lower.startsWith('http://') || lower.startsWith('https://')) {
          final uri = Uri.tryParse(trimmed);
          if (uri != null && uri.hasAuthority && uri.host.isNotEmpty) {
            imageWidget = Image.network(
              trimmed,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (ctx, err, stack) => _buildFallback(ctx, err, stack),
            );
          } else {
            imageWidget = _buildFallback(
              context,
              FormatException('Invalid image URL'),
              null,
            );
          }
        }
        // 3. Raw Base64 string fallback
        else if (!trimmed.startsWith('/') && !trimmed.startsWith('assets/') && trimmed.length > 80) {
          try {
            final bytes = _decodeBase64Cached(trimmed, trimmed);
            imageWidget = Image.memory(
              bytes,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (ctx, err, stack) => _buildFallback(ctx, err, stack),
            );
          } catch (e) {
            imageWidget = _buildFallback(context, e, null);
          }
        }
        // 4. Asset fallback
        else if (trimmed.startsWith('assets/')) {
          imageWidget = Image.asset(
            trimmed,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (ctx, err, stack) => _buildFallback(ctx, err, stack),
          );
        } else {
          imageWidget = _buildFallback(
            context,
            FormatException('Unsupported image URL scheme'),
            null,
          );
        }
      } catch (e) {
        imageWidget = _buildFallback(context, e, null);
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildEmptyOrInvalidFallback(BuildContext context, Object error) {
    if (placeholder != null) {
      return placeholder!;
    }
    return _buildFallback(context, error, null);
  }

  Widget _buildFallback(BuildContext context, Object? error, StackTrace? stack) {
    if (errorBuilder != null) {
      return errorBuilder!(
        context,
        error ?? StateError('Image unavailable'),
        stack,
      );
    }
    if (placeholder != null) {
      return placeholder!;
    }
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(Icons.broken_image_outlined, size: (width != null && width! < 30) ? 14 : 20, color: Colors.grey.shade400),
      ),
    );
  }
}
