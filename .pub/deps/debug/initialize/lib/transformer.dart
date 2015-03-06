// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.transformer;

import 'dart:async';
import 'dart:collection' show Queue;
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:barback/barback.dart';
import 'package:code_transformers/assets.dart';
import 'package:code_transformers/resolver.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:html5lib/dom.dart' as dom;
import 'package:html5lib/parser.dart' show parse;
import 'package:path/path.dart' as path;

import 'build/initializer_plugin.dart';
export 'build/initializer_plugin.dart';

/// Create a new [Asset] which inlines your [Initializer] annotations into
/// a new file that bootstraps your application.
Asset generateBootstrapFile(Resolver resolver, Transform transform,
    AssetId primaryAssetId, AssetId newEntryPointId,
    {bool errorIfNotFound: true, List<InitializerPlugin> plugins,
    bool appendDefaultPlugin: true}) {
  if (appendDefaultPlugin) {
    if (plugins == null) plugins = [];
    plugins.add(const DefaultInitializerPlugin());
  }
  return new _BootstrapFileBuilder(
      resolver, transform, primaryAssetId, newEntryPointId, errorIfNotFound,
      plugins: plugins).run();
}

/// Transformer which removes the mirror-based initialization logic and replaces
/// it with static logic.
class InitializeTransformer extends Transformer {
  final Resolvers _resolvers;
  final Iterable<Glob> _entryPointGlobs;
  final bool _errorIfNotFound;
  final List<InitializerPlugin> plugins;

  InitializeTransformer(List<String> entryPoints,
      {bool errorIfNotFound: true, this.plugins})
      : _entryPointGlobs = entryPoints.map((e) => new Glob(e)),
        _errorIfNotFound = errorIfNotFound,
        _resolvers = new Resolvers.fromMock({
          // The list of types below is derived from:
          //   * types that are used internally by the resolver (see
          //   _initializeFrom in resolver.dart).
          // TODO(jakemac): Move this into code_transformers so it can be shared.
          'dart:core': '''
            library dart.core;
            class Object {}
            class Function {}
            class StackTrace {}
            class Symbol {}
            class Type {}

            class String extends Object {}
            class bool extends Object {}
            class num extends Object {}
            class int extends num {}
            class double extends num {}
            class DateTime extends Object {}
            class Null extends Object {}

            class Deprecated extends Object {
              final String expires;
              const Deprecated(this.expires);
            }
            const Object deprecated = const Deprecated("next release");
            class _Override { const _Override(); }
            const Object override = const _Override();
            class _Proxy { const _Proxy(); }
            const Object proxy = const _Proxy();

            class List<V> extends Object {}
            class Map<K, V> extends Object {}
            ''',
          'dart:html': '''
            library dart.html;
            class HtmlElement {}
            ''',
        });

  factory InitializeTransformer.asPlugin(BarbackSettings settings) =>
      new InitializeTransformer(_readFileList(settings, 'entry_points'));

  bool isPrimary(AssetId id) => _entryPointGlobs.any((g) => g.matches(id.path));

  Future apply(Transform transform) {
    if (transform.primaryInput.id.path.endsWith('.dart')) {
      return _buildBootstrapFile(transform);
    } else if (transform.primaryInput.id.path.endsWith('.html')) {
      return transform.primaryInput.readAsString().then((html) {
        var document = parse(html);
        var originalDartFile =
            _findMainScript(document, transform.primaryInput.id, transform);
        return _buildBootstrapFile(transform, primaryId: originalDartFile).then(
            (AssetId newDartFile) {
          return _replaceEntryWithBootstrap(transform, document,
              transform.primaryInput.id, originalDartFile, newDartFile);
        });
      });
    } else {
      transform.logger.warning(
          'Invalid entry point ${transform.primaryInput.id}. Must be either a '
          '.dart or .html file.');
    }
    return new Future.value();
  }

