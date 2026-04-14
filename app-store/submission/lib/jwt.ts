import * as fs from "fs";
import * as jwt from "jsonwebtoken";

const TOKEN_LIFETIME_SECONDS = 20 * 60; // Apple-Maximum: 20 Minuten

let cachedToken: string | null = null;
let tokenExpiresAt = 0;

export function generateASCToken(): string {
  const now = Math.floor(Date.now() / 1000);

  // Token-Refresh: regeneriere wenn < 2 Minuten Restlaufzeit (Pitfall 3)
  if (cachedToken && tokenExpiresAt - now > 120) {
    return cachedToken;
  }

  const keyId = process.env.APP_STORE_CONNECT_KEY_ID;
  const issuerId = process.env.APP_STORE_CONNECT_ISSUER_ID;
  const keyPath = process.env.APP_STORE_CONNECT_KEY_PATH;

  if (!keyId || !issuerId || !keyPath) {
    throw new Error(
      "Missing ASC env vars: APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_KEY_PATH"
    );
  }

  const privateKey = fs.readFileSync(keyPath, "utf-8");
  const exp = now + TOKEN_LIFETIME_SECONDS;

  const token = jwt.sign(
    {
      iss: issuerId,
      aud: "appstoreconnect-v1",
      exp,
    },
    privateKey,
    {
      algorithm: "ES256",
      header: {
        alg: "ES256",
        kid: keyId,
        typ: "JWT",
      },
    }
  );

  cachedToken = token;
  tokenExpiresAt = exp;
  return token;
}
