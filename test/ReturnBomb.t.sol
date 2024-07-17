// SPDX-License-Identifier: MIT
// Copyright 2024 Divergence Tech Ltd.
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

// This is less of a test and more of an experiment to see how Solidity handles return bombing with a low-level call().
// Result: only an assembly-based call(..., 0, 0) avoids the return bomb entirely and a non-assembly address.call() will
// still copy even when only the success boolean is declared.

contract WithReturnData {
    function x(address a) external {
        (bool success, bytes memory ret) = a.call("");
        success;
        ret;
    }
}

contract WithtoutReturnData {
    function x(address a) external {
        (bool success,) = a.call(""); // This ideally wouldn't copy the return data, but it does.
        success;
    }
}

contract AssemblyCall {
    function x(address a) external {
        assembly ("memory-safe") {
            let success := call(0, a, 0, 0, 0, 0, 0)
        }
    }
}

contract ReturnBombTest is Test {
    function testReturnDataCopy() public {
        WithReturnData with = new WithReturnData();
        WithtoutReturnData without = new WithtoutReturnData();
        AssemblyCall ass = new AssemblyCall();

        assertTrue(_hasReturnDataCopy(address(with)));
        assertTrue(_hasReturnDataCopy(address(without))); // gotcha!
        assertFalse(_hasReturnDataCopy(address(ass)));
    }

    function _hasReturnDataCopy(address a) internal view returns (bool) {
        bytes memory code = a.code;
        for (uint256 i = 0; i < code.length; ++i) {
            if (code[i] == 0x3e) {
                return true;
            }
        }
        return false;
    }
}
