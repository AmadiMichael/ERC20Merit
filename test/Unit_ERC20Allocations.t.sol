// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20Merit, UD60x18, convert} from "../src/ERC20Merit.sol";
import {ERC20MeritLibrary} from "../src/ERC20MeritLibrary.sol";

/// modified from solmate ERC20 unit test (https://github.com/transmissions11/solmate/blob/main/src/test/ERC20.t.sol)

contract ERC20Merit_Test is Test {
    ERC20Merit token;
    ERC20MeritLibrary allocationsLibrary;

    struct TimeBasedInfo {
        uint256 startTime;
        uint256 endTime;
    }

    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    function setUp() public {
        token = new ERC20Merit("Token", "TKN", 18);
        allocationsLibrary = new ERC20MeritLibrary();
    }

    function testMint() public {
        token.mint(address(0xBEEF), 1e18);

        assertEq(token.totalSupply(), 1e18);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testBurn() public {
        token.mint(address(0xBEEF), 1e18);
        token.burn(address(0xBEEF), 0.9e18);

        assertEq(token.totalSupply(), 1e18 - 0.9e18);
        assertEq(token.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testApprove() public {
        assertTrue(token.approve(address(0xBEEF), 1e18));

        assertEq(token.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testTransfer() public {
        token.mint(address(this), 1e18);

        assertTrue(token.transfer(address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        token.mint(from, 1e18);

        vm.prank(from);
        token.approve(address(this), 1e18);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.allowance(from, address(this)), 0);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testInfiniteApproveTransferFrom() public {
        address from = address(0xABCD);

        token.mint(from, 1e18);

        vm.prank(from);
        token.approve(address(this), type(uint256).max);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.allowance(from, address(this)), type(uint256).max);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(token.allowance(owner, address(0xCAFE)), 1e18);
        assertEq(token.nonces(owner), 1);
    }

    function testFailTransferInsufficientBalance() public {
        token.mint(address(this), 0.9e18);
        token.transfer(address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientAllowance() public {
        address from = address(0xABCD);

        token.mint(from, 1e18);

        vm.prank(from);
        token.approve(address(this), 0.9e18);

        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientBalance() public {
        address from = address(0xABCD);

        token.mint(from, 0.9e18);

        vm.prank(from);
        token.approve(address(this), 1e18);

        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testFailPermitBadNonce() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            1,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testFailPermitBadDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(
            owner,
            address(0xCAFE),
            1e18,
            block.timestamp + 1,
            v,
            r,
            s
        );
    }

    function testFailPermitPastDeadline() public {
        uint256 oldTimestamp = block.timestamp;
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            oldTimestamp
                        )
                    )
                )
            )
        );

        vm.warp(block.timestamp + 1);
        token.permit(owner, address(0xCAFE), 1e18, oldTimestamp, v, r, s);
    }

    function testFailPermitReplay() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testAllocations() external {
        token.mint(address(0xABCD), 1e18);
        skip(5);

        token.mint(address(0x1234), 1e18);
        skip(5);

        logAllocationInfo(6, 11);

        token.burn(address(0xABCD), 1e18);
        token.burn(address(0x1234), 1e18);
        skip(10);

        token.mint(address(0xABCD), 1e18);
        token.burn(address(0xABCD), 1e18);
        token.mint(address(0xABCD), 1e18);
        token.burn(address(0xABCD), 1e18);
        skip(5);

        token.mint(address(0x1234), 1e18);
        skip(5);

        logAllocationInfo(16, 21);

        logAllocationInfo(26, 31);
    }

    function logAllocationInfo(uint256 time1, uint256 time2) private view {
        console.log(
            allocationsLibrary.getTotalMeritAllocations(address(token), time1)
        );
        console.log(
            allocationsLibrary.getTotalMeritAllocations(address(token), time2)
        );

        console.log(
            allocationsLibrary.allocated(address(token), address(0xABCD), time1)
        );
        console.log(
            allocationsLibrary.allocated(address(token), address(0xABCD), time2)
        );

        console.log(
            allocationsLibrary.allocated(address(token), address(0x1234), time1)
        );
        console.log(
            allocationsLibrary.allocated(address(token), address(0x1234), time2)
        );
    }

    function testAllocationTracker() external {
        uint256 allocationRate = token.ALLOCATION_RATE();
        address OWNER = address(0x5678);

        vm.startPrank(OWNER, OWNER);

        // FIRST MINT SCENARIO
        // t = 0
        token.mint(OWNER, 1e18);
        // skip by 5 seconds
        skip(5); // t = 5
        assertEq(
            allocationsLibrary.getTotalMeritAllocations(address(token), 6),
            allocationRate * 5
        );
        assertEq(
            allocationsLibrary.allocated(address(token), OWNER, 6),
            allocationRate * 5
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xABCD), 6),
            0
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 6),
            0
        );

        // TRANSFER SCENARIOS
        token.transfer(address(0xABCD), 0.5e18);

        skip(5); // t = 10
        assertEq(
            allocationsLibrary.getTotalMeritAllocations(address(token), 11),
            (allocationRate * 5) + (allocationRate * 5)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), OWNER, 11),
            (allocationRate * 5) + ((allocationRate * 5) / 2)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xABCD), 11),
            ((allocationRate * 5) / 2)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 11),
            0
        );

        changePrank(address(0xABCD));
        token.transfer(address(0xcafe), 0.25e18);

        skip(5); // t = 15
        assertEq(
            allocationsLibrary.getTotalMeritAllocations(address(token), 16),
            (allocationRate * 5) + (allocationRate * 5) + (allocationRate * 5)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), OWNER, 16),
            (allocationRate * 5) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 2)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xABCD), 16),
            ((allocationRate * 5) / 2) + ((allocationRate * 5) / 4)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 16),
            ((allocationRate * 5) / 4)
        );

        // BURN SCENARIO

        changePrank(OWNER);
        token.burn(OWNER, 0.25e18);

        skip(5); // t = 20
        assertEq(
            allocationsLibrary.getTotalMeritAllocations(address(token), 21),
            (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), OWNER, 21),
            (allocationRate * 5) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 3)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xABCD), 21),
            ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 4) +
                ((allocationRate * 5) / 3)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 21),
            ((allocationRate * 5) / 4) + ((allocationRate * 5) / 3)
        );

        // PRE BURN ALL SCENARIO
        changePrank(address(0xABCD));
        token.transfer(OWNER, 0.25e18);

        changePrank(address(0xCAFE));
        token.transfer(OWNER, 0.25e18);

        skip(5); // t = 25
        assertEq(
            allocationsLibrary.getTotalMeritAllocations(address(token), 26),
            (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), OWNER, 26),
            (allocationRate * 5) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 3) +
                (allocationRate * 5),
            "hh"
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xABCD), 26),
            ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 4) +
                ((allocationRate * 5) / 3) // no change
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 26),
            ((allocationRate * 5) / 4) + ((allocationRate * 5) / 3)
            // no change
        );

        // BURN ALL SCENARIO

        changePrank(OWNER);
        token.burn(OWNER, 0.75e18);

        skip(20); // t = 45 // no rent distributed while 0 supply
        assertEq(
            allocationsLibrary.getTotalMeritAllocations(address(token), 46),
            (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) // no change
        );
        assertEq(
            allocationsLibrary.allocated(address(token), OWNER, 46),
            (allocationRate * 5) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 3) +
                (allocationRate * 5) // no change
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xABCD), 46),
            ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 4) +
                ((allocationRate * 5) / 3) // no change
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 46),
            ((allocationRate * 5) / 4) + ((allocationRate * 5) / 3) // no change
        );

        // REMINT SCENARIO
        token.mint(OWNER, 1e18);

        skip(5); // t = 50
        assertEq(
            allocationsLibrary.getTotalMeritAllocations(address(token), 51),
            (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), OWNER, 51),
            (allocationRate * 5) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 3) +
                (allocationRate * 5) +
                (allocationRate * 5)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xABCD), 51),
            ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 4) +
                ((allocationRate * 5) / 3) // no change
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 51),
            ((allocationRate * 5) / 4) + ((allocationRate * 5) / 3) // no change
        );

        // TEST AFTER REMINT DISTRIBUTED ACCURACY
        token.transfer(address(0xABCD), 0.25e18);
        token.transfer(address(0xCAFE), 0.25e18);

        skip(5); // t = 55
        assertEq(
            allocationsLibrary.getTotalMeritAllocations(address(token), 56),
            (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                (allocationRate * 5)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), OWNER, 56),
            (allocationRate * 5) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 3) +
                (allocationRate * 5) +
                (allocationRate * 5) +
                ((allocationRate * 5) / 2)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xABCD), 56),
            ((allocationRate * 5) / 2) +
                ((allocationRate * 5) / 4) +
                ((allocationRate * 5) / 3) +
                ((allocationRate * 5) / 4)
        );
        assertEq(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 56),
            ((allocationRate * 5) / 4) +
                ((allocationRate * 5) / 3) +
                ((allocationRate * 5) / 4)
        );

        console.log(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 6) +
                allocationsLibrary.allocated(
                    address(token),
                    address(0xABCD),
                    6
                ) +
                allocationsLibrary.allocated(address(token), OWNER, 6)
        );
        console.log(
            allocationsLibrary.getTotalMeritAllocations(address(token), 6)
        );

        console.log(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 16) +
                allocationsLibrary.allocated(
                    address(token),
                    address(0xABCD),
                    16
                ) +
                allocationsLibrary.allocated(address(token), OWNER, 16)
        );
        console.log(
            allocationsLibrary.getTotalMeritAllocations(address(token), 16)
        );

        console.log(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 26) +
                allocationsLibrary.allocated(
                    address(token),
                    address(0xABCD),
                    26
                ) +
                allocationsLibrary.allocated(address(token), OWNER, 26)
        );
        console.log(
            allocationsLibrary.getTotalMeritAllocations(address(token), 26)
        );

        console.log(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 36) +
                allocationsLibrary.allocated(
                    address(token),
                    address(0xABCD),
                    36
                ) +
                allocationsLibrary.allocated(address(token), OWNER, 36)
        );
        console.log(
            allocationsLibrary.getTotalMeritAllocations(address(token), 36)
        );

        console.log(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 46) +
                allocationsLibrary.allocated(
                    address(token),
                    address(0xABCD),
                    46
                ) +
                allocationsLibrary.allocated(address(token), OWNER, 46)
        );
        console.log(
            allocationsLibrary.getTotalMeritAllocations(address(token), 46)
        );

        console.log(
            allocationsLibrary.allocated(address(token), address(0xCAFE), 56) +
                allocationsLibrary.allocated(
                    address(token),
                    address(0xABCD),
                    56
                ) +
                allocationsLibrary.allocated(address(token), OWNER, 56)
        );
        console.log(
            allocationsLibrary.getTotalMeritAllocations(address(token), 56)
        );
    }
}
