import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TELNYX_API_KEY = Deno.env.get("TELNYX_API_KEY")!;
const TELNYX_MESSAGING_PROFILE_ID = Deno.env.get("TELNYX_MESSAGING_PROFILE_ID")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { to, body, from } = await req.json();

    if (!to || !body) {
      return new Response(JSON.stringify({ error: "Missing required fields: to, body" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get phone number from config if not provided
    let fromNumber = from;
    if (!fromNumber) {
      const { data: config } = await supabase
        .from("telnyx_config")
        .select("phone_number")
        .eq("is_active", true)
        .single();
      fromNumber = config?.phone_number;
    }

    if (!fromNumber) {
      return new Response(JSON.stringify({ error: "No from number configured. Add a phone number to telnyx_config." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Send via Telnyx
    const telnyxRes = await fetch("https://api.telnyx.com/v2/messages", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${TELNYX_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromNumber,
        to,
        text: body,
        messaging_profile_id: TELNYX_MESSAGING_PROFILE_ID,
      }),
    });

    const telnyxData = await telnyxRes.json();

    if (!telnyxRes.ok) {
      // Log failure
      await supabase.from("sms_messages").insert({
        direction: "outbound",
        from_number: fromNumber,
        to_number: to,
        body,
        status: "failed",
        metadata: { error: telnyxData },
      });

      await supabase.from("communications").insert({
        channel: "sms",
        direction: "outbound",
        recipient: to,
        sender: fromNumber,
        body,
        status: "failed",
        metadata: { error: telnyxData },
      });

      return new Response(JSON.stringify({ error: "Failed to send SMS", details: telnyxData }), {
        status: telnyxRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const messageId = telnyxData.data?.id;

    // Log success
    await supabase.from("sms_messages").insert({
      direction: "outbound",
      from_number: fromNumber,
      to_number: to,
      body,
      status: "sent",
      provider_message_id: messageId,
    });

    await supabase.from("communications").insert({
      channel: "sms",
      direction: "outbound",
      recipient: to,
      sender: fromNumber,
      body,
      status: "sent",
      metadata: { telnyx_id: messageId },
    });

    return new Response(JSON.stringify({ success: true, id: messageId }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
