import express from "express";
import {
    castVote,
    queryVote,
    getVotesByElection,
    getResultsByElection,
    getAllVotes,
} from "../fabric/voting.js";

const router = express.Router();

// POST /api/vote
// Body: { voterId, electionId, partyId }
router.post("/vote", async (req, res) => {
    try {
        const { voterId, electionId, partyId } = req.body;

        if (!voterId || !electionId || !partyId) {
            return res.status(400).json({ error: "Missing voterId, electionId or partyId" });
        }

        await castVote(voterId, electionId, partyId);
        res.json({ message: "Vote recorded on ledger" });

    } catch (err) {
        // Chaincode double-vote error comes through here
        const status = err.message.includes("already voted") ? 409 : 500;
        res.status(status).json({ error: err.message });
    }
});

// GET /api/vote/:electionId/:voterId
router.get("/vote/:electionId/:voterId", async (req, res) => {
    try {
        const { electionId, voterId } = req.params;
        const vote = await queryVote(electionId, voterId);
        res.json(vote);
    } catch (err) {
        res.status(404).json({ error: err.message });
    }
});

// GET /api/votes/:electionId  — all VoteRecords for one election
router.get("/votes/:electionId", async (req, res) => {
    try {
        const votes = await getVotesByElection(req.params.electionId);
        res.json(votes);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/votes  — all votes across all elections (BlockchainExplorer)
router.get("/votes", async (req, res) => {
    try {
        const votes = await getAllVotes();
        res.json(votes);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET /api/results/:electionId  — { partyId: count }
router.get("/results/:electionId", async (req, res) => {
    try {
        const results = await getResultsByElection(req.params.electionId);
        res.json(results);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

export default router;
