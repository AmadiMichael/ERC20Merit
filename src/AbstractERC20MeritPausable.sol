// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ERC20 Merit Pausable
/// @author Amadi Michael
/// @notice extension of ERC20 Merit that supports pausability

import {AbstractERC20Merit, UD60x18, convert, ZERO} from "./AbstractERC20Merit.sol";
import {Pausable} from "./deps/Pausable.sol";

abstract contract AbstractERC20MeritPausable is AbstractERC20Merit, Pausable {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) AbstractERC20Merit(_name, _symbol, _decimals) {}

    /// @notice pauses all major functionalities of the token (i.e meritAllocation distribution, transfer, transferFrom, mint, burn) until unPaused
    /// @dev important to not pause allocation distribution (but only token functionalities) when the totalSupply == 0 as allocation distribution is currently not ongoing and repausing it updates the pause snapshot wrongly
    function abstractPause() internal virtual whenNotPaused {
        updateMeritAllocation(address(0), true, convert(0));
        if (!isMeritAllocationToBePaused()) stopMeritAllocationDistribution();
        _pause();
    }

    /// @notice unpauses all major functionalities of the token stopped by pausing it (i.e meritAllocation distribution, transfer, transferFrom, mint, burn) until unPaused
    /// @dev important to not unpause allocation distribution (but only token functionalities) when the totalSupply == 0 as allocation distribution is currently ongoing and reUnpausing it updates the pause snapshot wrongly
    function abstractUnPause() internal virtual whenPaused {
        _unpause();
        if (!isMeritAllocationToBePaused()) resumeMeritAllocationDistribution();
    }

    /// @notice overriden internal _transfer function that checks if contract is paused before proceeding to call super._transfer(...,...,...)
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused {
        super._transfer(from, to, amount);
    }
}
