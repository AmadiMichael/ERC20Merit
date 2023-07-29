// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ERC20 Merit Unguarded Mintable Implementation Example
/// @author Amadi Michael
/// @notice Unguarded Mintable Implementation Example

import {AbstractERC20Merit} from "../AbstractERC20Merit.sol";

contract WETHMerit is AbstractERC20Merit {
    error UnwrapFailed();

    constructor() AbstractERC20Merit("WETH Merit", "WETHM", 18) {}

    /// @notice mints tokens
    /// @param to: address to send wrapped eth to
    function wrap(address to) external payable virtual {
        _mint(to, msg.value);
    }

    /// @notice burn tokens
    /// @param to: address to send unwrapped eth to
    /// @param amount: amount of tokens to be burned
    function unwrap(address to, uint256 amount) external virtual {
        _burn(msg.sender, amount);
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert UnwrapFailed();
    }

    /// @notice any eth sent should be minted to user as wrapped eth merit
    receive() external payable {
        _mint(msg.sender, msg.value);
    }
}