  // Returns the AssetId of the newly created bootstrap file.
  Future<AssetId> _buildBootstrapFile(Transform transform,
      {AssetId primaryId}) {
    if (primaryId == null) primaryId = transform.primaryInput.id;
    var newEntryPointId = new AssetId(primaryId.package,
        '${path.url.withoutExtension(primaryId.path)}.initialize.dart');
    return transform.hasInput(newEntryPointId).then((exists) {
      if (exists) {
        transform.logger
            .error('New entry point file $newEntryPointId already exists.');
        return null;
      }

      return _resolvers.get(transform, [primaryId]).then((resolver) {
        transform.addOutput(generateBootstrapFile(
            resolver, transform, primaryId, newEntryPointId,
            errorIfNotFound: _errorIfNotFound, plugins: plugins));
        resolver.release();
        return newEntryPointId;
      });
    });
  }
  // Finds the first (and only) dart script on an html page and returns the
  // [AssetId] that points to it
  AssetId _findMainScript(
      dom.Document document, AssetId entryPoint, Transform transform) {
    var scripts = document.querySelectorAll('script[type="application/dart"]');
    if (scripts.length != 1) {
      transform.logger.error('Expected exactly one dart script in $entryPoint '
          'but found ${scripts.length}.');
      return null;
    }

    var src = scripts[0].attributes['src'];
    if (src == null) {
      // TODO(jakemac): Support inline scripts,
      transform.logger.error('Inline scripts are not supported at this time, '
          'see https://github.com/dart-lang/initialize/issues/20.');
      return null;
    }

    return uriToAssetId(
        entryPoint, src, transform.logger, scripts[0].sourceSpan);
  }

  // Replaces script tags pointing to [originalDartFile] with [newDartFile] in
  // [entryPoint].
  void _replaceEntryWithBootstrap(Transform transform, dom.Document document,
      AssetId entryPoint, AssetId originalDartFile, AssetId newDartFile) {
    var found = false;

    var scripts = document
        .querySelectorAll('script[type="application/dart"]')
        .where((script) {
      var assetId = uriToAssetId(entryPoint, script.attributes['src'],
          transform.logger, script.sourceSpan);
      return assetId == originalDartFile;
    }).toList();

    if (scripts.length != 1) {
      transform.logger.error(
          'Expected exactly one script pointing to $originalDartFile in '
          '$entryPoint, but found ${scripts.length}.');
      return;
    }
    scripts[0].attributes['src'] = path.url.relative(newDartFile.path,
        from: path.dirname(entryPoint.path));
    transform.addOutput(new Asset.fromString(entryPoint, document.outerHtml));
  }
}

// Class which builds a bootstrap file.
class _BootstrapFileBuilder {
  final Resolver _resolver;
  final Transform _transform;
  final bool _errorIfNotFound;
  AssetId _entryPoint;
  AssetId _newEntryPoint;

  /// The resolved initialize library.
  LibraryElement _initializeLibrary;
  /// The resolved Initializer class from the initialize library.
  ClassElement _initializer;

  /// Queue for intialization annotations.
  final _initQueue = new Queue<InitializerData>();
  /// All the annotations we have seen for each element
  final _seenAnnotations = new Map<Element, Set<ElementAnnotation>>();

  /// The list of [InitializerPlugin]s to apply. The first plugin which asks to
  /// be applied to a given initializer is the only one that will apply.
  List<InitializerPlugin> _plugins;

  TransformLogger _logger;

  _BootstrapFileBuilder(this._resolver, this._transform, this._entryPoint,
      this._newEntryPoint, this._errorIfNotFound,
      {List<InitializerPlugin> plugins}) {
    _logger = _transform.logger;
    _initializeLibrary =
        _resolver.getLibrary(new AssetId('initialize', 'lib/initialize.dart'));
    if (_initializeLibrary != null) {
      _initializer = _initializeLibrary.getType('Initializer');
    } else if (_errorIfNotFound) {
      _logger.warning('Unable to read "package:initialize/initialize.dart". '
          'This file must be imported via $_entryPoint or a transitive '
          'dependency.');
    }
    _plugins = plugins != null ? plugins : [const DefaultInitializerPlugin()];
  }

  /// Creates and returns the new bootstrap file.
  Asset run() {
    var entryLib = _resolver.getLibrary(_entryPoint);
    _readLibraries(entryLib);

    return new Asset.fromString(_newEntryPoint, _buildNewEntryPoint(entryLib));
  }

  /// Reads Initializer annotations on this library and all its dependencies in
  /// post-order.
  void _readLibraries(LibraryElement library, [Set<LibraryElement> seen]) {
    if (seen == null) seen = new Set<LibraryElement>();
    seen.add(library);

    // Visit all our dependencies.
    for (var library in _sortedLibraryDependencies(library)) {
      // Don't include anything from the sdk.
      if (library.isInSdk) continue;
      if (seen.contains(library)) continue;
      _readLibraries(library, seen);
    }

    // Read annotations in this order: library, top level methods, classes.
    _readAnnotations(library);
    for (var method in _topLevelMethodsOfLibrary(library, seen)) {
      _readAnnotations(method);
    }
    for (var clazz in _classesOfLibrary(library, seen)) {
      var superClass = clazz.supertype;
      while (superClass != null) {
        if (_readAnnotations(superClass.element) &&
            superClass.element.library != clazz.library) {
          _logger.warning(
              'We have detected a cycle in your import graph when running '
              'initializers on ${clazz.name}. This means the super class '
              '${superClass.name} has a dependency on this library '
              '(possibly transitive).');
        }
        superClass = superClass.superclass;
      }
      _readAnnotations(clazz);
    }
  }

