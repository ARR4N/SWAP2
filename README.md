# SWAP2
[![forge](https://github.com/solidifylabs/SWAP2/actions/workflows/forge.yml/badge.svg?branch=main)](https://github.com/solidifylabs/SWAP2/actions/workflows/forge.yml)

**SWAP2 is a protocol for OTC NFT trading using ephemeral, CREATE2-deployed contracts with minimal gas overhead.**

## Navigating the code

1. See [SWAP2 Design](./SWAP2-Design.md) to become familiar with the design and terminology.
2. Install [Task](https://taskfile.dev/) and run `task` to generate code.
3. Navigate in the order recommended below.

### `src/`

1. `ET.sol`: general contracts for CREATE2-deployed contracts that "phone home" for mutable constructor arguments.
2. `TMPL/README.md`: explanation of generated code.
3. `TMPL/TMPLSwapperDeployer.tmpl.sol`: factory side of `ET`, deploying swapper Instances with variable execution arguments (Fill vs Cancel).
   * Also includes all pre-deployment code, e.g. predicting counterfactual addresses.
4. `TMPL/TMPLSwapperBase.tmpl.sol`: implementation of Swap logic; although a base contract, the entire implementation is here.
5. `<T>/<T>Swap.sol`: structs defining types of assets that can be traded; field types govern which overloaded library functions are called in the respective `<T>SwapperBase` constructor.
6. `ConsiderationLib.sol` and `ERC721TransferLib.sol`: handling of fungible and non-fungible assets, respectively.
7. `SWAP2.sol`: merely glue of all `<T>SwapperDeployer`s and `<T>SwapperProposer`s generated from `TMPLSwapperDeployer.tmpl.sol`.

Files not included above will naturally be encountered as they are referenced by those explicitly listed.

> [!TIP]
> All `Foo*.gen.sol` files are identical to their `TMPL*.tmpl.sol` equivalents, save for identifier substitution: `s/TMPL/Foo/`.
> These aren't checked in as they risk being out of sync; run `task` instead.

### `test/`

1. `SwapperTestBase.t.sol`: defines a fuzzable `TestCase` struct, helpers, and virtual functions to be implemented by consideration-specific tests.
   * Note that no actual tests are implemented in here; it simply provides a general test harness.
   * The virtual functions replace, for example, `vm.deal()`, `address.balance`, etc.
2. `{NativeToken,ERC20}Test.t.sol`: providers of virtual functions defined by `SwapperTestBase`.
3. `ERC721ForXTest.sol`: abstract contract with suite of (typically end-to-end) tests, suitable for all `<T>Swap` types.
   * Defines virtual functions to be provided for swap-specific instances.
4. `<A>For<B>Test.t.sol`: compositions of `ERC721ForXTest` with `{NativeToken,ERC20}Test` with swap-specific implementations using `<A>For<B>Swap` arguments.
5. All other `*.t.sol` files: unit tests not covered elsewhere.
