const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, content-type, x-api-key, x-auth-token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_TIMEOUT_MS = 10000;
const GOOGLE_TOKEN_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_AUDIENCE = "https://oauth2.googleapis.com/token";
const GOOGLE_TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";

let cachedGoogleToken = null;
let cachedGoogleTokenExpiresAt = 0;

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function getProvidedAuth(request, payload) {
  const authHeader = request.headers.get("authorization") ?? "";
  const bearerValue = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : authHeader.trim();

  const apiKeyValue = request.headers.get("x-api-key")?.trim() ?? "";
  const authTokenHeader = request.headers.get("x-auth-token")?.trim() ?? "";
  const queryToken = new URL(request.url).searchParams.get("token")?.trim() ?? "";
  const payloadAuthToken =
    typeof payload?.auth_token === "string" ? payload.auth_token.trim() : "";

  return [bearerValue, apiKeyValue, authTokenHeader, queryToken, payloadAuthToken]
    .find((value) => value.length > 0) ?? "";
}

function getExpectedAuth(env) {
  return (
    env.PUSH_WEBHOOK_AUTH ??
    env.WEBHOOK_AUTH ??
    env.AUTH_TOKEN ??
    ""
  ).trim();
}

function validatePayload(payload) {
  if (!payload || typeof payload !== "object") {
    return "Invalid JSON payload.";
  }

  if (typeof payload.token !== "string" || payload.token.trim().length < 8) {
    return "token is required.";
  }

  if (typeof payload.title !== "string" || payload.title.trim().length < 1) {
    return "title is required.";
  }

  if (typeof payload.body !== "string" || payload.body.trim().length < 1) {
    return "body is required.";
  }

  return null;
}

