// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library polymer.src.build.polymer_bootstrap;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:code_transformers/messages/build_logger.dart';
import 'package:code_transformers/assets.dart';
import 'package:code_transformers/resolver.dart';
import 'package:path/path.dart' as path;
import 'package:web_components/build/web_components.dart';

import 'common.dart';
import 'messages.dart';
import 'polymer_smoke_generator.dart';

/// The primary polymer transformer that handles everything which requires a
/// [Resolver] so they can share it.
// Note: This is effectively tested in `all_phases_test.dart` as it doesn't
// really deserve its own unit test.
class PolymerBootstrapTransformer extends Transformer with PolymerTransformer {
  final Resolvers resolvers;
  final TransformOptions options;

  PolymerBootstrapTransformer(this.options, {String sdkDir})
      // TODO(sigmund): consider restoring here a resolver that uses the real
      // SDK once the analyzer is lazy and only an resolves what it needs:
      //: resolvers = new Resolvers(sdkDir != null ? sdkDir : dartSdkDirectory);
      : resolvers = new Resolvers.fromMock({
        // The list of types below is derived from:
        //   * types we use via our smoke queries, including HtmlElement and
        //     types from `_typeHandlers` (deserialize.dart)
        //   * types that are used internally by the resolver (see
        //   _initializeFrom in resolver.dart).
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

  /// Only run on entry point .html files.
  bool isPrimary(AssetId id) => options.isHtmlEntryPoint(id);

  Future apply(Transform transform) {
    var logger = new BuildLogger(transform,
        convertErrorsToWarnings: !options.releaseMode,
        detailsUri: 'http://goo.gl/5HPeuP');
    var primaryId = transform.primaryInput.id;
    return readPrimaryAsHtml(transform, logger).then((document) {
      var script = document.querySelector('script[type="application/dart"]');
      if (script == null) {
        logger.warning(NO_DART_SCRIPT.create({'url': primaryId.path}));
        return null;
      }

      var entryScriptId = uriToAssetId(
          primaryId, script.attributes['src'], logger, script.sourceSpan);

      return resolvers.get(transform, [entryScriptId]).then((resolver) {
        var webComponentsBootstrapId =
            primaryId.changeExtension('.web_components.bootstrap.dart');
        var webComponentsBootstrap = generateWebComponentsBootstrap(resolver,
            transform, document, entryScriptId, webComponentsBootstrapId);
        transform.addOutput(webComponentsBootstrap);

        var polymerBootstrapId =
            primaryId.addExtension('.polymer.bootstrap.dart');
        script.attributes['src'] = path.basename(polymerBootstrapId.path);

        return generatePolymerBootstrap(transform, resolver,
            webComponentsBootstrapId, polymerBootstrapId, document, options,
            resolveFromId: entryScriptId).then((polymerBootstrap) {
          transform.addOutput(polymerBootstrap);
          transform
              .addOutput(new Asset.fromString(primaryId, document.outerHtml));
          resolver.release();
        });
      });
    });
  }
}
