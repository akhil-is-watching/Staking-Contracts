// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPool.sol";

contract PoolFactory is Ownable {
    using SafeERC20 for IERC20;

    struct Pool {
        uint256 allocatedRewardBalance;
        uint256 poolStakeBalance;
        bool disabled;
        bool created;
    }


    uint256 private totalPoolStakeBalance;
    uint256 private totalRewardBalance;
    IERC20 private rewardToken;
    address private implementation;

    mapping(address => Pool) private _pools;



    modifier onlyPool() {
        require(_pools[msg.sender].created, "ERR: INVALID POOL");
        _;
    }

    constructor(
        address _implementation,
        IERC20 _rewardToken
    ) Ownable(msg.sender){
        implementation = _implementation;
        rewardToken = _rewardToken;
    }

    function createPool(
        uint256 stakingPeriod,
        uint256 rewardPercentage,
        bytes32 _salt
    ) external onlyOwner returns(address) {
        address poolAddress = _createPool(stakingPeriod, rewardPercentage, _salt);
        Pool storage pool = _pools[poolAddress];
        pool.created = true;
        return poolAddress;
    }


    function depositStake(uint256 amount) external onlyPool {
        Pool storage pool = _pools[msg.sender];
        pool.poolStakeBalance += amount;
        totalPoolStakeBalance += amount;
    }

    function withdrawStake(uint256 amount) external onlyPool{
        Pool storage pool = _pools[msg.sender];
        require(pool.poolStakeBalance >= amount, "ERR: INSUFFICIENT STAKE BALANCE");
        pool.poolStakeBalance -= amount;
        totalPoolStakeBalance -= amount;
        rewardToken.safeTransfer(msg.sender, amount);
    }

    function depositReward(
        uint256 amount, 
        address[] memory poolArray,
        uint256[] memory alloc
    ) external {
        require(poolArray.length == alloc.length, "ERR: INVALID ARRAY LENGTHS");
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        totalRewardBalance += amount;
        uint256 total = 0;
        for(uint256 i=0; i<poolArray.length;) {  
            Pool storage pool = _pools[poolArray[i]];
            pool.allocatedRewardBalance += amount * alloc[i] / 1e4;
            total += alloc[i];
            unchecked {
                i += 1;
            }
        }
        require(total == 10000, "ERR: INVALID ALLOCATION");
    }

    function withdrawReward(uint256 amount) external onlyPool {
        Pool storage pool = _pools[msg.sender];
        require(pool.allocatedRewardBalance >= amount, "ERR: INSUFFICIENT REWARD BALANCE");
        pool.allocatedRewardBalance -= amount;
        totalRewardBalance -= amount;
        rewardToken.safeTransfer(msg.sender, amount);
    }

    function disablePool(address poolAddress) external onlyOwner{
        Pool storage pool = _pools[poolAddress];
        IPool(poolAddress).disableStaking();
        pool.disabled = true;
    }


    function poolRewardBalance(address poolAddress) external view returns(uint256) {
        uint256 poolBalance = _pools[poolAddress].allocatedRewardBalance;
        return poolBalance;
    }

    function predictAddress(
        bytes32 _salt
    ) external view returns(address) {
        return Clones.predictDeterministicAddress(implementation, _salt);
    }

    function _createPool(
        uint256 _stakingPeriod,
        uint256 _rewardPercentage,
        bytes32 salt_
    ) private returns(address) {
        bytes memory initData = abi.encodeWithSelector(
            IPool.initialize.selector,
            rewardToken,
            address(this),
            _stakingPeriod,
            _rewardPercentage
        );

        address proxy = Clones.cloneDeterministic(implementation, salt_);
        (bool success,) = proxy.call(initData);
        if(!success)
            revert();
        return proxy;
    }
}