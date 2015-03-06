// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize;

// The `loader_replacer` transformer will replace this with a static_loader.
import 'src/static_loader.dart' as loader;
import 'dart:async';
import 'dart:collection';

part 'src/init_method.dart';
part 'src/initializer.dart';

/// Top level function which crawls the dependency graph and runs initializers.
/// If `typeFilter` and/or `customFilter` are supplied then only those types of
/// annotations will be parsed. If both filters are supplied they are treated
/// as an AND.
Future run({List<Type> typeFilter, InitializerFilter customFilter}) {
  return _runInitQueue(loader.loadInitializers(
      typeFilter: typeFilter, customFilter: customFilter));
}

Future _runInitQueue(Queue<Function> initializers) {
  if (initializers.isEmpty) return new Future.value(null);

  var initializer = initializers.removeFirst();
  var val = initializer();
  if (val is! Future) val = new Future.value(val);

  return val.then((_) => _runInitQueue(initializers));
}
