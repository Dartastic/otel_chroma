// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_chroma_suppression.dart';

const _tracerName = 'dartastic_otel_libs_chroma';
const _systemValue = 'chroma';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedChromaQuery` callback.
class ChromaQueryResult<T> {
  const ChromaQueryResult({required this.value, this.resultCount});
  final T value;
  final int? resultCount;
}

/// Wraps a Chroma `query` (similarity search) in a CLIENT span.
Future<T> tracedChromaQuery<T>({
  required String collection,
  required Future<ChromaQueryResult<T>> Function() invoke,
  int? topK,
  int? embeddingDim,
}) async {
  if (chromaInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': 'query',
    'db.collection.name': collection,
    'chroma.collection': collection,
  };
  if (topK != null) m['vector_db.search.top_k'] = topK;
  if (embeddingDim != null) m['vector_db.embedding.dim'] = embeddingDim;

  final span = _tracer().startSpan(
    'chroma query $collection',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.resultCount != null) {
      span.addAttributes(OTel.attributes([
        OTel.attributeInt('vector_db.search.result_count', r.resultCount!),
      ]));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Wraps a Chroma upsert/add/delete in a CLIENT span.
Future<T> tracedChromaUpsert<T>({
  required String operation,
  required String collection,
  required Future<T> Function() invoke,
  int? itemCount,
}) async {
  if (chromaInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': operation,
    'db.collection.name': collection,
    'chroma.collection': collection,
  };
  if (itemCount != null) m['vector_db.upsert.item_count'] = itemCount;

  final span = _tracer().startSpan(
    'chroma $operation $collection',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
