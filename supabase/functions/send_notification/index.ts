import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

type RequestBody = {
  user_id?: string;
  title?: string;
  body?: string;
  category?: "general" | "announcement" | "membership" | "payment" | "job";
  data?: Record<string, unknown>;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const PUSH_WEBHOOK_URL = Deno.env.get("PUSH_WEBHOOK_URL")?.trim() ?? "";
const PUSH_WEBHOOK_AUTH = Deno.env.get("PUSH_WEBHOOK_AUTH")?.trim() ?? "";

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing required Supabase environment variables.");
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      ok: false,
      error: "Method not allowed. Use POST.",
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse(401, {
        ok: false,
        error: "Missing Authorization header.",
      });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return jsonResponse(401, {
        ok: false,
        error: "Invalid or expired JWT.",
      });
    }

    const actorId = userData.user.id;
    const isActorActive = await isUserActive(actorId);
    if (!isActorActive) {
      return jsonResponse(403, {
        ok: false,
        error: "Account is pending approval.",
      });
    }

    const hasAdminRole = await hasRole(actorId, "admin");
    const hasPresidentRole = await hasRole(actorId, "president");
    if (!hasAdminRole && !hasPresidentRole) {
      return jsonResponse(403, {
        ok: false,
        error: "Forbidden.",
      });
    }

    const parsed = await parseBody(req);
    if (!parsed.ok) {
      return jsonResponse(400, { ok: false, error: parsed.error });
    }
    const body = parsed.body;

    let targetUserIds: string[] = [];
    if (body.user_id) {
      targetUserIds = [body.user_id];
    } else {
      const { data: activeProfiles, error: activeProfileError } = await adminClient
        .from("profiles")
        .select("id")
        .eq("is_active", true);
      if (activeProfileError) {
        return jsonResponse(500, {
          ok: false,
          error: "Failed to resolve active user list.",
        });
      }
      targetUserIds = (activeProfiles ?? []).map((item) => item.id as string);
    }

    if (targetUserIds.length === 0) {
      return jsonResponse(200, {
        ok: true,
        inserted: 0,
      });
    }

    const payload = targetUserIds.map((userId) => ({
      user_id: userId,
      title: body.title,
      body: body.body,
      category: body.category ?? "general",
      meta: body.data ?? {},
    }));

    const { error: insertError } = await adminClient
      .from("user_notifications")
      .insert(payload);

    if (insertError) {
      return jsonResponse(500, {
        ok: false,
        error: "Failed to insert notifications.",
      });
    }

    let pushDispatched = 0;
    let pushFailed = 0;
    if (PUSH_WEBHOOK_URL.length > 0) {
      const { data: tokenRows, error: tokenError } = await adminClient
        .from("device_push_tokens")
        .select("user_id, token, platform")
        .in("user_id", targetUserIds)
        .eq("is_active", true);

      if (!tokenError && tokenRows && tokenRows.length > 0) {
        for (const item of tokenRows) {
          const token = (item.token as string | null)?.trim() ?? "";
          const userId = (item.user_id as string | null)?.trim() ?? "";
          if (token.length === 0 || userId.length === 0) {
            continue;
          }
          try {
            const response = await fetch(PUSH_WEBHOOK_URL, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                ...(PUSH_WEBHOOK_AUTH.length > 0
                  ? { Authorization: `Bearer ${PUSH_WEBHOOK_AUTH}` }
                  : {}),
              },
              body: JSON.stringify({
                user_id: userId,
                token,
                platform: item.platform as string | null,
                title: body.title,
                body: body.body,
                category: body.category ?? "general",
                data: body.data ?? {},
              }),
            });
            if (response.ok) {
              pushDispatched += 1;
            } else {
              pushFailed += 1;
            }
          } catch {
            pushFailed += 1;
          }
        }
      }
    }

    await insertAuditLog({
      actor_id: actorId,
      action: "notifications_sent",
      entity: "user_notifications",
      entity_id: null,
      meta: {
        target_count: targetUserIds.length,
        targeted_user_id: body.user_id ?? null,
        category: body.category ?? "general",
        push_dispatched: pushDispatched,
        push_failed: pushFailed,
      },
    });

    return jsonResponse(200, {
      ok: true,
      inserted: targetUserIds.length,
      push_dispatched: pushDispatched,
      push_failed: pushFailed,
    });
  } catch {
    return jsonResponse(500, { ok: false, error: "Internal server error." });
  }
});

async function parseBody(req: Request): Promise<
  { ok: true; body: RequestBody } | { ok: false; error: string }
> {
  try {
    const body = await req.json() as RequestBody;
    if (!body || typeof body !== "object") {
      return { ok: false, error: "Invalid JSON body." };
    }
    if (typeof body.title !== "string" || body.title.trim().length < 2) {
      return { ok: false, error: "title must be at least 2 chars." };
    }
    if (typeof body.body !== "string" || body.body.trim().length < 2) {
      return { ok: false, error: "body must be at least 2 chars." };
    }
    if (body.user_id !== undefined && !isUuid(body.user_id)) {
      return { ok: false, error: "user_id must be valid uuid when provided." };
    }
    if (
      body.category !== undefined &&
      body.category !== "general" &&
      body.category !== "announcement" &&
      body.category !== "membership" &&
      body.category !== "payment" &&
      body.category !== "job"
    ) {
      return { ok: false, error: "category is invalid." };
    }

    return {
      ok: true,
      body: {
        user_id: body.user_id,
        title: body.title.trim(),
        body: body.body.trim(),
        category: body.category ?? "general",
        data: body.data ?? {},
      },
    };
  } catch {
    return { ok: false, error: "Request body must be valid JSON." };
  }
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

async function hasRole(uid: string, roleKey: "admin" | "president"): Promise<boolean> {
  const { data, error } = await adminClient.rpc("has_role", {
    p_uid: uid,
    p_role_key: roleKey,
  });
  if (error) {
    return false;
  }
  return data === true;
}

async function isUserActive(uid: string): Promise<boolean> {
  const { data, error } = await adminClient.rpc("is_user_active", {
    p_uid: uid,
  });
  if (error) {
    return false;
  }
  return data === true;
}

async function insertAuditLog(payload: {
  actor_id: string;
  action: string;
  entity: string;
  entity_id: string | null;
  meta: Record<string, unknown>;
}): Promise<void> {
  await adminClient.from("audit_logs").insert(payload);
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
