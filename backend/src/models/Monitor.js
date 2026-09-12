import mongoose from "mongoose";

const monitorSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    name: { type: String, required: true, trim: true },
    url: { type: String, required: true, trim: true },
    checkIntervalMinutes: { type: Number, default: 5, min: 1 },
    isActive: { type: Boolean, default: true },
    lastStatus: { type: String, enum: ["up", "down", "unknown"], default: "unknown" },
    lastCheckedAt: { type: Date },
  },
  { timestamps: true }
);

export default mongoose.model("Monitor", monitorSchema);
