# ============ BACKEND: SSL + domain info ============
Set-Location backend

npm install whoiser

@'
import tls from "tls";
import whoiser from "whoiser";

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
    const result = await whoiser(rootDomain, { timeout: 8000 });

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
'@ | Set-Content -Path "src\services\domainInfo.service.js" -Encoding ASCII

@'
import Monitor from "../models/Monitor.js";
import CheckLog from "../models/CheckLog.js";
import Incident from "../models/Incident.js";
import { getUserId } from "../middleware/auth.middleware.js";
import { getSSLInfo, getDomainInfo } from "../services/domainInfo.service.js";

export const createMonitor = async (req, res) => {
  try {
    const userId = getUserId(req);
    const { name, url, checkIntervalMinutes } = req.body;

    if (!name || !url) {
      return res.status(400).json({ error: "name and url are required" });
    }

    const existingCount = await Monitor.countDocuments({ userId });
    if (existingCount >= 5) {
      return res.status(403).json({ error: "You can only monitor a maximum of 5 websites. Delete an existing monitor to add a new one." });
    }

    const monitor = await Monitor.create({ userId, name, url, checkIntervalMinutes });
    res.status(201).json(monitor);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getMonitors = async (req, res) => {
  try {
    const userId = getUserId(req);
    const monitors = await Monitor.find({ userId }).sort({ createdAt: -1 });
    res.json(monitors);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getMonitorById = async (req, res) => {
  try {
    const userId = getUserId(req);
    const monitor = await Monitor.findOne({ _id: req.params.id, userId });
    if (!monitor) return res.status(404).json({ error: "Monitor not found" });
    res.json(monitor);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const updateMonitor = async (req, res) => {
  try {
    const userId = getUserId(req);
    const { name, url, checkIntervalMinutes, isActive } = req.body;
    const monitor = await Monitor.findOneAndUpdate(
      { _id: req.params.id, userId },
      { name, url, checkIntervalMinutes, isActive },
      { new: true, runValidators: true }
    );
    if (!monitor) return res.status(404).json({ error: "Monitor not found" });
    res.json(monitor);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const deleteMonitor = async (req, res) => {
  try {
    const userId = getUserId(req);
    const monitor = await Monitor.findOneAndDelete({ _id: req.params.id, userId });
    if (!monitor) return res.status(404).json({ error: "Monitor not found" });
    await CheckLog.deleteMany({ monitorId: monitor._id });
    await Incident.deleteMany({ monitorId: monitor._id });
    res.json({ message: "Monitor deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getMonitorLogs = async (req, res) => {
  try {
    const userId = getUserId(req);
    const monitor = await Monitor.findOne({ _id: req.params.id, userId });
    if (!monitor) return res.status(404).json({ error: "Monitor not found" });
    const logs = await CheckLog.find({ monitorId: monitor._id }).sort({ checkedAt: -1 }).limit(200);
    res.json(logs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getMonitorStats = async (req, res) => {
  try {
    const userId = getUserId(req);
    const monitor = await Monitor.findOne({ _id: req.params.id, userId });
    if (!monitor) return res.status(404).json({ error: "Monitor not found" });

    const since24h = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const logs24h = await CheckLog.find({ monitorId: monitor._id, checkedAt: { $gte: since24h } }).sort({ checkedAt: 1 });

    const totalChecks = logs24h.length;
    const upChecks = logs24h.filter((l) => l.status === "up").length;
    const uptimePercent = totalChecks > 0 ? ((upChecks / totalChecks) * 100).toFixed(2) : null;

    const avgResponseTime =
      totalChecks > 0
        ? Math.round(logs24h.reduce((sum, l) => sum + (l.responseTimeMs || 0), 0) / totalChecks)
        : null;

    const recentLogs = await CheckLog.find({ monitorId: monitor._id }).sort({ checkedAt: -1 }).limit(50);
    const incidents = await Incident.find({ monitorId: monitor._id }).sort({ startedAt: -1 }).limit(10);

    let urlInfo = {};
    try {
      const parsed = new URL(monitor.url);
      urlInfo = {
        protocol: parsed.protocol.replace(":", ""),
        hostname: parsed.hostname,
        isHttps: parsed.protocol === "https:",
      };
    } catch (e) {
      urlInfo = {};
    }

    res.json({
      monitor,
      uptimePercent,
      avgResponseTime,
      totalChecks24h: totalChecks,
      recentLogs: recentLogs.reverse(),
      incidents,
      urlInfo,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getMonitorDomainInfo = async (req, res) => {
  try {
    const userId = getUserId(req);
    const monitor = await Monitor.findOne({ _id: req.params.id, userId });
    if (!monitor) return res.status(404).json({ error: "Monitor not found" });

    const hostname = new URL(monitor.url).hostname;

    const [ssl, domain] = await Promise.all([
      getSSLInfo(hostname),
      getDomainInfo(hostname),
    ]);

    res.json({ ssl, domain });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
'@ | Set-Content -Path "src\controllers\monitors.controller.js" -Encoding ASCII

@'
import express from "express";
import { requireAuth } from "@clerk/express";
import {
  createMonitor,
  getMonitors,
  getMonitorById,
  updateMonitor,
  deleteMonitor,
  getMonitorLogs,
  getMonitorStats,
  getMonitorDomainInfo,
} from "../controllers/monitors.controller.js";

const router = express.Router();

router.use(requireAuth());

router.post("/", createMonitor);
router.get("/", getMonitors);
router.get("/:id", getMonitorById);
router.put("/:id", updateMonitor);
router.delete("/:id", deleteMonitor);
router.get("/:id/logs", getMonitorLogs);
router.get("/:id/stats", getMonitorStats);
router.get("/:id/domain-info", getMonitorDomainInfo);

export default router;
'@ | Set-Content -Path "src\routes\monitors.routes.js" -Encoding ASCII

# ============ FRONTEND: extend MonitorDetailModal with SSL/domain section ============
Set-Location ..\frontend

@'
import { useEffect, useState } from "react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { useApiClient } from "../api/client";

const MonitorDetailModal = ({ monitorId, isOpen, onClose, onUpdated, onDeleted }) => {
  const api = useApiClient();
  const [stats, setStats] = useState(null);
  const [domainInfo, setDomainInfo] = useState(null);
  const [domainLoading, setDomainLoading] = useState(true);
  const [loading, setLoading] = useState(true);
  const [isEditing, setIsEditing] = useState(false);
  const [editName, setEditName] = useState("");
  const [editUrl, setEditUrl] = useState("");
  const [editInterval, setEditInterval] = useState(5);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  const fetchStats = async () => {
    setLoading(true);
    try {
      const res = await api.get("/api/monitors/" + monitorId + "/stats");
      setStats(res.data);
      setEditName(res.data.monitor.name);
      setEditUrl(res.data.monitor.url);
      setEditInterval(res.data.monitor.checkIntervalMinutes);
    } catch (err) {
      setError("Failed to load monitor details");
    } finally {
      setLoading(false);
    }
  };

  const fetchDomainInfo = async () => {
    setDomainLoading(true);
    try {
      const res = await api.get("/api/monitors/" + monitorId + "/domain-info");
      setDomainInfo(res.data);
    } catch (err) {
      setDomainInfo(null);
    } finally {
      setDomainLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen && monitorId) {
      fetchStats();
      fetchDomainInfo();
      setIsEditing(false);
    }
  }, [isOpen, monitorId]);

  if (!isOpen) return null;

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError("");
    try {
      const res = await api.put("/api/monitors/" + monitorId, {
        name: editName,
        url: editUrl,
        checkIntervalMinutes: editInterval,
      });
      onUpdated(res.data);
      setIsEditing(false);
      fetchStats();
      fetchDomainInfo();
    } catch (err) {
      setError(err.response?.data?.error || "Failed to update monitor");
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm("Delete this monitor and all its history?")) return;
    try {
      await api.delete("/api/monitors/" + monitorId);
      onDeleted(monitorId);
      onClose();
    } catch (err) {
      setError("Failed to delete monitor");
    }
  };

  const chartData =
    stats?.recentLogs?.map((log) => ({
      time: new Date(log.checkedAt).toLocaleTimeString(),
      responseTime: log.responseTimeMs,
    })) || [];

  const formatDate = (d) => (d ? new Date(d).toLocaleDateString() : "N/A");

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg p-6 w-full max-w-2xl shadow-lg max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-start mb-4">
          <h2 className="text-lg font-bold">Monitor Details</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-black">X</button>
        </div>

        {error && <div className="bg-red-100 text-red-700 text-sm px-3 py-2 rounded mb-3">{error}</div>}

        {loading ? (
          <div className="py-10 text-center text-gray-400">Loading...</div>
        ) : (
          <>
            {isEditing ? (
              <form onSubmit={handleSave} className="space-y-3 mb-6">
                <div>
                  <label className="block text-sm font-medium mb-1">Name</label>
                  <input value={editName} onChange={(e) => setEditName(e.target.value)} required className="w-full border rounded px-3 py-2 text-sm" />
                </div>
                <div>
                  <label className="block text-sm font-medium mb-1">URL</label>
                  <input value={editUrl} onChange={(e) => setEditUrl(e.target.value)} required className="w-full border rounded px-3 py-2 text-sm" />
                </div>
                <div>
                  <label className="block text-sm font-medium mb-1">Check Interval (minutes)</label>
                  <input type="number" min="1" value={editInterval} onChange={(e) => setEditInterval(Number(e.target.value))} className="w-full border rounded px-3 py-2 text-sm" />
                </div>
                <div className="flex gap-2">
                  <button type="submit" disabled={saving} className="bg-black text-white px-4 py-2 rounded text-sm disabled:opacity-50">
                    {saving ? "Saving..." : "Save Changes"}
                  </button>
                  <button type="button" onClick={() => setIsEditing(false)} className="border px-4 py-2 rounded text-sm">
                    Cancel
                  </button>
                </div>
              </form>
            ) : (
              <div className="mb-6">
                <div className="flex justify-between items-center">
                  <div>
                    <h3 className="text-xl font-semibold">{stats.monitor.name}</h3>
                    <a href={stats.monitor.url} target="_blank" rel="noreferrer" className="text-sm text-blue-600 break-all">
                      {stats.monitor.url}
                    </a>
                  </div>
                  <span
                    className={
                      "px-3 py-1 text-xs rounded font-medium " +
                      (stats.monitor.lastStatus === "up"
                        ? "bg-green-100 text-green-700"
                        : stats.monitor.lastStatus === "down"
                        ? "bg-red-100 text-red-700"
                        : "bg-gray-100 text-gray-600")
                    }
                  >
                    {stats.monitor.lastStatus}
                  </span>
                </div>

                <div className="flex gap-4 mt-3 text-xs text-gray-500 flex-wrap">
                  <span>Protocol: {stats.urlInfo.protocol || "n/a"}</span>
                  <span>HTTPS: {stats.urlInfo.isHttps ? "Yes" : "No"}</span>
                  <span>Host: {stats.urlInfo.hostname || "n/a"}</span>
                  <span>Interval: every {stats.monitor.checkIntervalMinutes} min</span>
                </div>

                <div className="flex gap-2 mt-3">
                  <button onClick={() => setIsEditing(true)} className="text-sm border px-3 py-1.5 rounded">Edit</button>
                  <button onClick={handleDelete} className="text-sm border border-red-300 text-red-600 px-3 py-1.5 rounded">Delete</button>
                </div>
              </div>
            )}

            <div className="grid grid-cols-3 gap-3 mb-6">
              <div className="border rounded-lg p-3 text-center">
                <div className="text-2xl font-bold">{stats.uptimePercent ?? "N/A"}{stats.uptimePercent ? "%" : ""}</div>
                <div className="text-xs text-gray-500">Uptime (24h)</div>
              </div>
              <div className="border rounded-lg p-3 text-center">
                <div className="text-2xl font-bold">{stats.avgResponseTime ?? "N/A"}{stats.avgResponseTime ? "ms" : ""}</div>
                <div className="text-xs text-gray-500">Avg Response Time</div>
              </div>
              <div className="border rounded-lg p-3 text-center">
                <div className="text-2xl font-bold">{stats.totalChecks24h}</div>
                <div className="text-xs text-gray-500">Checks (24h)</div>
              </div>
            </div>

            <div className="mb-6">
              <h4 className="text-sm font-semibold mb-2">SSL Certificate & Domain Info</h4>
              {domainLoading ? (
                <p className="text-sm text-gray-400">Looking up SSL and domain info...</p>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div className="border rounded-lg p-3">
                    <div className="text-xs font-semibold text-gray-500 mb-2">SSL CERTIFICATE</div>
                    {domainInfo?.ssl?.available ? (
                      <ul className="text-sm space-y-1">
                        <li><span className="text-gray-500">Issuer:</span> {domainInfo.ssl.issuer}</li>
                        <li><span className="text-gray-500">Valid From:</span> {formatDate(domainInfo.ssl.validFrom)}</li>
                        <li><span className="text-gray-500">Valid To:</span> {formatDate(domainInfo.ssl.validTo)}</li>
                        <li>
                          <span className="text-gray-500">Expires in:</span>{" "}
                          <span className={domainInfo.ssl.daysUntilExpiry < 14 ? "text-red-600 font-semibold" : "text-green-600"}>
                            {domainInfo.ssl.daysUntilExpiry} days
                          </span>
                        </li>
                      </ul>
                    ) : (
                      <p className="text-sm text-gray-400">{domainInfo?.ssl?.error || "No SSL info available (not HTTPS?)"}</p>
                    )}
                  </div>

                  <div className="border rounded-lg p-3">
                    <div className="text-xs font-semibold text-gray-500 mb-2">DOMAIN (WHOIS)</div>
                    {domainInfo?.domain?.available ? (
                      <ul className="text-sm space-y-1">
                        <li><span className="text-gray-500">Domain:</span> {domainInfo.domain.domain}</li>
                        <li><span className="text-gray-500">Registrar:</span> {domainInfo.domain.registrar || "N/A"}</li>
                        <li><span className="text-gray-500">Registered:</span> {formatDate(domainInfo.domain.createdDate)}</li>
                        <li><span className="text-gray-500">Expires:</span> {formatDate(domainInfo.domain.expiryDate)}</li>
                        {domainInfo.domain.daysUntilExpiry !== null && (
                          <li>
                            <span className="text-gray-500">Expires in:</span>{" "}
                            <span className={domainInfo.domain.daysUntilExpiry < 30 ? "text-red-600 font-semibold" : "text-green-600"}>
                              {domainInfo.domain.daysUntilExpiry} days
                            </span>
                          </li>
                        )}
                      </ul>
                    ) : (
                      <p className="text-sm text-gray-400">{domainInfo?.domain?.error || "No WHOIS data available"}</p>
                    )}
                  </div>
                </div>
              )}
            </div>

            {chartData.length > 0 && (
              <div className="mb-6">
                <h4 className="text-sm font-semibold mb-2">Response Time (recent checks)</h4>
                <ResponsiveContainer width="100%" height={180}>
                  <LineChart data={chartData}>
                    <XAxis dataKey="time" tick={{ fontSize: 10 }} />
                    <YAxis tick={{ fontSize: 10 }} />
                    <Tooltip />
                    <Line type="monotone" dataKey="responseTime" stroke="#000" strokeWidth={2} dot={false} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            )}

            <div>
              <h4 className="text-sm font-semibold mb-2">Incident History</h4>
              {stats.incidents.length === 0 ? (
                <p className="text-sm text-gray-400">No incidents recorded.</p>
              ) : (
                <ul className="space-y-2">
                  {stats.incidents.map((inc) => (
                    <li key={inc._id} className="text-sm border rounded px-3 py-2 flex justify-between">
                      <span>Started: {new Date(inc.startedAt).toLocaleString()}</span>
                      <span className={inc.resolvedAt ? "text-green-600" : "text-red-600"}>
                        {inc.resolvedAt ? "Resolved " + new Date(inc.resolvedAt).toLocaleString() : "Ongoing"}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default MonitorDetailModal;
'@ | Set-Content -Path "src\components\MonitorDetailModal.jsx" -Encoding ASCII

Set-Location ..
Write-Host "Done: SSL + WHOIS domain info added (backend service + route), modal updated (frontend)" -ForegroundColor Green
Write-Host "Restart both dev servers." -ForegroundColor Yellow 