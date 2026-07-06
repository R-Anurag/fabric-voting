package main

import (
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
	contractapi.Contract
}

// VoteRecord stores the full vote details on the ledger
type VoteRecord struct {
	VoterID    string `json:"voterId"`
	ElectionID string `json:"electionId"`
	PartyID    string `json:"partyId"`
	Timestamp  string `json:"timestamp"`
}

// ========================
// CastVote
// ========================
func (s *SmartContract) CastVote(
	ctx contractapi.TransactionContextInterface,
	voterID string,
	electionID string,
	partyID string,
) error {
	if voterID == "" || electionID == "" || partyID == "" {
		return fmt.Errorf("voterID, electionID and partyID must all be provided")
	}

	// Scoped key: one vote per voter per election
	voterKey := "vote:" + electionID + ":" + voterID

	existing, err := ctx.GetStub().GetState(voterKey)
	if err != nil {
		return fmt.Errorf("failed to read world state: %v", err)
	}
	if existing != nil {
		return fmt.Errorf("voter %s has already voted in election %s", voterID, electionID)
	}

	// Get transaction timestamp
	txTimestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return fmt.Errorf("failed to get transaction timestamp: %v", err)
	}
	timestamp := time.Unix(txTimestamp.Seconds, 0).UTC().Format(time.RFC3339)

	// Store full vote record
	record := VoteRecord{
		VoterID:    voterID,
		ElectionID: electionID,
		PartyID:    partyID,
		Timestamp:  timestamp,
	}
	recordBytes, err := json.Marshal(record)
	if err != nil {
		return fmt.Errorf("failed to marshal vote record: %v", err)
	}
	err = ctx.GetStub().PutState(voterKey, recordBytes)
	if err != nil {
		return fmt.Errorf("failed to record vote: %v", err)
	}

	// Update scoped party count: count:{electionId}:{partyId}
	countKey := "count:" + electionID + ":" + partyID

	countBytes, err := ctx.GetStub().GetState(countKey)
	if err != nil {
		return fmt.Errorf("failed to read party count: %v", err)
	}

	count := 0
	if countBytes != nil {
		count, _ = strconv.Atoi(string(countBytes))
	}
	count++

	err = ctx.GetStub().PutState(countKey, []byte(strconv.Itoa(count)))
	if err != nil {
		return fmt.Errorf("failed to update party count: %v", err)
	}

	return nil
}

// ========================
// QueryVote
// ========================
func (s *SmartContract) QueryVote(
	ctx contractapi.TransactionContextInterface,
	electionID string,
	voterID string,
) (string, error) {
	voterKey := "vote:" + electionID + ":" + voterID

	voteBytes, err := ctx.GetStub().GetState(voterKey)
	if err != nil {
		return "", fmt.Errorf("failed to read vote: %v", err)
	}
	if voteBytes == nil {
		return "", fmt.Errorf("no vote found for voter %s in election %s", voterID, electionID)
	}

	return string(voteBytes), nil
}

// ========================
// GetVotesByElection
// Returns all VoteRecords for a given election
// ========================
func (s *SmartContract) GetVotesByElection(
	ctx contractapi.TransactionContextInterface,
	electionID string,
) (string, error) {
	prefix := "vote:" + electionID + ":"
	// Range end: increment last char of prefix to get upper bound
	startKey := prefix
	endKey := "vote:" + electionID + ";"

	iterator, err := ctx.GetStub().GetStateByRange(startKey, endKey)
	if err != nil {
		return "", fmt.Errorf("failed to get votes by election: %v", err)
	}
	defer iterator.Close()

	var votes []VoteRecord

	for iterator.HasNext() {
		kv, err := iterator.Next()
		if err != nil {
			return "", err
		}
		var record VoteRecord
		if err := json.Unmarshal(kv.Value, &record); err != nil {
			continue
		}
		votes = append(votes, record)
	}

	if votes == nil {
		votes = []VoteRecord{}
	}

	jsonBytes, err := json.Marshal(votes)
	if err != nil {
		return "", fmt.Errorf("failed to marshal votes: %v", err)
	}

	return string(jsonBytes), nil
}

// ========================
// GetResultsByElection
// Returns { partyId: count } for a given election
// ========================
func (s *SmartContract) GetResultsByElection(
	ctx contractapi.TransactionContextInterface,
	electionID string,
) (string, error) {
	startKey := "count:" + electionID + ":"
	endKey := "count:" + electionID + ";"

	iterator, err := ctx.GetStub().GetStateByRange(startKey, endKey)
	if err != nil {
		return "", fmt.Errorf("failed to get results: %v", err)
	}
	defer iterator.Close()

	results := make(map[string]int)
	prefixLen := len("count:" + electionID + ":")

	for iterator.HasNext() {
		kv, err := iterator.Next()
		if err != nil {
			return "", err
		}
		partyID := kv.Key[prefixLen:]
		count, _ := strconv.Atoi(string(kv.Value))
		results[partyID] = count
	}

	jsonBytes, err := json.Marshal(results)
	if err != nil {
		return "", fmt.Errorf("failed to marshal results: %v", err)
	}

	return string(jsonBytes), nil
}

// ========================
// GetAllVotes (kept for backwards compat)
// ========================
func (s *SmartContract) GetAllVotes(
	ctx contractapi.TransactionContextInterface,
) (string, error) {
	iterator, err := ctx.GetStub().GetStateByRange("vote:", "vote;")
	if err != nil {
		return "", err
	}
	defer iterator.Close()

	var votes []VoteRecord

	for iterator.HasNext() {
		kv, err := iterator.Next()
		if err != nil {
			return "", err
		}
		var record VoteRecord
		if err := json.Unmarshal(kv.Value, &record); err != nil {
			continue
		}
		votes = append(votes, record)
	}

	if votes == nil {
		votes = []VoteRecord{}
	}

	jsonBytes, err := json.Marshal(votes)
	if err != nil {
		return "", err
	}

	return string(jsonBytes), nil
}

// ========================
// main
// ========================
func main() {
	chaincode, err := contractapi.NewChaincode(new(SmartContract))
	if err != nil {
		panic(err.Error())
	}
	if err := chaincode.Start(); err != nil {
		panic(err.Error())
	}
}
