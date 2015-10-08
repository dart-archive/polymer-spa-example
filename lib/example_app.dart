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
class ExampleApp extends PolymerElement {
  /// The current selected [Page].
  Page selectedPage;

  /// The list of pages in our app.
  final List<Page> pages =  [
    new Page('Single', 'one', isDefault: true),
    new Page('page', 'two'),
    new Page('app', 'three'),
    new Page('using', 'four'),
    new Page('Polymer', 'five')
  ];

  /// Index of the current [Page]
  int routeIdx;

  var route;

  /// The [Router] which is going to control the app.
  final Router router = new Router(useFragment: true);

  ExampleApp.created() : super.created();

  /// Convenience getters that return the expected types to avoid casts.
  IronA11yKeys get keys => $['keys'];
  NeonAnimatedPages get neonPages => $['pages'];
  PaperDrawerPanel get menu => $['drawerPanel'];

  @reflectable
  BodyElement get body => document.body;

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

    // Set up the number keys to send you to pages.
    int i = 0;
    var keysToAdd = pages.map((page) => ++i);
    keys.keys = '${keys.keys} ${keysToAdd.join(' ')}';

    set('pages', pages);
  }

  /// Updates [selectedPage] and the current route whenever the route changes.
  @Observe('routeIdx')
  void routeIdxChanged(int newRouteIdx) {
    if (newRouteIdx != null && newRouteIdx >= 0 && newRouteIdx < pages.length) {
      route = pages[newRouteIdx].path;
    } else {
      route = "";
    }
    if (route.isEmpty) {
      selectedPage = pages.firstWhere((page) => page.isDefault);
      set('selectedPage', selectedPage);
    } else {
      selectedPage = pages.firstWhere((page) => page.path == route);
      set('selectedPage', selectedPage);
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
      set('routeIdx', pages.indexOf(page));
    } else {
      set('routeIdx', -1);
    }
  }

  /// Handler for key events.
  @reflectable
  void keyHandler(event, [_]) {
    print("keyEvent $event");
   /*
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
        detail['shift']
            ? corePages.selectPrevious(false)
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
    } catch (e) {}*/
  }

  /// Cycle pages on click.
  @reflectable
  void cyclePages(Event event, [_]) {
    // Clicks on links should not cycle pages.
    if (event.target.toString() == 'a') {
      return;
    }
    (_["sourceEvent"] as MouseEvent).shiftKey ? neonPages.selectPrevious() : neonPages.selectNext();
  }

  /// Close the menu whenever you select an item.
  @reflectable
  void menuItemClicked(event, [_]) {
    menu.closeDrawer();
  }

  @reflectable
  String computeUrl(String url) => "#$url";

  @reflectable
  String computeIconName(Page item) => "label" + (route != item.path ? '-outline' : '');
}
