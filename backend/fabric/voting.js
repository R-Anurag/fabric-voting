import { getContract } from "./gateway.js";

export async function castVote(voterId, candidate) {
    const { gateway, contract } = await getContract();
    try {
        await contract.submitTransaction("CastVote", voterId, candidate);
        return { success: true };
    } finally {
        gateway.close();
    }
}

export async function queryVote(voterId) {
    const { gateway, contract } = await getContract();
    try {
        const result = await contract.evaluateTransaction("QueryVote", voterId);

        // ✅ CRITICAL FIX
        return Buffer.from(result).toString("utf8");
    } finally {
        gateway.close();
    }
}

export async function getAllVotes() {
    const { gateway, contract } = await getContract();
    try {
        const result = await contract.evaluateTransaction("GetAllVotes");

        // ✅ Convert → parse ONCE
        return JSON.parse(Buffer.from(result).toString("utf8"));
    } finally {
        gateway.close();
    }
}

export async function getResults() {
    const { gateway, contract } = await getContract();
    try {
        const result = await contract.evaluateTransaction("GetResults");

        // ✅ Convert → parse ONCE
        return JSON.parse(Buffer.from(result).toString("utf8"));
    } finally {
        gateway.close();
    }
}
