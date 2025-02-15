// ignore_for_file: deprecated_member_use_from_same_package

/// An asset loader which dynamically loads font from the given url and caches it.
/// It can be easily fetched from cache and loaded on demand.
library dynamic_cached_fonts;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:meta/meta.dart';

import 'src/utils.dart';

export 'package:flutter_cache_manager/flutter_cache_manager.dart';

export 'src/utils.dart' show cacheKeyFromUrl;

part 'src/raw_dynamic_cached_fonts.dart';

/// Allows dynamically loading fonts from the given url.
///
/// Fetching fonts from Firebase Storage is also supported.
///
/// For ready to use, simple interface, initialize [DynamicCachedFonts] and call
/// the [load] method either in you `initState()` or just before `runApp()` itself.
///
/// ```dart
/// class _SomeStateFulWidgetState extends State<_SomeStateFulWidget> {
///   @override
///   void initState() {
///     const DynamicCachedFonts dynamicCachedFont = DynamicCachedFonts(
///       fontFamily: 'font',
///       url: // Add url to a font
///     );
///     dynamicCachedFont.load();
///
///     super.initState();
///   }
/// ```
///
/// ```dart
/// void main() async {
///   final DynamicCachedFont dynamicCachedFont = DynamicCachedFont(
///     fontFamily: 'font',
///     url: // Add url to a font
///   );
///   dynamicCachedFont.load();
///
///   runApp(
///     YourAppHere(
///       ...
///       TextStyle(
///         fontFamily: 'font'
///       ),
///       ...
///     ),
///   );
/// }
/// ```
///
/// For greater customization, use static methods.
///
/// - [cacheFont] to download a font file and cache it.
/// - [canLoadFont] to check whether a font is available
///   and can be used by calling [loadCachedFont].
/// - [loadCachedFont] to load a downloaded font.
/// - [removeCachedFont] to delete the font file.
class DynamicCachedFonts {
  /// Allows dynamically loading fonts from the given url and caching them.
  ///
  /// - **REQUIRED** The [url] property is used to specify the download url
  ///   for the required font. It should be a valid http/https url which points to
  ///   a font file.
  ///   Currently, only OpenType (OTF) and TrueType (TTF) fonts are supported.
  ///
  /// - **REQUIRED** The [fontFamily] property is used to specify the name
  ///   of the font family which is to be used as [TextStyle.fontFamily].
  ///
  /// - The [maxCacheObjects] property defines how large the cache is allowed to be.
  ///   If there are more files the files that haven't been used for the longest
  ///   time will be removed.
  ///
  ///   It is used to specify the cache configuration, [Config],
  ///   for [CacheManager].
  ///
  /// - [cacheStalePeriod] is the time duration in which
  ///   a cache object is considered 'stale'. When a file is cached but
  ///   not being used for a certain time the file will be deleted
  ///
  ///   Defaults to 365 days.
  ///
  ///   It is used to specify the cache configuration, [Config],
  ///   for [CacheManager].
  DynamicCachedFonts({
    required String url,
    required this.fontFamily,
    this.maxCacheObjects = kDefaultMaxCacheObjects,
    this.cacheStalePeriod = kDefaultCacheStalePeriod,
  })  : assert(
          fontFamily != '',
          'fontFamily cannot be empty',
        ),
        assert(
          url != '',
          'url cannot be empty',
        ),
        urls = <String>[url],
        _isFirebaseURL = false,
        _loaded = false;

