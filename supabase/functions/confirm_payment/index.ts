import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

type RequestBody = {
  payment_id?: string;
  status?: "succeeded" | "failed" | "refunded";
  provider_ref?: string;
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
      return jsonResponse(400, {
        ok: false,
        error: parsed.error,
      });
    }
    const body = parsed.body;

    const { data: paymentRow, error: paymentError } = await adminClient
      .from("payments")
      .select("id, invoice_id, user_id, amount, status, provider_ref")
      .eq("id", body.payment_id)
      .maybeSingle();

    if (paymentError) {
      return jsonResponse(500, {
        ok: false,
        error: "Failed to load payment.",
      });
    }
    if (!paymentRow) {
      return jsonResponse(404, {
        ok: false,
        error: "Payment not found.",
      });
    }

    const nowIso = new Date().toISOString();
    const nextStatus = body.status!;
    const previousStatus = paymentRow.status as string;
    const providerRef = body.provider_ref?.trim() || paymentRow.provider_ref;
    const paidAt = nextStatus === "succeeded" ? nowIso : null;

    const { error: paymentUpdateError } = await adminClient
      .from("payments")
      .update({
        status: nextStatus,
        provider_ref: providerRef,
      })
      .eq("id", paymentRow.id);

    if (paymentUpdateError) {
      return jsonResponse(500, {
        ok: false,
        error: "Failed to update payment status.",
      });
    }

    if (paymentRow.invoice_id) {
      const invoiceStatus = nextStatus === "succeeded" ? "paid" : "unpaid";
      const { error: invoiceUpdateError } = await adminClient
        .from("dues_invoices")
        .update({
          status: invoiceStatus,
          paid_at: paidAt,
        })
        .eq("id", paymentRow.invoice_id);

      if (invoiceUpdateError) {
        return jsonResponse(500, {
          ok: false,
          error: "Payment updated but invoice status update failed.",
        });
      }
    }

    await adminClient
      .from("payment_checkout_sessions")
      .update({
        status: nextStatus === "succeeded" ? "succeeded" : "failed",
      })
      .eq("payment_id", paymentRow.id)
      .in("status", ["created", "redirected"]);

    await adminClient
      .from("payment_reconciliation_logs")
      .insert({
        payment_id: paymentRow.id as string,
        invoice_id: paymentRow.invoice_id as string | null,
        actor_id: actorId,
        previous_status: previousStatus,
        next_status: nextStatus,
        reason: body.reason?.trim() || null,
        provider_ref: providerRef ?? null,
      });

    await insertAuditLog({
      actor_id: actorId,
      action: "payment_status_confirmed",
      entity: "payments",
      entity_id: paymentRow.id as string,
      meta: {
        previous_status: previousStatus,
        status: nextStatus,
        invoice_id: paymentRow.invoice_id,
        reason: body.reason?.trim() || null,
      },
    });

    return jsonResponse(200, {
      ok: true,
      payment_id: paymentRow.id,
      status: nextStatus,
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
    if (typeof body.payment_id !== "string" || !isUuid(body.payment_id)) {
      return { ok: false, error: "payment_id must be a valid uuid string." };
    }
    if (
      body.status !== "succeeded" && body.status !== "failed" &&
      body.status !== "refunded"
    ) {
      return {
        ok: false,
        error: "status must be one of: succeeded, failed, refunded.",
      };
    }
    if (
      body.provider_ref !== undefined &&
      typeof body.provider_ref !== "string"
    ) {
      return { ok: false, error: "provider_ref must be string when provided." };
    }
    if (
      body.reason !== undefined &&
      typeof body.reason !== "string"
    ) {
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
