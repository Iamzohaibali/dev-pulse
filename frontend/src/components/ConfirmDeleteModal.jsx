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