  /// Allows dynamically loading fonts from the given list of url and caching them.
  /// The [fontFamily] groups a series of related font assets, each of which defines
  /// how to render a specific [FontWeight] and [FontStyle] within the family.
  ///
  /// - **REQUIRED** The [urls] property is used to specify the download urls
  ///   for the required fonts. It should be a list of valid http/https urls
  ///   which point to font files.
  ///
  ///   Currently, only OpenType (OTF) and TrueType (TTF) fonts are supported.
  ///
  /// - **REQUIRED** The [fontFamily] property is used to specify the name
  ///   of the font family which is to be used as [TextStyle.fontFamily].
  ///
  /// - The [maxCacheObjects] property defines how large the cache is allowed to be.
  ///   If there are more files the files that haven't been used for the longest
  ///   time will be removed.
  ///
  ///   It is used to specify the cache configuration, [Config],
  ///   for [CacheManager].
  ///
  /// - [cacheStalePeriod] is the time duration in which
  ///   a cache object is considered 'stale'. When a file is cached but
  ///   not being used for a certain time the file will be deleted
  ///
  ///   Defaults to 365 days.
  ///
  ///   It is used to specify the cache configuration, [Config],
  ///   for [CacheManager].
  DynamicCachedFonts.family({
    required this.urls,
    required this.fontFamily,
    this.maxCacheObjects = kDefaultMaxCacheObjects,
    this.cacheStalePeriod = kDefaultCacheStalePeriod,
  })  : assert(
          fontFamily != '',
          'fontFamily cannot be empty',
        ),
        assert(
          urls.length > 1,
          'At least 2 urls have to be provided. To load a single font url, use the default constructor',
        ),
        assert(
          urls.every(
            (String url) => url != '',
          ),
          'url cannot be empty',
        ),
        _isFirebaseURL = false,
        _loaded = false;

  /// Allows dynamically loading fonts from firebase storage with the given
  /// firebase storage url, and caching them.
  ///
  /// _**Firebase app must be initialized before loading the font!!**_
  ///
  /// - **REQUIRED** The [bucketUrl] property is used to specify the download url
  ///   for the required font. It should be a valid Google Cloud Storage (gs://) url
  ///   which points to a font file.
  ///   Currently, only OpenType (OTF) and TrueType (TTF) fonts are supported.
  ///
  /// - **REQUIRED** The [fontFamily] property is used to specify the name
  ///   of the font family which is to be used as [TextStyle.fontFamily].
  ///
  /// - The [maxCacheObjects] property defines how large the cache is allowed to be.
  ///   If there are more files the files that haven't been used for the longest
  ///   time will be removed.
  ///
  ///   It is used to specify the cache configuration, [Config],
  ///   for [CacheManager].
  ///
  /// - [cacheStalePeriod] is the time duration in which
  ///   a cache object is considered 'stale'. When a file is cached but
  ///   not being used for a certain time the file will be deleted
  ///
  ///   Defaults to 365 days.
  ///
  ///   It is used to specify the cache configuration, [Config],
  ///   for [CacheManager].
  DynamicCachedFonts.fromFirebase({
    required String bucketUrl,
    required this.fontFamily,
    this.maxCacheObjects = kDefaultMaxCacheObjects,
    this.cacheStalePeriod = kDefaultCacheStalePeriod,
  })  : assert(
          fontFamily != '',
          'fontFamily cannot be empty',
        ),
        assert(
          bucketUrl != '',
          'bucketUrl cannot be empty',
        ),
        urls = <String>[bucketUrl],
        _isFirebaseURL = true,
        _loaded = false;

  /// Used to specify the download url(s) for the required font(s).
  ///
  /// It should be a valid http/https url or a Google Cloud Storage (gs://) url,
  /// when using [DynamicCachedFonts.fromFirebase], which points to
  /// a font file.
  ///
  /// Currently, only OpenType (OTF) and TrueType (TTF) fonts are supported.
  ///
  /// To load multiple fonts in a family, use [DynamicCachedFonts.family].
  final List<String> urls;

  /// Used to specify the name of the font family
  /// which is to be used as [TextStyle.fontFamily].
  final String fontFamily;

  /// Defines how large the cache is allowed to be.
  ///
  /// If there are more files the files that haven't been used for the longest
  /// time will be removed.
  ///
  /// It is used to specify the cache configuration, [Config],
  /// for [CacheManager].
  final int maxCacheObjects;

