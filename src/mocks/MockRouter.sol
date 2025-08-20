// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMockLP {
    function mint(address to_, uint256 amount_) external;
}

contract MockRouter {
    using SafeERC20 for IERC20;

    address public lpToken; // set once for tests

    constructor(address lpToken_) {
        lpToken = lpToken_;
    }

    function setLpToken(address lp_) external {
        require(lpToken == address(0), "LP already set");
        lpToken = lp_;
    }

    // Minimal addLiquidity mock:
    // - pulls ~80% of desired amounts from msg.sender (the manager)
    // - mints LP to 'to' with a simple rule: liquidity = amountA + amountB
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint /*amountAMin*/,
        uint /*amountBMin*/,
        address to,
        uint /*deadline*/
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        amountA = (amountADesired * 80) / 100;
        amountB = (amountBDesired * 80) / 100;

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        liquidity = amountA + amountB;
        IMockLP(lpToken).mint(to, liquidity);
    }

    function removeLiquidity(
        address tokenA_,
        address tokenB_,
        uint256 liquidity_,
        uint256, // amountAMin (ignored)
        uint256, // amountBMin (ignored)
        address to_,
        uint256 // deadline (ignored)
    ) external returns (uint256 amountA, uint256 amountB) {
        // Simula que devuelve los tokens al usuario
        amountA = liquidity_ / 2;
        amountB = liquidity_ / 2;

        IERC20(tokenA_).transfer(to_, amountA);
        IERC20(tokenB_).transfer(to_, amountB);
    }

}
