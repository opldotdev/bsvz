// Command chronicle_oracle runs scripts through go-sdk's interpreter and
// prints the final data stack and error, the reference for
// tests/chronicle_vectors.zig. It expects a go-sdk checkout beside bsvz
// (../go-sdk), like the script corpus tests.
package main

import (
	"bufio"
	"encoding/hex"
	"fmt"
	"os"
	"strings"

	"github.com/bsv-blockchain/go-sdk/script"
	"github.com/bsv-blockchain/go-sdk/script/interpreter"
	"github.com/bsv-blockchain/go-sdk/script/interpreter/debug"
	"github.com/bsv-blockchain/go-sdk/transaction"
)

// Each input line: "<name> <chronicle 0|1> <tx version> <locking hex>".
// Prints the data stack after the last executed opcode, and the error.
func main() {
	sc := bufio.NewScanner(os.Stdin)
	sc.Buffer(make([]byte, 64<<20), 64<<20)
	for sc.Scan() {
		f := strings.Fields(sc.Text())
		if len(f) < 4 {
			continue
		}
		b, err := hex.DecodeString(f[3])
		if err != nil {
			panic(err)
		}
		var ver uint32
		fmt.Sscan(f[2], &ver)
		lock := script.NewFromBytes(b)
		unlock := script.NewFromBytes([]byte{})
		prev := &transaction.TransactionOutput{Satoshis: 1, LockingScript: lock}
		tx := transaction.NewTransaction()
		tx.Version = ver
		tx.AddInput(&transaction.TransactionInput{SourceTXID: nil, UnlockingScript: unlock, SequenceNumber: 0xffffffff})
		tx.AddOutput(&transaction.TransactionOutput{Satoshis: 0, LockingScript: script.NewFromBytes([]byte{0x6a})})
		var stack [][]byte
		dbg := debug.NewDebugger()
		dbg.AttachAfterExecuteOpcode(func(s *interpreter.State) {
			stack = append([][]byte{}, s.DataStack...)
		})
		opts := []interpreter.ExecutionOptionFunc{
			interpreter.WithTx(tx, 0, prev),
			interpreter.WithForkID(),
			interpreter.WithAfterGenesis(),
			interpreter.WithDebugger(dbg),
		}
		if f[1] == "1" {
			opts = append(opts, interpreter.WithAfterChronicle())
		}
		err = interpreter.NewEngine().Execute(opts...)
		parts := make([]string, len(stack))
		for i, s := range stack {
			parts[i] = hex.EncodeToString(s)
			if parts[i] == "" {
				parts[i] = "''"
			}
		}
		es := "ok"
		if err != nil {
			es = err.Error()
		}
		fmt.Printf("%s stack=[%s] err=%s\n", f[0], strings.Join(parts, ","), es)
	}
}
