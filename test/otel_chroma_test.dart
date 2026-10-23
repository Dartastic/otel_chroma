// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_chroma/otel_chroma.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_chroma-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('query records CLIENT span', () async {
    await tracedChromaQuery<String>(
      collection: 'docs',
      topK: 5,
      embeddingDim: 1536,
      invoke: () async => const ChromaQueryResult(
        value: 'hits',
        resultCount: 5,
      ),
    );
    final a = attrsOf(spans.findSpanByName('chroma query docs')!);
    expect(a['db.system'], 'chroma');
    expect(a['db.operation'], 'query');
    expect(a['chroma.collection'], 'docs');
    expect(a['vector_db.search.top_k'], 5);
    expect(a['vector_db.embedding.dim'], 1536);
    expect(a['vector_db.search.result_count'], 5);
  });

  test('upsert records CLIENT span', () async {
    await tracedChromaUpsert<String>(
      operation: 'upsert',
      collection: 'docs',
      itemCount: 100,
      invoke: () async => 'ok',
    );
    final a = attrsOf(spans.findSpanByName('chroma upsert docs')!);
    expect(a['db.operation'], 'upsert');
    expect(a['vector_db.upsert.item_count'], 100);
  });

  test('suppression skips spans', () async {
    await runWithoutChromaInstrumentationAsync(() async {
      await tracedChromaQuery<String>(
        collection: 'c',
        invoke: () async => const ChromaQueryResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('chroma '), isEmpty);
  });
}
