// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ERC20 Merit Library
/// @author Amadi Michael
/// @notice Contract for calculating the total meritAllocation or/and meritAllocations of any given user at any given timestamp

import {ERC20Merit, IERC20Merit} from "./ERC20Merit.sol";
import {UD60x18, convert} from "prb-math/UD60x18.sol";

contract ERC20MeritLibrary {
    function meritAllocationBetween(
        address assetAddress,
        address _account,
        uint256 start,
        uint256 end
    ) external view returns (uint256 meritAllocation) {
        uint256 multiplier = ERC20Merit(assetAddress).MULTIPLIER();

        uint256 meritAllocationAtStartTime = _allocated(
            ERC20Merit(assetAddress),
            _account,
            start,
            multiplier
        );
        uint256 meritAllocationAtEndTime = _allocated(
            ERC20Merit(assetAddress),
            _account,
            end,
            multiplier
        );

        meritAllocation = meritAllocationAtEndTime - meritAllocationAtStartTime;
    }

    /// @notice returns an accurate (even while contract is paused) allocated coefficient of ID of `accountAddress`
    function allocated(
        address assetAddress,
        address _account,
        uint256 time
    ) external view returns (uint256 meritAllocation) {
        uint256 multiplier = ERC20Merit(assetAddress).MULTIPLIER();
        return _allocated(ERC20Merit(assetAddress), _account, time, multiplier);
    }

    function totalMeritAllocationBetween(
        address assetAddress,
        uint256 start,
        uint256 end
    ) external view returns (uint256 totalMeritAllocations) {
        uint256 totalMeritAllocationsAtStartTime = _getTotalMeritAllocations(
            ERC20Merit(assetAddress),
            start
        );
        uint256 totalMeritAllocationsAtEndTime = _getTotalMeritAllocations(
            ERC20Merit(assetAddress),
            end
        );
        return
            totalMeritAllocationsAtEndTime - totalMeritAllocationsAtStartTime;
    }

    /// @notice returns totalMeritAllocations distributed at time
    /// Require that token.initTime() > 0 and token.initTime() <= block.timestamp
    function getTotalMeritAllocations(
        address assetAddress,
        uint256 time
    ) external view returns (uint256 _totalMeritAllocations) {
        return _getTotalMeritAllocations(ERC20Merit(assetAddress), time);
    }

    function _getTotalMeritAllocations(
        ERC20Merit token,
        uint256 time
    ) private view returns (uint256 _totalMeritAllocations) {
        IERC20Merit.GeneralBasedInfo memory generalBasedInfo = token
            .generalBasedInfoAt(time);

        // If time == last update time then the totalMeritAllocations stored there is accurate.
        // else we calculate it based on conditionals in the else block
        if (time == generalBasedInfo.lastUpdateTime) {
            _totalMeritAllocations = generalBasedInfo.totalMeritAllocations;
        } else {
            IERC20Merit.SectionBasedInfo memory sectionBasedInfo = token
                .sectionBasedInfoAt(time);
            // if the last meritAllocation distribution pause time was before the last update time then we just
            // calculate the total meritAllocation by adding meritAllocationRate * time elapsed to the total meritAllocation of last update time

            // Else, that means a pause in meritAllocation distribution occured between the last update time and time requested and
            // using the above formula would return a higher and inaccurate total meritAllocation
            // To solve this, We perform the same calculation but "around" the time frame when meritAllocation was paused
            // we calculate total meritAllocation between the last update time and start time then do the same for time between end time and time requested
            // we then add this to the total meritAllocation at last update time to get the accurate value
            if (sectionBasedInfo.startTime < generalBasedInfo.lastUpdateTime) {
                _totalMeritAllocations =
                    generalBasedInfo.totalMeritAllocations +
                    (token.ALLOCATION_RATE() *
                        (time - generalBasedInfo.lastUpdateTime));
            } else {
                uint256 meritAllocationRate = token.ALLOCATION_RATE();
                _totalMeritAllocations =
                    generalBasedInfo.totalMeritAllocations +
                    (meritAllocationRate *
                        (sectionBasedInfo.startTime -
                            generalBasedInfo.lastUpdateTime));

                // if the pause ended before time requested, calculate total meritAllocations between end time and time requsted
                // else do nothing.
                if (sectionBasedInfo.endTime != 0)
                    _totalMeritAllocations += (meritAllocationRate *
                        (time - sectionBasedInfo.endTime));
            }
        }
    }

    function _allocated(
        ERC20Merit token,
        address _account,
        uint256 time,
        uint256 multiplier
    ) private view returns (uint256 meritAllocation) {
        IERC20Merit.GeneralBasedInfo memory generalBasedInfo = token
            .generalBasedInfoAt(time);
        IERC20Merit.UserBasedInfo memory userBasedInfo = token.userBasedInfoAt(
            time,
            _account
        );

        // get meritAllocationPerToken
        UD60x18 _meritAllocationPerToken = meritAllocationPerToken(
            generalBasedInfo,
            time,
            token.ALLOCATION_RATE(),
            multiplier
        );

        meritAllocation = meritAllocations(
            userBasedInfo,
            _meritAllocationPerToken,
            multiplier
        );
    }

    function meritAllocationPerToken(
        IERC20Merit.GeneralBasedInfo memory generalBasedInfo,
        uint256 time,
        uint256 meritAllocationRate,
        uint256 multiplier
    ) private pure returns (UD60x18 _meritAllocationPerToken) {
        _meritAllocationPerToken = generalBasedInfo
            .meritAllocationPerTokenStored;

        if (generalBasedInfo.totalSupply > 0) {
            _meritAllocationPerToken = _meritAllocationPerToken.add(
                convert(
                    meritAllocationRate *
                        (time - generalBasedInfo.lastUpdateTime) *
                        multiplier
                ).div(convert(generalBasedInfo.totalSupply))
            );
        }
    }

    function meritAllocations(
        IERC20Merit.UserBasedInfo memory userBasedInfo,
        UD60x18 _meritAllocationPerToken,
        uint256 multiplier
    ) private pure returns (uint256) {
        return
            convert(
                userBasedInfo.meritAllocations.add(
                    convert(userBasedInfo.balance)
                        .mul(
                            _meritAllocationPerToken.sub(
                                userBasedInfo
                                    .userLastMeritAllocationPerTokenStored
                            )
                        )
                        .div(convert(multiplier))
                )
            );
    }
}
