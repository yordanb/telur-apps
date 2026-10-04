import { useCallback, useEffect, useState } from 'react';
import { list } from '../lib/crud';

export interface ListState<T> {
  rows: T[];
  loading: boolean;
  loadingMore: boolean;
  error: string | null;
  hasMore: boolean;
  reload: () => void;
  loadMore: () => void;
}

/**
 * Hook list generik mengikuti pola CRUD backend:
 * ?skip=&limit=&start_date=&end_date= + filter tambahan.
 */
export function useList<T>(
  path: string,
  filters: Record<string, string | undefined>,
  limit = 20,
): ListState<T> {
  const key = JSON.stringify({ path, filters, limit });
  const [rows, setRows] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(true);

  const fetchPage = useCallback(async (skip: number): Promise<T[]> => {
    const parsed = JSON.parse(key) as { path: string; filters: Record<string, string | undefined>; limit: number };
    const q = new URLSearchParams();
    for (const [k, v] of Object.entries(parsed.filters)) {
      if (v) q.set(k, v);
    }
    q.set('skip', String(skip));
    q.set('limit', String(parsed.limit));
    return list<T>(`${parsed.path}?${q.toString()}`);
  }, [key]);

  const loadFirst = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchPage(0);
      setRows(data);
      const parsed = JSON.parse(key) as { limit: number };
      setHasMore(data.length >= parsed.limit);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    } finally {
      setLoading(false);
    }
  }, [fetchPage, key]);

  useEffect(() => {
    void loadFirst();
  }, [loadFirst]);

  const loadMore = useCallback(async () => {
    setLoadingMore(true);
    try {
      const data = await fetchPage(rows.length);
      setRows((prev) => [...prev, ...data]);
      const parsed = JSON.parse(key) as { limit: number };
      setHasMore(data.length >= parsed.limit);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    } finally {
      setLoadingMore(false);
    }
  }, [fetchPage, rows.length, key]);

  return { rows, loading, loadingMore, error, hasMore, reload: loadFirst, loadMore };
}