  /// The time duration in which
  /// a cache object is considered 'stale'. When a file is cached but
  /// not being used for a certain time the file will be deleted
  ///
  /// Defaults to 365 days.
  ///
  /// It is used to specify the cache configuration, [Config],
  /// for [CacheManager].
  final Duration cacheStalePeriod;

  /// Determines whether [url] is a firebase storage bucket url.
  final bool _isFirebaseURL;

  /// Checks whether [load] has already been called.
  bool _loaded;

  /// Used to download and load a font into the
  /// app with the given [url] and cache configuration.
  ///
  /// This method can be called in `main()`, `initState()` or on button tap/click
  /// as needed.
  Stream<dynamic> load() async* {
    if (_loaded) throw StateError('Font has already been loaded');
    _loaded = true;

    WidgetsFlutterBinding.ensureInitialized();

    final List<String> downloadUrls = await Future.wait(
      urls.map(
        (String url) async => _isFirebaseURL ? await Utils.handleUrl(url) : url,
      ),
    );

    Iterable<FileInfo> fontFiles;

    try {
      fontFiles = await loadCachedFamily(
        downloadUrls,
        fontFamily: fontFamily,
      );

      // Checks whether any of the files is invalid.
      // The validity is determined by parsing headers returned when the file was
      // requested. The date/time is a file validity guarantee by the source.
      // This was done to preserve `Cachemanager.getSingleFile`'s behaviour.
      fontFiles
          .where((FileInfo font) => font.validTill.isBefore(DateTime.now()))
          .forEach((FileInfo font) => cacheFont(
                font.originalUrl,
                cacheStalePeriod: cacheStalePeriod,
                maxCacheObjects: maxCacheObjects,
              ));
    } catch (_) {
      devLog(<String>['Font is not in cache.', 'Loading font now...']);

      for (final String url in downloadUrls)
        yield* cacheFont(
          url,
          cacheStalePeriod: cacheStalePeriod,
          maxCacheObjects: maxCacheObjects,
        );

      fontFiles = await loadCachedFamily(
        downloadUrls,
        fontFamily: fontFamily,
      );
    }

    yield fontFiles;
  }

  /// Accepts [cacheManager] and [force] to provide a custom [CacheManager] for testing.
  ///
  /// - **REQUIRED** The [cacheManager] property is used to specify a custom instance of
  ///   [CacheManager]. Caching can be customized using the [Config] object passed to
  ///   the instance.
  ///
  /// - The [force] property is used to specify whether or not to overwrite an existing
  ///   instance of custom cache manager.
  ///
  ///   If [force] is true and a custom cache manager already exists, it will be
  ///   overwritten with the new instance. This means any fonts cached earlier,
  ///   cannot be accessed using the new instance.
  /// ---
  /// Any new [DynamicCachedFonts] instance or any [RawDynamicCachedFonts] methods
  /// called after this method will use [cacheManager] to download, cache
  /// and load fonts. This means custom configuration **cannot** be provided.
  ///
  /// [maxCacheObjects] and [cacheStalePeriod] will have no effect after calling
  ///  this method. Customize these values in the [Config] object passed to the
  /// [CacheManager] used in [cacheManager].
  @visibleForTesting
  static void custom({
    required CacheManager cacheManager,
    bool force = false,
  }) =>
      RawDynamicCachedFonts.custom(
        cacheManager: cacheManager,
        force: force,
      );

  /// Downloads and caches font from the [url] with the given configuration.
  ///
  /// - **REQUIRED** The [url] property is used to specify the download url
  ///   for the required font. It should be a valid http/https url which points to
  ///   a font file.
  ///   Currently, only OpenType (OTF) and TrueType (TTF) fonts are supported.
  ///
  /// - The [maxCacheObjects] property defines how large the cache is allowed to be.
  ///   If there are more files the files that haven't been used for the longest
  ///   time will be removed.
  ///
  ///   It is used to specify the cache configuration, [Config],
  ///   for [CacheManager].
  ///
  /// - [cacheStalePeriod] is the time duration in which
  ///   a cache object is considered 'stale'. When a file is cached but
  ///   not being used for a certain time the file will be deleted
  ///
  ///   Defaults to 365 days.
  ///
  ///   It is used to specify the cache configuration, [Config],
  ///   for [CacheManager].
  Stream<dynamic> cacheFont(
    String url, {
    Duration cacheStalePeriod = kDefaultCacheStalePeriod,
    int maxCacheObjects = kDefaultMaxCacheObjects,
  }) async* {
    yield* RawDynamicCachedFonts.cacheFont(
      url,
      cacheStalePeriod: cacheStalePeriod,
      maxCacheObjects: maxCacheObjects,
    );
  }

