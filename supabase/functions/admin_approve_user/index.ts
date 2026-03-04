import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

type RequestBody = {
  user_id?: string;
  approve?: boolean;
  reason?: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

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
    return jsonResponse(
      405,
      { ok: false, error: "Method not allowed. Use POST." },
    );
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
      return jsonResponse(403, { ok: false, error: "Forbidden." });
    }

    const parsed = await parseBody(req);
    if (!parsed.ok) {
      return jsonResponse(400, { ok: false, error: parsed.error });
    }
    const body = parsed.body;
    const targetUserId = body.user_id!.trim();
    const approve = body.approve!;
    const reason = body.reason?.trim() || null;

    const { data: profileRow, error: profileLookupError } = await adminClient
      .from("profiles")
      .select("id, is_active")
      .eq("id", targetUserId)
      .maybeSingle();

    if (profileLookupError) {
      return jsonResponse(500, {
        ok: false,
        error: "Failed to load target profile.",
      });
    }
    if (!profileRow) {
      return jsonResponse(404, {
        ok: false,
        error: "Target profile not found.",
      });
    }

    if (approve) {
      const now = new Date().toISOString();
      const { error: activateProfileError } = await adminClient
        .from("profiles")
        .update({
          is_active: true,
          approved_by: actorId,
          approved_at: now,
        })
        .eq("id", targetUserId);

      if (activateProfileError) {
        return jsonResponse(500, {
          ok: false,
          error: "Failed to activate profile.",
        });
      }

      const { data: activatedOrgRows, error: activateOrgError } = await adminClient
        .from("organization_members")
        .update({ status: "active" })
        .eq("user_id", targetUserId)
        .eq("status", "pending")
        .select("org_id");

      if (activateOrgError) {
        return jsonResponse(500, {
          ok: false,
          error: "Failed to activate organization memberships.",
        });
      }

      await insertAuditLog({
        actor_id: actorId,
        action: "user_activation_approved",
        entity: "profiles",
        entity_id: targetUserId,
        meta: {
          reason,
          activated_org_memberships: activatedOrgRows?.length ?? 0,
        },
      });

      return jsonResponse(200, {
        ok: true,
        status: "approved",
        user_id: targetUserId,
      });
    }

    const { error: keepInactiveError } = await adminClient
      .from("profiles")
      .update({
        is_active: false,
        approved_by: null,
        approved_at: null,
      })
      .eq("id", targetUserId);

    if (keepInactiveError) {
      return jsonResponse(500, {
        ok: false,
        error: "Failed to keep profile in pending state.",
      });
    }

    await insertAuditLog({
      actor_id: actorId,
      action: "user_activation_rejected",
      entity: "profiles",
      entity_id: targetUserId,
      meta: {
        reason,
      },
    });

    return jsonResponse(200, {
      ok: true,
      status: "rejected",
      user_id: targetUserId,
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
    if (typeof body.user_id !== "string" || !isUuid(body.user_id)) {
      return { ok: false, error: "user_id must be a valid uuid string." };
    }
    if (typeof body.approve !== "boolean") {
      return { ok: false, error: "approve must be boolean." };
    }
    if (body.reason !== undefined && typeof body.reason !== "string") {
      return { ok: false, error: "reason must be string when provided." };
    }

    return { ok: true, body };
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
  entity_id: string;
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
