// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20Allocations} from "../src/ERC20Allocations.sol";
import {ERC20AllocationsLibrary} from "../src/ERC20AllocationsLibrary.sol";

contract ERC20AllocationsInvariants is Test {
    ERC20AllocationsInvariantsHandler erc20AllocationsInvariantsHandler;
    ERC20Allocations token;
    ERC20AllocationsLibrary allocationsLibrary;

    function setUp() public {
        token = new ERC20Allocations("Token", "TKN", 18);
        erc20AllocationsInvariantsHandler = new ERC20AllocationsInvariantsHandler(
            token
        );
        allocationsLibrary = new ERC20AllocationsLibrary();

        targetContract(address(erc20AllocationsInvariantsHandler));
    }

    function invariantERC20Allocations() public {
        // run one last time after invariant runs
        // note: it is also called randomly in between random calls to assert accuracy
        erc20AllocationsInvariantsHandler.assertBalanceSumEqualsTotalSupply();
        erc20AllocationsInvariantsHandler
            .assertTotalAllocationsIsGreaterThanOrEqualToEarneds(42, 42);
    }
}

contract ERC20AllocationsInvariantsHandler is Test {
    ERC20Allocations token;
    uint256 public sum;
    ERC20AllocationsLibrary allocationsLibrary;
    address[] holders;
    uint256 lastTimestamp;
    mapping(address => bool) isHolder;

    constructor(ERC20Allocations _token) {
        token = _token;
        allocationsLibrary = new ERC20AllocationsLibrary();
    }

    function assertBalanceSumEqualsTotalSupply() public {
        assertEq(
            token.totalSupply(),
            sum,
            "balance sum not equal to total supply"
        );
    }

    function assertTotalAllocationsIsGreaterThanOrEqualToEarneds(
        uint256 time,
        uint256 skipp
    ) public returns (uint256 totalAllocations, uint256 sumAllocations) {
        privateSkip(skipp);

        console.log("timeee", block.timestamp);
        if (token.initTime() == 0) return (0, 0);
        if (token.initTime() >= block.timestamp - 1)
            vm.warp(block.timestamp + 2);

        time = bound(time, token.initTime() + 1, block.timestamp - 1);
        totalAllocations = allocationsLibrary.getTotalAllocations(
            address(token),
            time
        );
        console.log("total allocations", totalAllocations);

        uint256 i;
        for (i; i < holders.length; i++) {
            sumAllocations += allocationsLibrary.allocated(
                address(token),
                holders[i],
                time
            );
        }
        console.log("i", i);
        console.log("summed allocations", sumAllocations);

        assertEq(
            sumAllocations <= totalAllocations && totalAllocations != 0
                ? sumAllocations != 0
                : true,
            true,
            "Your math is errored bro!"
        );
        assertEq(totalAllocations - sumAllocations <= 100, true); // with more depth per runs this("100") might need to be increased
    }

    function mint(address to, uint256 amount, uint256 skipp) public {
        privateSkip(skipp);
        amount = bound(amount, 0, token.MAX_SUPPLY() - token.totalSupply());

        token.mint(to, amount);
        sum += amount;

        if (!isHolder[to] && amount > 0) {
            holders.push(to);
            isHolder[to] = true;
        }
        assertTotalAllocationsIsGreaterThanOrEqualToEarneds(skipp, skipp);
    }

    function burn(address from, uint256 amount, uint256 skipp) public {
        privateSkip(skipp);
        amount = bound(amount, 0, token.balanceOf(from));

        token.burn(from, amount);
        sum -= amount;
        assertTotalAllocationsIsGreaterThanOrEqualToEarneds(skipp, skipp);
    }

    function approve(address to, uint256 amount, uint256 skipp) public {
        privateSkip(skipp);
        token.approve(to, amount);
        assertTotalAllocationsIsGreaterThanOrEqualToEarneds(skipp, skipp);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount,
        uint256 skipp
    ) public {
        privateSkip(skipp);
        amount = token.allowance(from, address(this)) > token.balanceOf(from)
            ? bound(amount, 0, token.balanceOf(from))
            : bound(amount, 0, token.allowance(from, address(this)));

        token.transferFrom(from, to, amount);

        if (!isHolder[to] && amount > 0) {
            holders.push(to);
            isHolder[to] = true;
        }
        assertTotalAllocationsIsGreaterThanOrEqualToEarneds(skipp, skipp);
    }

    function transfer(address to, uint256 amount, uint256 skipp) public {
        privateSkip(skipp);
        amount = bound(amount, 0, token.balanceOf(address(this)));

        token.transfer(to, amount);

        if (!isHolder[to] && amount > 0) {
            holders.push(to);
            isHolder[to] = true;
        }
        assertTotalAllocationsIsGreaterThanOrEqualToEarneds(skipp, skipp);
    }

    function privateSkip(uint256 secondsAhead) private {
        secondsAhead = bound(secondsAhead, 0, 100 * 365 days);
        vm.warp(lastTimestamp + secondsAhead);
        lastTimestamp = block.timestamp;
    }
}
