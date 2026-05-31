import { describe, expect, test } from 'bun:test';
import { getRecipe, listRecipes } from '../../src/core/ai/recipes/index.ts';
import { dimsProviderOptions } from '../../src/core/ai/dims.ts';

describe('ruri recipe', () => {
  test('registers local native ruri embedding provider', () => {
    const recipe = getRecipe('ruri');
    expect(recipe).toBeDefined();
    expect(listRecipes().some(r => r.id === 'ruri')).toBe(true);
    expect(recipe!.tier).toBe('native');
    expect(recipe!.implementation).toBe('native-ruri');
    expect(recipe!.auth_env?.required ?? []).toEqual([]);
    expect(recipe!.touchpoints.embedding?.models).toContain('ruri-v3-310m');
    expect(recipe!.touchpoints.embedding?.default_dims).toBe(768);
    expect(recipe!.touchpoints.embedding?.cost_per_1m_tokens_usd).toBe(0);
  });

  test('threads document/query input type through provider options', () => {
    expect(dimsProviderOptions('native-ruri', 'ruri-v3-310m', 768, 'document')).toEqual({
      ruri: { input_type: 'document' },
    });
    expect(dimsProviderOptions('native-ruri', 'ruri-v3-310m', 768, 'query')).toEqual({
      ruri: { input_type: 'query' },
    });
  });
});
