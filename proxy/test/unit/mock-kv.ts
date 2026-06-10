// In-memory замена KVNamespace для юнит-тестов.
export class MockKV {
  store = new Map<string, string>();

  async get(key: string): Promise<string | null> {
    return this.store.get(key) ?? null;
  }

  async put(key: string, value: string, _options?: unknown): Promise<void> {
    this.store.set(key, value);
  }
}

export function asKV(kv: MockKV): KVNamespace {
  return kv as unknown as KVNamespace;
}
