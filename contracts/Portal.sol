// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IMigrator.sol";

contract Portal is ReentrancyGuard {
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
    uint256[] public minimumRewardRate;

    uint256 public stakeLimit;
	uint256 public contractStakeLimit;
    uint256 public distributionLimit;

    mapping(address => User) public users;
    mapping(address => uint256[]) public providerRewardRatios;

    IERC20[] public rewardsToken;
    IERC20 public stakingToken;

    constructor(
        uint256 _endBlock,
        address[] memory _rewardsToken,
        uint256[] memory _minimumRewardRate,
        address _stakingToken,
        uint256 _stakeLimit,
		uint256 _contractStakeLimit,
		uint256 _distributionLimit
    ) {
        require(
            _endBlock > block.number,
            "Portal: The end block must be in the future."
        );
        require(_stakeLimit != 0, "Portal: Stake limit needs to be more than 0");
        require(_contractStakeLimit != 0, "Portal: Contract Stake limit needs to be more than 0");

        endBlock = _endBlock;
        stakingToken = IERC20(_stakingToken);
        minimumRewardRate = _minimumRewardRate;
        stakeLimit = _stakeLimit;
        contractStakeLimit = _contractStakeLimit;
        distributionLimit = _distributionLimit;

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

        for (uint256 i = user.rewards.length; i < rewardsToken.length; i++) {
            user.rewards.push(0);
            user.userRewardPerTokenPaid.push(0);
        }

        updateReward(user);
        require(amount > 0, "Portal: cannot stake 0");
        require(user.balance + amount <= stakeLimit, "Portal: user stake limit exceeded");
        require(totalStaked + amount <= contractStakeLimit, "Portal: contract stake limit exceeded");
        totalStaked = totalStaked + amount;
        user.balance = user.balance + amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        User storage user = users[msg.sender];
        updateReward(user);
        require(amount > 0, "Portal: cannot withdraw 0");
        totalStaked = totalStaked - amount;
        user.balance = user.balance - amount;
        stakingToken.safeTransfer(msg.sender, amount);
    }

    function harvest() public nonReentrant {
        User storage user = users[msg.sender];
        updateReward(user);

        for (uint256 i = 0; i < rewardsToken.length; i++) {
            uint256 reward = user.rewards[i];
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

    function addReward(uint256[] memory rewards, uint256 newEndBlock) external nonReentrant {
        require(newEndBlock >= endBlock, "Portal: invalid end block");

        User storage user = users[msg.sender];
        for (uint256 i = user.rewards.length; i < rewardsToken.length; i++) {
            user.rewards.push(0);
            user.userRewardPerTokenPaid.push(0);
        }

        uint256[] storage providerRatios = providerRewardRatios[msg.sender];
        for (uint256 i = providerRatios.length; i < rewardsToken.length; i++) {
            providerRatios.push(0);
        }

        updateReward(user);

        rewardsDuration = newEndBlock - block.number;

        for (uint256 i = 0; i < rewardsToken.length; i++) {
            uint256 remainingReward = 0;

            if (totalRewards[i] > 0) {
                remainingReward = totalRewards[i] - totalEarned(i);
                rewardRate[i] = (rewards[i] + remainingReward) / rewardsDuration;
            } else {
                rewardRate[i] = rewards[i] / rewardsDuration;
            }

            require(minimumRewardRate[i] <= rewardRate[i], "Portal: invalid reward rate");
            uint256 newRewardRatio = remainingReward == 0 ? 1e18 : (rewards[i] * 1e18) / remainingReward;
            providerRatios[i] = providerRatios[i] + newRewardRatio;
            totalRewardRatios[i] = totalRewardRatios[i] + providerRatios[i];
            rewardsToken[i].safeTransferFrom(msg.sender, address(this), rewards[i]);
            totalRewards[i] = totalRewards[i] + rewards[i];
        }

        lastBlockUpdate = block.number;
        endBlock = newEndBlock;
    }

    function removeReward() external nonReentrant {
        User storage user = users[msg.sender];
        uint256[] storage providerRatios = providerRewardRatios[msg.sender];

        updateReward(user);

        rewardsDuration = endBlock - block.number;

        for (uint256 i = 0; i < rewardsToken.length; i++) {
            uint256 remainingReward = totalRewards[i] - totalEarned(i);
            uint256 providerPortion = (remainingReward * providerRatios[i]) / totalRewardRatios[i];
            totalRewardRatios[i] = totalRewardRatios[i] - providerRatios[i];
            providerRatios[i] = 0;
            totalRewards[i] = totalRewards[i] - providerPortion;
            rewardRate[i] = (remainingReward - providerPortion) / rewardsDuration;
            rewardsToken[i].safeTransfer(msg.sender, providerPortion);
        }

        lastBlockUpdate = block.number;
    }

    function migrate(uint256 _amount, address _portal) external nonReentrant {
        User storage user = users[msg.sender];
        require(user.balance >= _amount, "Portal: migrate amount exceeds balance");
        stakingToken.approve(_portal, _amount);
        IMigrator(_portal).migrate(_amount);
    }

    function rewardPerTokenStaked(uint256 tokenIndex) public view returns (uint256) {
        return
            totalStaked > distributionLimit
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

    function updateReward(User storage user) internal {
        uint256 _lastBlockRewardIsApplicable = lastBlockRewardIsApplicable();

        for (uint256 i = 0; i < rewardsToken.length; i++) {
            uint256 _rewardPerTokenSnapshot = rewardPerTokenSnapshot[i];

            if (totalStaked > distributionLimit) {
                _rewardPerTokenSnapshot =
                    _rewardPerTokenSnapshot +
                    (((_lastBlockRewardIsApplicable - lastBlockUpdate) * rewardRate[i] * 1e18) / totalStaked);
            }

            distributedReward[i] =
                distributedReward[i] +
                ((totalStaked * (_rewardPerTokenSnapshot - totalRewardPerTokenSnapshot[i])) / 1e18);

            user.rewards[i] = user.rewards[i] + ((user.balance * (_rewardPerTokenSnapshot - user.userRewardPerTokenPaid[i])) / 1e18);

            user.userRewardPerTokenPaid[i] = _rewardPerTokenSnapshot;

            totalRewardPerTokenSnapshot[i] = _rewardPerTokenSnapshot;

            rewardPerTokenSnapshot[i] = _rewardPerTokenSnapshot;
        }

        lastBlockUpdate = _lastBlockRewardIsApplicable;
    }
}
