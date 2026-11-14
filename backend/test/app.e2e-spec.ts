import { resolveAllowedOrigins } from '../src/main';

describe('Security startup config (e2e-safe)', () => {
  it('blocks wildcard CORS in production', () => {
    expect(() => resolveAllowedOrigins('*', 'production')).toThrow();
  });
});
