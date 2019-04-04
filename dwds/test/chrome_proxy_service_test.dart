// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:dwds/src/chrome_proxy_service.dart';

import 'package:http/http.dart' as http;
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';
import 'package:vm_service_lib/vm_service_lib.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

import 'test_context.dart';

final context = TestContext();
ChromeProxyService get service => context.service;
WipConnection get tabConnection => context.tabConnection;

void main() {
  setUpAll(() async {
    await context.setUp();
  });

  tearDownAll(() async {
    await context.tearDown();
  });

  group('breakpoints', () {
    VM vm;
    Isolate isolate;
    ScriptList scripts;
    ScriptRef mainScript;

    setUp(() async {
      vm = await service.getVM();
      isolate = await service.getIsolate(vm.isolates.first.id) as Isolate;
      scripts = await service.getScripts(isolate.id);
      mainScript =
          scripts.scripts.firstWhere((each) => each.uri.contains('main.dart'));
    });

    test('addBreakPoint', () async {
      //  ### separately test - setting breakpoint and the JS/dart position is right.
      // Returning the SourceLocation (i.e. token position).
      // Move these tests to a separate test file? Or does that help?
      // 
      await service.addBreakpoint(isolate.id, mainScript.id, 19);
      var breakpoints = isolate.breakpoints;
      expect(breakpoints, isNotEmpty);
      expect (breakpoints.any((b) => b.location.tokenPos == 42), isNotNull);
      
     });

    test('addBreakpointAtEntry', () {
      expect(() => service.addBreakpointAtEntry(null, null),
          throwsUnimplementedError);
    });

    test('addBreakpointWithScriptUri', () {
      expect(() => service.addBreakpointWithScriptUri(null, null, null),
          throwsUnimplementedError);
    });
  });

  group('callServiceExtension', () {
    test('success', () async {
      var serviceMethod = 'ext.test.callServiceExtension';
      await tabConnection.runtime
          .evaluate('registerExtension("$serviceMethod");');

      // The non-string keys/values get auto json-encoded to match the vm
      // behavior.
      var args = {
        'bool': true,
        'list': [1, '2', 3],
        'map': {'foo': 'bar'},
        'num': 1.0,
        'string': 'hello',
        1: 2,
        false: true,
      };
      var result =
          await service.callServiceExtension(serviceMethod, args: args);
      expect(
          result.json,
          args.map((k, v) => MapEntry(k is String ? k : jsonEncode(k),
              v is String ? v : jsonEncode(v))));
    });

    test('failure', () async {
      var serviceMethod = 'ext.test.callServiceExtensionWithError';
      await tabConnection.runtime
          .evaluate('registerExtensionWithError("$serviceMethod");');

      var errorDetails = {'intentional': 'error'};
      expect(
          service.callServiceExtension(serviceMethod, args: {
            'code': '-32001',
            'details': jsonEncode(errorDetails),
          }),
          throwsA(predicate((error) =>
              error is RPCError &&
              error.code == -32001 &&
              error.details == jsonEncode(errorDetails))));
    });
  });

  test('clearCpuProfile', () {
    expect(() => service.clearCpuProfile(null), throwsUnimplementedError);
  });

  test('clearVMTimeline', () {
    expect(() => service.clearVMTimeline(), throwsUnimplementedError);
  });

  test('clearVMTimeline', () {
    expect(() => service.clearVMTimeline(), throwsUnimplementedError);
  });

  test('collectAllGarbage', () {
    expect(() => service.collectAllGarbage(null), throwsUnimplementedError);
  });

  test('clearVMTimeline', () {
    expect(() => service.clearVMTimeline(), throwsUnimplementedError);
  });

  group('evaluate', () {
    Isolate isolate;
    setUpAll(() async {
      var vm = await service.getVM();
      isolate = await service.getIsolate(vm.isolates.first.id) as Isolate;
    });

    group('top level methods', () {
      test('can return strings', () async {
        expect(
            await service.evaluate(
                isolate.id, isolate.rootLib.id, "helloString('world')"),
            const TypeMatcher<InstanceRef>().having(
                (instance) => instance.valueAsString, 'value', 'world'));
      });

      test('can return bools', () async {
        expect(
            await service.evaluate(
                isolate.id, isolate.rootLib.id, 'helloBool(true)'),
            const TypeMatcher<InstanceRef>().having(
                (instance) => instance.valueAsString, 'valueAsString', 'true'));
        expect(
            await service.evaluate(
                isolate.id, isolate.rootLib.id, 'helloBool(false)'),
            const TypeMatcher<InstanceRef>().having(
                (instance) => instance.valueAsString,
                'valueAsString',
                'false'));
      });

      test('can return nums', () async {
        expect(
            await service.evaluate(
                isolate.id, isolate.rootLib.id, 'helloNum(42.0)'),
            const TypeMatcher<InstanceRef>().having(
                (instance) => instance.valueAsString, 'valueAsString', '42'));
        expect(
            await service.evaluate(
                isolate.id, isolate.rootLib.id, 'helloNum(42.2)'),
            const TypeMatcher<InstanceRef>().having(
                (instance) => instance.valueAsString, 'valueAsString', '42.2'));
      });
    });
  });

  test('evaluateInFrame', () {
    expect(() => service.evaluateInFrame(null, null, null),
        throwsUnimplementedError);
  });

  test('getAllocationProfile', () {
    expect(() => service.getAllocationProfile(null), throwsUnimplementedError);
  });

  test('getCpuProfile', () {
    expect(() => service.getCpuProfile(null, null), throwsUnimplementedError);
  });

  test('getFlagList', () {
    expect(() => service.getFlagList(), throwsUnimplementedError);
  });

  test('getInstances', () {
    expect(
        () => service.getInstances(null, null, null), throwsUnimplementedError);
  });

  group('getIsolate', () {
    test('works for existing isolates', () async {
      var vm = await service.getVM();
      var result = await service.getIsolate(vm.isolates.first.id);
      expect(result, const TypeMatcher<Isolate>());
      var isolate = result as Isolate;
      expect(isolate.name, contains(context.appUrl));
      expect(isolate.rootLib.uri, 'hello_world/main.dart');
      expect(
          isolate.libraries,
          containsAll([
            predicate((LibraryRef lib) => lib.uri == 'dart:core'),
            predicate((LibraryRef lib) => lib.uri == 'dart:html'),
            predicate((LibraryRef lib) => lib.uri == 'package:path/path.dart'),
            predicate((LibraryRef lib) => lib.uri == 'hello_world/main.dart'),
          ]));
      expect(isolate.extensionRPCs, contains('ext.hello_world.existing'));
    });

    test('throws for invalid ids', () async {
      expect(service.getIsolate('bad'), throwsArgumentError);
    });
  });

  group('getObject', () {
    Isolate isolate;
    Library rootLibrary;
    setUpAll(() async {
      var vm = await service.getVM();
      isolate = await service.getIsolate(vm.isolates.first.id) as Isolate;
      rootLibrary =
          await service.getObject(isolate.id, isolate.rootLib.id) as Library;
    });

    test('Libraries', () async {
      expect(rootLibrary, isNotNull);
      expect(rootLibrary.uri, 'hello_world/main.dart');
      expect(rootLibrary.classes.length, 1);
      var testClass = rootLibrary.classes.first;
      expect(testClass.name, 'MyTestClass');
    });

    test('Classes', () async {
      var testClass = await service.getObject(
          isolate.id, rootLibrary.classes.first.id) as Class;

      expect(
          testClass.functions,
          unorderedEquals([
            predicate((FuncRef f) => f.name == 'hello' && !f.isStatic),
          ]));
    });

    test('Scripts', () async {
      var scripts = await service.getScripts(isolate.id);
      assert(scripts.scripts.isNotEmpty);
      for (var scriptRef in scripts.scripts) {
        var script =
            await service.getObject(isolate.id, scriptRef.id) as Script;
        var result = await http.get('http://localhost:${context.port}/'
            '${script.uri.replaceAll("package:", "packages/")}');
        expect(script.source, result.body);
        expect(scriptRef.uri, endsWith('.dart'));
      }
    });
  });

  test('getScripts', () async {
    var vm = await service.getVM();
    var isolateId = vm.isolates.first.id;
    var scripts = await service.getScripts(isolateId);
    expect(scripts, isNotNull);
    expect(scripts.scripts.length, greaterThan(0));
    // Test for a known script
    expect(scripts.scripts.map((s) => s.uri), contains(endsWith('path.dart')));
  });

  test('clearVMTimeline', () {
    expect(() => service.clearVMTimeline(), throwsUnimplementedError);
  });

  test('getSourceReport', () {
    expect(() => service.getSourceReport(null, null), throwsUnimplementedError);
  });

  test('getStack', () {
    expect(() => service.getStack(null), throwsUnimplementedError);
  });

  test('getVM', () async {
    var vm = await service.getVM();
    expect(vm.name, isNotNull);
    expect(vm.version, Platform.version);
    expect(vm.isolates.length, equals(1));
    var isolate = vm.isolates.first;
    expect(isolate.id, isNotNull);
    expect(isolate.name, isNotNull);
    expect(isolate.number, isNotNull);
  });

  test('getVersion', () async {
    var version = await service.getVersion();
    expect(version, isNotNull);
    expect(version.major, greaterThan(0));
  });

  test('invoke', () {
    expect(
        () => service.invoke(null, null, null, null), throwsUnimplementedError);
  });

  test('kill', () {
    expect(() => service.kill(null), throwsUnimplementedError);
  });

  test('onEvent', () {
    expect(() => service.onEvent(null), throwsUnimplementedError);
  });

  test('pause / resume', () async {
    var vm = await service.getVM();
    var isolateId = vm.isolates.first.id;
    var pauseCompleter = Completer();
    var pauseSub = tabConnection.debugger.onPaused.listen((_) {
      pauseCompleter.complete();
    });
    var resumeCompleter = Completer();
    var resumseSub = tabConnection.debugger.onResumed.listen((_) {
      resumeCompleter.complete();
    });
    expect(await service.pause(isolateId), const TypeMatcher<Success>());
    await pauseCompleter.future;
    expect(await service.resume(isolateId), const TypeMatcher<Success>());
    await resumeCompleter.future;
    await pauseSub.cancel();
    await resumseSub.cancel();
  });

  test('registerService', () async {
    expect(() => service.registerService('ext.foo.bar', null),
        throwsUnimplementedError);
  });

  test('reloadSources', () {
    expect(() => service.reloadSources(null), throwsUnimplementedError);
  });

  test('removeBreakpoint', () {
    expect(
        () => service.removeBreakpoint(null, null), throwsUnimplementedError);
  });

  test('requestHeapSnapshot', () {
    expect(() => service.requestHeapSnapshot(null, null, null),
        throwsUnimplementedError);
  });

  test('setExceptionPauseMode', () {
    expect(() => service.setExceptionPauseMode(null, null),
        throwsUnimplementedError);
  });

  test('setFlag', () {
    expect(() => service.setFlag(null, null), throwsUnimplementedError);
  });

  test('setLibraryDebuggable', () {
    expect(() => service.setLibraryDebuggable(null, null, null),
        throwsUnimplementedError);
  });

  test('setName', () async {
    var vm = await service.getVM();
    var isolateId = vm.isolates.first.id;
    expect(service.setName(isolateId, 'test'), completion(isSuccess));
    var isolate = await service.getIsolate(isolateId);
    expect(isolate.name, 'test');
  });

  test('setVMName', () async {
    expect(service.setVMName('foo'), completion(isSuccess));
    var vm = await service.getVM();
    expect(vm.name, 'foo');
  });

  test('setVMTimelineFlags', () {
    expect(() => service.setVMTimelineFlags(null), throwsUnimplementedError);
  });

  test('streamCancel', () {
    expect(() => service.streamCancel(null), throwsUnimplementedError);
  });

  group('streamListen/onEvent', () {
    group('Debug', () {
      Stream<Event> eventStream;

      setUp(() async {
        expect(
            await service.streamListen('Debug'), const TypeMatcher<Success>());
        eventStream = service.onEvent('Debug');
      });

      test('basic Pause/Resume', () async {
        expect(service.streamListen('Debug'), completion(isSuccess));
        var stream = service.onEvent('Debug');
        unawaited(tabConnection.debugger.pause());
        await expectLater(
            stream,
            emitsThrough(const TypeMatcher<Event>()
                .having((e) => e.kind, 'kind', EventKind.kPauseInterrupted)));
        unawaited(tabConnection.debugger.resume());
        expect(
            eventStream,
            emitsThrough(const TypeMatcher<Event>()
                .having((e) => e.kind, 'kind', EventKind.kResume)));
      });

      test('Inspect', () async {
        expect(
            eventStream,
            emitsThrough(const TypeMatcher<Event>()
                .having((e) => e.kind, 'kind', EventKind.kInspect)
                .having(
                    (e) => e.inspectee,
                    'inspectee',
                    const TypeMatcher<InstanceRef>()
                        .having((instance) => instance.id, 'id', isNotNull)
                        .having((instance) => instance.kind, 'inspectee.kind',
                            InstanceKind.kPlainInstance))));
        await tabConnection.runtime.evaluate('inspectInstance()');
      });
    });

    test('Extension', () async {
      expect(service.streamListen('Extension'), completion(isSuccess));
      var stream = service.onEvent('Extension');
      var eventKind = 'my.custom.event';
      expect(
          stream,
          emitsThrough(predicate((Event event) =>
              event.kind == EventKind.kExtension &&
              event.extensionKind == eventKind &&
              event.extensionData.data['example'] == 'data')));
      await tabConnection.runtime.evaluate("postEvent('$eventKind');");
    });

    test('GC', () async {
      expect(service.streamListen('GC'), completion(isSuccess));
    });

    group('Isolate', () {
      Stream<Event> isolateEventStream;

      setUp(() async {
        expect(await service.streamListen('Isolate'), isSuccess);
        isolateEventStream = service.onEvent('Isolate');
      });

      test('ServiceExtensionAdded', () async {
        var extensionMethod = 'ext.foo.bar';
        expect(
            isolateEventStream,
            emitsThrough(predicate((Event event) =>
                event.kind == EventKind.kServiceExtensionAdded &&
                event.extensionRPC == extensionMethod)));
        await tabConnection.runtime
            .evaluate("registerExtension('$extensionMethod');");
      });

      test('lifecycle events', () async {
        var vm = await service.getVM();
        var initialIsolateId = vm.isolates.first.id;
        var eventsDone = expectLater(
            isolateEventStream,
            emitsThrough(emitsInOrder([
              predicate((Event event) =>
                  event.kind == EventKind.kIsolateExit &&
                  event.isolate.id == initialIsolateId),
              predicate((Event event) =>
                  event.kind == EventKind.kIsolateStart &&
                  event.isolate.id != initialIsolateId),
              predicate((Event event) =>
                  event.kind == EventKind.kIsolateRunnable &&
                  event.isolate.id != initialIsolateId),
            ])));
        service.destroyIsolate();
        await service.createIsolate();
        await eventsDone;
        expect(
            (await service.getVM()).isolates.first.id, isNot(initialIsolateId));
      });
    });

    test('Timeline', () async {
      expect(service.streamListen('Timeline'), completion(isSuccess));
    });

    test('Stdout', () async {
      expect(service.streamListen('Stdout'), completion(isSuccess));
      expect(
          service.onEvent('Stdout'),
          emitsThrough(predicate((Event event) =>
              event.kind == EventKind.kWriteEvent &&
              String.fromCharCodes(base64.decode(event.bytes))
                  .contains('hello'))));
      await tabConnection.runtime.evaluate('console.log("hello");');
    });

    test('Stderr', () async {
      expect(service.streamListen('Stderr'), completion(isSuccess));
      var stderrStream = service.onEvent('Stderr');
      expect(
          stderrStream,
          emitsThrough(predicate((Event event) =>
              event.kind == EventKind.kWriteEvent &&
              String.fromCharCodes(base64.decode(event.bytes))
                  .contains('Error'))));
      await tabConnection.runtime.evaluate('console.error("Error");');
    });

    test('VM', () async {
      var status = await service.streamListen('VM');
      expect(status, isSuccess);
      var stream = service.onEvent('VM');
      expect(
          stream,
          emitsThrough(predicate((Event e) =>
              e.kind == EventKind.kVMUpdate && e.vm.name == 'test')));
      await service.setVMName('test');
    });
  });
}

const isSuccess = TypeMatcher<Success>();
