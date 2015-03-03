// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(jakemac): These don't contain elements and don't have wrappers. We
// should be exposing them outside of the `src` folder but aren't. We also may
// want to make a dart file for them that just contains this html import.
@HtmlImport('package:'
    'core_elements/src/core-animated-pages/transitions/slide-from-right.html')
@HtmlImport('package:core_elements/src/font-roboto/roboto.html')
library polymer_core_and_paper_examples.spa.elements;

export 'package:core_elements/core_animated_pages.dart';
export 'package:core_elements/core_toolbar.dart';
export 'package:core_elements/core_scaffold.dart';
export 'package:core_elements/core_icon_button.dart';
export 'package:core_elements/core_icon.dart';
export 'package:core_elements/core_menu.dart';
export 'package:paper_elements/paper_item.dart';
export 'package:core_elements/core_a11y_keys.dart';
export 'package:core_elements/core_ajax_dart.dart';

import 'package:polymer/polymer.dart' show HtmlImport;
