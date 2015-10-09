// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@HtmlImport('src/example_app.html')
library polymer_core_and_paper_examples.spa.app;

import 'dart:html';
import 'dart:js';
import 'package:polymer/polymer.dart';
import 'package:polymer_elements/iron_a11y_keys_behavior.dart';
import 'package:route_hierarchical/client.dart';
import 'src/elements.dart';
import 'package:web_components/web_components.dart' show HtmlImport;

/// Simple class which maps page names to paths.
class Page extends JsProxy {
  @reflectable
  final String name;
  @reflectable
  final String path;
  final bool isDefault;

  /*
Can't be const because of JsProxy ??
 */
  Page(this.name, this.path, {this.isDefault: false});

  String toString() => '$name';
}

/// Element representing the entire example app. There should only be one of
/// these in existence.
@PolymerRegister('example-app')
class ExampleApp extends PolymerElement with IronA11yKeysBehavior {
  /// The current selected [Page].
  @property
  Page get selectedPage => _selectedPage;
  @reflectable // https://github.com/dart-lang/polymer-dart/issues/621
  void set selectedPage(Page newPage) {
    _selectedPage = newPage;
    notifyPath('selectedPage', selectedPage);
  }

  Page _selectedPage;

  /// The list of pages in our app.
  @property
  final List<Page> pages = [
    new Page('Single', 'one', isDefault: true),
    new Page('page', 'two'),
    new Page('app', 'three'),
    new Page('using', 'four'),
    new Page('Polymer', 'five')
  ];

  /// Index of the current [Page]
  @Property(observer: 'routeIdxChanged')
  int get routeIdx => _routeIdx;
  @reflectable // https://github.com/dart-lang/polymer-dart/issues/621
  void set routeIdx(int value) {
    _routeIdx = value;
    notifyPath('routeIdx', routeIdx);
  }

  int _routeIdx;

  @property
  String get route => _route;
  @reflectable // https://github.com/dart-lang/polymer-dart/issues/621
  void set route(String newRoute) {
    _route = newRoute;
    notifyPath('route', route);
  }

  String _route;

  /// The [Router] which is going to control the app.
  final Router router = new Router(useFragment: true);

  ExampleApp.created() : super.created();

  /// Convenience getters that return the expected types to avoid casts.
  NeonAnimatedPages get neonPages => $['pages'];
  PaperDrawerPanel get menu => $['drawerPanel'];

  ready() {
    // Set up the routes for all the pages.

    pages.forEach((Page page) {
      router.root.addRoute(
          name: page.name,
          path: page.path,
          defaultRoute: page.isDefault,
          enter: enterRoute);
    });
    router.listen();

    // Set up the key bindings.
    int i = 0;
    var keysToAdd = ['up', 'down', 'left', 'right', 'space', 'space+shift']
      ..addAll(pages.map((page) => '${++i}'));

    for (var key in keysToAdd) {
      addOwnKeyBinding(key, 'keyHandler');
    }
  }

  /// Updates [selectedPage] and the current route whenever the route changes.
  @reflectable
  void routeIdxChanged(int newRouteIdx, [_]) {
    if (newRouteIdx != null && newRouteIdx >= 0 && newRouteIdx < pages.length) {
      route = pages[newRouteIdx].path;
    } else {
      route = "";
    }
    if (route.isEmpty) {
      selectedPage = pages.firstWhere((page) => page.isDefault);
    } else {
      selectedPage = pages.firstWhere((page) => page.path == route);
    }
    if (selectedPage != null) {
      router.go(selectedPage.name, {});
    }
  }

  /// Updates [route] whenever we enter a new route.
  void enterRoute(RouteEvent e) {
    route = e.path;
    if (route != null && route.isNotEmpty) {
      Page page = pages.firstWhere((Page item) => item.path == route);
      routeIdx = pages.indexOf(page);
    } else {
      routeIdx = -1;
    }
  }

  /// Handler for key events.
  @reflectable
  void keyHandler(event, [_]) {
    var detail = event.detail;
    switch (detail['key']) {
      case 'left':
      case 'up':
        neonPages.selectPrevious();
        return;
      case 'right':
      case 'down':
        neonPages.selectNext();
        return;
      case 'space':
        detail['shift'] ? neonPages.selectPrevious() : neonPages.selectNext();
        return;
    }

    // Try to parse as a number if we didn't recognize it as something else.
    try {
      var num = int.parse(detail['key']);
      if (num <= pages.length) {
        routeIdx = num - 1;
      }
      return;
    } catch (e) {}
  }

  /// Cycle pages on click.
  @reflectable
  void cyclePages(Event event, [_]) {
    // Clicks on links should not cycle pages.
    if (event.target.toString() == 'a') {
      return;
    }
    (_["sourceEvent"] as MouseEvent).shiftKey
        ? neonPages.selectPrevious()
        : neonPages.selectNext();
  }

  /// Close the menu whenever you select an item.
  @reflectable
  void menuItemClicked(event, [_]) {
    menu.closeDrawer();
  }

  @reflectable
  String computeUrl(String url) => "#$url";

  @reflectable
  String computeIconName(String itemPath, String route) =>
      "label" + (route != itemPath ? '-outline' : '');
}
