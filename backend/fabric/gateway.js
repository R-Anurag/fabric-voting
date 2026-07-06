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

const walletPath = path.join(__dirname, "../wallet");
const certPath = path.join(walletPath, "admin-cert.pem");
const keyPath = path.join(walletPath, "admin-key.pem");

const peerEndpoint = process.env.PEER_ENDPOINT || "localhost:7051";
const asLocalhost = process.env.AS_LOCALHOST !== "false";

export async function getContract() {
    const certificate = fs.readFileSync(certPath);
    const privateKeyPem = fs.readFileSync(keyPath);

    const privateKey = crypto.createPrivateKey(privateKeyPem);
    const signer = signers.newPrivateKeySigner(privateKey);

    const client = new grpc.Client(
        peerEndpoint,
        grpc.credentials.createInsecure()
    );

    const gateway = connect({
        client,
        identity: {
            mspId: "Org1MSP",
            credentials: certificate,
        },
        signer,
        discovery: {
            enabled: true,
            asLocalhost,
        },
    });

    const network = gateway.getNetwork(channelName);
    const contract = network.getContract(chaincodeName);

    return { gateway, contract };
}
