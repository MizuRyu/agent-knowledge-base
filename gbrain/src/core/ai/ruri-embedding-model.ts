import type { EmbeddingModelV3 } from '@ai-sdk/provider';
import { embedWithRuriWorker } from './ruri-worker.ts';

function resolveInputType(providerOptions: unknown): 'document' | 'query' {
  const ruri = (providerOptions as any)?.ruri;
  return ruri?.input_type === 'query' ? 'query' : 'document';
}

function estimateTokens(values: string[]): number {
  return values.reduce((sum, value) => sum + Math.ceil((value ?? '').length), 0);
}

export class RuriEmbeddingModel implements EmbeddingModelV3 {
  readonly specificationVersion = 'v3';
  readonly provider = 'ruri';
  readonly modelId: string;
  readonly maxEmbeddingsPerCall = undefined;
  readonly supportsParallelCalls = true;

  constructor(modelId: string) {
    this.modelId = modelId;
  }

  async doEmbed({
    values,
    abortSignal,
    providerOptions,
  }: Parameters<EmbeddingModelV3['doEmbed']>[0]): Promise<Awaited<ReturnType<EmbeddingModelV3['doEmbed']>>> {
    const embeddings = await embedWithRuriWorker(
      this.modelId,
      values,
      resolveInputType(providerOptions),
      abortSignal,
    );
    return {
      embeddings,
      usage: { tokens: estimateTokens(values) },
      warnings: [],
    };
  }
}
