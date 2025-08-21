// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockFactory {
    address public pair;
    address public token0;
    address public token1;

    function setPair(address pair_, address token0_, address token1_) external {
        pair = pair_;
        token0 = token0_;
        token1 = token1_;
    }

    function getPair(address t0, address t1) external view returns (address) {
        if ((t0 == token0 && t1 == token1) || (t0 == token1 && t1 == token0)) {
            return pair;
        }
        return address(0);
    }
}
