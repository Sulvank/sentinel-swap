// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/SentinelSwap.sol";
import "../src/mocks/MockLP.sol";
import "../src/mocks/MockRouter.sol";
import "../src/mocks/MockFactory.sol";
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

    error DeadlineExpired(uint256 nowTs, uint256 deadline);
    error TokenNotAllowed(address token);

    event RewardClaimed(address indexed user, uint256 amount);


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

        // Deploy mock factory and set LP pair
        MockFactory factory = new MockFactory();
        factory.setPair(address(lp), address(tokenA), address(tokenB));


        // Deploy SentinelSwap with router and factory
        sentinelSwap = new SentinelSwap(address(router), address(factory), address(this));

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


    function testAddLiquidityRefundsLeftoversAndMintsLP() public {
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

    function testAddLiquidityRevertsOnDeadline() public {
        uint256 nowTs = block.timestamp; // capture current block timestamp

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                DeadlineExpired.selector,
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



    function testAddLiquidityRevertsOnNotAllowedToken() public {
        sentinelSwap.setAllowedToken(address(tokenB), false);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenNotAllowed.selector,
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

    function testRemoveLiquidityRevertsIfLocked() public {
        vm.startPrank(user);

        tokenA.approve(address(sentinelSwap), 1000e18);
        tokenB.approve(address(sentinelSwap), 1000e18);

        sentinelSwap.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000e18,
            1000e18,
            0,
            0,
            block.timestamp + 1 hours
        );

        // No ha pasado el timelock
        vm.expectRevert("Liquidity is still locked");
        sentinelSwap.removeLiquidity(
            address(tokenA),
            address(tokenB),
            1e18, // LP tokens (ajustar)
            0,
            0,
            block.timestamp + 1 hours
        );
    }

    function testRemoveLiquidityRevertsBeforeTimelock() public {
        vm.startPrank(user);

        tokenA.approve(address(sentinelSwap), 1000e18);
        tokenB.approve(address(sentinelSwap), 1000e18);

        sentinelSwap.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000e18,
            1000e18,
            0,
            0,
            block.timestamp + 1 hours
        );

        vm.expectRevert("Liquidity is still locked");
        sentinelSwap.removeLiquidity(
            address(tokenA),
            address(tokenB),
            1000e18,
            0,
            0,
            block.timestamp + 1 hours
        );
    }

    function testClaimRewardsAccumulatesOverTime() public {
        vm.startPrank(user);

        tokenA.approve(address(sentinelSwap), 1000e18);
        tokenB.approve(address(sentinelSwap), 1000e18);

        (,, uint256 liquidity) = sentinelSwap.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000e18,
            1000e18,
            0,
            0,
            block.timestamp + 1 hours
        );

        // Avanza el tiempo para cumplir timelock y ganar recompensas
        vm.warp(block.timestamp + 6 days);

        // 👇 ESTA LÍNEA es la solución al error actual
        ERC20(address(lp)).approve(address(sentinelSwap), type(uint256).max);

        // Ahora ya puedes retirar liquidez sin revert
        sentinelSwap.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            block.timestamp + 1 hours
        );

        // Verifica y reclama las recompensas
        uint256 rewardsBefore = sentinelSwap.rewards(user);
        assertGt(rewardsBefore, 0);

        sentinelSwap.claimRewards();
        uint256 rewardsAfter = sentinelSwap.rewards(user);
        assertEq(rewardsAfter, 0);

    }

    function testClaimRewardsRevertsIfZero() public {
        vm.startPrank(user);
        vm.expectRevert("No rewards to claim");
        sentinelSwap.claimRewards();
    }

    function testClaimRewardsEmitsEvent() public {
        vm.startPrank(user);

        tokenA.approve(address(sentinelSwap), 1000e18);
        tokenB.approve(address(sentinelSwap), 1000e18);

        (, , uint256 liquidity) = sentinelSwap.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000e18,
            1000e18,
            0,
            0,
            block.timestamp + 1 hours
        );

        vm.warp(block.timestamp + 6 days);

        // ✅ Aprobación del LP token (soluciona el revert)
        ERC20(address(lp)).approve(address(sentinelSwap), type(uint256).max);

        sentinelSwap.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            block.timestamp + 1 hours
        );

        uint256 expectedReward = sentinelSwap.rewards(user);

        vm.expectEmit(true, false, false, true);
        emit RewardClaimed(user, expectedReward);

        sentinelSwap.claimRewards();
    }

    function testRemoveLiquidityRefundsTokens() public {
        vm.startPrank(user);

        tokenA.approve(address(sentinelSwap), 1000e18);
        tokenB.approve(address(sentinelSwap), 1000e18);

        (,, uint256 liquidity) = sentinelSwap.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000e18,
            1000e18,
            0,
            0,
            block.timestamp + 1 hours
        );

        // Avanza el tiempo para cumplir timelock
        vm.warp(block.timestamp + 7 days);

        // ✅ Aprueba el LP token antes de retirar
        ERC20(address(lp)).approve(address(sentinelSwap), type(uint256).max);

        // Retira liquidez
        sentinelSwap.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            block.timestamp + 1 hours
        );

        // Verifica que los tokens fueron devueltos al usuario
        assertGt(tokenA.balanceOf(user), 0);
        assertGt(tokenB.balanceOf(user), 0);
    }

    function testUpdateRewardsNoLiquidityDoesNotRevert() public {
        // No hay LP añadidos, así que no hay rewards
        vm.prank(user);

        // Simula reclamo indirecto sin revert (rewards = 0)
        vm.expectRevert("No rewards to claim");
        sentinelSwap.claimRewards();
    }

    function testRemoveLiquidityRevertsIfPairDoesNotExist() public {
        address fakeToken = address(0x1234);

        // Asegura que ambos tokens estén permitidos
        sentinelSwap.setAllowedToken(fakeToken, true);
        sentinelSwap.setAllowedToken(address(tokenA), true);

        // Avanza el tiempo para evitar el revert por timelock
        vm.warp(block.timestamp + 2 days);

        vm.expectRevert("Pair does not exist");
        vm.prank(user);
        sentinelSwap.removeLiquidity(
            address(tokenA),
            fakeToken,
            1e18,
            0,
            0,
            block.timestamp + 1 hours
        );
    }





}
