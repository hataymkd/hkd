import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

type RequestBody = {
  application_id?: string;
  approve?: boolean;
  reject_reason?: string;
  temp_password?: string;
};

type MemberType = "courier" | "courier_company" | "business";
type OrganizationRole = "owner" | "manager" | "staff";

type MembershipApplicationRow = {
  id: string;
  full_name: string;
  phone: string;
  status: "pending" | "approved" | "rejected";
  member_type: MemberType;
  org_name: string | null;
  org_phone: string | null;
  org_tax_no: string | null;
  requested_org_role: OrganizationRole | null;
  meta: Record<string, unknown> | null;
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

    const applicationId = body.application_id!.trim();
    const approve = body.approve!;
    const rejectReason = body.reject_reason?.trim() || null;
    const tempPassword = body.temp_password?.trim();

    if (!approve) {
      if (!rejectReason) {
        return jsonResponse(400, {
          ok: false,
          error: "reject_reason is required when approve=false.",
        });
      }

      const now = new Date().toISOString();
      const { data: rejectedRow, error: rejectError } = await adminClient
        .from("membership_applications")
        .update({
          status: "rejected",
          reject_reason: rejectReason,
          reviewed_by: actorId,
          reviewed_at: now,
        })
        .eq("id", applicationId)
        .eq("status", "pending")
        .select("id")
        .maybeSingle();

      if (rejectError) {
        return jsonResponse(500, {
          ok: false,
          error: "Failed to reject membership application.",
        });
      }
      if (!rejectedRow) {
        return jsonResponse(404, {
          ok: false,
          error: "Pending membership application not found.",
        });
      }

      const auditResult = await insertAuditLog({
        actor_id: actorId,
        action: "membership_application_rejected",
        entity: "membership_applications",
        entity_id: applicationId,
        meta: {
          reject_reason: rejectReason,
        },
      });

      if (!auditResult.ok) {
        await adminClient
          .from("membership_applications")
          .update({
            status: "pending",
            reject_reason: null,
            reviewed_by: null,
            reviewed_at: null,
          })
          .eq("id", applicationId)
          .eq("status", "rejected");

        return jsonResponse(500, {
          ok: false,
          error: "Failed to write audit log for rejection.",
        });
      }

      return jsonResponse(200, { ok: true, status: "rejected" });
    }

    const { data: applicationRaw, error: applicationError } = await adminClient
      .from("membership_applications")
      .select(
        "id, full_name, phone, status, member_type, org_name, org_phone, org_tax_no, requested_org_role, meta",
      )
      .eq("id", applicationId)
      .eq("status", "pending")
      .maybeSingle();

    if (applicationError) {
      return jsonResponse(500, {
        ok: false,
        error: "Failed to load membership application.",
      });
    }
    if (!applicationRaw) {
      return jsonResponse(404, {
        ok: false,
        error: "Pending membership application not found.",
      });
    }

    const parsedApplication = normalizeMembershipApplication(applicationRaw);
    if (!parsedApplication) {
      return jsonResponse(400, {
        ok: false,
        error: "Membership application data is invalid.",
      });
    }

    const application = parsedApplication;

    const shouldGeneratePassword = !(tempPassword && tempPassword.length >= 8);
    const password = shouldGeneratePassword
      ? generateStrongPassword()
      : tempPassword!;

    const { data: createdAuth, error: createAuthError } = await adminClient.auth
      .admin.createUser({
        phone: application.phone,
        password,
        phone_confirm: true,
        user_metadata: {
          full_name: application.full_name,
          source: "membership_approval",
        },
      });

    if (createAuthError || !createdAuth.user?.id) {
      return jsonResponse(400, {
        ok: false,
        error: "Failed to create auth user for this phone.",
      });
    }

    const newUserId = createdAuth.user.id;
    let createdOrganizationId: string | null = null;
    const reviewedAt = new Date().toISOString();

    try {
      const { error: profileError } = await adminClient
        .from("profiles")
        .upsert(
          {
            id: newUserId,
            full_name: application.full_name,
            phone: application.phone,
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

      if (application.member_type === "business" ||
          application.member_type === "courier_company") {
        const organizationName = application.org_name?.trim() || "";
        const organizationPhone = application.org_phone?.trim() || "";

        if (!organizationName || !organizationPhone) {
          throw new Error("Organization data missing for application.");
        }

        const { data: organizationInsert, error: organizationError } =
          await adminClient
            .from("organizations")
            .insert({
              type: application.member_type,
              name: organizationName,
              phone: organizationPhone,
              tax_no: application.org_tax_no,
              created_by: newUserId,
            })
            .select("id")
            .single();

        if (organizationError || !organizationInsert?.id) {
          throw new Error("Failed to create organization.");
        }

        createdOrganizationId = organizationInsert.id as string;

        const { error: orgOwnerError } = await adminClient
          .from("organization_members")
            .insert({
              org_id: createdOrganizationId,
              user_id: newUserId,
              org_role: "owner",
              status: "pending",
            });

        if (orgOwnerError) {
          throw new Error("Failed to create organization owner membership.");
        }
      } else if (application.member_type === "courier") {
        const selectedOrgId = extractSelectedOrganizationId(application.meta);
        if (selectedOrgId) {
          const { data: existingOrg, error: orgLookupError } = await adminClient
            .from("organizations")
            .select("id")
            .eq("id", selectedOrgId)
            .maybeSingle();

          if (orgLookupError || !existingOrg) {
            throw new Error("Selected organization not found.");
          }

          const requestedRole = resolveCourierOrganizationRole(application);
          const { error: orgMemberError } = await adminClient
            .from("organization_members")
            .upsert(
              {
                org_id: selectedOrgId,
                user_id: newUserId,
                org_role: requestedRole,
                status: "pending",
              },
              { onConflict: "org_id,user_id" },
            );

          if (orgMemberError) {
            throw new Error("Failed to link courier to selected organization.");
          }
        }
      }

      const { data: approvedRow, error: approveError } = await adminClient
        .from("membership_applications")
        .update({
          status: "approved",
          reject_reason: null,
          reviewed_by: actorId,
          reviewed_at: reviewedAt,
        })
        .eq("id", applicationId)
        .eq("status", "pending")
        .select("id")
        .maybeSingle();

      if (approveError || !approvedRow) {
        throw new Error("Failed to mark membership application as approved.");
      }

      const auditResult = await insertAuditLog({
        actor_id: actorId,
        action: "membership_application_approved",
        entity: "membership_applications",
        entity_id: applicationId,
        meta: {
          user_id: newUserId,
          member_type: application.member_type,
          organization_id: createdOrganizationId,
        },
      });

      if (!auditResult.ok) {
        throw new Error("Failed to write approval audit log.");
      }
    } catch (_error) {
      await bestEffortRollbackApproved({
        applicationId,
        newUserId,
        createdOrganizationId,
      });

      return jsonResponse(500, {
        ok: false,
        error: "Approval failed and rollback was applied.",
      });
    }

    return jsonResponse(200, {
      ok: true,
      status: "approved",
      user_id: newUserId,
      temp_password: shouldGeneratePassword ? password : null,
    });
  } catch (_err) {
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
    if (
      typeof body.application_id !== "string" || !isUuid(body.application_id)
    ) {
      return { ok: false, error: "application_id must be a valid uuid string." };
    }
    if (typeof body.approve !== "boolean") {
      return { ok: false, error: "approve must be boolean." };
    }
    if (
      body.reject_reason !== undefined && typeof body.reject_reason !== "string"
    ) {
      return { ok: false, error: "reject_reason must be string when provided." };
    }
    if (
      body.temp_password !== undefined && typeof body.temp_password !== "string"
    ) {
      return { ok: false, error: "temp_password must be string when provided." };
    }
    if (typeof body.temp_password === "string" && body.temp_password.length > 0 &&
      body.temp_password.length < 8) {
      return { ok: false, error: "temp_password must be at least 8 chars." };
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

function normalizeMembershipApplication(
  raw: unknown,
): MembershipApplicationRow | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const row = raw as Record<string, unknown>;

  if (typeof row.id !== "string" || typeof row.full_name !== "string" ||
    typeof row.phone !== "string") {
    return null;
  }

  const memberType = parseMemberType(row.member_type) ?? "courier";

  const requestedOrgRole = parseOrganizationRole(row.requested_org_role);
  const meta = row.meta && typeof row.meta === "object"
    ? row.meta as Record<string, unknown>
    : null;

  return {
    id: row.id,
    full_name: row.full_name,
    phone: row.phone,
    status: "pending",
    member_type: memberType,
    org_name: typeof row.org_name === "string" ? row.org_name : null,
    org_phone: typeof row.org_phone === "string" ? row.org_phone : null,
    org_tax_no: typeof row.org_tax_no === "string" ? row.org_tax_no : null,
    requested_org_role: requestedOrgRole,
    meta,
  };
}

function parseMemberType(value: unknown): MemberType | null {
  if (value === "courier" || value === "courier_company" || value === "business") {
    return value;
  }
  return null;
}

function parseOrganizationRole(value: unknown): OrganizationRole | null {
  if (value === "owner" || value === "manager" || value === "staff") {
    return value;
  }
  return null;
}

function extractSelectedOrganizationId(
  meta: Record<string, unknown> | null,
): string | null {
  if (!meta) {
    return null;
  }

  const candidates = [
    meta.organization_id,
    meta.org_id,
    meta.selected_org_id,
  ];

  for (const candidate of candidates) {
    if (typeof candidate === "string" && isUuid(candidate)) {
      return candidate;
    }
  }

  return null;
}

function resolveCourierOrganizationRole(
  application: MembershipApplicationRow,
): OrganizationRole {
  const meta = application.meta;
  if (meta) {
    const metaRole = parseOrganizationRole(meta.requested_org_role) ??
      parseOrganizationRole(meta.org_role);
    if (metaRole) {
      return metaRole;
    }
  }

  if (application.requested_org_role &&
    application.requested_org_role !== "owner") {
    return application.requested_org_role;
  }

  return "staff";
}

function generateStrongPassword(length = 20): string {
  const upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  const lower = "abcdefghijkmnopqrstuvwxyz";
  const digits = "23456789";
  const symbols = "!@#$%^*()-_=+";
  const all = upper + lower + digits + symbols;

  const initial = [
    randomChar(upper),
    randomChar(lower),
    randomChar(digits),
    randomChar(symbols),
  ];

  for (let i = initial.length; i < length; i++) {
    initial.push(randomChar(all));
  }

  for (let i = initial.length - 1; i > 0; i--) {
    const j = crypto.getRandomValues(new Uint32Array(1))[0] % (i + 1);
    const tmp = initial[i];
    initial[i] = initial[j];
    initial[j] = tmp;
  }

  return initial.join("");
}

function randomChar(chars: string): string {
  const idx = crypto.getRandomValues(new Uint32Array(1))[0] % chars.length;
  return chars[idx];
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
}): Promise<{ ok: true } | { ok: false }> {
  const { error } = await adminClient.from("audit_logs").insert(payload);
  if (error) {
    return { ok: false };
  }
  return { ok: true };
}

async function bestEffortRollbackApproved(input: {
  applicationId: string;
  newUserId: string;
  createdOrganizationId: string | null;
}): Promise<void> {
  const { applicationId, newUserId, createdOrganizationId } = input;

  await adminClient
    .from("membership_applications")
    .update({
      status: "pending",
      reject_reason: null,
      reviewed_by: null,
      reviewed_at: null,
    })
    .eq("id", applicationId)
    .eq("status", "approved");

  await adminClient
    .from("organization_members")
    .delete()
    .eq("user_id", newUserId);

  if (createdOrganizationId) {
    await adminClient
      .from("organizations")
      .delete()
      .eq("id", createdOrganizationId);
  }

  await adminClient
    .from("user_roles")
    .delete()
    .eq("user_id", newUserId)
    .eq("role_key", "member");

  await adminClient
    .from("profiles")
    .delete()
    .eq("id", newUserId);

  await adminClient.auth.admin.deleteUser(newUserId);
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