  bool _readAnnotations(Element element) {
    var found = false;
    element.metadata.where((ElementAnnotation meta) {
      // First filter out anything that is not a Initializer.
      var e = meta.element;
      if (e is PropertyAccessorElement) {
        return _isInitializer(e.variable.evaluationResult.value.type);
      } else if (e is ConstructorElement) {
        return _isInitializer(e.returnType);
      }
      return false;
    }).where((ElementAnnotation meta) {
      _seenAnnotations.putIfAbsent(element, () => new Set<ElementAnnotation>());
      return !_seenAnnotations[element].contains(meta);
    }).forEach((ElementAnnotation meta) {
      _seenAnnotations[element].add(meta);
      _initQueue.addLast(new InitializerData._(element, meta));
      found = true;
    });
    return found;
  }

  String _buildNewEntryPoint(LibraryElement entryLib) {
    var importsBuffer = new StringBuffer();
    var initializersBuffer = new StringBuffer();
    var libraryPrefixes = new Map<LibraryElement, String>();

    // Import the static_loader, initializer, and original entry point.
    importsBuffer
        .writeln("import 'package:initialize/src/static_loader.dart';");
    importsBuffer.writeln("import 'package:initialize/initialize.dart';");
    libraryPrefixes[entryLib] = 'i0';

    initializersBuffer.writeln('initializers.addAll([');
    while (_initQueue.isNotEmpty) {
      var next = _initQueue.removeFirst();

      libraryPrefixes.putIfAbsent(
          next.targetElement.library, () => 'i${libraryPrefixes.length}');
      libraryPrefixes.putIfAbsent(next.annotationElement.element.library,
          () => 'i${libraryPrefixes.length}');

      // Run the first plugin which asks to be ran and then stop.
      var data = new InitializerPluginData(
          next, _newEntryPoint, libraryPrefixes, _resolver, _logger);
      var plugin = _plugins.firstWhere((p) => p.shouldApply(data), orElse: () {
        _logger.error('No InitializerPlugin handled the annotation: '
            '${next.annotationElement} on: ${next.targetElement}.');
      });
      if (plugin == null) continue;

      var text = plugin.apply(data);
      if (text != null) initializersBuffer.writeln('$text,');
    }
    initializersBuffer.writeln(']);');

    libraryPrefixes
        .forEach((lib, prefix) => _writeImport(lib, prefix, importsBuffer));

    // TODO(jakemac): copyright and library declaration
    return new DartFormatter().format('''
$importsBuffer
main() {
$initializersBuffer
  i0.main();
}
''');
  }

  _writeImport(LibraryElement lib, String prefix, StringBuffer buffer) {
    AssetId id = (lib.source as dynamic).assetId;

    if (id.path.startsWith('lib/')) {
      var packagePath = id.path.replaceFirst('lib/', '');
      buffer.write("import 'package:${id.package}/${packagePath}'");
    } else if (id.package != _newEntryPoint.package) {
      _logger.error("Can't import `${id}` from `${_newEntryPoint}`");
    } else if (path.url.split(id.path)[0] ==
        path.url.split(_newEntryPoint.path)[0]) {
      var relativePath = path.url.relative(
          id.path, from: path.url.dirname(_newEntryPoint.path));
      buffer.write("import '${relativePath}'");
    } else {
      _logger.error("Can't import `${id}` from `${_newEntryPoint}`");
    }
    buffer.writeln(' as $prefix;');
  }

  bool _isInitializer(InterfaceType type) {
    // If `_initializer` wasn't found then it was never loaded (even
    // transitively), and so no annotations can be initializers.
    if (_initializer == null) return false;
    if (type == null) return false;
    if (type.element.type == _initializer.type) return true;
    if (_isInitializer(type.superclass)) return true;
    for (var interface in type.interfaces) {
      if (_isInitializer(interface)) return true;
    }
    return false;
  }

