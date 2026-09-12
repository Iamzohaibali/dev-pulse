import tls from "tls";
import { whoisDomain } from "whoiser";

export const getSSLInfo = (hostname) => {
  return new Promise((resolve) => {
    try {
      const socket = tls.connect(
        { host: hostname, port: 443, servername: hostname, timeout: 8000, rejectUnauthorized: false },
        () => {
          const cert = socket.getPeerCertificate();
          socket.end();

          if (!cert || Object.keys(cert).length === 0) {
            return resolve({ available: false, error: "No certificate found" });
          }

          resolve({
            available: true,
            issuer: cert.issuer?.O || cert.issuer?.CN || "Unknown",
            subject: cert.subject?.CN || hostname,
            validFrom: cert.valid_from,
            validTo: cert.valid_to,
            daysUntilExpiry: Math.ceil((new Date(cert.valid_to) - new Date()) / (1000 * 60 * 60 * 24)),
            fingerprint: cert.fingerprint,
          });
        }
      );

      socket.on("error", (err) => {
        resolve({ available: false, error: err.message });
      });

      socket.on("timeout", () => {
        socket.destroy();
        resolve({ available: false, error: "Connection timed out" });
      });
    } catch (err) {
      resolve({ available: false, error: err.message });
    }
  });
};

export const getDomainInfo = async (hostname) => {
  try {
    const rootDomain = hostname.split(".").slice(-2).join(".");
    const result = await whoisDomain(rootDomain, { timeout: 8000 });

    const registrarKey = Object.keys(result)[0];
    const data = result[registrarKey];

    if (!data) return { available: false, error: "No WHOIS data found" };

    const createdDate = data["Created Date"] || data["created"] || data["Creation Date"] || null;
    const expiryDate = data["Expiry Date"] || data["expires"] || data["Registry Expiry Date"] || data["Registrar Registration Expiration Date"] || null;
    const registrar = data["Registrar"] || data["registrar"] || null;

    let daysUntilExpiry = null;
    if (expiryDate) {
      const parsedExpiry = new Date(expiryDate);
      if (!isNaN(parsedExpiry)) {
        daysUntilExpiry = Math.ceil((parsedExpiry - new Date()) / (1000 * 60 * 60 * 24));
      }
    }

    return {
      available: true,
      domain: rootDomain,
      registrar,
      createdDate,
      expiryDate,
      daysUntilExpiry,
    };
  } catch (err) {
    return { available: false, error: err.message };
  }
};
