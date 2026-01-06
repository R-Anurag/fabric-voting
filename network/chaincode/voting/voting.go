package main

import (
    "encoding/json"
    "fmt"
    "strconv"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides voting functions
type SmartContract struct {
    contractapi.Contract
}

// ========================
// CastVote
// ========================
func (s *SmartContract) CastVote(
    ctx contractapi.TransactionContextInterface,
    voterID string,
    candidate string,
) error {

    if voterID == "" || candidate == "" {
        return fmt.Errorf("voterID and candidate must be provided")
    }

    // Use namespaced voter key
    voterKey := "vote:" + voterID

    // 🔒 Prevent double voting
    existing, err := ctx.GetStub().GetState(voterKey)
    if err != nil {
        return fmt.Errorf("failed to read world state: %v", err)
    }
    if existing != nil {
        return fmt.Errorf("voter %s has already voted", voterID)
    }

    // Store voter -> candidate
    err = ctx.GetStub().PutState(voterKey, []byte(candidate))
    if err != nil {
        return fmt.Errorf("failed to record vote: %v", err)
    }

    // ========================
    // Update candidate count
    // ========================
    countKey := "count:" + candidate

    countBytes, err := ctx.GetStub().GetState(countKey)
    if err != nil {
        return fmt.Errorf("failed to read candidate count: %v", err)
    }

    count := 0
    if countBytes != nil {
        count, _ = strconv.Atoi(string(countBytes))
    }

    count++
    err = ctx.GetStub().PutState(countKey, []byte(strconv.Itoa(count)))
    if err != nil {
        return fmt.Errorf("failed to update candidate count: %v", err)
    }

    return nil
}

// ========================
// QueryVote
// ========================
func (s *SmartContract) QueryVote(
    ctx contractapi.TransactionContextInterface,
    voterID string,
) (string, error) {

    voterKey := "vote:" + voterID

    vote, err := ctx.GetStub().GetState(voterKey)
    if err != nil {
        return "", fmt.Errorf("failed to read vote: %v", err)
    }
    if vote == nil {
        return "", fmt.Errorf("no vote found for voter %s", voterID)
    }

    return string(vote), nil
}

// ========================
// GetAllVotes
// ========================
func (s *SmartContract) GetAllVotes(
    ctx contractapi.TransactionContextInterface,
) (string, error) {

    iterator, err := ctx.GetStub().GetStateByRange("vote:", "vote;")
    if err != nil {
        return "", err
    }
    defer iterator.Close()

    votes := make(map[string]string)

    for iterator.HasNext() {
        kv, err := iterator.Next()
        if err != nil {
            return "", err
        }

        voterID := kv.Key[len("vote:"):]
        votes[voterID] = string(kv.Value)
    }

    jsonBytes, err := json.Marshal(votes)
    if err != nil {
        return "", err
    }

    return string(jsonBytes), nil
}

// ========================
// GetResults (Candidate → Count)
// ========================
func (s *SmartContract) GetResults(
    ctx contractapi.TransactionContextInterface,
) (string, error) {

    iterator, err := ctx.GetStub().GetStateByRange("count:", "count;")
    if err != nil {
        return "", err
    }
    defer iterator.Close()

    results := make(map[string]int)

    for iterator.HasNext() {
        kv, err := iterator.Next()
        if err != nil {
            return "", err
        }

        candidate := kv.Key[len("count:"):]
        count, _ := strconv.Atoi(string(kv.Value))
        results[candidate] = count
    }

    jsonBytes, err := json.Marshal(results)
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
