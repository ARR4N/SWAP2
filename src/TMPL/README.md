# Solidity templates

All `*.tmpl.sol` files in this directory are templates to generate Solidity source code by globally replacing `TMPL` within the file.
The generated code MUST NOT be modified further.
`TMPLSwap.sol` is a special template that is used similarly, but the results constitute only boilerplate and are expected to be modified.

The templates compile as regular Solidity code and should be read as such.
The only differences between instances of generated code will be as a result of overloading due to types in the respective `<T>Swap` structs.
See `ConsiderationLib` and `ERC721TransferLib` to understand these differences.

Note that the `TMPLSwapperBase` constructor is not payable, hence the need for the `For{Native,ERC20}Swapper.sol` differentiation.
These extending contracts do nothing but forward their constructor argument to the base, and the native implementation is marked as payable.
To allow for compilation, `TMPLSwapper.tmpl.sol` is a symbolic link to `ForERC20Swapper.sol`

See the root `Taskfile.yml` for usage of the templates.
