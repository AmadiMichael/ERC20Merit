// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ERC20 Allocations
/// @author Amadi Michael
/// @notice An ERC20 token extension that automatically tracks and stores data
/// that can be used to determine how loyal a holder was during any given period of time.

import {AbstractERC20, IERC20Allocations} from "./AbstractERC20.sol";
import {Arrays} from "./libraries/Arrays.sol";
import {UD60x18, convert, ZERO} from "prb-math/UD60x18.sol";

contract ERC20Allocations is AbstractERC20 {
    using Arrays for uint256[];

    /// @notice Allocation to be distributed per second
    uint256 public constant ALLOCATION_RATE = 10_000_000_000;

    /// @notice multiplier for scaling numerators before division.
    uint256 public constant MULTIPLIER = 1e18;

    /// @notice Caps total supply, Important variable that ensures continued accuracy. see allocationPerToken function...
    uint256 public immutable MAX_SUPPLY;

    /// @notice timestamp the first nonzero token amount was minted
    /// @dev if first mint can be made during construction of contract then making this value immutable will save gas while calling transfer, transferFrom, mint and burn
    uint256 public initTime;

    /// @notice type SectionBasedInfo (see interface)
    SectionBasedInfo private sectionBasedInfo;

    /// @notice type GeneralBasedInfo (see interface)
    GeneralBasedInfo private generalBasedInfo;

    /// @notice type GeneralBasedInfoSnapshots  (see interface)
    GeneralBasedInfoSnapshots private _generalBasedInfoSnapshots;

    /// @notice type SectionBasedInfoSnapshots  (see interface)
    SectionBasedInfoSnapshots private _sectionBasedInfoSnapshots;

    /// @notice user => UserBasedInfo struct (see interface)
    mapping(address => UserBasedInfo) private userBasedInfo;

    /// @notice UserBasedInfo of a user at the end of each time snapshots
    mapping(address => UserBasedInfoSnapshots) private _userBasedInfoSnapshots;

    /**
     * @notice Use ALLOCATION_RATE * 1 second * multiplier as max supply because in allocationPerToken() we divide
     * (ALLOCATION_RATE * seconds since last update (minimum non-zero value of 1) * multiplier) by totalSupply which with a max supply
     * would have a value that at most equals the numerator here
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) AbstractERC20(name_, symbol_, decimals_) {
        /**
         * FOR A CAPPED MAX SUPPLY
         */
        MAX_SUPPLY = ALLOCATION_RATE * 1 seconds * MULTIPLIER; // used as max supply for utmost accuracy
    }

    //___________________________________________________________________________________________________________________________

    /// @notice overriden internal _transfer function that uses recordTransfer
    // @dev fromId and toId must be above 0 at all times!
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // for backward compatibility do not revert on transfering 0 when total supply is 0 or when not inited

        // dont process when amount is 0 to save gas
        if (amount != 0) {
            updateSnapshot(from, to, TransactionType.TRANSFER);
            recordTransfer(from, to, amount, TransactionType.TRANSFER);
        }

        emit Transfer(from, to, amount);
    }

    /**
     * @notice override and updates _mint from abstractERC20
     */
    function _mint(address to, uint256 amount) internal override {
        // for backward compatibility do not revert on transfering 0 when total supply is 0 or when not inited

        // dont process when amount is 0 to save gas
        if (amount != 0) {
            // prevent total supply from exceeding max supply
            if (totalSupply + amount > MAX_SUPPLY)
                revert TotalSupplyCannotExceedMaxSupply();

            // set init time only once at first non-zero mint
            if (initTime == 0) initTime = block.timestamp;

            updateSnapshot(address(0), to, TransactionType.MINT);
            recordTransfer(address(0), to, amount, TransactionType.MINT);
        }

        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice override and updates _mint from abstractERC20
     */
    function _burn(address from, uint256 amount) internal override {
        // for backward compatibility do not revert on transfering 0 when total supply is 0 or when not inited

        // dont process when amount is 0 to save gas
        if (amount != 0) {
            updateSnapshot(from, address(0), TransactionType.BURN);
            recordTransfer(from, address(0), amount, TransactionType.BURN);
        }

        emit Transfer(from, address(0), amount);
    }

    /// @notice mints tokens
    /// @param amount: amount of tokens to be minted
    function mint(address to, uint256 amount) external virtual {
        _mint(to, amount);
    }

    /// @notice burn tokens
    /// @param amount: amount of tokens to be burned
    function burn(address from, uint256 amount) external virtual {
        _burn(from, amount);
    }

    /// @notice Updates snapshot array, works like openzeppelin's ERC20 snapshot
    function updateSnapshot(
        address from,
        address to,
        TransactionType txType
    ) private {
        if (txType == TransactionType.MINT) {
            // mint
            _updateUserBasedInfoSnapshot(to);
            _updateGeneralBasedInfoSnapshot();
        } else if (txType == TransactionType.BURN) {
            // burn
            _updateUserBasedInfoSnapshot(from);
            _updateGeneralBasedInfoSnapshot();
        } else {
            // transfer
            _updateUserBasedInfoSnapshot(from);
            _updateUserBasedInfoSnapshot(to);
            _updateGeneralBasedInfoSnapshot();
        }
    }

    /************************************************************* AUTOMATED ALLOCATION DISTRIBUTION ALGORITHM SECTION ******************************************************************* */

    /// @notice updates generalBasedInfo and userBasedInfo of _account
    function updateAllocation(
        address _account,
        bool updateRewardPerTokenStored,
        UD60x18 transientAllocationPerTokenStored
    ) private returns (UD60x18) {
        // only updates generalBasedInfo if its updateAllocationPerToken is true which saves gas
        // by avoiding storing the same data twice in cases like transfer and transferFrom
        if (updateRewardPerTokenStored) {
            transientAllocationPerTokenStored = allocationPerToken();
            generalBasedInfo
                .allocationPerTokenStored = transientAllocationPerTokenStored;
            generalBasedInfo.totalAllocations = _getTotalAllocations();
            generalBasedInfo.lastUpdateTime = block.timestamp;
        }

        userBasedInfo[_account].allocations = _allocated(
            _account,
            transientAllocationPerTokenStored
        );
        userBasedInfo[_account]
            .userLastAllocationPerTokenStored = transientAllocationPerTokenStored;
        userBasedInfo[_account].lastUpdateTime = block.timestamp;

        return transientAllocationPerTokenStored;
    }

    /// @notice updates the SectionBasedInfoSnapshot with the past one before updating it
    function stopAllocationDistribution() private {
        _updateSectionBasedInfoSnapshot();
        sectionBasedInfo = SectionBasedInfo({
            startTime: uint128(block.timestamp),
            endTime: 0
        });
    }

    /// @notice updates the SectionBasedInfoSnapshot if allocation distribution is being resumed
    /// updtaes last update time to be == block.timepstamp to avoid total allocations accounting for time when total supply was 0
    function resumeAllocationDistribution() private {
        /// if allocation distribution is currently paused...
        if (isAllocationsPaused()) {
            _updateSectionBasedInfoSnapshot();
            sectionBasedInfo.endTime = uint128(block.timestamp);
        }
        // set lastUpdateTime to be now if total supply == 0 (i.e if allocation is paused and we are minting a non zero value)
        // not within the if block to avoid updating snapshot at initTime
        generalBasedInfo.lastUpdateTime = block.timestamp;
    }

    function isAllocationToBePaused() internal view virtual returns (bool) {
        return totalSupply == 0;
    }

    function isAllocationsPaused() public view virtual returns (bool) {
        return sectionBasedInfo.startTime != 0 && sectionBasedInfo.endTime == 0;
    }

    /// @notice called after `transferTakeFrom` to check if the the transaction made totalSupply to be 0 (ie the tx burnt all of totalSupply)
    function checkIfZeroSupply() private {
        if (isAllocationToBePaused()) stopAllocationDistribution();
    }

    /// @notice called before transferGiveTo to check if the totalSupply for that asset is 0 (ie the tx is going to mint a non-zero amount of tokens).
    function checkIfNonZeroSupply() private {
        if (isAllocationToBePaused()) resumeAllocationDistribution();
    }

    /**
     * @notice logic for updating balances via mint, burn, and transfer
     */
    function recordTransfer(
        address from,
        address to,
        uint256 _amount,
        TransactionType txType
    ) private {
        if (txType == TransactionType.MINT) {
            checkIfNonZeroSupply(); // checks before minting if supply is 0 ie will go to non-zero since owner cannot mint 0
            updateAllocation(to, true, ZERO);
            transferGiveTo(to, _amount, true);
        } else if (txType == TransactionType.BURN) {
            updateAllocation(from, true, ZERO);
            transferTakeFrom(from, _amount, true);
            checkIfZeroSupply(); // checks after transferTakeFrom (and if it is a burn tx) if supply is now zero
        } else {
            UD60x18 transientAllocationPerTokenStored = updateAllocation(
                from,
                true,
                ZERO
            ); // transient cache
            transferTakeFrom(from, _amount, false);
            updateAllocation(to, false, transientAllocationPerTokenStored);
            transferGiveTo(to, _amount, false);
        }
    }

    /// @notice records offloading of an asset by a user
    function transferTakeFrom(
        address user,
        uint256 _amount,
        bool updateTotalSupply
    ) private {
        uint256 fromBalance = balanceOf[user];
        if (fromBalance < _amount)
            revert InsufficientBalance(fromBalance, _amount);
        unchecked {
            if (updateTotalSupply) {
                uint256 _totalSupply = totalSupply;
                totalSupply = _totalSupply - _amount;
                generalBasedInfo.totalSupply = _totalSupply - _amount;
            }
            uint256 newBalance = fromBalance - _amount;
            balanceOf[user] = newBalance;
            userBasedInfo[user].balance = newBalance;
        }
    }

    /// @notice records a holdership of an asset by a user
    function transferGiveTo(
        address user,
        uint256 _amount,
        bool updateTotalSupply
    ) private {
        // Cannot overflow because the max totalSupply cap
        unchecked {
            if (updateTotalSupply) {
                uint256 _totalSupply = totalSupply;
                totalSupply = _totalSupply + _amount;
                generalBasedInfo.totalSupply = _totalSupply + _amount;
            }
            uint256 fromBalance = balanceOf[user];
            balanceOf[user] = fromBalance + _amount;
            userBasedInfo[user].balance = fromBalance + _amount;
        }
    }

    /************************************************************* INTERNAL ALLOCATION CALCULATION HELPERS ******************************************************************* */

    function allocationPerToken()
        private
        view
        returns (UD60x18 allocationPerTokenStored)
    {
        // Scaled up to MULTIPLIER for better accuracy
        // ensure that totalsupply is at least equal to the allocation to be distrubuted to a user in one second (allocation_RATE * 1 second * MULTIPLIER)
        // if it's higher, even by 1, the division returns 0. This is prevented by MAX_SUPPLY variable

        allocationPerTokenStored = generalBasedInfo.allocationPerTokenStored;

        if (generalBasedInfo.totalSupply > 0) {
            allocationPerTokenStored = allocationPerTokenStored.add(
                convert(
                    ALLOCATION_RATE *
                        (block.timestamp - generalBasedInfo.lastUpdateTime) *
                        MULTIPLIER
                ).div(convert(totalSupply))
            );
        }
    }

    /// @notice returns current allocated coefficient of `_account`
    /// @dev Whole equation `B(∑ CurrentallocationPerToken - ∑ user last allocation per token stored)`
    function _allocated(
        address _account,
        UD60x18 currentAllocationPerToken
    ) private view returns (UD60x18) {
        return
            userBasedInfo[_account].allocations.add(
                convert(balanceOf[_account])
                    .mul(
                        currentAllocationPerToken.sub(
                            userBasedInfo[_account]
                                .userLastAllocationPerTokenStored
                        )
                    )
                    .div(convert(MULTIPLIER))
            );
    }

    /// @notice returns the current total allocations distributed
    /// @dev adds last stored allocation to the allocations distributed between last update time and block.timestamp
    function _getTotalAllocations() private view returns (uint256) {
        return
            generalBasedInfo.totalAllocations +
            (ALLOCATION_RATE *
                (block.timestamp - generalBasedInfo.lastUpdateTime));
    }

    /************************************************************* SNAPSHOTS SECTION ******************************************************************* */

    ///@notice Modified from OpenZeppelin's ERC20 Snapshot

    /**
     * FROM OPENZEPPELIN SNAPHOT COMMENT
     *
     * There is a constant overhead for normal ERC20 transfers due to the additional snapshot bookkeeping. This overhead is
     * only significant for the first transfer that immediately follows a snapshot for a particular account. Subsequent
     * transfers will have normal cost until the next snapshot, and so on.
     */

    function generalBasedInfoAt(
        uint256 time
    ) external view returns (GeneralBasedInfo memory) {
        (
            bool snapshotted,
            GeneralBasedInfo memory value
        ) = _valueOfGeneralBasedInfoAt(time, _generalBasedInfoSnapshots);

        return snapshotted ? value : generalBasedInfo;
    }

    function userBasedInfoAt(
        uint256 time,
        address user
    ) external view returns (UserBasedInfo memory) {
        (
            bool snapshotted,
            UserBasedInfo memory value
        ) = _valueOfUserBasedInfoAt(time, _userBasedInfoSnapshots[user]);

        return snapshotted ? value : userBasedInfo[user];
    }

    function sectionBasedInfoAt(
        uint256 time
    ) external view returns (SectionBasedInfo memory) {
        (
            bool snapshotted,
            SectionBasedInfo memory value
        ) = _valueOfSectionBasedInfoAt(time, _sectionBasedInfoSnapshots);

        return snapshotted ? value : sectionBasedInfo;
    }

    function _valueOfGeneralBasedInfoAt(
        uint256 time,
        GeneralBasedInfoSnapshots storage generalBasedInfoSnapshots_
    ) private view returns (bool, GeneralBasedInfo memory) {
        if (time <= initTime || time > block.timestamp) revert NoSnapshot();

        uint256 index = generalBasedInfoSnapshots_.ids.findUpperBound(time);

        if (index == generalBasedInfoSnapshots_.ids.length) {
            return (false, GeneralBasedInfo(0, 0, ZERO, 0));
        } else {
            return (true, generalBasedInfoSnapshots_.values[index]);
        }
    }

    function _valueOfUserBasedInfoAt(
        uint256 time,
        UserBasedInfoSnapshots storage userBasedInfo_
    ) private view returns (bool, UserBasedInfo memory) {
        if (time <= initTime || time > block.timestamp) revert NoSnapshot();

        uint256 index = userBasedInfo_.ids.findUpperBound(time);

        if (index == userBasedInfo_.ids.length) {
            return (false, UserBasedInfo(0, ZERO, ZERO, 0));
        } else {
            return (true, userBasedInfo_.values[index]);
        }
    }

    function _valueOfSectionBasedInfoAt(
        uint256 time,
        SectionBasedInfoSnapshots storage sectionBasedInfoSnapshots_
    ) private view returns (bool, SectionBasedInfo memory) {
        if (time <= initTime || time > block.timestamp) revert NoSnapshot();

        uint256 index = sectionBasedInfoSnapshots_.ids.findUpperBound(time);

        if (index == sectionBasedInfoSnapshots_.ids.length) {
            return (false, SectionBasedInfo(0, 0));
        } else {
            return (true, sectionBasedInfoSnapshots_.values[index]);
        }
    }

    function _updateGeneralBasedInfoSnapshot() private {
        if (generalBasedInfo.lastUpdateTime < block.timestamp) {
            _generalBasedInfoSnapshots.ids.push(block.timestamp);
            _generalBasedInfoSnapshots.values.push(generalBasedInfo);
        }
    }

    function _updateUserBasedInfoSnapshot(address account) private {
        if (userBasedInfo[account].lastUpdateTime < block.timestamp) {
            _userBasedInfoSnapshots[account].ids.push(block.timestamp);
            _userBasedInfoSnapshots[account].values.push(
                userBasedInfo[account]
            );
        }
    }

    function _updateSectionBasedInfoSnapshot() private {
        if (sectionBasedInfo.startTime < block.timestamp) {
            _sectionBasedInfoSnapshots.ids.push(block.timestamp);
            _sectionBasedInfoSnapshots.values.push(sectionBasedInfo);
        }
    }
}
