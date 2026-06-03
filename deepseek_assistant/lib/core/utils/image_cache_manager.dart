import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;

class ImageCacheManager {
  static final Map<String, Uint8List> _memoryCache = {};
  static const int _maxCacheSize = 50; 
  static int _currentSize = 0;

  static Uint8List? getImage(String base64) {
    final cacheKey = _generateCacheKey(base64);
    
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
      developer.log('使用缓存的图片', name: 'ImageCache');
      return cached;
    }
    
    try {
      final bytes = base64Decode(base64);
      _addToCache(cacheKey, bytes);
      return bytes;
    } catch (e) {
      developer.log('图片解码失败: $e', name: 'ImageCache');
      return null;
    }
  }

  static String _generateCacheKey(String base64) {
    return base64.hashCode.toString();
  }

  static void _addToCache(String key, Uint8List bytes) {
    if (_memoryCache.length >= _maxCacheSize) {
      _evictOldest();
    }
    
    _memoryCache[key] = bytes;
    _currentSize += bytes.length;
    
    if (_currentSize > 10 * 1024 * 1024) { 
      developer.log('缓存超过10MB，清理旧缓存', name: 'ImageCache');
      _evictOldest();
    }
  }

  static void _evictOldest() {
    if (_memoryCache.isNotEmpty) {
      final firstKey = _memoryCache.keys.first;
      final removed = _memoryCache.remove(firstKey);
      if (removed != null) {
        _currentSize -= removed.length;
      }
      developer.log('清理缓存条目', name: 'ImageCache');
    }
  }

  static void clearCache() {
    _memoryCache.clear();
    _currentSize = 0;
    developer.log('图片缓存已清空', name: 'ImageCache');
  }

  static int get cacheSize => _memoryCache.length;
  static int get cacheBytes => _currentSize;
}