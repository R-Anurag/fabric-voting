import express from "express";
import {
    castVote,
    queryVote,
    getAllVotes,
    getResults
} from "../fabric/voting.js";

const router = express.Router();

router.post("/vote", async (req, res) => {
    try {
        const { voterId, candidate } = req.body;

        if (!voterId || !candidate) {
            return res.status(400).json({ error: "Missing voterId or candidate" });
        }

        await castVote(voterId, candidate);
        res.json({ message: "Vote recorded" });

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.get("/vote/:voterId", async (req, res) => {
    try {
        const vote = await queryVote(req.params.voterId);
        res.json({ voterId: req.params.voterId, vote });
    } catch (err) {
        res.status(404).json({ error: err.message });
    }
});

// voterId → candidate
router.get("/votes", async (req, res) => {
    try {
        const votes = await getAllVotes();
        res.json(votes);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// candidate → count
router.get("/results", async (req, res) => {
    try {
        const results = await getResults();
        res.json(results);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

export default router;
