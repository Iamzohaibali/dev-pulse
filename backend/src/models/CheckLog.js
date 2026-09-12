import mongoose from "mongoose";

const checkLogSchema = new mongoose.Schema(
  {
    monitorId: { type: mongoose.Schema.Types.ObjectId, ref: "Monitor", required: true, index: true },
    status: { type: String, enum: ["up", "down"], required: true },
    responseTimeMs: { type: Number },
    statusCode: { type: Number },
    checkedAt: { type: Date, default: Date.now },
  }
);

export default mongoose.model("CheckLog", checkLogSchema);
