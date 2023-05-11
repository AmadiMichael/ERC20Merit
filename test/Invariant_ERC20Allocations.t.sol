// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20Allocations} from "../src/ERC20Allocations.sol";
import {ERC20AllocationsLibrary} from "../src/ERC20AllocationsLibrary.sol";

contract ERC20Invariants is Test {
    BalanceSum balanceSum;
    ERC20Allocations token;
    ERC20AllocationsLibrary allocationsLibrary;

    function setUp() public {
        token = new ERC20Allocations("Token", "TKN", 18);
        balanceSum = new BalanceSum(token);
        allocationsLibrary = new ERC20AllocationsLibrary();

        targetContract(address(balanceSum));
    }

    function invariantERC20Allocations() public {
        // run one last time after invariant runs
        // note: it is also called randomly in between random calls to assert accuracy
        balanceSum.assertBalanceSumEqualsTotalSupply();
        balanceSum.assertTotalAllocationsIsGreaterThanOrEqualToEarneds(42, 42);
    }

    function testThis() public {
        // vm.warp(1);
        // // token.mint(
        // //     address(this),
        // //     1167805047274141983172893812
        // // );
        // console.log(token.MAX_SUPPLY());
        // vm.warp(5);
        // token.mint(address(this), 7301);
        // vm.warp(27);
        // token.mint(
        //     address(0xabcd),
        //     36717430630808027468154168254911183362900000000000 - 7303
        // );
        // vm.warp(66);
        // token.mint(address(0xcafe), 1);
        // vm.warp(150);
        // token.mint(address(0xabcd), 1);
        // console.log(
        //     "total allocation at 3 by 4",
        //     allocationsLibrary.getTotalAllocations(address(token), 134)
        // );
        // console.log(
        //     "allocation at 3 by 4",
        //     allocationsLibrary.allocated(address(token), address(this), 134)
        // );
        // console.log(
        //     "allocation at 3 by 4",
        //     allocationsLibrary.allocated(address(token), address(0xabcd), 134)
        // );
        // console.log(
        //     "allocation at 3 by 4",
        //     allocationsLibrary.allocated(address(token), address(0xcafe), 134)
        // );
        // // token.transfer(address(this), 1167805047274141983172893812 / 2);
        // // vm.warp(7);
        // // console.log(
        // //     "total allocation at 3 by 4",
        // //     allocationsLibrary.getTotalAllocations(address(token), 6)
        // // );
        // // console.log(
        // //     "allocation at 3 by 4",
        // //     allocationsLibrary.allocated(address(token), address(this), 6)
        // // );
    }
}

contract BalanceSum is Test {
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
        console.log(secondsAhead);
        secondsAhead = bound(secondsAhead, 0, 100 * 365 days);
        vm.warp(lastTimestamp + secondsAhead);
        lastTimestamp = block.timestamp;
    }
}
