import { generateASCToken } from "./jwt";

const ASC_BASE = "https://api.appstoreconnect.apple.com";

export class AscApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly body: unknown,
    message: string
  ) {
    super(message);
    this.name = "AscApiError";
  }
}

export async function ascFetch<T = unknown>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const token = generateASCToken();
  const url = path.startsWith("http") ? path : `${ASC_BASE}${path}`;

  const response = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...((options.headers as Record<string, string>) ?? {}),
    },
  });

  if (!response.ok) {
    const body = await response.json().catch(() => response.text());
    throw new AscApiError(
      response.status,
      body,
      `ASC API ${options.method ?? "GET"} ${path} → ${response.status}: ${JSON.stringify(body)}`
    );
  }

  if (response.status === 204) return {} as T;
  return response.json() as Promise<T>;
}

export async function withRetry<T>(
  fn: () => Promise<T>,
  maxAttempts = 5
): Promise<T> {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err: unknown) {
      const isRateLimit = err instanceof AscApiError && err.status === 429;
      if (!isRateLimit || attempt === maxAttempts - 1) throw err;
      const delay = Math.pow(2, attempt) * 1000 + Math.random() * 500;
      console.log(
        `Rate limited (429), retrying in ${Math.round(delay)}ms... (attempt ${attempt + 1}/${maxAttempts})`
      );
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
  throw new Error("Max retries exceeded");
}
