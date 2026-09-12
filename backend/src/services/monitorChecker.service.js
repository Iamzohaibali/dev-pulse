import cron from "node-cron";
import axios from "axios";
import { clerkClient } from "@clerk/express";
import Monitor from "../models/Monitor.js";
import CheckLog from "../models/CheckLog.js";
import Incident from "../models/Incident.js";
import { sendDownAlert, sendRecoveryAlert } from "./email.service.js";

const getUserEmail = async (userId) => {
  try {
    const user = await clerkClient.users.getUser(userId);
    return user.emailAddresses?.[0]?.emailAddress || null;
  } catch (err) {
    console.error("Failed to fetch user email from Clerk:", err.message);
    return null;
  }
};

const checkMonitor = async (monitor) => {
  const startTime = Date.now();
  let status = "down";
  let statusCode = null;

  try {
    const response = await axios.get(monitor.url, { timeout: 10000 });
    statusCode = response.status;
    status = response.status >= 200 && response.status < 400 ? "up" : "down";
  } catch (err) {
    status = "down";
    statusCode = err.response?.status || 0;
  }

  const responseTimeMs = Date.now() - startTime;

  await CheckLog.create({ monitorId: monitor._id, status, responseTimeMs, statusCode });

  const wasUp = monitor.lastStatus === "up" || monitor.lastStatus === "unknown";

  if (status === "down" && wasUp) {
    await Incident.create({ monitorId: monitor._id, startedAt: new Date() });
    const email = await getUserEmail(monitor.userId);
    if (email) await sendDownAlert(email, monitor);
  }

  if (status === "up" && monitor.lastStatus === "down") {
    await Incident.findOneAndUpdate({ monitorId: monitor._id, resolvedAt: null }, { resolvedAt: new Date() });
    const email = await getUserEmail(monitor.userId);
    if (email) await sendRecoveryAlert(email, monitor);
  }

  monitor.lastStatus = status;
  monitor.lastCheckedAt = new Date();
  await monitor.save();
};

export const startMonitorChecker = () => {
  cron.schedule("* * * * *", async () => {
    try {
      const monitors = await Monitor.find({ isActive: true });
      await Promise.all(monitors.map(checkMonitor));
    } catch (err) {
      console.error("Monitor checker error:", err.message);
    }
  });
  console.log("Monitor checker cron job started (every 1 minute)");
};
