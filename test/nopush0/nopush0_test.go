package nopush0

import (
	"errors"
	"strings"
	"testing"

	"github.com/divergencetech/ethier/ethtest"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/core/vm"
)

//go:generate ./abigen.sh

func TestDeployWithoutPUSH0(t *testing.T) {
	sim := ethtest.NewSimulatedBackendTB(t, 1)
	_, _, proposer, err := DeployNopush0(sim.Acc(0), sim, common.HexToAddress("0x42"))

	invalid := new(vm.ErrInvalidOpCode)
	if !errors.As(err, &invalid) || !strings.Contains(err.Error(), "PUSH0") {
		t.Errorf("deployment error = %v; is not %T or doesn't reference PUSH0", err, invalid)
	}

	// The abigen output erroneously named the contract type `Nopush0`. This
	// code is a noop but provides a compiler guarantee that the `proposer`
	// variable is in fact a SWAP2Proposer so the above test is valid.
	var _ interface {
		Propose(*bind.TransactOpts, MultiERC721ForNativeSwap) (*types.Transaction, error)
		Propose0(*bind.TransactOpts, MultiERC721ForERC20Swap) (*types.Transaction, error)
		Propose1(*bind.TransactOpts, ERC721ForERC20Swap) (*types.Transaction, error)
		Propose2(*bind.TransactOpts, ERC721ForNativeSwap) (*types.Transaction, error)
	} = proposer
}
