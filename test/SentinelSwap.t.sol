// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/SentinelSwap.sol";
import "../src/mocks/MockLP.sol";
import "../src/mocks/MockRouter.sol";
import "../src/mocks/TestToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SentinelSwapTest is Test {
    SentinelSwap private sentinelSwap;
    MockRouter private router;
    MockLP private lp;

    TestToken private tokenA;
    TestToken private tokenB;

    address private user;

    function setUp() public {
        user = address(0xBEEF);

        // Deploy tokens
        tokenA = new TestToken("TokenA", "TKA");
        tokenB = new TestToken("TokenB", "TKB");

        // Deploy router first (no LP yet)
        router = new MockRouter(address(0));

        // Deploy LP knowing the real router address
        lp = new MockLP(address(router));
        router.setLpToken(address(lp));

        // Deploy manager (factory can be a dummy for unit tests)
        sentinelSwap = new SentinelSwap(address(router), address(1), address(this));

        // Whitelist tokens
        sentinelSwap.setAllowedToken(address(tokenA), true);
        sentinelSwap.setAllowedToken(address(tokenB), true);

        // Fund user and approve manager
        tokenA.mint(user, 1_000e18);
        tokenB.mint(user, 1_000e18);

        vm.startPrank(user);
        IERC20(address(tokenA)).approve(address(sentinelSwap), type(uint256).max);
        IERC20(address(tokenB)).approve(address(sentinelSwap), type(uint256).max);
        vm.stopPrank();
    }

    function testAddLiquidity_RefundsLeftoversAndMintsLP() public {
        uint256 desiredA_ = 500e18;
        uint256 desiredB_ = 400e18;
        uint256 deadline_ = block.timestamp + 1 hours;

        uint256 userABefore = tokenA.balanceOf(user);
        uint256 userBBefore = tokenB.balanceOf(user);
        uint256 userLPBefore = ERC20(address(lp)).balanceOf(user);

        vm.prank(user);
        (uint256 usedA, uint256 usedB, uint256 liq) = sentinelSwap.addLiquidity(
            address(tokenA),
            address(tokenB),
            desiredA_,
            desiredB_,
            0,
            0,
            deadline_
        );

        // Router mock uses 80% of desired
        assertEq(usedA, (desiredA_ * 80) / 100);
        assertEq(usedB, (desiredB_ * 80) / 100);
        assertEq(liq, usedA + usedB);

        // User balances decreased only by used (leftovers were refunded)
        assertEq(tokenA.balanceOf(user), userABefore - usedA);
        assertEq(tokenB.balanceOf(user), userBBefore - usedB);

        // User received LP
        assertEq(ERC20(address(lp)).balanceOf(user), userLPBefore + liq);

        // Manager retains no token dust
        assertEq(tokenA.balanceOf(address(sentinelSwap)), 0);
        assertEq(tokenB.balanceOf(address(sentinelSwap)), 0);
    }

    function testAddLiquidity_RevertsOnDeadline() public {
        uint256 nowTs = block.timestamp; // capture current block timestamp

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SentinelSwap.DeadlineExpired.selector,
                nowTs,            // nowTs inside the function
                nowTs - 1         // the expired deadline you pass
            )
        );
        sentinelSwap.addLiquidity(
            address(tokenA),
            address(tokenB),
            1e18,
            1e18,
            0,
            0,
            nowTs - 1            // expired
        );
    }


    function testAddLiquidity_RevertsOnNotAllowedToken() public {
        sentinelSwap.setAllowedToken(address(tokenB), false);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SentinelSwap.TokenNotAllowed.selector,
                address(tokenB) // the address the revert encodes
            )
        );
        sentinelSwap.addLiquidity(
            address(tokenA),
            address(tokenB),
            1e18,
            1e18,
            0,
            0,
            block.timestamp + 1 hours
        );
    }

}
