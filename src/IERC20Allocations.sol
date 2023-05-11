//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
import {UD60x18} from "prb-math/UD60x18.sol";

interface IERC20Allocations {
    error InsufficientAllowance(uint256 allowed, uint256 amount);
    error InsufficientBalance(uint256 balance, uint256 amount);
    error PermitDeadlineExpired(uint256 deadline, uint256 currentTimestamp);
    error InvalidSigner();
    error TotalSupplyCannotExceedMaxSupply();
    error NoSnapshot();

    enum TransactionType {
        MINT,
        BURN,
        TRANSFER
    }

    // Snapshotted values have arrays of ids and the value corresponding to that id. These could be an array of a
    // Snapshot struct, but that would impede usage of functions that work on an array.

    struct GeneralBasedInfoSnapshots {
        uint256[] ids;
        GeneralBasedInfo[] values;
    }

    struct UserBasedInfoSnapshots {
        uint256[] ids;
        UserBasedInfo[] values;
    }

    struct SectionBasedInfoSnapshots {
        uint256[] ids;
        SectionBasedInfo[] values;
    }

    struct SectionBasedInfo {
        uint128 startTime;
        uint128 endTime;
    }

    struct GeneralBasedInfo {
        // 4 slots
        uint256 lastUpdateTime;
        uint256 totalAllocations;
        UD60x18 allocationPerTokenStored;
        uint256 totalSupply;
    }

    struct UserBasedInfo {
        // 4 slots
        uint256 lastUpdateTime;
        UD60x18 allocations;
        UD60x18 userLastAllocationPerTokenStored;
        uint256 balance;
    }
}
