// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IPool {
    function initialize(
        IERC20 token,
        address factory,
        uint256 stakingPeriod,
        uint256 rewardPercentage
    ) external;

    function disableStaking() external;
}