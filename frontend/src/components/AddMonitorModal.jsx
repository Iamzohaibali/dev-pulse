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
