// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IV2Router02.sol";
import "./interfaces/IV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// Orchestrator over a Uniswap V2-like router (no custom pool)
contract SentinelSwap is Ownable {
    using SafeERC20 for IERC20;

    uint256 public rewardRate = 1e16; // 0.01 tokens per second per LP token
    uint256 public liquidityTimelock = 1 days;
    address public router;
    address public factory;

    // Allowed token whitelist (security)
    mapping(address => bool) public allowedTokens;
    mapping(address => uint256) public lastLiquidityAdd;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userLiquidity;
    mapping(address => uint256) public lastUpdate;

    // Custom errors
    error ZeroAddress();
    error TokenNotAllowed(address token);
    error DeadlineExpired(uint256 nowTs, uint256 deadline);

    // Events
    event TokenAllowed(address indexed token, bool allowed);
    event LiquidityAdded(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address router_, address factory_, address initialOwner_) Ownable(initialOwner_) {
        if (router_ == address(0) || factory_ == address(0)) revert ZeroAddress();
        router = router_;
        factory = factory_;
    }

    function setAllowedToken(address token_, bool allowed_) external onlyOwner {
        if (token_ == address(0)) revert ZeroAddress();
        allowedTokens[token_] = allowed_;
        emit TokenAllowed(token_, allowed_);
    }

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

        {
            uint256 leftoverA = IERC20(tokenA_).balanceOf(address(this));
            if (leftoverA > 0) IERC20(tokenA_).safeTransfer(msg.sender, leftoverA);
        }
        {
            uint256 leftoverB = IERC20(tokenB_).balanceOf(address(this));
            if (leftoverB > 0) IERC20(tokenB_).safeTransfer(msg.sender, leftoverB);
        }

        _updateRewards(msg.sender);
        userLiquidity[msg.sender] += liquidity;
        lastLiquidityAdd[msg.sender] = block.timestamp;

        emit LiquidityAdded(msg.sender, tokenA_, tokenB_, amountA, amountB, liquidity);
    }

    function removeLiquidity(
        address tokenA_,
        address tokenB_,
        uint256 liquidity_,
        uint256 amountAMin_,
        uint256 amountBMin_,
        uint256 deadline_
    ) external returns (uint256 amountA, uint256 amountB) {
        _requireAllowed(tokenA_);
        _requireAllowed(tokenB_);
        if (block.timestamp > deadline_) revert DeadlineExpired(block.timestamp, deadline_);

        require(
            block.timestamp >= lastLiquidityAdd[msg.sender] + liquidityTimelock,
            "Liquidity is still locked"
        );

        address pair = IV2Factory(factory).getPair(tokenA_, tokenB_);
        if (pair == address(0)) revert("Pair does not exist");

        uint256 before = IERC20(pair).balanceOf(address(this));
        IERC20(pair).safeTransferFrom(msg.sender, address(this), liquidity_);
        uint256 received = IERC20(pair).balanceOf(address(this)) - before;

        _approveRouter(pair, received);

        (amountA, amountB) = IV2Router02(router).removeLiquidity(
            tokenA_,
            tokenB_,
            received,
            amountAMin_,
            amountBMin_,
            msg.sender,
            deadline_
        );

        _updateRewards(msg.sender);
        userLiquidity[msg.sender] -= liquidity_;
    }

    function claimRewards() external {
        _updateRewards(msg.sender);

        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        rewards[msg.sender] = 0;

        // Future: Transfer or mint real tokens here
        emit RewardClaimed(msg.sender, reward);
    }

    function _updateRewards(address user_) internal {
        uint256 liquidity = userLiquidity[user_];
        if (liquidity > 0) {
            uint256 duration = block.timestamp - lastUpdate[user_];
            rewards[user_] += duration * liquidity * rewardRate / 1e18;
        }
        lastUpdate[user_] = block.timestamp;
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
