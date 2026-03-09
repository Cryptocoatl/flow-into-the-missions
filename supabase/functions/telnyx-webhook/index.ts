import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  // Telnyx sends POST webhooks
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const payload = await req.json();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Telnyx webhook v2 format
    const eventData = payload.data;
    const eventType = eventData?.event_type;
    const msgPayload = eventData?.payload;

    if (!msgPayload) {
      return new Response(JSON.stringify({ received: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Handle inbound messages
    if (eventType === "message.received") {
      const fromNumber = msgPayload.from?.phone_number || msgPayload.from;
      const toNumber = msgPayload.to?.[0]?.phone_number || msgPayload.to;
      const body = msgPayload.text || msgPayload.body || "";
      const messageId = msgPayload.id;

      // Log inbound SMS
      await supabase.from("sms_messages").insert({
        direction: "inbound",
        from_number: fromNumber,
        to_number: toNumber,
        body,
        status: "received",
        provider_message_id: messageId,
        metadata: { event_type: eventType, raw: msgPayload },
      });

      // Also log in communications
      await supabase.from("communications").insert({
        channel: "sms",
        direction: "inbound",
        sender: fromNumber,
        recipient: toNumber,
        body,
        status: "delivered",
        metadata: { telnyx_id: messageId },
      });
    }

    // Handle delivery receipts
    if (eventType === "message.sent" || eventType === "message.delivered" || eventType === "message.failed") {
      const messageId = msgPayload.id;
      const status = eventType === "message.delivered" ? "delivered"
                   : eventType === "message.failed" ? "failed"
                   : "sent";

      // Update existing message status
      if (messageId) {
        await supabase
          .from("sms_messages")
          .update({ status, metadata: { delivery_event: eventType } })
          .eq("provider_message_id", messageId);
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Telnyx webhook error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
