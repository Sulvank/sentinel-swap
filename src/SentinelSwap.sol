// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// Orchestrator over a Uniswap V2-like router (no custom pool)
contract SentinelSwap is Ownable {
    using SafeERC20 for IERC20;

    // DEX router and factory addresses
    address public router;
    address public factory;

    // Allowed token whitelist (security)
    mapping(address => bool) public allowedTokens;

    // Custom errors (cheaper than require strings)
    error ZeroAddress();
    error TokenNotAllowed(address token);
    error DeadlineExpired(uint256 nowTs, uint256 deadline);

    // Event to track whitelist changes
    event TokenAllowed(address indexed token, bool allowed);
        event LiquidityAdded(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    /// Explicit owner (OZ v5 requires initial owner)
    constructor(address router_, address factory_, address initialOwner_) Ownable(initialOwner_) {
        if (router_ == address(0) || factory_ == address(0)) revert ZeroAddress();
        router = router_;
        factory = factory_;
    }

    /// Toggle token allow-list (owner only)
    function setAllowedToken(address token_, bool allowed_) external onlyOwner {
        if (token_ == address(0)) revert ZeroAddress();
        allowedTokens[token_] = allowed_;
        emit TokenAllowed(token_, allowed_);
    }

    /// Internal helper reused in add/remove/swap
    function _requireAllowed(address token_) internal view {
        if (!allowedTokens[token_]) revert TokenNotAllowed(token_);
    }


    function addLiquidity(
        address tokenA_,
        address tokenB_,
        uint256 amountADesired_,
        uint256 amountBDesired_,
        uint256 amountAMin_,
        uint256 amountBMin_,
        uint256 deadline_
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // 1) basic checks
        _requireAllowed(tokenA_);
        _requireAllowed(tokenB_);
        if (block.timestamp > deadline_) revert DeadlineExpired(block.timestamp, deadline_);

        // 2) pull tokens from user into the manager (fee-on-transfer friendly)
        uint256 balABefore = IERC20(tokenA_).balanceOf(address(this));
        uint256 balBBefore = IERC20(tokenB_).balanceOf(address(this));
        IERC20(tokenA_).safeTransferFrom(msg.sender, address(this), amountADesired_);
        IERC20(tokenB_).safeTransferFrom(msg.sender, address(this), amountBDesired_);
        uint256 receivedA = IERC20(tokenA_).balanceOf(address(this)) - balABefore;
        uint256 receivedB = IERC20(tokenB_).balanceOf(address(this)) - balBBefore;

        // 3) approve router (use received amounts to handle fee-on-transfer tokens)
        IERC20(tokenA_).forceApprove(router, receivedA);
        IERC20(tokenB_).forceApprove(router, receivedB);

        // 4) call router; mint LP directly to the user
        (amountA, amountB, liquidity) = IV2Router02(router).addLiquidity(
            tokenA_,
            tokenB_,
            receivedA,
            receivedB,
            amountAMin_,
            amountBMin_,
            msg.sender,
            deadline_
        );

        // 5) refund leftovers to the user (any dust remaining on the manager)
        uint256 leftoverA = IERC20(tokenA_).balanceOf(address(this));
        uint256 leftoverB = IERC20(tokenB_).balanceOf(address(this));
        if (leftoverA > 0) IERC20(tokenA_).safeTransfer(msg.sender, leftoverA);
        if (leftoverB > 0) IERC20(tokenB_).safeTransfer(msg.sender, leftoverB);

        emit LiquidityAdded(msg.sender, tokenA_, tokenB_, amountA, amountB, liquidity);
    }
}
