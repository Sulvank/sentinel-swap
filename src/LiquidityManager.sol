// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

/// Orchestrator over a Uniswap V2-like router (no custom pool)
contract LiquidityManager is Ownable {
    // DEX router and factory addresses
    address public router;
    address public factory;

    // Allowed token whitelist
    mapping(address => bool) public allowedTokens;

    // Custom errors
    error ZeroAddress();
    error TokenNotAllowed(address token);

    // Event to track whitelist changes
    event TokenAllowed(address indexed token, bool allowed);

    /// Explicit owner
    constructor(address router_, address factory_, address initialOwner_) Ownable(initialOwner_) {
        if (router_ == address(0) || factory_ == address(0)) revert ZeroAddress();
        router = router_;
        factory = factory_;
    }

    /// Toggle token allow-list
    function setAllowedToken(address token_, bool allowed_) external onlyOwner {
        if (token_ == address(0)) revert ZeroAddress();
        allowedTokens[token_] = allowed_;
        emit TokenAllowed(token_, allowed_);
    }

    /// Internal helper reused in add/remove/swap
    function _requireAllowed(address token_) internal view {
        if (!allowedTokens[token_]) revert TokenNotAllowed(token_);
    }
}
