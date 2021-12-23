// Copyright 2013-2018 Workiva Inc.
//
// Licensed under the Boost Software License (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.boost.org/LICENSE_1_0.txt
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This software or document includes material copied from or derived
// from JSON-Schema-Test-Suite (https://github.com/json-schema-org/JSON-Schema-Test-Suite),
// Copyright (c) 2012 Julian Berman, which is licensed under the following terms:
//
//     Copyright (c) 2012 Julian Berman
//
//     Permission is hereby granted, free of charge, to any person obtaining a copy
//     of this software and associated documentation files (the "Software"), to deal
//     in the Software without restriction, including without limitation the rights
//     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//     copies of the Software, and to permit persons to whom the Software is
//     furnished to do so, subject to the following conditions:
//
//     The above copyright notice and this permission notice shall be included in
//     all copies or substantial portions of the Software.
//
//     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//     THE SOFTWARE.

import 'package:uri/uri.dart' show UriTemplate;

import 'package:json_schema/src/json_schema/constants.dart';
import 'package:json_schema/src/json_schema/json_schema.dart';

class JsonSchemaUtils {
  static JsonSchema getSubMapFromFragment(JsonSchema schema, Uri uri) {
    if (uri.fragment?.isNotEmpty == true) {
      schema = schema.resolvePath(Uri.parse('#${uri.fragment}'));
    }
    return schema;
  }

  static Uri getBaseFromFullUri(Uri uri) {
    List<String> segments = [];
    if (uri.pathSegments.isNotEmpty) {
      segments = []..addAll(uri.pathSegments);
      segments.removeLast();

      return uri.replace(pathSegments: segments);
    }
    return uri;
  }

  static String unescapeJsonPointerToken(String token) {
    // From private implementation: https://github.com/f3ath/rfc-6901-dart/blob/82adfa14e9da95f80bbe537ecaa5b8846d4d2119/lib/src/_internal/reference.dart#L19-L20
    return token.replaceAll("~1", "/").replaceAll("~0", "~");
  }
}

class DefaultValidators {
  emailValidator(String email) => JsonSchemaValidationRegexes.email.firstMatch(email) != null;

  uriValidator(String uri) {
    try {
      final result = Uri.parse(uri);
      // If a URI has no scheme, it is invalid.
      if (result.path.startsWith('//') || result.scheme.isEmpty) return false;
      // If a URI contains spaces, it is invalid.
      if (uri.contains(' ')) return false;
      // If a URI contains backslashes, it is invalid
      if (uri.contains('\\')) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  uriReferenceValidator(String uriReference) {
    try {
      Uri.parse(uriReference);
      // If a URI contains spaces, it is invalid.
      if (uriReference.contains(' ')) return false;
      // If a URI contains backslashes, it is invalid.
      if (uriReference.contains('\\')) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  uriTemplateValidator(String uriTemplate) {
    try {
      UriTemplate(uriTemplate);
      return true;
    } catch (e) {
      return false;
    }
  }
}
