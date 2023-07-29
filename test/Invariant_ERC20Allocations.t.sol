// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20Merit} from "../src/sample-implementation/ERC20Merit.sol";
import {ERC20MeritLibrary} from "../src/ERC20MeritLibrary.sol";

contract ERC20MeritInvariants is Test {
    ERC20MeritInvariantsHandler erc20AllocationsInvariantsHandler;
    ERC20Merit token;
    ERC20MeritLibrary allocationsLibrary;

    function setUp() public {
        token = new ERC20Merit("Token", "TKN", 18);
        erc20AllocationsInvariantsHandler = new ERC20MeritInvariantsHandler(
            token
        );
        allocationsLibrary = new ERC20MeritLibrary();

        targetContract(address(erc20AllocationsInvariantsHandler));
    }

    function invariantERC20Merit() public {
        // run one last time after invariant runs
        // note: it is also called randomly in between random calls to assert accuracy
        erc20AllocationsInvariantsHandler.assertBalanceSumEqualsTotalSupply();
        erc20AllocationsInvariantsHandler
            .assertTotalAllocationsIsGreaterThanOrEqualToEarneds(42, 42);
    }

    // function testThis() public {
    //     vm.warp(1);
    //     token.mint(address(this), 1e18);
    //     vm.warp(100);
    //     token.mint(address(this), 1e18);
    //     vm.warp(200);

    //     console.log(
    //         "total allocations",
    //         allocationsLibrary.getTotalMeritAllocations(address(token), 200)
    //     );
    //     console.log(
    //         "allocation ",
    //         allocationsLibrary.allocated(address(token), address(this), 200)
    //     );

    //     console.log(
    //         "total allocations",
    //         allocationsLibrary.getTotalMeritAllocations(address(token), 102)
    //     );
    //     console.log(
    //         "allocation ",
    //         allocationsLibrary.allocated(address(token), address(this), 102)
    //     );

    //     // token.mint(
    //     //     address(this),
    //     //     1167805047274141983172893812
    //     // );
    //     // console.log(token.MAX_SUPPLY());
    //     // vm.warp(5);
    //     // token.mint(address(this), 7301);
    //     // vm.warp(27);
    //     // token.mint(
    //     //     address(0xabcd),
    //     //     36717430630808027468154168254911183362900000000000 - 7303
    //     // );
    //     // vm.warp(66);
    //     // token.mint(address(0xcafe), 1);
    //     // vm.warp(150);
    //     // token.mint(address(0xabcd), 1);
    //     // console.log(
    //     //     "total allocation at 3 by 4",
    //     //     allocationsLibrary.getTotalMeritAllocations(address(token), 134)
    //     // );
    //     // console.log(
    //     //     "allocation at 3 by 4",
    //     //     allocationsLibrary.allocated(address(token), address(this), 134)
    //     // );
    //     // console.log(
    //     //     "allocation at 3 by 4",
    //     //     allocationsLibrary.allocated(address(token), address(0xabcd), 134)
    //     // );
    //     // console.log(
    //     //     "allocation at 3 by 4",
    //     //     allocationsLibrary.allocated(address(token), address(0xcafe), 134)
    //     // );
    //     // // token.transfer(address(this), 1167805047274141983172893812 / 2);
    //     // // vm.warp(7);
    //     // // console.log(
    //     // //     "total allocation at 3 by 4",
    //     // //     allocationsLibrary.getTotalMeritAllocations(address(token), 6)
    //     // // );
    //     // // console.log(
    //     // //     "allocation at 3 by 4",
    //     // //     allocationsLibrary.allocated(address(token), address(this), 6)
    //     // // );
    // }
}

contract ERC20MeritInvariantsHandler is Test {
    uint256 private constant SKIP_MAX = 1000 * 365 days; // 100 years skips (i.e difference between two transactions sent to the contract) possible
    ERC20Merit token;
    uint256 public sum;
    ERC20MeritLibrary allocationsLibrary;
    address[] holders;
    uint256 lastTimestamp;
    mapping(address => bool) isHolder;

    constructor(ERC20Merit _token) {
        token = _token;
        allocationsLibrary = new ERC20MeritLibrary();
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
        totalAllocations = allocationsLibrary.getTotalMeritAllocations(
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
        assertEq(totalAllocations - sumAllocations <= 100, true); // with more depth per runs this (ie "100") might need to be increased
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
        secondsAhead = bound(secondsAhead, 0, SKIP_MAX);
        vm.warp(lastTimestamp + secondsAhead);
        lastTimestamp = block.timestamp;
    }
}
