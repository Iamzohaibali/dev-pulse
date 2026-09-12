import { Resend } from "resend";

const resend = new Resend(process.env.RESEND_API_KEY);

export const sendDownAlert = async (toEmail, monitor) => {
  try {
    await resend.emails.send({
      from: process.env.RESEND_FROM_EMAIL,
      to: toEmail,
      subject: "DOWN ALERT: " + monitor.name + " is unreachable",
      html:
        "<h2 style=\"color:#dc2626\">Your site is down</h2>" +
        "<p><strong>" + monitor.name + "</strong> (" + monitor.url + ") failed its last check.</p>" +
        "<p>Detected at: " + new Date().toLocaleString() + "</p>" +
        "<p>DevPulse will notify you again once it recovers.</p>",
    });
    console.log("Down alert email sent to " + toEmail + " for " + monitor.name);
  } catch (err) {
    console.error("Failed to send down alert email:", err.message);
  }
};

export const sendRecoveryAlert = async (toEmail, monitor) => {
  try {
    await resend.emails.send({
      from: process.env.RESEND_FROM_EMAIL,
      to: toEmail,
      subject: "RESOLVED: " + monitor.name + " is back up",
      html:
        "<h2 style=\"color:#16a34a\">Your site is back up</h2>" +
        "<p><strong>" + monitor.name + "</strong> (" + monitor.url + ") is responding normally again.</p>" +
        "<p>Recovered at: " + new Date().toLocaleString() + "</p>",
    });
    console.log("Recovery email sent to " + toEmail + " for " + monitor.name);
  } catch (err) {
    console.error("Failed to send recovery email:", err.message);
  }
};
