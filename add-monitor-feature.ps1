# ============ BACKEND: update createMonitor with 5-monitor limit ============
Set-Location backend

@'
import Monitor from "../models/Monitor.js";
import CheckLog from "../models/CheckLog.js";
import { getUserId } from "../middleware/auth.middleware.js";

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
    const monitor = await Monitor.findOneAndUpdate({ _id: req.params.id, userId }, req.body, { new: true });
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
'@ | Set-Content -Path "src\controllers\monitors.controller.js" -Encoding ASCII

# ============ FRONTEND: AddMonitorModal + Dashboard ============
Set-Location ..\frontend

@'
import { useState } from "react";
import { useApiClient } from "../api/client";

const AddMonitorModal = ({ isOpen, onClose, onMonitorAdded, currentCount }) => {
  const api = useApiClient();
  const [name, setName] = useState("");
  const [url, setUrl] = useState("");
  const [checkIntervalMinutes, setCheckIntervalMinutes] = useState(5);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");

    if (currentCount >= 5) {
      setError("You can only monitor a maximum of 5 websites.");
      return;
    }

    setLoading(true);
    try {
      const res = await api.post("/api/monitors", { name, url, checkIntervalMinutes });
      onMonitorAdded(res.data);
      setName("");
      setUrl("");
      setCheckIntervalMinutes(5);
      onClose();
    } catch (err) {
      setError(err.response?.data?.error || "Failed to add monitor");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 w-full max-w-md shadow-lg">
        <h2 className="text-lg font-bold mb-4">Add Monitor</h2>

        {error && (
          <div className="bg-red-100 text-red-700 text-sm px-3 py-2 rounded mb-3">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-3">
          <div>
            <label className="block text-sm font-medium mb-1">Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="My Website"
              required
              className="w-full border rounded px-3 py-2 text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">URL</label>
            <input
              type="url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://example.com"
              required
              className="w-full border rounded px-3 py-2 text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Check Interval (minutes)</label>
            <input
              type="number"
              min="1"
              value={checkIntervalMinutes}
              onChange={(e) => setCheckIntervalMinutes(Number(e.target.value))}
              className="w-full border rounded px-3 py-2 text-sm"
            />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm rounded border"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-4 py-2 text-sm rounded bg-black text-white disabled:opacity-50"
            >
              {loading ? "Adding..." : "Add Monitor"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default AddMonitorModal;
'@ | Set-Content -Path "src\components\AddMonitorModal.jsx" -Encoding ASCII

@'
import { useEffect, useState } from "react";
import { useApiClient } from "../api/client";
import AddMonitorModal from "../components/AddMonitorModal";

const Dashboard = () => {
  const api = useApiClient();
  const [monitors, setMonitors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [error, setError] = useState("");

  const fetchMonitors = async () => {
    try {
      const res = await api.get("/api/monitors");
      setMonitors(res.data);
    } catch (err) {
      setError("Failed to load monitors");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMonitors();
  }, []);

  const handleMonitorAdded = (newMonitor) => {
    setMonitors((prev) => [newMonitor, ...prev]);
  };

  const handleDelete = async (id) => {
    if (!confirm("Delete this monitor?")) return;
    try {
      await api.delete("/api/monitors/" + id);
      setMonitors((prev) => prev.filter((m) => m._id !== id));
    } catch (err) {
      console.error(err);
    }
  };

  if (loading) return <div className="p-6">Loading...</div>;

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h1 className="text-2xl font-bold">Your Monitors</h1>
          <p className="text-sm text-gray-500">{monitors.length} / 5 used</p>
        </div>
        <button
          onClick={() => setIsModalOpen(true)}
          disabled={monitors.length >= 5}
          className="bg-black text-white px-4 py-2 rounded-md text-sm disabled:opacity-40 disabled:cursor-not-allowed"
        >
          + Add Monitor
        </button>
      </div>

      {error && <div className="text-red-600 text-sm mb-3">{error}</div>}

      {monitors.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          No monitors yet. Click "Add Monitor" to start tracking a website.
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {monitors.map((m) => (
            <div key={m._id} className="border rounded-lg p-4 shadow-sm relative">
              <button
                onClick={() => handleDelete(m._id)}
                className="absolute top-2 right-2 text-gray-400 hover:text-red-500 text-sm"
              >
                X
              </button>
              <h2 className="font-semibold">{m.name}</h2>
              <p className="text-sm text-gray-500 break-all">{m.url}</p>
              <span
                className={
                  "inline-block mt-2 px-2 py-1 text-xs rounded " +
                  (m.lastStatus === "up"
                    ? "bg-green-100 text-green-700"
                    : m.lastStatus === "down"
                    ? "bg-red-100 text-red-700"
                    : "bg-gray-100 text-gray-600")
                }
              >
                {m.lastStatus}
              </span>
            </div>
          ))}
        </div>
      )}

      <AddMonitorModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onMonitorAdded={handleMonitorAdded}
        currentCount={monitors.length}
      />
    </div>
  );
};

export default Dashboard;
'@ | Set-Content -Path "src\pages\Dashboard.jsx" -Encoding ASCII

Set-Location ..
Write-Host "Done. AddMonitorModal.jsx and updated Dashboard.jsx (frontend), monitors.controller.js (backend) written." -ForegroundColor Green
Write-Host "Restart both dev servers now (Ctrl+C then npm run dev in each terminal)." -ForegroundColor Yellow