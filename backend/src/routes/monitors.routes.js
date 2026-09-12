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
