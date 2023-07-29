// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ERC20 Merit Unguarded Mintable Implementation Example
/// @author Amadi Michael
/// @notice Unguarded Mintable Implementation Example

import {AbstractERC20Merit} from "../AbstractERC20Merit.sol";
import {SolmateERC20} from "../deps/SolmateERC20.sol";

contract ERC20MeritWrapper is AbstractERC20Merit {
    SolmateERC20 public immutable token;

    constructor(
        address _token
    )
        AbstractERC20Merit(
            SolmateERC20(_token).name(),
            SolmateERC20(_token).symbol(),
            SolmateERC20(_token).decimals()
        )
    {
        token = SolmateERC20(_token);
    }

    /// @notice mints tokens
    /// @param to: address to send wrapped tokens to
    /// @param amount: amount of tokens to be minted
    function wrap(address to, uint256 amount) external virtual {
        token.transferFrom(msg.sender, address(this), amount);
        _mint(to, amount);
    }

    /// @notice burn tokens
    /// @param to: address to send unwrapped tokens to
    /// @param amount: amount of tokens to be burned
    function unwrap(address to, uint256 amount) external virtual {
        _burn(msg.sender, amount);
        token.transfer(to, amount);
    }
}
