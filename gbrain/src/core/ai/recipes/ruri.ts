import type { Recipe } from '../types.ts';

export const ruri: Recipe = {
  id: 'ruri',
  name: 'Ruri v3 (local)',
  tier: 'native',
  implementation: 'native-ruri',
  auth_env: {
    required: [],
    optional: [
      'GBRAIN_RURI_UV',
      'GBRAIN_RURI_WORKER',
      'GBRAIN_RURI_MODEL',
      'GBRAIN_RURI_DEVICE',
    ],
  },
  touchpoints: {
    embedding: {
      models: ['ruri-v3-310m'],
      default_dims: 768,
      cost_per_1m_tokens_usd: 0,
      price_last_verified: '2026-05-26',
      max_batch_tokens: 6000,
      chars_per_token: 1,
      safety_factor: 0.8,
    },
  },
  setup_hint:
    'Run locally with uv. The native provider starts scripts/ruri_embed_worker.py and loads cl-nagoya/ruri-v3-310m via sentence-transformers.',
};
