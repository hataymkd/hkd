import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

type RequestBody = {
  invoice_id?: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const PAYMENT_PROVIDER = (Deno.env.get("PAYMENT_PROVIDER") ?? "manual").trim()
  .toLowerCase();
const PAYMENT_CHECKOUT_BASE_URL = (Deno.env.get("PAYMENT_CHECKOUT_BASE_URL") ??
  "").trim();

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

    const parsed = await parseBody(req);
    if (!parsed.ok) {
      return jsonResponse(400, { ok: false, error: parsed.error });
    }
    const invoiceId = parsed.body.invoice_id!.trim();

    const hasAdminRole = await hasRole(actorId, "admin");
    const hasPresidentRole = await hasRole(actorId, "president");
    const canManageAll = hasAdminRole || hasPresidentRole;

    const { data: invoiceRow, error: invoiceError } = await adminClient
      .from("dues_invoices")
      .select(
        "id, user_id, amount, status, period_id, dues_periods(period_key, due_date)",
      )
      .eq("id", invoiceId)
      .maybeSingle();

    if (invoiceError) {
      return jsonResponse(500, {
        ok: false,
        error: "Failed to load invoice.",
      });
    }
    if (!invoiceRow) {
      return jsonResponse(404, {
        ok: false,
        error: "Invoice not found.",
      });
    }

    const invoice = invoiceRow as {
      id: string;
      user_id: string;
      amount: number;
      status: "unpaid" | "paid" | "overdue";
      period_id: string;
      dues_periods?: {
        period_key?: string;
        due_date?: string;
      } | null;
    };

    if (!canManageAll && invoice.user_id !== actorId) {
      return jsonResponse(403, {
        ok: false,
        error: "Forbidden.",
      });
    }

    if (invoice.status === "paid") {
      return jsonResponse(400, {
        ok: false,
        error: "Invoice is already paid.",
      });
    }

    const checkoutRef = crypto.randomUUID().replaceAll("-", "");
    const provider = PAYMENT_PROVIDER.length > 0 ? PAYMENT_PROVIDER : "manual";

    const { data: paymentRow, error: paymentError } = await adminClient
      .from("payments")
      .insert({
        invoice_id: invoice.id,
        user_id: invoice.user_id,
        amount: invoice.amount,
        provider,
        provider_ref: checkoutRef,
        status: "created",
      })
      .select("id")
      .single();

    if (paymentError || !paymentRow?.id) {
      return jsonResponse(500, {
        ok: false,
        error: "Failed to create payment record.",
      });
    }

    const checkoutUrl = buildCheckoutUrl({
      baseUrl: PAYMENT_CHECKOUT_BASE_URL,
      paymentId: paymentRow.id as string,
      invoiceId: invoice.id,
      checkoutRef,
    });

    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();

    const { error: checkoutSessionError } = await adminClient
      .from("payment_checkout_sessions")
      .insert({
        payment_id: paymentRow.id,
        invoice_id: invoice.id,
        user_id: invoice.user_id,
        provider,
        checkout_ref: checkoutRef,
        checkout_url: checkoutUrl,
        status: checkoutUrl ? "redirected" : "created",
        expires_at: expiresAt,
        meta: {
          period_key: invoice.dues_periods?.period_key ?? null,
          due_date: invoice.dues_periods?.due_date ?? null,
          requested_by: actorId,
        },
      });

    if (checkoutSessionError) {
      await adminClient
        .from("payments")
        .delete()
        .eq("id", paymentRow.id);
      return jsonResponse(500, {
        ok: false,
        error: "Failed to create checkout session.",
      });
    }

    await insertAuditLog({
      actor_id: actorId,
      action: "payment_checkout_created",
      entity: "payments",
      entity_id: paymentRow.id as string,
      meta: {
        invoice_id: invoice.id,
        provider,
        checkout_ref: checkoutRef,
      },
    });

    return jsonResponse(200, {
      ok: true,
      payment_id: paymentRow.id,
      provider,
      status: checkoutUrl ? "redirected" : "created",
      checkout_url: checkoutUrl,
      instructions: checkoutUrl
        ? null
        : "Odeme istegi olusturuldu. Dernek yonetimi odeme kaydini onayladiginda durum guncellenecektir.",
    });
  } catch {
    return jsonResponse(500, { ok: false, error: "Internal server error." });
  }
});

function buildCheckoutUrl(input: {
  baseUrl: string;
  paymentId: string;
  invoiceId: string;
  checkoutRef: string;
}): string | null {
  if (input.baseUrl.length === 0) {
    return null;
  }
  const separator = input.baseUrl.includes("?") ? "&" : "?";
  return `${input.baseUrl}${separator}payment_id=${input.paymentId}&invoice_id=${input.invoiceId}&ref=${input.checkoutRef}`;
}

async function parseBody(req: Request): Promise<
  { ok: true; body: RequestBody } | { ok: false; error: string }
> {
  try {
    const body = await req.json() as RequestBody;
    if (!body || typeof body !== "object") {
      return { ok: false, error: "Invalid JSON body." };
    }
    if (typeof body.invoice_id !== "string" || !isUuid(body.invoice_id)) {
      return { ok: false, error: "invoice_id must be a valid uuid string." };
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
