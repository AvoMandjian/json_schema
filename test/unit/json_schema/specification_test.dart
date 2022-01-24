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

import 'dart:convert';
import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../constants.dart';
import '../specification_remotes.dart';
import '../specification_tests.dart';

void main() {
  final allDraft4 =
      specificationTests.entries.where((MapEntry<String, String> entry) => entry.key.startsWith('/draft4'));
  final allDraft6 =
      specificationTests.entries.where((MapEntry<String, String> entry) => entry.key.startsWith('/draft6'));
  final allDraft7 =
      specificationTests.entries.where((MapEntry<String, String> entry) => entry.key.startsWith('/draft7'));

  final runAllTestsForDraftX = (SchemaVersion schemaVersion, Iterable<MapEntry<String, String>> allTests,
      List<String> skipFiles, List<String> skipTests,
      {bool isSync = false, RefProvider refProvider}) {
    String shortSchemaVersion = schemaVersion.toString();
    if (schemaVersion == SchemaVersion.draft4) {
      shortSchemaVersion = 'draft4';
    } else if (schemaVersion == SchemaVersion.draft6) {
      shortSchemaVersion = 'draft6';
    } else if (schemaVersion == SchemaVersion.draft7) {
      shortSchemaVersion = 'draft7';
    }

    allTests.forEach((testEntry) {
      if (testEntry is MapEntry) {
        final checkResult = (List<ValidationError> validationResults, bool expectedResult) {
          if (validationResults.isEmpty != expectedResult && expectedResult == true) {
            validationResults.forEach((error) {
              print(error);
            });
          }
          expect(validationResults.isEmpty, expectedResult);
        };

        group('Validations ($shortSchemaVersion) ${path.basename(testEntry.key)}', () {
          // Skip these for now - reason shown.
          if (skipFiles.contains(path.basename(testEntry.key))) return;

          final List tests = json.decode(testEntry.value);
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
                List<ValidationError> validationResults;
                final bool expectedResult = validationTest['valid'];

                if (isSync) {
                  final schema = JsonSchema.create(
                    schemaData,
                    schemaVersion: schemaVersion,
                    refProvider: refProvider,
                  );
                  validationResults = schema.validateWithErrors(instance);
                  expect(validationResults.isEmpty, expectedResult);
                } else {
                  final checkResultAsync = expectAsync2(checkResult);
                  JsonSchema.createAsync(schemaData, schemaVersion: schemaVersion, refProvider: refProvider)
                      .then((schema) {
                    validationResults = schema.validateWithErrors(instance);
                    checkResultAsync(validationResults, expectedResult);
                  });
                }
              });
            });
          });
        });
      }
    });
  };

  // Mock Ref Provider for refRemote tests. Emulates what createFromUrl would return.
  final RefProvider syncRefProvider = RefProvider.sync((String ref) {
    return json.decode(specificationRemotes[ref]);
  });

  // ignore: deprecated_member_use_from_same_package
  final RefProvider deprecatedSyncRefSchemaProvider = RefProvider.syncSchema((String ref) {
    final schemaDef = syncRefProvider.provide(ref);
    if (schemaDef != null) {
      return JsonSchema.create(schemaDef);
    }

    return null;
  });

  final RefProvider asyncRefProvider = RefProvider.async((String ref) async {
    // Mock a delayed response.
    await Future.delayed(Duration(microseconds: 1));
    return syncRefProvider.provide(ref);
  });

  // ignore: deprecated_member_use_from_same_package
  final RefProvider deprecatedAsyncRefSchemaProvider = RefProvider.asyncSchema((String ref) async {
    // Mock a delayed response.
    await Future.delayed(Duration(microseconds: 1));
    return deprecatedSyncRefSchemaProvider.provide(ref);
  });

  // Run all tests asynchronously with no ref provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedTestFiles,
    commonSkippedTests,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedTestFiles,
    commonSkippedTests,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft7,
    commonSkippedTestFiles,
    commonSkippedTests,
  );

  // Run all tests synchronously with a sync ref provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedTestFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: deprecatedSyncRefSchemaProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedTestFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: deprecatedSyncRefSchemaProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft7,
    commonSkippedTestFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: deprecatedSyncRefSchemaProvider,
  );

  // Run all tests synchronously with a sync json provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedTestFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: syncRefProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedTestFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: syncRefProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft6,
    commonSkippedTestFiles,
    commonSkippedTests,
    isSync: true,
    refProvider: syncRefProvider,
  );

  // Run all tests asynchronously with an async ref provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedTestFiles,
    commonSkippedTests,
    refProvider: deprecatedAsyncRefSchemaProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedTestFiles,
    commonSkippedTests,
    refProvider: deprecatedAsyncRefSchemaProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft6,
    commonSkippedTestFiles,
    commonSkippedTests,
    refProvider: deprecatedAsyncRefSchemaProvider,
  );

  // Run all tests asynchronously with an async json provider.
  runAllTestsForDraftX(
    SchemaVersion.draft4,
    allDraft4,
    commonSkippedTestFiles,
    commonSkippedTests,
    refProvider: asyncRefProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft6,
    allDraft6,
    commonSkippedTestFiles,
    commonSkippedTests,
    refProvider: asyncRefProvider,
  );
  runAllTestsForDraftX(
    SchemaVersion.draft7,
    allDraft6,
    commonSkippedTestFiles,
    commonSkippedTests,
    refProvider: asyncRefProvider,
  );
}