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
