import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

type RequestBody = {
  org_id?: string;
  phone?: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const INVITE_BASE_URL = Deno.env.get("INVITE_BASE_URL") ?? "";

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

    const parsed = await parseBody(req);
    if (!parsed.ok) {
      return jsonResponse(400, { ok: false, error: parsed.error });
    }
    const body = parsed.body;

    const isAdmin = await hasRole(actorId, "admin");
    const isPresident = await hasRole(actorId, "president");
    const hasOrgManageRole = await hasOrgManagePermission(
      body.org_id!,
      actorId,
    );

    if (!isAdmin && !isPresident && !hasOrgManageRole) {
      return jsonResponse(403, { ok: false, error: "Forbidden." });
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    const token = crypto.randomUUID().replaceAll("-", "");

    const { data: inviteRow, error: inviteError } = await adminClient
      .from("invites")
      .insert({
        org_id: body.org_id!,
        phone: body.phone!,
        token,
        expires_at: expiresAt.toISOString(),
        status: "pending",
        created_by: actorId,
      })
      .select("id, token, expires_at")
      .single();

    if (inviteError || !inviteRow) {
      return jsonResponse(500, {
        ok: false,
        error: "Failed to create invite.",
      });
    }

    const inviteUrl = buildInviteUrl(inviteRow.token as string);

    await insertAuditLog({
      actor_id: actorId,
      action: "invite_created",
      entity: "invites",
      entity_id: inviteRow.id as string,
      meta: {
        org_id: body.org_id,
        phone: body.phone,
        expires_at: inviteRow.expires_at,
      },
    });

    return jsonResponse(200, {
      ok: true,
      token: inviteRow.token,
      expires_at: inviteRow.expires_at,
      invite_url: inviteUrl,
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
    if (typeof body.org_id !== "string" || !isUuid(body.org_id)) {
      return { ok: false, error: "org_id must be a valid uuid string." };
    }
    if (typeof body.phone !== "string" || !isE164(body.phone.trim())) {
      return { ok: false, error: "phone must be valid E.164." };
    }

    return {
      ok: true,
      body: {
        org_id: body.org_id.trim(),
        phone: body.phone.trim(),
      },
    };
  } catch {
    return { ok: false, error: "Request body must be valid JSON." };
  }
}

function buildInviteUrl(token: string): string {
  const base = INVITE_BASE_URL.trim();
  if (base.length === 0) {
    return `hkd://invite?token=${token}`;
  }

  const separator = base.includes("?") ? "&" : "?";
  return `${base}${separator}token=${token}`;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function isE164(value: string): boolean {
  return /^\+[1-9][0-9]{7,14}$/.test(value);
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

async function hasOrgManagePermission(orgId: string, uid: string): Promise<boolean> {
  const { data, error } = await adminClient.rpc("has_org_role", {
    p_org_id: orgId,
    p_uid: uid,
    p_roles: ["owner", "manager"],
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
