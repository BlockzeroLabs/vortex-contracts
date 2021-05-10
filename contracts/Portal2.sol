// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Portal2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public endBlock;
    uint256 public rewardRate;
    uint256 public rewardsDuration;
    uint256 public lastBlockUpdate;
    uint256 public rewardPerTokenSnapshot;
    uint256 public totalStaked;
    uint256 public distributedReward;
    uint256 public totalRewardPerTokenSnapshot;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    constructor(
        uint256 _endBlock,
        address _rewardsToken,
        address _stakingToken
    ) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        endBlock = _endBlock;
    }

    function stake(uint256 amount) external nonReentrant {
        updateReward();
        require(amount > 0, "Cannot stake 0");
        totalStaked = totalStaked + amount;
        balances[msg.sender] = balances[msg.sender] + amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        updateReward();
        require(amount > 0, "Cannot withdraw 0");
        totalStaked = totalStaked - amount;
        balances[msg.sender] = balances[msg.sender] - amount;
        stakingToken.safeTransfer(msg.sender, amount);
    }

    function harvest() public nonReentrant {
        updateReward();
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(balances[msg.sender]);
        harvest();
    }

    function addReward(uint256 reward, uint256 newEndBlock) external {
        updateReward();

        uint256 remainingBlocks = endBlock - block.number;
        uint256 remainingReward = remainingBlocks * rewardRate;

        rewardsDuration = newEndBlock - block.number;
        rewardRate = (reward + remainingReward) / rewardsDuration;

        rewardsToken.safeTransferFrom(msg.sender, address(this), reward);

        uint256 balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance / rewardsDuration, "Provided reward too high");

        lastBlockUpdate = block.number;
        endBlock = newEndBlock;
    }

    function lastBlockRewardIsApplicable() public view returns (uint256) {
        return block.number > endBlock ? endBlock : block.number;
    }

    function rewardPerTokenStaked() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenSnapshot;
        }
        return rewardPerTokenSnapshot + (((lastBlockRewardIsApplicable() - lastBlockUpdate) * rewardRate * 1e18) / totalStaked);
    }

    function totalEarned() public view returns (uint256) {
        return distributedReward + ((totalStaked * (rewardPerTokenStaked() - totalRewardPerTokenSnapshot)) / 1e18);
    }

    function earned(address account) public view returns (uint256) {
        return rewards[account] + ((balances[account] * (rewardPerTokenStaked() - userRewardPerTokenPaid[account])) / 1e18);
    }

    function harvestForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    function getHarvested() external view returns (uint256) {
        return rewardPerTokenStaked() * totalStaked;
    }

    function updateReward() internal {
        address account = msg.sender;
        rewardPerTokenSnapshot = rewardPerTokenStaked();
        lastBlockUpdate = lastBlockRewardIsApplicable();
        rewards[account] = earned(account);
        distributedReward = totalEarned();
        userRewardPerTokenPaid[account] = rewardPerTokenSnapshot;
        totalRewardPerTokenSnapshot = rewardPerTokenSnapshot;
    }
}
