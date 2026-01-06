import fs from "fs";
import path from "path";
import crypto from "crypto";
import grpc from "@grpc/grpc-js";
import { connect, signers } from "@hyperledger/fabric-gateway";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const channelName = "election-channel";
const chaincodeName = "voting";

// Wallet paths
const walletPath = path.join(__dirname, "../wallet");
const certPath = path.join(walletPath, "admin-cert.pem");
const keyPath = path.join(walletPath, "admin-key.pem");

export async function getContract() {
    // Load identity
    const certificate = fs.readFileSync(certPath);
    const privateKeyPem = fs.readFileSync(keyPath);

    const privateKey = crypto.createPrivateKey(privateKeyPem);
    const signer = signers.newPrivateKeySigner(privateKey);

    // Connect to Org1 peer
    const client = new grpc.Client(
        "localhost:7051",
        grpc.credentials.createInsecure()
    );

    const gateway = connect({
        client,
        identity: {
            mspId: "Org1MSP",
            credentials: certificate,
        },
        signer,
        // 🔥 CRITICAL: ENABLE DISCOVERY
        discovery: {
            enabled: true,
            asLocalhost: true,
        },
    });

    const network = gateway.getNetwork(channelName);
    const contract = network.getContract(chaincodeName);

    return { gateway, contract };
}
