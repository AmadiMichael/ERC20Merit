// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ERC20 Merit Unguarded Mintable Implementation Example
/// @author Amadi Michael
/// @notice Unguarded Mintable Implementation Example

import {AbstractERC20Merit, UD60x18, convert, ZERO} from "./AbstractERC20Merit.sol";

contract ERC20Merit is AbstractERC20Merit {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) AbstractERC20Merit(name_, symbol_, decimals_) {}

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
}
