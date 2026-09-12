import mongoose from "mongoose";

const incidentSchema = new mongoose.Schema(
  {
    monitorId: { type: mongoose.Schema.Types.ObjectId, ref: "Monitor", required: true, index: true },
    startedAt: { type: Date, required: true },
    resolvedAt: { type: Date },
    cause: { type: String },
  },
  { timestamps: true }
);

export default mongoose.model("Incident", incidentSchema);
