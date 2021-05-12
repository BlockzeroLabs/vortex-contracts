// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Portal2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct User {
        uint256 balance;
        uint256[] userRewardPerTokenPaid;
        uint256[] rewards;
    }

    uint256 public endBlock;
    uint256 public rewardsDuration;
    uint256 public lastBlockUpdate;
    uint256 public totalStaked;

    uint256[] public rewardRate;
    uint256[] public totalRewards;
    uint256[] public rewardPerTokenSnapshot;
    uint256[] public distributedReward;
    uint256[] public totalRewardPerTokenSnapshot;
    uint256[] public totalRewardRatios;

    mapping(address => User) public users;
    mapping(address => uint256[]) public providerRewardRatios;

    IERC20[] public rewardsToken;
    IERC20 public stakingToken;

    constructor(
        uint256 _endBlock,
        address[] memory _rewardsToken,
        address _stakingToken
    ) {
        endBlock = _endBlock;
        stakingToken = IERC20(_stakingToken);

        for (uint256 i = 0; i < _rewardsToken.length; i++) {
            rewardsToken.push(IERC20(_rewardsToken[i]));
            rewardRate.push(0);
            totalRewards.push(0);
            rewardPerTokenSnapshot.push(0);
            distributedReward.push(0);
            totalRewardPerTokenSnapshot.push(0);
            totalRewardRatios.push(0);
        }
    }

    function stake(uint256 amount) external nonReentrant {
        User storage user = users[msg.sender];

        // Init user on first call.
        for (uint256 i = user.rewards.length; i < rewardsToken.length; i++) {
            user.rewards.push(0);
            user.userRewardPerTokenPaid.push(0);
        }

        updateReward();
        require(amount > 0, "Cannot stake 0");
        totalStaked = totalStaked + amount;
        user.balance = user.balance + amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        updateReward();
        require(amount > 0, "Cannot withdraw 0");
        totalStaked = totalStaked - amount;
        users[msg.sender].balance = users[msg.sender].balance - amount;
        stakingToken.safeTransfer(msg.sender, amount);
    }

    function harvest() public nonReentrant {
        User storage user = users[msg.sender];
        updateReward();

        for (uint256 i = 0; i < rewardsToken.length; i++) {
            uint256 reward = user.rewards[i];

            console.log("reward: ", reward);

            if (reward > 0) {
                user.rewards[i] = 0;
                rewardsToken[i].safeTransfer(msg.sender, reward);
            }
        }
    }

    function exit() external {
        withdraw(users[msg.sender].balance);
        harvest();
    }

    function addReward(uint256[] memory rewards, uint256 newEndBlock) external {
        require(newEndBlock >= endBlock, "New endblock cannot be before current endblock");
        User storage user = users[msg.sender];

        // Init user on first call.
        for (uint256 i = user.rewards.length; i < rewardsToken.length; i++) {
            user.rewards.push(0);
            user.userRewardPerTokenPaid.push(0);
        }

        uint256[] storage providerRatios = providerRewardRatios[msg.sender];

        // Init provider on first call.
        for (uint256 i = providerRatios.length; i < rewardsToken.length; i++) {
            providerRatios.push(0);
        }

        updateReward();

        rewardsDuration = newEndBlock - block.number;

        for (uint256 i = 0; i < rewardsToken.length; i++) {
            uint256 remainingReward = 0;

            if (totalRewards[i] > 0) {
                remainingReward = totalRewards[i] - totalEarned(i);
                rewardRate[i] = (rewards[i] + remainingReward) / rewardsDuration;
            } else {
                rewardRate[i] = rewards[i] / rewardsDuration;
            }

            console.log("remainingReward ", remainingReward);

            uint256 newRewardRatio = remainingReward == 0 ? 1e18 : (rewards[i] * 1e18) / remainingReward;
            console.log("newRewardRatio: ", newRewardRatio);
            providerRatios[i] = providerRatios[i] + newRewardRatio;
            console.log("providerRatios: ", providerRatios[i]);
            totalRewardRatios[i] = totalRewardRatios[i] + providerRatios[i];
            console.log("totalRewardRatios: ", totalRewardRatios[i]);

            rewardsToken[i].safeTransferFrom(msg.sender, address(this), rewards[i]);
            totalRewards[i] = totalRewards[i] + rewards[i];
        }

        lastBlockUpdate = block.number;
        endBlock = newEndBlock;
    }

    function removeReward() external {
        uint256[] storage providerRatios = providerRewardRatios[msg.sender];

        updateReward();

        rewardsDuration = endBlock - block.number;

        for (uint256 i = 0; i < rewardsToken.length; i++) {
            console.log("totalEarned", totalEarned(i));
            uint256 remainingReward = totalRewards[i] - totalEarned(i);

            console.log("remainingReward:", remainingReward);
            uint256 providerPortion = (remainingReward * providerRatios[i]) / totalRewardRatios[i];
            console.log("providerPortion: ", providerPortion);
            rewardsToken[i].safeTransfer(msg.sender, providerPortion);

            totalRewardRatios[i] = totalRewardRatios[i] - providerRatios[i];
            providerRatios[i] = 0;

            rewardRate[i] = (remainingReward - providerPortion) / rewardsDuration;
        }

        lastBlockUpdate = block.number;
    }

    function rewardPerTokenStaked(uint256 tokenIndex) public view returns (uint256) {
        return
            totalStaked > 0
                ? rewardPerTokenSnapshot[tokenIndex] +
                    (((lastBlockRewardIsApplicable() - lastBlockUpdate) * rewardRate[tokenIndex] * 1e18) / totalStaked)
                : rewardPerTokenSnapshot[tokenIndex];
    }

    function earned(address account, uint256 tokenIndex) public view returns (uint256) {
        User memory user = users[account];

        return
            user.rewards[tokenIndex] +
            ((user.balance * (rewardPerTokenStaked(tokenIndex) - user.userRewardPerTokenPaid[tokenIndex])) / 1e18);
    }

    function totalEarned(uint256 tokenIndex) public view returns (uint256) {
        return
            distributedReward[tokenIndex] +
            ((totalStaked * (rewardPerTokenStaked(tokenIndex) - totalRewardPerTokenSnapshot[tokenIndex])) / 1e18);
    }

    function lastBlockRewardIsApplicable() public view returns (uint256) {
        return block.number > endBlock ? endBlock : block.number;
    }

    function harvestForDuration(uint256 tokenIndex) public view returns (uint256) {
        return rewardRate[tokenIndex] * rewardsDuration;
    }

    function updateReward() internal {
        User storage user = users[msg.sender];

        uint256 _lastBlockRewardIsApplicable = lastBlockRewardIsApplicable();

        for (uint256 i = 0; i < rewardsToken.length; i++) {
            if (totalStaked > 0) {
                rewardPerTokenSnapshot[i] =
                    rewardPerTokenSnapshot[i] +
                    (((_lastBlockRewardIsApplicable - lastBlockUpdate) * rewardRate[i] * 1e18) / totalStaked);
            }

            distributedReward[i] =
                distributedReward[i] +
                ((totalStaked * (rewardPerTokenSnapshot[i] - totalRewardPerTokenSnapshot[i])) / 1e18);

            user.rewards[i] = user.rewards[i] + ((user.balance * (rewardPerTokenSnapshot[i] - user.userRewardPerTokenPaid[i])) / 1e18);

            user.userRewardPerTokenPaid[i] = rewardPerTokenSnapshot[i];

            totalRewardPerTokenSnapshot[i] = rewardPerTokenSnapshot[i];
        }

        lastBlockUpdate = _lastBlockRewardIsApplicable;
    }
}
