cd C:\Users\DELL\Desktop\dev-pulse\frontend

@'
import { useState } from "react";

const ConfirmDeleteModal = ({ isOpen, onClose, onConfirm, monitorName, monitorUrl }) => {
  const [typedUrl, setTypedUrl] = useState("");
  const [deleting, setDeleting] = useState(false);

  if (!isOpen) return null;

  const isMatch = typedUrl.trim() === monitorUrl;

  const handleConfirm = async () => {
    if (!isMatch) return;
    setDeleting(true);
    try {
      await onConfirm();
    } finally {
      setDeleting(false);
      setTypedUrl("");
    }
  };

  const handleClose = () => {
    setTypedUrl("");
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-[60] p-4">
      <div className="bg-white rounded-lg p-6 w-full max-w-md shadow-lg border border-red-200">
        <h2 className="text-lg font-bold text-red-600 mb-2">Delete Monitor</h2>
        <p className="text-sm text-gray-600 mb-4">
          This will permanently delete <strong>{monitorName}</strong> and all its check history and incidents. This cannot be undone.
        </p>

        <label className="block text-sm font-medium mb-1">
          Type <span className="font-mono bg-gray-100 px-1 rounded">{monitorUrl}</span> to confirm
        </label>
        <input
          type="text"
          value={typedUrl}
          onChange={(e) => setTypedUrl(e.target.value)}
          placeholder={monitorUrl}
          className="w-full border rounded px-3 py-2 text-sm mb-4"
          autoFocus
        />

        <div className="flex justify-end gap-2">
          <button onClick={handleClose} className="px-4 py-2 text-sm rounded border">
            Cancel
          </button>
          <button
            onClick={handleConfirm}
            disabled={!isMatch || deleting}
            className="px-4 py-2 text-sm rounded bg-red-600 text-white disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {deleting ? "Deleting..." : "Delete Monitor"}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmDeleteModal;
'@ | Set-Content -Path "src\components\ConfirmDeleteModal.jsx" -Encoding ASCII

@'
import { useEffect, useState } from "react";
import { useApiClient } from "../api/client";
import AddMonitorModal from "../components/AddMonitorModal";
import MonitorDetailModal from "../components/MonitorDetailModal";

const Dashboard = () => {
  const api = useApiClient();
  const [monitors, setMonitors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [selectedMonitorId, setSelectedMonitorId] = useState(null);
  const [error, setError] = useState("");

  const fetchMonitors = async () => {
    try {
      const res = await api.get("/api/monitors");
      setMonitors(res.data);
    } catch (err) {
      setError("Failed to load monitors");
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

  const handleMonitorUpdated = (updated) => {
    setMonitors((prev) => prev.map((m) => (m._id === updated._id ? updated : m)));
  };

  const handleMonitorDeleted = (id) => {
    setMonitors((prev) => prev.filter((m) => m._id !== id));
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
          onClick={() => setIsAddModalOpen(true)}
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
            <div
              key={m._id}
              onClick={() => setSelectedMonitorId(m._id)}
              className="border rounded-lg p-4 shadow-sm cursor-pointer hover:shadow-md transition"
            >
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
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        onMonitorAdded={handleMonitorAdded}
        currentCount={monitors.length}
      />

      <MonitorDetailModal
        monitorId={selectedMonitorId}
        isOpen={!!selectedMonitorId}
        onClose={() => setSelectedMonitorId(null)}
        onUpdated={handleMonitorUpdated}
        onDeleted={handleMonitorDeleted}
      />
    </div>
  );
};

export default Dashboard;
'@ | Set-Content -Path "src\pages\Dashboard.jsx" -Encoding ASCII

@'
import { useEffect, useState } from "react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { useApiClient } from "../api/client";
import ConfirmDeleteModal from "./ConfirmDeleteModal";

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
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);

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

  const handleDeleteConfirmed = async () => {
    await api.delete("/api/monitors/" + monitorId);
    onDeleted(monitorId);
    setIsDeleteModalOpen(false);
    onClose();
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
                  <button onClick={() => setIsDeleteModalOpen(true)} className="text-sm border border-red-300 text-red-600 px-3 py-1.5 rounded">Delete</button>
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

      {stats && (
        <ConfirmDeleteModal
          isOpen={isDeleteModalOpen}
          onClose={() => setIsDeleteModalOpen(false)}
          onConfirm={handleDeleteConfirmed}
          monitorName={stats.monitor.name}
          monitorUrl={stats.monitor.url}
        />
      )}
    </div>
  );
};

export default MonitorDetailModal;
'@ | Set-Content -Path "src\components\MonitorDetailModal.jsx" -Encoding ASCII

Write-Host "Done: ConfirmDeleteModal added, delete now requires typing the exact URL" -ForegroundColor Green