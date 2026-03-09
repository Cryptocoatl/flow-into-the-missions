// sms-service.js — Send SMS via Telnyx (through Supabase edge function)
// Requires: supabase client initialized in shared/supabase.js

(function () {
  'use strict';

  const FUNCTION_URL = SUPABASE_URL + '/functions/v1/send-sms';

  /**
   * Send an SMS via Telnyx
   * @param {Object} options
   * @param {string} options.to - Recipient phone number (E.164 format, e.g. +12125551234)
   * @param {string} options.body - Message text
   * @param {string} [options.from] - Sender number (default: from telnyx_config)
   * @returns {Promise<{success: boolean, id?: string, error?: string}>}
   */
  async function sendSMS({ to, body, from }) {
    const session = await supabase.auth.getSession();
    const token = session?.data?.session?.access_token;
    if (!token) throw new Error('Not authenticated');

    const res = await fetch(FUNCTION_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ to, body, from }),
    });

    return res.json();
  }

  // Expose globally
  window.sendSMS = sendSMS;
})();
