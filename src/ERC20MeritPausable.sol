// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title ERC20 Merit Pausable
/// @author Amadi Michael
/// @notice extension of ERC20 Merit that supports pausability

import {AbstractERC20MeritPausable, UD60x18, convert, ZERO} from "./AbstractERC20MeritPausable.sol";
import {Ownable2Step} from "./deps/Ownable2Step.sol";

contract ERC20MeritPausable is AbstractERC20MeritPausable, Ownable2Step {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        Ownable2Step(msg.sender)
        AbstractERC20MeritPausable(_name, _symbol, _decimals)
    {}

    function pause() external onlyOwner {
        abstractPause();
    }

    function unPause() external onlyOwner {
        abstractUnPause();
    }

    /// @notice mints tokens
    /// @param amount: amount of tokens to be minted
    function mint(address to, uint256 amount) external whenNotPaused onlyOwner {
        _mint(to, amount);
    }

    /// @notice burn tokens
    /// @param amount: amount of tokens to be burned
    function burn(
        address from,
        uint256 amount
    ) external whenNotPaused onlyOwner {
        _burn(from, amount);
    }
}
