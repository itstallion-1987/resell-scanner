// In-memory замена KVNamespace для юнит-тестов.
export class MockKV {
  store = new Map<string, string>();
  // Последние options на put по ключу — чтобы проверять expirationTtl
  ttls = new Map<string, number | undefined>();

  async get(key: string): Promise<string | null> {
    return this.store.get(key) ?? null;
  }

  async put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void> {
    this.store.set(key, value);
    this.ttls.set(key, options?.expirationTtl);
  }
}

export function asKV(kv: MockKV): KVNamespace {
  return kv as unknown as KVNamespace;
}
