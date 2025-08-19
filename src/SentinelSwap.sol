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
        _requireAllowed(tokenA_);
        _requireAllowed(tokenB_);
        if (block.timestamp > deadline_) revert DeadlineExpired(block.timestamp, deadline_);

        uint256 receivedA = _pullReceived(tokenA_, amountADesired_);
        uint256 receivedB = _pullReceived(tokenB_, amountBDesired_);

        _approveRouter(tokenA_, receivedA);
        _approveRouter(tokenB_, receivedB);

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

        // refund leftovers in two tiny scopes (helps IR-less compilers too)
        {
            uint256 leftoverA = IERC20(tokenA_).balanceOf(address(this));
            if (leftoverA > 0) IERC20(tokenA_).safeTransfer(msg.sender, leftoverA);
        }
        {
            uint256 leftoverB = IERC20(tokenB_).balanceOf(address(this));
            if (leftoverB > 0) IERC20(tokenB_).safeTransfer(msg.sender, leftoverB);
        }

        emit LiquidityAdded(msg.sender, tokenA_, tokenB_, amountA, amountB, liquidity);
    }


    function _pullReceived(address token_, uint256 amount_) internal returns (uint256 received_) {
        uint256 before_ = IERC20(token_).balanceOf(address(this));
        IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);
        received_ = IERC20(token_).balanceOf(address(this)) - before_;
    }

    function _approveRouter(address token_, uint256 amount_) internal {
        IERC20(token_).forceApprove(router, amount_);
    }

}
