// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



interface IFactory {

    function depositStake(uint256 amount) external;
    function withdrawStake(uint256 amount) external;
    function withdrawReward(uint256 amount) external;
    function poolRewardBalance(address poolAddress) external view returns(uint256);
}