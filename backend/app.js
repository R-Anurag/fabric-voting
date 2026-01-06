import express from "express";
import cors from "cors";
import votingRoutes from "./routes/voting.routes.js";

const app = express();

// 🔥 REQUIRED middleware
app.use(cors());
app.use(express.json());          // <-- THIS WAS MISSING
app.use(express.urlencoded({ extended: true }));

app.use("/api", votingRoutes);

const PORT = 5000;
app.listen(PORT, () => {
    console.log(`🚀 Backend running at http://localhost:${PORT}`);
});

