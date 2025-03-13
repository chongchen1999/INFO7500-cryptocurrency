// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "src/core/interfaces/IERC20.sol";

contract TestHelper is Test {
    function assertBalanceChange(
        address token,
        address account,
        int256 expectedChange,
        function() external fn
    ) internal {
        uint256 balanceBefore = IERC20(token).balanceOf(account);
        fn();
        uint256 balanceAfter = IERC20(token).balanceOf(account);
        
        if (expectedChange > 0) {
            assertEq(balanceAfter - balanceBefore, uint256(expectedChange));
        } else {
            assertEq(balanceBefore - balanceAfter, uint256(-expectedChange));
        }
    }

    function assertETHBalanceChange(
        address account,
        int256 expectedChange,
        function() external fn
    ) internal {
        uint256 balanceBefore = account.balance;
        fn();
        uint256 balanceAfter = account.balance;
        
        if (expectedChange > 0) {
            assertEq(balanceAfter - balanceBefore, uint256(expectedChange));
        } else {
            assertEq(balanceBefore - balanceAfter, uint256(-expectedChange));
        }
    }
}