async function sendWithFcmLegacy(env, payload) {
  const config = getFcmConfig(env);
  if (!config.ok) {
    return {
      ok: false,
      provider: "fcm_v1",
      error: config.error,
    };
  }

  let accessToken;
  try {
    accessToken = await getGoogleAccessToken(config.clientEmail, config.privateKey);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to obtain Google access token.";
    return {
      ok: false,
      provider: "fcm_v1",
      error: message,
    };
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT_MS);

  const messageData = stringifyDataMap(payload.data);

  try {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${config.projectId}/messages:send`,
      {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: payload.token.trim(),
          notification: {
            title: payload.title.trim(),
            body: payload.body.trim(),
          },
          data: messageData,
          android: {
            priority: "HIGH",
          },
        },
      }),
      signal: controller.signal,
    }
    );

    const rawText = await response.text();
    let parsed;
    try {
      parsed = JSON.parse(rawText);
    } catch {
      parsed = null;
    }

    if (!response.ok) {
      return {
        ok: false,
        provider: "fcm_v1",
        status: response.status,
        error: "FCM request failed.",
        response: parsed ?? rawText,
      };
    }

    if (typeof parsed?.name !== "string" || parsed.name.length < 1) {
      return {
        ok: false,
        provider: "fcm_v1",
        error: "FCM v1 response did not include message name.",
        response: parsed ?? rawText,
      };
    }

    return {
      ok: true,
      provider: "fcm_v1",
      response: parsed ?? rawText,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return {
      ok: false,
      provider: "fcm_v1",
      error: message,
    };
  } finally {
    clearTimeout(timeout);
  }
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    if (request.method !== "POST") {
      return jsonResponse(405, {
        ok: false,
        error: "Method not allowed. Use POST.",
      });
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return jsonResponse(400, {
        ok: false,
        error: "Request body must be valid JSON.",
      });
    }

    const expectedAuth = getExpectedAuth(env);
    if (!expectedAuth) {
      return jsonResponse(500, {
        ok: false,
        error: "Webhook auth is not configured.",
      });
    }

    const providedAuth = getProvidedAuth(request, payload);
    if (!providedAuth || providedAuth !== expectedAuth) {
      return new Response("unauthorized", {
        status: 401,
        headers: corsHeaders,
      });
    }

    const validationError = validatePayload(payload);
    if (validationError) {
      return jsonResponse(400, {
        ok: false,
        error: validationError,
      });
    }

    const providerResult = await sendWithFcmLegacy(env, payload);
    if (!providerResult.ok) {
      return jsonResponse(502, {
        ok: false,
        accepted: false,
        provider: providerResult.provider,
        error: providerResult.error ?? "Provider error.",
        provider_response: providerResult.response ?? null,
      });
    }

    return jsonResponse(200, {
      ok: true,
      accepted: true,
      provider: providerResult.provider,
      user_id: typeof payload.user_id === "string" ? payload.user_id : null,
      received_at: new Date().toISOString(),
    });
  },
};

function getFcmConfig(env) {
  const rawJson = (env.FCM_SERVICE_ACCOUNT_JSON ?? "").trim();
  if (rawJson.length > 0) {
    try {
      const parsed = JSON.parse(rawJson);
      const projectId = typeof parsed.project_id === "string" ? parsed.project_id.trim() : "";
      const clientEmail = typeof parsed.client_email === "string"
        ? parsed.client_email.trim()
        : "";
      const privateKey = typeof parsed.private_key === "string"
        ? parsed.private_key
        : "";
      if (!projectId || !clientEmail || !privateKey) {
        return {
          ok: false,
          error: "FCM_SERVICE_ACCOUNT_JSON is missing project_id/client_email/private_key.",
        };
      }
      return {
        ok: true,
        projectId,
        clientEmail,
        privateKey: normalizePrivateKey(privateKey),
      };
    } catch {
      return {
        ok: false,
        error: "FCM_SERVICE_ACCOUNT_JSON is invalid JSON.",
      };
    }
  }

  const projectId = (env.FCM_PROJECT_ID ?? "").trim();
  const clientEmail = (env.FCM_CLIENT_EMAIL ?? "").trim();
  const privateKey = normalizePrivateKey((env.FCM_PRIVATE_KEY ?? "").trim());

  if (!projectId || !clientEmail || !privateKey) {
    return {
      ok: false,
      error:
        "FCM config missing. Provide FCM_SERVICE_ACCOUNT_JSON or FCM_PROJECT_ID + FCM_CLIENT_EMAIL + FCM_PRIVATE_KEY.",
    };
  }

  return {
    ok: true,
    projectId,
    clientEmail,
    privateKey,
  };
}

function normalizePrivateKey(value) {
  return value.replace(/\\n/g, "\n").trim();
}

function base64UrlEncode(value) {
  const bytes = value instanceof Uint8Array
    ? value
    : new TextEncoder().encode(value);
  let binary = "";
  for (const b of bytes) {
    binary += String.fromCharCode(b);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function pemToArrayBuffer(pem) {
  const cleaned = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binaryString = atob(cleaned);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i += 1) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

async function signJwt(claims, clientEmail, privateKey) {
  const header = {
    alg: "RS256",
    typ: "JWT",
  };
  const payload = {
    iss: clientEmail,
    scope: GOOGLE_TOKEN_SCOPE,
    aud: GOOGLE_TOKEN_AUDIENCE,
    iat: claims.iat,
    exp: claims.exp,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKey),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedToken)
  );

  return `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;
}

async function getGoogleAccessToken(clientEmail, privateKey) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedGoogleToken && cachedGoogleTokenExpiresAt > now + 60) {
    return cachedGoogleToken;
  }

  const jwt = await signJwt(
    {
      iat: now,
      exp: now + 3600,
    },
    clientEmail,
    privateKey
  );

  const tokenResponse = await fetch(GOOGLE_TOKEN_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const rawText = await tokenResponse.text();
  let parsed;
  try {
    parsed = JSON.parse(rawText);
  } catch {
    parsed = null;
  }

  if (!tokenResponse.ok || typeof parsed?.access_token !== "string") {
    throw new Error("Google OAuth token request failed.");
  }

  cachedGoogleToken = parsed.access_token;
  cachedGoogleTokenExpiresAt = now + (typeof parsed.expires_in === "number" ? parsed.expires_in : 3600);
  return cachedGoogleToken;
}

function stringifyDataMap(value) {
  const result = {
    category: "general",
  };

  if (value && typeof value === "object") {
    for (const [key, mapValue] of Object.entries(value)) {
      if (mapValue === null || mapValue === undefined) {
        continue;
      }
      result[key] = typeof mapValue === "string" ? mapValue : JSON.stringify(mapValue);
    }
  }

  return result;
}
