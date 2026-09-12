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
