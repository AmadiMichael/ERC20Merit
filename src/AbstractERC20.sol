// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title ERC20 Abstract Contract
/// @author Amadi Michael

import {ERC20 as SolmateERC20} from "solmate/tokens/ERC20.sol";
import {IERC20Allocations} from "./IERC20Allocations.sol";

abstract contract AbstractERC20 is SolmateERC20, IERC20Allocations {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string private constant VERSION = "1";

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) SolmateERC20(_name, _symbol, _decimals) {}

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice override SolmateERC20 transfer function to make it call internal _transfer function
    /// so as to have a single function to modify for transfer and transferFrom balance update logics
    /// @dev replaces require revert statements with if/revert pattern
    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount);

        return true;
    }

    /// @notice override SolmateERC20 transfer function to make it call internal _transfer function
    /// so as to have a single function to modify for transfer and transferFrom balance update logics
    /// @dev replaces require revert statements with if/revert pattern
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance(allowed, amount);
            allowance[from][msg.sender] = allowed - amount;
        }

        _transfer(from, to, amount);

        return true;
    }

    /// @notice override SolmateERC20 transfer function to make it call internal _transfer function
    /// so as to have a single function to modify for transfer and transferFrom balance update logics
    /// @dev replaces require revert statements with if/revert pattern
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev replaces require revert statements with if/revert pattern
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        if (deadline < block.timestamp)
            revert PermitDeadlineExpired(deadline, block.timestamp);

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            if (recoveredAddress == address(0) || recoveredAddress != owner)
                revert InvalidSigner();

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    /// @dev replaces "1" default version with a constant variable VERSION to reduce chances of
    /// accidentally missing it if a new version is released in the future.
    function computeDomainSeparator()
        internal
        view
        virtual
        override
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name)),
                    keccak256(bytes(VERSION)),
                    block.chainid,
                    address(this)
                )
            );
    }
}
