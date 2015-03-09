// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@HtmlImport('src/example_app.html')
library polymer_spa_example.example_app;

import 'package:core_elements/core_animated_pages.dart';
import 'package:core_elements/core_animated_pages/transitions/slide_from_right.dart';
import 'package:core_elements/core_icon.dart';
import 'package:core_elements/core_icon_button.dart';
import 'package:core_elements/core_menu.dart';
import 'package:core_elements/core_scaffold.dart';
import 'package:core_elements/core_toolbar.dart';
import 'package:core_elements/roboto.dart';
import 'package:paper_elements/paper_item.dart';
import 'package:polymer/polymer.dart';

/// Simple class which maps page names to paths.
class Page {
  final String name;
  final String path;
  final bool isDefault;
  const Page(this.name, this.path, {this.isDefault: false});
}

@CustomTag('example-app')
class ExampleApp extends PolymerElement {
  ExampleApp.created() : super.created();

  /// The list of pages in our app.
  final List<Page> pages = const [
    const Page('Single', 'one', isDefault: true),
    const Page('page', 'two'),
    const Page('app', 'three'),
    const Page('using', 'four'),
    const Page('Polymer', 'five'),
  ];

  /// The current route.
  @observable var route;
}
