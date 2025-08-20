// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockFactory {
    address public lp;

    function setPair(address lp_) external {
        lp = lp_;
    }

    function getPair(address, address) external view returns (address) {
        return lp;
    }
}