  /// Checks whether the given [url] can be loaded directly from cache.
  ///
  /// - **REQUIRED** The [url] property is used to specify the url
  ///   for the required font. It should be a valid http/https url which points to
  ///   a font file. The [url] should match the url passed to [cacheFont].
  static Future<bool> canLoadFont(String url) => RawDynamicCachedFonts.canLoadFont(url);

  /// Fetches the given [url] from cache and loads it as an asset.
  ///
  /// - **REQUIRED** The [url] property is used to specify the url
  ///   for the required font. It should be a valid http/https url which points to
  ///   a font file. The [url] should match the url passed to [cacheFont].
  ///
  /// - **REQUIRED** The [fontFamily] property is used to specify the name
  ///   of the font family which is to be used as [TextStyle.fontFamily].
  static Future<FileInfo> loadCachedFont(
    String url, {
    required String fontFamily,
    @visibleForTesting FontLoader? fontLoader,
  }) =>
      RawDynamicCachedFonts.loadCachedFont(
        url,
        fontFamily: fontFamily,
        fontLoader: fontLoader,
      );

  /// Fetches the given [urls] from cache and loads them into the engine to be used.
  ///
  /// [urls] should be a series of related font assets,
  /// each of which defines how to render a specific [FontWeight] and [FontStyle]
  /// within the family.
  ///
  /// Call [canLoadFont] before calling this method to make sure the font is
  /// available in cache.
  ///
  /// - **REQUIRED** The [urls] property is used to specify the urls
  ///   for the required family. It should be a list of valid http/https urls
  ///   which point to font files.
  ///   Every url in [urls] should be loaded into cache by calling [cacheFont] for each.
  ///
  /// - **REQUIRED** The [fontFamily] property is used to specify the name
  ///   of the font family which is to be used as [TextStyle.fontFamily].
  static Future<Iterable<FileInfo>> loadCachedFamily(
    List<String> urls, {
    required String fontFamily,
    @visibleForTesting FontLoader? fontLoader,
  }) =>
      RawDynamicCachedFonts.loadCachedFamily(
        urls,
        fontFamily: fontFamily,
        fontLoader: fontLoader,
      );

  /// Removes the given [url] can be loaded directly from cache.
  ///
  /// - **REQUIRED** The [url] property is used to specify the url
  ///   for the required font. It should be a valid http/https url which points to
  ///   a font file. The [url] should match the url passed to [cacheFont].
  static Future<void> removeCachedFont(String url) => RawDynamicCachedFonts.removeCachedFont(
        url,
      );

  /// Used to specify whether detailed logs should be printed for debugging.
  ///
  /// Logging is disabled by default.
  ///
  /// Call this method before any other `DynamicCachedFonts.*` or `RawDynamicCachedFonts.*`
  /// method(s) to enable logging.
  /// Once this method is called with false, any command called after that won't log.
  ///
  /// ```dart
  /// DynamicCachedFonts.toggleVerboseLogging(true);
  /// ... // Any command called here will log results.
  /// DynamicCachedFonts.toggleVerboseLogging(false);
  /// ... // Any command called here won't log results.
  /// ```
  static void toggleVerboseLogging(bool shouldVerboseLog) {
    Utils.shouldVerboseLog = shouldVerboseLog;

    devLog(
      ['${shouldVerboseLog ? 'Enabled' : 'Disabled'} verbose logging'],
      overrideLoggerConfig: true,
    );
  }
}
