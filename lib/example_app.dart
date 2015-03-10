// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@HtmlImport('src/example_app.html')
library polymer_core_and_paper_examples.spa.app;

import 'dart:html';
import 'dart:js';
import 'package:polymer/polymer.dart';
import 'package:route_hierarchical/client.dart';
import 'src/elements.dart';

/// Simple class which maps page names to paths.
class Page {
  final String name;
  final String path;
  final bool isDefault;
  const Page(this.name, this.path, {this.isDefault: false});

  String toString() => '$name';
}

/// Element representing the entire example app. There should only be one of
/// these in existence.
@CustomTag('example-app')
class ExampleApp extends PolymerElement {
  /// The current selected [Page].
  @observable Page selectedPage;

  /// The list of pages in our app.
  final List<Page> pages = const [
    const Page('Single', 'one', isDefault: true),
    const Page('page', 'two'),
    const Page('app', 'three'),
    const Page('using', 'four'),
    const Page('Polymer', 'five'),
  ];

  /// The path of the current [Page].
  @observable var route;

  /// The [Router] which is going to control the app.
  final Router router = new Router(useFragment: true);

  ExampleApp.created() : super.created();

  /// Convenience getters that return the expected types to avoid casts.
  CoreA11yKeys get keys => $['keys'];
  CoreScaffold get scaffold => $['scaffold'];
  CoreAnimatedPages get corePages => $['pages'];
  CoreMenu get menu => $['menu'];
  BodyElement get body => document.body;

  domReady() {
    // Set up the routes for all the pages.
    for (var page in pages) {
      router.root.addRoute(
          name: page.name, path: page.path, defaultRoute: page.isDefault,
          enter: enterRoute);
    }
    router.listen();

    // Set up the number keys to send you to pages.
    int i = 0;
    var keysToAdd = pages.map((page) => ++i);
    keys.keys = '${keys.keys} ${keysToAdd.join(' ')}';
  }

  /// Updates [selectedPage] and the current route whenever the route changes.
  void routeChanged() {
    if (route is! String) return;
    if (route.isEmpty) {
      selectedPage = pages.firstWhere((page) => page.isDefault);
    } else {
      selectedPage = pages.firstWhere((page) => page.path == route);
    }
    router.go(selectedPage.name, {});
  }

  /// Updates [route] whenever we enter a new route.
  void enterRoute(RouteEvent e) {
    route = e.path;
  }

  /// Handler for key events.
  void keyHandler(e) {
    var detail = new JsObject.fromBrowserObject(e)['detail'];

    switch (detail['key']) {
      case 'left':
      case 'up':
        corePages.selectPrevious(false);
        return;
      case 'right':
      case 'down':
        corePages.selectNext(false);
        return;
      case 'space':
        detail['shift'] ? corePages.selectPrevious(false)
            : corePages.selectNext(false);
        return;
    }

    // Try to parse as a number if we didn't recognize it as something else.
    try {
      var num = int.parse(detail['key']);
      if (num <= pages.length) {
        route = pages[num - 1].path;
      }
      return;
    } catch(e) {}
  }

  /// Cycle pages on click.
  void cyclePages(Event e, detail, sender) {
    var event = new JsObject.fromBrowserObject(e);
    // Clicks on links should not cycle pages.
    if (event['target'].localName == 'a') {
      return;
    }

    event['shiftKey'] ? sender.selectPrevious(true) : sender.selectNext(true);
  }

  /// Close the menu whenever you select an item.
  void menuItemClicked(_) {
    scaffold.closeDrawer();
  }
}
