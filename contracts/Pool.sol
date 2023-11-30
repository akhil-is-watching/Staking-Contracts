// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IFactory.sol";
import "hardhat/console.sol";

contract StakingPool is Initializable {
    using SafeERC20 for IERC20;

    struct PoolConfig {
        IERC20 token;
        address factory;
        uint256 stakingPeriod;
        uint256 rewardPercentage;
        bool stakingEnabled;
    }

    struct Stake {
        address staker;
        uint256 amount;
        uint256 accumulatedReward;
        uint256 expectedReward;
        uint256 stakeTimestamp;
        uint256 endTimestamp;
        bool rewardClaimed;
        bool stakeClaimed;
    }

    PoolConfig private _config;

    mapping(address => Stake) private _stakes;

    modifier isStaking() {
        require(_config.stakingEnabled, "ERR: STAKING DISABLED");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == _config.factory, "ERR: NOT FACTORY");
        _;
    }

    function initialize(
        IERC20 token,
        address factory,
        uint256 stakingPeriod,
        uint256 rewardPercentage
    ) external initializer {
        _config.token = token;
        _config.factory = factory;
        _config.stakingPeriod = stakingPeriod;
        _config.rewardPercentage = rewardPercentage;
        _config.stakingEnabled = true;
    }

    function deposit(uint256 amount) external isStaking {
        _config.token.safeTransferFrom(msg.sender, _config.factory, amount);
        IFactory(_config.factory).depositStake(amount);
        _deposit(amount);
    }

    function withdraw() external {
        Stake memory stake = _stakes[msg.sender];
        require(stake.endTimestamp <= block.timestamp, "ERR: STAKING PERIOD STILL ACTIVE");
        require(!stake.stakeClaimed, "ERR: STAKE ALREADY CLAIMED");
        if(!stake.rewardClaimed && (stake.expectedReward + stake.accumulatedReward) <= rewardBalanceAvailable())
            claimReward();
        _withdraw();
        IFactory(_config.factory).withdrawStake(stake.amount);
        _config.token.safeTransfer(msg.sender, stake.amount);
    }

    function claimReward() public {
        Stake storage stake = _stakes[msg.sender];
        uint256 rewardToWithdraw = stake.accumulatedReward + stake.expectedReward;
        require(!stake.rewardClaimed, "ERR: REWARD ALREADY CLAIMED");
        require(rewardToWithdraw <= rewardBalanceAvailable(), "ERR: INSUFFICIENT REWARD BALANCE");
        IFactory(_config.factory).withdrawReward(rewardToWithdraw);
        _config.token.safeTransfer(msg.sender, rewardToWithdraw);
        stake.accumulatedReward = 0;
        stake.expectedReward = 0;
        stake.rewardClaimed = true;
    }

    function disableStaking() external onlyFactory {
        _config.stakingEnabled = false;
    }

    function getStake(address staker) external view returns(Stake memory) {
        return _stakes[staker];
    }

    function stakingTimeLeft(address staker) external view returns(uint256) {
        Stake memory stake = _stakes[staker];
        return block.timestamp >= stake.endTimestamp ? 0: stake.endTimestamp - block.timestamp;
    }

    function expectedRewards(address staker) external view returns(uint256) {
        Stake memory stake = _stakes[staker];
        return stake.expectedReward + stake.accumulatedReward;
    }

    function rewardBalanceAvailable() public view returns(uint256) {
        uint256 rewardBalance = IFactory(_config.factory).poolRewardBalance(address(this));
        return rewardBalance;
    }

    function _deposit(uint256 amount) private {
        Stake storage stake = _stakes[msg.sender];
        if(stake.amount != 0) {
            uint256 accumulatedReward = stake.amount * ((block.timestamp - stake.stakeTimestamp) > _config.stakingPeriod ? _config.stakingPeriod : (block.timestamp - stake.stakeTimestamp)) * _config.rewardPercentage / 1e4 / _config.stakingPeriod;
            stake.accumulatedReward += accumulatedReward;
        }
        stake.amount += amount;
        stake.stakeTimestamp = block.timestamp;
        stake.endTimestamp = block.timestamp + _config.stakingPeriod;
        stake.expectedReward = stake.amount * _config.rewardPercentage / 1e4;
        stake.stakeClaimed = false;
        stake.rewardClaimed = false;
    }

    function _withdraw() private {
        Stake storage stake = _stakes[msg.sender];
        stake.amount = 0;
        stake.stakeTimestamp = 0;
        stake.endTimestamp = 0;
        stake.stakeClaimed = true;
        if(!stake.rewardClaimed)
            stake.accumulatedReward += stake.expectedReward;
            stake.expectedReward = 0;
    }

}