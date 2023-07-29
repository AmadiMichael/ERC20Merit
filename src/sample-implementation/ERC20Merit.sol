// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ERC20 Merit Unguarded Mintable Implementation Example
/// @author Amadi Michael
/// @notice Unguarded Mintable and Burnable Implementation Example

import {AbstractERC20Merit} from "../AbstractERC20Merit.sol";

contract ERC20Merit is AbstractERC20Merit {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) AbstractERC20Merit(name_, symbol_, decimals_) {}

    /// @notice mints tokens
    /// @param to: address to mint tokens to
    /// @param amount: amount of tokens to be minted
    function mint(address to, uint256 amount) external virtual {
        _mint(to, amount);
    }

    /// @notice burn tokens
    /// @param from: address to burn tokens from
    /// @param amount: amount of tokens to be burned
    function burn(address from, uint256 amount) external virtual {
        _burn(from, amount);
    }
}
