// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_chroma/otel_chroma.dart';

/// Traces Chroma calls with OpenTelemetry.
///
/// `otel_chroma` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Chroma call in
/// [tracedChromaQuery]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'chroma-example');

  // Wraps a Chroma query (similarity search) in a CLIENT span.
  final chromaQueryId = await tracedChromaQuery<String>(
    collection: 'orders',
    topK: 1,
    embeddingDim: 1,
    invoke: () async {
      // Make the Chroma call here, then report what it returned.
      const id = 'chroma_8f3a2c';
      return const ChromaQueryResult(value: id, resultCount: 3);
    },
  );
  OTelLog.info('tracedChromaQuery returned $chromaQueryId');

  // Wraps a Chroma upsert/add/delete in a CLIENT span.
  final chromaUpsertId = await tracedChromaUpsert<String>(
    operation: 'create',
    collection: 'orders',
    itemCount: 3,
    invoke: () async {
      // Make the Chroma call here, then report what it returned.
      return 'chroma_8f3a2c';
    },
  );
  OTelLog.info('tracedChromaUpsert create returned $chromaUpsertId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutChromaInstrumentationAsync.
  await runWithoutChromaInstrumentationAsync(
    () => tracedChromaQuery<String>(
      collection: 'orders',
      topK: 1,
      embeddingDim: 1,
      invoke: () async {
        const id = 'chroma_8f3a2c';
        return const ChromaQueryResult(value: id, resultCount: 3);
      },
    ),
  );

  await OTel.shutdown();
}
