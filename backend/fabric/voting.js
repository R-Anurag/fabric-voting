import { getContract } from "./gateway.js";

const parse = (result) => JSON.parse(Buffer.from(result).toString("utf8"));

export async function castVote(voterId, electionId, partyId) {
    const { gateway, contract } = await getContract();
    try {
        await contract.submitTransaction("CastVote", voterId, electionId, partyId);
        return { success: true };
    } finally {
        gateway.close();
    }
}

export async function queryVote(electionId, voterId) {
    const { gateway, contract } = await getContract();
    try {
        const result = await contract.evaluateTransaction("QueryVote", electionId, voterId);
        return parse(result);
    } finally {
        gateway.close();
    }
}

export async function getVotesByElection(electionId) {
    const { gateway, contract } = await getContract();
    try {
        const result = await contract.evaluateTransaction("GetVotesByElection", electionId);
        return parse(result);
    } finally {
        gateway.close();
    }
}

export async function getResultsByElection(electionId) {
    const { gateway, contract } = await getContract();
    try {
        const result = await contract.evaluateTransaction("GetResultsByElection", electionId);
        return parse(result);
    } finally {
        gateway.close();
    }
}

export async function getAllVotes() {
    const { gateway, contract } = await getContract();
    try {
        const result = await contract.evaluateTransaction("GetAllVotes");
        return parse(result);
    } finally {
        gateway.close();
    }
}
