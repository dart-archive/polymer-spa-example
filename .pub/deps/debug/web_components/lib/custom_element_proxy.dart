// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library web_components.custom_element_proxy;

import 'package:initialize/initialize.dart';
import 'interop.dart';

/// Annotation for a dart class which proxies a javascript custom element.
/// This will not work unless `interop_support.js` is loaded.
// TODO(jakemac): Add an @HtmlImport here to a new file which includes
// `interop_support.js`. We will need to point everything else at that html file
// as well for deduplication purposes (could even just copy it in as an inline
// script so the js file no longer exists?).
class CustomElementProxy implements Initializer<Type> {
  final String tagName;
  final String extendsTag;

  const CustomElementProxy(this.tagName, {this.extendsTag});

  void initialize(Type t) {
    registerDartType(tagName, t, extendsTag: extendsTag);
  }
}
