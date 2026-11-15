// Return the SHA-256 of a text.
// Payload: {"text": "..."}. Result: {"sha256": "<hex>", "bytes": N}.
// Network: none. Standard library and the vendored Ignitify client only.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log"

	ignitify "ignitify.local/runtime"
)

type input struct {
	Text *string `json:"text"`
}

func main() {
	ignitify.Start(run)
}

func run(payload json.RawMessage, ctx *ignitify.Ctx) (any, error) {
	var in input
	if err := json.Unmarshal(payload, &in); err != nil {
		return nil, err
	}
	if in.Text == nil {
		// A returned error fails the run; its text is the run error.
		return nil, errors.New("payload.text is required")
	}
	sum := sha256.Sum256([]byte(*in.Text))
	ctx.Metric("bytes_hashed", float64(len(*in.Text)), "", nil)
	log.Printf("hashed %d bytes", len(*in.Text))
	return map[string]any{"sha256": hex.EncodeToString(sum[:]), "bytes": len(*in.Text)}, nil
}
