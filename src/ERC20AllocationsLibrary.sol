// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ERC20 Allocations Library
/// @author Amadi Michael
/// @notice Contract for calculating the total allocation or/and allocations of any given user at any given timestamp

import {ERC20Allocations, IERC20Allocations} from "./ERC20Allocations.sol";
import {UD60x18, convert} from "prb-math/UD60x18.sol";

contract ERC20AllocationsLibrary {
    function allocationBetween(
        address assetAddress,
        address _account,
        uint256 start,
        uint256 end
    ) external view returns (uint256 allocation) {
        uint256 multiplier = ERC20Allocations(assetAddress).MULTIPLIER();

        uint256 allocationAtStartTime = _allocated(
            ERC20Allocations(assetAddress),
            _account,
            start,
            multiplier
        );
        uint256 allocationAtEndTime = _allocated(
            ERC20Allocations(assetAddress),
            _account,
            end,
            multiplier
        );

        allocation = allocationAtEndTime - allocationAtStartTime;
    }

    /// @notice returns an accurate (even while contract is paused) allocated coefficient of ID of `accountAddress`
    function allocated(
        address assetAddress,
        address _account,
        uint256 time
    ) external view returns (uint256 allocation) {
        uint256 multiplier = ERC20Allocations(assetAddress).MULTIPLIER();
        return
            _allocated(
                ERC20Allocations(assetAddress),
                _account,
                time,
                multiplier
            );
    }

    function totalAllocationBetween(
        address assetAddress,
        uint256 start,
        uint256 end
    ) external view returns (uint256 totalAllocations) {
        uint256 totalAllocationsAtStartTime = _getTotalAllocations(
            ERC20Allocations(assetAddress),
            start
        );
        uint256 totalAllocationsAtEndTime = _getTotalAllocations(
            ERC20Allocations(assetAddress),
            end
        );
        return totalAllocationsAtEndTime - totalAllocationsAtStartTime;
    }

    /// @notice returns totalAllocations distributed at time
    /// Require that token.initTime() > 0 and token.initTime() <= block.timestamp
    function getTotalAllocations(
        address assetAddress,
        uint256 time
    ) external view returns (uint256 _totalAllocations) {
        return _getTotalAllocations(ERC20Allocations(assetAddress), time);
    }

    function _getTotalAllocations(
        ERC20Allocations token,
        uint256 time
    ) private view returns (uint256 _totalAllocations) {
        IERC20Allocations.GeneralBasedInfo memory generalBasedInfo = token
            .generalBasedInfoAt(time);

        // If time == last update time then the totalAllocations stored there is accurate.
        // else we calculate it based on conditionals in the else block
        if (time == generalBasedInfo.lastUpdateTime) {
            _totalAllocations = generalBasedInfo.totalAllocations;
        } else {
            IERC20Allocations.SectionBasedInfo memory sectionBasedInfo = token
                .sectionBasedInfoAt(time);
            // if the last allocation distribution pause time was before the last update time then we just
            // calculate the total allocation by adding allocationRate * time elapsed to the total allocation of last update time

            // Else, that means a pause in allocation distribution occured between the last update time and time requested and
            // using the above formula would return a higher and inaccurate total allocation
            // To solve this, We perform the same calculation but "around" the time frame when allocation was paused
            // we calculate total allocation between the last update time and start time then do the same for time between end time and time requested
            // we then add this to the total allocation at last update time to get the accurate value
            if (sectionBasedInfo.startTime < generalBasedInfo.lastUpdateTime) {
                _totalAllocations =
                    generalBasedInfo.totalAllocations +
                    (token.ALLOCATION_RATE() *
                        (time - generalBasedInfo.lastUpdateTime));
            } else {
                uint256 allocationRate = token.ALLOCATION_RATE();
                _totalAllocations =
                    generalBasedInfo.totalAllocations +
                    (allocationRate *
                        (sectionBasedInfo.startTime -
                            generalBasedInfo.lastUpdateTime));

                // if the pause ended before time requested, calculate total allocations between end time and time requsted
                // else do nothing.
                if (sectionBasedInfo.endTime != 0)
                    _totalAllocations += (allocationRate *
                        (time - sectionBasedInfo.endTime));
            }
        }
    }

    function _allocated(
        ERC20Allocations token,
        address _account,
        uint256 time,
        uint256 multiplier
    ) private view returns (uint256 allocation) {
        IERC20Allocations.GeneralBasedInfo memory generalBasedInfo = token
            .generalBasedInfoAt(time);
        IERC20Allocations.UserBasedInfo memory userBasedInfo = token
            .userBasedInfoAt(time, _account);

        // get allocationPerToken
        UD60x18 _allocationPerToken = allocationPerToken(
            generalBasedInfo,
            time,
            token.ALLOCATION_RATE(),
            multiplier
        );

        allocation = allocations(
            userBasedInfo,
            _allocationPerToken,
            multiplier
        );
    }

    function allocationPerToken(
        IERC20Allocations.GeneralBasedInfo memory generalBasedInfo,
        uint256 time,
        uint256 allocationRate,
        uint256 multiplier
    ) private pure returns (UD60x18 _allocationPerToken) {
        _allocationPerToken = generalBasedInfo.allocationPerTokenStored;

        if (generalBasedInfo.totalSupply > 0) {
            _allocationPerToken = _allocationPerToken.add(
                convert(
                    allocationRate *
                        (time - generalBasedInfo.lastUpdateTime) *
                        multiplier
                ).div(convert(generalBasedInfo.totalSupply))
            );
        }
    }

    function allocations(
        IERC20Allocations.UserBasedInfo memory userBasedInfo,
        UD60x18 _allocationPerToken,
        uint256 multiplier
    ) private pure returns (uint256) {
        return
            convert(
                userBasedInfo.allocations.add(
                    convert(userBasedInfo.balance)
                        .mul(
                            _allocationPerToken.sub(
                                userBasedInfo.userLastAllocationPerTokenStored
                            )
                        )
                        .div(convert(multiplier))
                )
            );
    }
}
