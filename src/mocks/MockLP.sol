// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLP is ERC20 {
    address public router;

    constructor(address router_) ERC20("Mock LP", "MLP") {
        router = router_;
    }

    function mint(address to_, uint256 amount_) external {
        require(msg.sender == router, "Only router");
        _mint(to_, amount_);
    }
}
