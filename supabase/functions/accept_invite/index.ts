import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

type RequestBody = {
  token?: string;
  full_name?: string;
  phone?: string;
  password?: string;
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
    const parsed = await parseBody(req);
    if (!parsed.ok) {
      return jsonResponse(400, { ok: false, error: parsed.error });
    }
    const body = parsed.body;

    const nowIso = new Date().toISOString();
    const { data: inviteRaw, error: inviteError } = await adminClient
      .from("invites")
      .select("id, org_id, phone, token, expires_at, status")
      .eq("token", body.token!)
      .maybeSingle();

    if (inviteError) {
      return jsonResponse(500, { ok: false, error: "Failed to load invite." });
    }
    if (!inviteRaw) {
      return jsonResponse(404, { ok: false, error: "Invite not found." });
    }

    const invite = inviteRaw as {
      id: string;
      org_id: string;
      phone: string;
      token: string;
      expires_at: string;
      status: "pending" | "accepted" | "expired" | "cancelled";
    };

    if (invite.status !== "pending") {
      return jsonResponse(400, {
        ok: false,
        error: "Invite is not pending.",
      });
    }
    if (new Date(invite.expires_at).getTime() <= Date.now()) {
      await adminClient
        .from("invites")
        .update({ status: "expired" })
        .eq("id", invite.id)
        .eq("status", "pending");
      return jsonResponse(400, { ok: false, error: "Invite has expired." });
    }
    if (invite.phone !== body.phone) {
      return jsonResponse(400, {
        ok: false,
        error: "Phone does not match invite.",
      });
    }

    const { data: createdAuth, error: createAuthError } = await adminClient.auth
      .admin.createUser({
        phone: body.phone!,
        password: body.password!,
        phone_confirm: true,
        user_metadata: {
          full_name: body.full_name!,
          source: "invite_accept",
        },
      });

    if (createAuthError || !createdAuth.user?.id) {
      return jsonResponse(400, {
        ok: false,
        error: "Failed to create auth user for this phone.",
      });
    }

    const newUserId = createdAuth.user.id;

    try {
      const { error: profileError } = await adminClient
        .from("profiles")
        .upsert(
          {
            id: newUserId,
            full_name: body.full_name!,
            phone: body.phone!,
            is_active: false,
            approved_by: null,
            approved_at: null,
          },
          { onConflict: "id" },
        );
      if (profileError) {
        throw new Error("Failed to create profile.");
      }

      const { error: userRoleError } = await adminClient
        .from("user_roles")
        .upsert(
          {
            user_id: newUserId,
            role_key: "member",
          },
          { onConflict: "user_id,role_key" },
        );
      if (userRoleError) {
        throw new Error("Failed to assign member role.");
      }

      const { error: orgMemberError } = await adminClient
        .from("organization_members")
        .upsert(
          {
            org_id: invite.org_id,
            user_id: newUserId,
            org_role: "staff",
            status: "pending",
          },
          { onConflict: "org_id,user_id" },
        );
      if (orgMemberError) {
        throw new Error("Failed to create organization membership.");
      }

      const { error: inviteUpdateError } = await adminClient
        .from("invites")
        .update({
          status: "accepted",
          accepted_user_id: newUserId,
          accepted_at: nowIso,
        })
        .eq("id", invite.id)
        .eq("status", "pending");
      if (inviteUpdateError) {
        throw new Error("Failed to update invite.");
      }

      await insertAuditLog({
        actor_id: null,
        action: "invite_accepted_pending_approval",
        entity: "invites",
        entity_id: invite.id,
        meta: {
          user_id: newUserId,
          org_id: invite.org_id,
        },
      });
    } catch {
      await rollback({
        userId: newUserId,
        orgId: invite.org_id,
        inviteId: invite.id,
      });
      return jsonResponse(500, {
        ok: false,
        error: "Invite acceptance failed and rollback was applied.",
      });
    }

    return jsonResponse(200, {
      ok: true,
      user_id: newUserId,
      status: "pending_approval",
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
    if (typeof body.token !== "string" || body.token.trim().length < 16) {
      return { ok: false, error: "token is invalid." };
    }
    if (
      typeof body.full_name !== "string" ||
      body.full_name.trim().length < 2
    ) {
      return { ok: false, error: "full_name must be at least 2 chars." };
    }
    if (typeof body.phone !== "string" || !isE164(body.phone.trim())) {
      return { ok: false, error: "phone must be valid E.164." };
    }
    if (typeof body.password !== "string" || body.password.length < 8) {
      return { ok: false, error: "password must be at least 8 chars." };
    }

    return {
      ok: true,
      body: {
        token: body.token.trim(),
        full_name: body.full_name.trim(),
        phone: body.phone.trim(),
        password: body.password,
      },
    };
  } catch {
    return { ok: false, error: "Request body must be valid JSON." };
  }
}

function isE164(value: string): boolean {
  return /^\+[1-9][0-9]{7,14}$/.test(value);
}

async function insertAuditLog(payload: {
  actor_id: string | null;
  action: string;
  entity: string;
  entity_id: string;
  meta: Record<string, unknown>;
}): Promise<void> {
  await adminClient.from("audit_logs").insert(payload);
}

async function rollback(input: {
  userId: string;
  orgId: string;
  inviteId: string;
}): Promise<void> {
  await adminClient
    .from("organization_members")
    .delete()
    .eq("org_id", input.orgId)
    .eq("user_id", input.userId);

  await adminClient
    .from("user_roles")
    .delete()
    .eq("user_id", input.userId)
    .eq("role_key", "member");

  await adminClient
    .from("profiles")
    .delete()
    .eq("id", input.userId);

  await adminClient
    .from("invites")
    .update({
      status: "pending",
      accepted_user_id: null,
      accepted_at: null,
    })
    .eq("id", input.inviteId)
    .eq("status", "accepted");

  await adminClient.auth.admin.deleteUser(input.userId);
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
