// email-service.js — Send emails via Resend (through Supabase edge function)
// Requires: supabase client initialized in shared/supabase.js

(function () {
  'use strict';

  const FUNCTION_URL = SUPABASE_URL + '/functions/v1/send-email';

  /**
   * Send an email via Resend
   * @param {Object} options
   * @param {string|string[]} options.to - Recipient email(s)
   * @param {string} options.subject - Email subject
   * @param {string} options.html - HTML body
   * @param {string} [options.from] - Sender (default: onboarding@resend.dev)
   * @returns {Promise<{success: boolean, id?: string, error?: string}>}
   */
  async function sendEmail({ to, subject, html, from }) {
    const session = await supabase.auth.getSession();
    const token = session?.data?.session?.access_token;
    if (!token) throw new Error('Not authenticated');

    const res = await fetch(FUNCTION_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ to, subject, html, from }),
    });

    return res.json();
  }

  // Expose globally
  window.sendEmail = sendEmail;
})();
