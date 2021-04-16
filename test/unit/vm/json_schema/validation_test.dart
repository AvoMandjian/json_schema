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

@TestOn('vm')

library json_schema.test_validation;

import 'dart:convert';
import 'dart:io';
import 'package:json_schema/json_schema.dart';
import 'package:json_schema/vm.dart';
import 'package:json_schema/src/json_schema/constants.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

final Logger _logger = Logger('test_validation');

void main([List<String> args]) {
  configureJsonSchemaForVm();

  // Serve remotes for ref tests.
  final specFileHandler = createStaticHandler('test/JSON-Schema-Test-Suite/remotes');
  io.serve(specFileHandler, 'localhost', 1234);

  final additionalRemotesHandler = createStaticHandler('test/additional_remotes');
  io.serve(additionalRemotesHandler, 'localhost', 4321);

  if (args?.isEmpty == true) {
    Logger.root.onRecord.listen((LogRecord r) => print('${r.loggerName} [${r.level}]:\t${r.message}'));
    Logger.root.level = Level.OFF;
  }

  ////////////////////////////////////////////////////////////////////////
  // Uncomment to see logging of exceptions
  // Logger.root.onRecord.listen((LogRecord r) =>
  //   print('${r.loggerName} [${r.level}]:\t${r.message}'));

  Logger.root.level = Level.OFF;

  // Draft 4 Tests
  final Directory testSuiteFolderV4 = Directory('./test/JSON-Schema-Test-Suite/tests/draft4');
  final Directory optionalsV4 = Directory(path.joinAll([testSuiteFolderV4.path, 'optional']));
  final allDraft4 = testSuiteFolderV4.listSync()..addAll(optionalsV4.listSync());

  // Draft 6 Tests
  final Directory testSuiteFolderV6 = Directory('./test/JSON-Schema-Test-Suite/tests/draft6');
  final Directory optionalsV6 = Directory(path.joinAll([testSuiteFolderV6.path, 'optional']));
  final allDraft6 = testSuiteFolderV6.listSync()..addAll(optionalsV6.listSync());

  // Draft 7 Tests
  final Directory testSuiteFolderV7 = Directory('./test/JSON-Schema-Test-Suite/tests/draft7');
  final Directory optionalsV7 = Directory(path.joinAll([testSuiteFolderV7.path, 'optional']));
  final allDraft7 = testSuiteFolderV7.listSync()..addAll(optionalsV7.listSync());

  final runAllTestsForDraftX =
      (SchemaVersion schemaVersion, List<FileSystemEntity> allTests, List<String> skipFiles, List<String> skipTests,
          {bool isSync = false, RefProvider refProvider}) {
    String shortSchemaVersion = schemaVersion.toString();
    if (schemaVersion == SchemaVersion.draft4) {
      shortSchemaVersion = 'draft4';
    } else if (schemaVersion == SchemaVersion.draft6) {
      shortSchemaVersion = 'draft6';
    }

    allTests.forEach((testEntry) {
      if (testEntry is File) {
        group('Validations ($shortSchemaVersion) ${path.basename(testEntry.path)}', () {
          // Skip these for now - reason shown.
          if (skipFiles.contains(path.basename(testEntry.path))) return;

          final List tests = json.decode((testEntry).readAsStringSync());
          tests.forEach((testEntry) {
            final schemaData = testEntry['schema'];
            final description = testEntry['description'];
            final List validationTests = testEntry['tests'];

            validationTests.forEach((validationTest) {
              final String validationDescription = validationTest['description'];
              final String testName = '${description} : ${validationDescription}';

              // Individual test cases to skip - reason listed in comments.
              if (skipTests.contains(testName)) return;

              test(testName, () {
                final instance = validationTest['data'];
                bool validationResult;
                final bool expectedResult = validationTest['valid'];

                if (isSync) {
                  final schema = JsonSchema.createSchema(
                    schemaData,
                    schemaVersion: schemaVersion,
                    refProvider: refProvider,
                  );
                  validationResult = schema.validate(instance);
                  expect(validationResult, expectedResult);
                } else {
                  final checkResult = expectAsync0(() => expect(validationResult, expectedResult));
                  JsonSchema.createSchemaAsync(schemaData, schemaVersion: schemaVersion, refProvider: refProvider)
                      .then((schema) {
                    validationResult = schema.validate(instance);
                    checkResult();
                  });
                }
              });
            });
          });
        });
      }
    });
  };

  // Mock Ref Provider for refRemote tests. Emulates what createSchemaFromUrl would return.
  final RefProvider syncRefJsonProvider = RefProvider.syncJson((String ref) {
    switch (ref) {
      case 'http://localhost:1234/integer.json':
        return json.decode(r'''
          {
            "type": "integer"
          }
        ''');
        break;
      case 'http://localhost:1234/subSchemas.json':
        return json.decode(r'''
          {
            "integer": {
              "type": "integer"
            },
            "refToInteger": {
              "$ref": "#/integer"
            }
        }
        ''');
        break;
      case 'http://localhost:1234/subSchemas.json':
        return json.decode(r'''
          {
            "integer": {
              "type": "integer"
            },
            "refToInteger": {
              "$ref": "#/integer"
            }
        }
        ''');
        break;
      case 'http://localhost:1234/folder/folderInteger.json':
        return json.decode(r'''
          {
            "type": "integer"
          }
        ''');
        break;
      case 'http://localhost:1234/name.json':
        return json.decode(r'''
          {
            "definitions": {
              "orNull": {
                "anyOf": [
                  {
                    "type": "null"
                  },
                  {
                    "$ref": "#"
                  }
                ]
              }
            },
            "type": "string"
          }
        ''');
        break;
      case 'http://localhost:1234/baseUriChangeFolderInSubschema/folderInteger.json':
        return json.decode('''
          {
              "type": "integer"
          }
        ''');
      case 'http://localhost:1234/baseUriChangeFolder/folderInteger.json':
        return json.decode('''
          {
              "type": "integer"
          }
        ''');
      case 'http://localhost:1234/baseUriChange/folderInteger.json':
        return json.decode('''
          {
              "type": "integer"
          }
        ''');
      default:
        return null;
        break;
    }
  });

  final RefProvider syncRefProvider = RefProvider.syncSchema((String ref) {
    final schemaDef = syncRefJsonProvider.provide(ref);
    if (schemaDef != null) {
      return JsonSchema.createSchema(schemaDef);
    }

    return null;
  });

  final RefProvider asyncRefJsonProvider = RefProvider.asyncJson((String ref) async {
    // Mock a delayed response.
    await Duration(milliseconds: 1);
    return syncRefJsonProvider.provide(ref);
  });

  final RefProvider asyncRefProvider = RefProvider.asyncSchema((String ref) async {
    // Mock a delayed response.
    await Duration(milliseconds: 1);
    return syncRefProvider.provide(ref);
  });

  final List<String> commonSkippedFiles = const [
    /// Optional in draft7:
    'content.json'
  ];

  /// A list of tests to skip for all drafts.
  /// Should match the portion of the test name printed after the JSON file name on test run.
  final List<String> commonSkippedTests = const [
    // Parsing of large numbers in JSON changed in Dart 2.2, resulting in
    // a more accurate representation of the input, but a type of `double`.
    // Previous versions of Dart pass this test, but the integer output is not
    // equivalent to the JSON input.
    'integer : a bignum is an integer',
    'integer : a negative bignum is an integer',
    // Skip new tests from the spec that we don't pass yet:
    'all integers are multiples of 0.5, if overflow is handled : valid if optional overflow handling is implemented',
  ];

  // Run all tests asynchronously with no ref provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedFiles,
    commonSkippedTests,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedFiles,
    commonSkippedTests,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft7,
    commonSkippedFiles,
    commonSkippedTests,
  );

  // Run all tests synchronously with a sync ref provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: syncRefProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: syncRefProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft7,
    commonSkippedFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: syncRefProvider,
  );

  // Run all tests synchronously with a sync json provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: syncRefJsonProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: syncRefJsonProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft6,
    commonSkippedFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: syncRefJsonProvider,
  );

  // Run all tests asynchronously with an async ref provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedFiles,
    commonSkippedTests,
    refProvider: asyncRefProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedFiles,
    commonSkippedTests,
    refProvider: asyncRefProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft6,
    commonSkippedFiles,
    commonSkippedTests,
    refProvider: asyncRefProvider,
  );

  // Run all tests asynchronously with an async json provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedFiles,
    commonSkippedTests,
    refProvider: asyncRefJsonProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedFiles,
    commonSkippedTests,
    refProvider: asyncRefJsonProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft6,
    commonSkippedFiles,
    commonSkippedTests,
    refProvider: asyncRefJsonProvider,
  );

  group('Schema self validation', () {
    for (final version in SchemaVersion.values.map((value) => value.toString())) {
      test('version: $version', () {
        // Pull in the official schema, verify description and then ensure
        // that the schema satisfies the schema for schemas.
        final url = version;
        JsonSchema.createSchemaFromUrl(url).then(expectAsync1((schema) {
          expect(schema.validate(schema.schemaMap), isTrue);
        }));
      });
    }
  });

  group('Nested \$refs in root schema', () {
    test('properties', () async {
      final barSchema = await JsonSchema.createSchemaAsync({
        "properties": {
          "foo": {"\$ref": "http://localhost:1234/integer.json#"},
          "bar": {"\$ref": "http://localhost:4321/string.json#"}
        },
        "required": ["foo", "bar"]
      });

      final isValid = barSchema.validate({"foo": 2, "bar": "test"});

      final isInvalid = barSchema.validate({"foo": 2, "bar": 4});

      expect(isValid, isTrue);
      expect(isInvalid, isFalse);
    });

    test('items', () async {
      final schema = await JsonSchema.createSchemaAsync({
        "items": {"\$ref": "http://localhost:1234/integer.json"}
      });

      final isValid = schema.validate([1, 2, 3, 4]);
      final isInvalid = schema.validate([1, 2, 3, '4']);

      expect(isValid, isTrue);
      expect(isInvalid, isFalse);
    });

    test('not / anyOf', () async {
      final schema = await JsonSchema.createSchemaAsync({
        "items": {
          "not": {
            "anyOf": [
              {"\$ref": "http://localhost:1234/integer.json#"},
              {"\$ref": "http://localhost:4321/string.json#"},
            ]
          }
        }
      });

      final isValid = schema.validate([3.4]);
      final isInvalid = schema.validate(['test']);

      expect(isValid, isTrue);
      expect(isInvalid, isFalse);
    });
  });

  group('examples property', () {
    group('in draft4', () {
      test('should NOT be supported', () {
        final schema = JsonSchema.createSchema({
          "type": "string",
          "examples": ["This", "message", "is", "lost."]
        }, schemaVersion: SchemaVersion.draft4);

        expect(schema.examples.isEmpty, isTrue);
      });
      test('should still pass the default value to the examples getter', () {
        final schema = JsonSchema.createSchema({
          "type": "string",
          "examples": ["This", "message", "is", "lost."],
          "default": "But this one isn't.",
        }, schemaVersion: SchemaVersion.draft4);

        expect(schema.examples.length, equals(1));
        expect(schema.examples.single, equals("But this one isn't."));
      });
    });

    group('in draft 6', () {
      test('should be supported', () {
        final schema = JsonSchema.createSchema({
          "type": "string",
          "examples": ["This", "message", "is", "not", "lost!"]
        }, schemaVersion: SchemaVersion.draft6);

        expect(schema.examples.length, equals(5));
        expect(schema.examples[4], equals('lost!'));
      });
      test('should append the default value to the examples getter', () {
        final schema = JsonSchema.createSchema({
          "type": "string",
          "examples": ["This", "message", "is", "not", "lost!"],
          "default": "And neither is this one",
        }, schemaVersion: SchemaVersion.draft6);

        expect(schema.examples.length, equals(6));
        expect(schema.examples[0], equals("This"));
        expect(schema.examples[5], equals("And neither is this one"));
      });
    });
  });

  test('Schema from relative filesystem URI should be supported', () async {
    // this assumes that tests are run from the root directory of the project
    final schema = await JsonSchema.createSchemaFromUrl('test/relative_refs/root.json');

    expect(schema.validate({"string": 123, "integer": 123}), isFalse);
    expect(schema.validate({"string": "a string", "integer": "a string"}), isFalse);
    expect(schema.validate({"string": "a string", "integer": 123}), isTrue);
  });

  test('Recursive refs from a remote schema should be supported with a json provider', () async {
    final RefProvider syncRefJsonProvider = RefProvider.syncJson((String ref) {
      switch (ref) {
        case 'http://localhost:1234/tree.json':
          return {
            "\$id": "http://localhost:1234/tree.json",
            "description": "tree of nodes",
            "type": "object",
            "properties": {
              "meta": {"type": "string"},
              "nodes": {
                "type": "array",
                "items": {"\$ref": "node.json"}
              }
            },
            "required": ["meta", "nodes"]
          };
        case 'http://localhost:1234/node.json':
          return {
            "\$id": "http://localhost:1234/node.json",
            "description": "nodes",
            "type": "object",
            "properties": {
              "value": {"type": "number"},
              "subtree": {"\$ref": "tree.json"}
            },
            "required": ["value"]
          };
        default:
          return null;
      }
    });

    final schema = await JsonSchema.createSchema(
      syncRefJsonProvider.provide('http://localhost:1234/tree.json'),
      refProvider: syncRefJsonProvider,
    );

    final isValid = schema.validate({
      "meta": "a string",
      "nodes": [
        {
          "value": 123,
          "subtree": {"meta": "a string", "nodes": []}
        }
      ]
    });

    final isInvalid = schema.validate({
      "meta": "a string",
      "nodes": [
        {
          "value": 123,
          "subtree": {
            "meta": "a string",
            "nodes": [
              {
                "value": 123,
                "subtree": {"meta": 123, "nodes": []}
              }
            ]
          }
        }
      ]
    });

    expect(isValid, isTrue);
    expect(isInvalid, isFalse);
  });

  test('Should respect configurable format validation', () {
    final schema = JsonSchema.createSchema({
      'properties': {
        'someKey': {'format': 'uri-template'}
      }
    });

    final isValidFormatsOn = schema.validate({'someKey': 'http://example.com/dictionary/{term:1}/{term'});

    expect(isValidFormatsOn, isFalse);

    final isValidFormatsOff =
        schema.validate({'someKey': 'http://example.com/dictionary/{term:1}/{term'}, validateFormats: false);

    expect(isValidFormatsOff, isTrue);

    final errorsFormatsOn = schema.validateWithErrors({'someKey': 'http://example.com/dictionary/{term:1}/{term'});

    expect(errorsFormatsOn, isNotEmpty);

    final errorsFormatsOff =
        schema.validateWithErrors({'someKey': 'http://example.com/dictionary/{term:1}/{term'}, validateFormats: false);

    expect(errorsFormatsOff, isEmpty);
  });
}
