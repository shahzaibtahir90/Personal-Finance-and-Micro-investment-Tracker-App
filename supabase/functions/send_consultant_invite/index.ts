import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Replace with your SendGrid API key or use environment variable
const SENDGRID_API_KEY = Deno.env.get("SENDGRID_API_KEY");
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") || "no-reply@yourdomain.com";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }
  try {
    const { to, name, inviter, invite_link } = await req.json();
    if (!to || !name || !inviter || !invite_link) {
      return new Response("Missing fields", { status: 400 });
    }
    const emailBody = {
      personalizations: [
        {
          to: [{ email: to, name }],
          subject: `Consultant Invitation from ${inviter}`,
        },
      ],
      from: { email: FROM_EMAIL, name: "Personal Finance App" },
      content: [
        {
          type: "text/plain",
          value: `Hello ${name},\n\nYou have been invited by ${inviter} to join as a consultant. Click the link below to accept the invitation and register:\n\n${invite_link}\n\nIf you did not expect this, you can ignore this email.`,
        },
      ],
    };
    const resp = await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SENDGRID_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(emailBody),
    });
    if (!resp.ok) {
      const err = await resp.text();
      return new Response(`SendGrid error: ${err}`, { status: 500 });
    }
    return new Response("Email sent", { status: 200 });
  } catch (e) {
    return new Response(`Error: ${e}`, { status: 500 });
  }
});