  /// Retrieves all top-level methods that are visible if you were to import
  /// [lib]. This includes exported methods from other libraries too.
  List<FunctionElement> _topLevelMethodsOfLibrary(
      LibraryElement library, Set<LibraryElement> seen) {
    var result = [];
    result.addAll(library.units.expand((u) => u.functions));
    for (var export in library.exports) {
      if (seen.contains(export.exportedLibrary)) continue;
      var exported = _topLevelMethodsOfLibrary(export.exportedLibrary, seen);
      _filter(exported, export.combinators);
      result.addAll(exported);
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Retrieves all classes that are visible if you were to import [lib]. This
  /// includes exported classes from other libraries.
  List<ClassElement> _classesOfLibrary(
      LibraryElement library, Set<LibraryElement> seen) {
    var result = [];
    result.addAll(library.units.expand((u) => u.types));
    for (var export in library.exports) {
      if (seen.contains(export.exportedLibrary)) continue;
      var exported = _classesOfLibrary(export.exportedLibrary, seen);
      _filter(exported, export.combinators);
      result.addAll(exported);
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Filters [elements] that come from an export, according to its show/hide
  /// combinators. This modifies [elements] in place.
  void _filter(List<Element> elements, List<NamespaceCombinator> combinators) {
    for (var c in combinators) {
      if (c is ShowElementCombinator) {
        var show = c.shownNames.toSet();
        elements.retainWhere((e) => show.contains(e.displayName));
      } else if (c is HideElementCombinator) {
        var hide = c.hiddenNames.toSet();
        elements.removeWhere((e) => hide.contains(e.displayName));
      }
    }
  }

  Iterable<LibraryElement> _sortedLibraryDependencies(LibraryElement library) {
    // TODO(jakemac): Investigate supporting annotations on part-of directives.
    getLibrary(UriReferencedElement element) {
      if (element is ImportElement) return element.importedLibrary;
      if (element is ExportElement) return element.exportedLibrary;
    }

    return (new List.from(library.imports)
      ..addAll(library.exports)
      ..sort((a, b) {
      // dart: imports don't have a uri
      if (a.uri == null && b.uri != null) return -1;
      if (b.uri == null && a.uri != null) return 1;
      if (a.uri == null && b.uri == null) {
        return getLibrary(a).name.compareTo(getLibrary(b).name);
      }

      // package: imports next
      var aIsPackage = a.uri.startsWith('package:');
      var bIsPackage = b.uri.startsWith('package:');
      if (aIsPackage && !bIsPackage) {
        return -1;
      } else if (bIsPackage && !aIsPackage) {
        return 1;
      } else if (bIsPackage && aIsPackage) {
        return a.uri.compareTo(b.uri);
      }

      // And finally compare based on the relative uri if both are file paths.
      var aUri = path.url.relative(a.source.uri.path,
          from: path.url.dirname(library.source.uri.path));
      var bUri = path.url.relative(b.source.uri.path,
          from: path.url.dirname(library.source.uri.path));
      return aUri.compareTo(bUri);
    })).map(getLibrary);
  }
}

/// An [Initializer] annotation and the target of that annotation.
class InitializerData {
  /// The target [Element] of the annotation.
  final Element targetElement;

  /// The [ElementAnnotation] representing the annotation itself.
  final ElementAnnotation annotationElement;

  AstNode _targetNode;

  /// The target [AstNode] of the annotation.
  // TODO(jakemac): We at least cache this for now, but  ideally `targetElement`
  // would actually be the getter, and `targetNode` would be the property.
  AstNode get targetNode {
    if (_targetNode == null) _targetNode = targetElement.node;
    return _targetNode;
  }

  /// The [Annotation] representing the annotation itself.
  Annotation get annotationNode {
    var annotatedNode;
    if (targetNode is SimpleIdentifier &&
        targetNode.parent is LibraryIdentifier) {
      annotatedNode = targetNode.parent.parent;
    } else if (targetNode is ClassDeclaration ||
        targetNode is FunctionDeclaration) {
      annotatedNode = targetNode;
    } else {
      return null;
    }
    if (annotatedNode is! AnnotatedNode) return null;
    var astMeta = annotatedNode.metadata;

    return astMeta.firstWhere((m) => m.elementAnnotation == annotationElement);
  }

  InitializerData._(this.targetElement, this.annotationElement);
}

// Reads a file list from a barback settings configuration field.
_readFileList(BarbackSettings settings, String field) {
  var value = settings.configuration[field];
  if (value == null) return null;
  var files = [];
  bool error;
  if (value is List) {
    files = value;
    error = value.any((e) => e is! String);
  } else if (value is String) {
    files = [value];
    error = false;
  } else {
    error = true;
  }
  if (error) {
    print('Bad value for "$field" in the initialize transformer. '
        'Expected either one String or a list of Strings.');
  }
  return files;
}
