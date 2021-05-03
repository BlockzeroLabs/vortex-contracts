// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IERC20Detailed.sol";

contract Portal is ReentrancyGuard {
    using SafeERC20 for IERC20Detailed;

    uint256 public startBlock;

    uint256 public endBlock;

    uint256 public totalStaked;

    uint256 public lastRewardBlock;

    uint256 public stakeLimit;

    uint256 public contractStakeLimit;

    uint256[] public rewardPerBlock;

    uint256[] public accumulatedRewardMultiplier;

    address[] public rewardsTokens;

    IERC20Detailed public stakingToken;

    struct UserInfo {
        uint256 firstStakedBlockNumber;
        uint256 amountStaked; // How many tokens the user has staked.
        uint256[] rewardDebt; //
        uint256[] tokensOwed; // How many tokens the contract owes to the user.
    }

    mapping(address => UserInfo) public userInfo;

    constructor(
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _stakeLimit,
        uint256 _contractStakeLimit,
        uint256[] memory _rewardPerBlock,
        address[] memory _rewardsTokens,
        IERC20Detailed _stakingToken
    ) {
        require(_startBlock > block.number, "Portal:: Invalid starting block.");
        require(_endBlock > block.number, "Portal:: Invalid ending block.");
        require(_rewardPerBlock.length == _rewardsTokens.length, "Portal:: Invalid rewards.");
        require(_stakeLimit != 0, "Portal:: Invalid user stake limit.");
        require(_contractStakeLimit != 0, "Portal:: Invalid total stake limit.");

        stakingToken = _stakingToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
        rewardsTokens = _rewardsTokens;
        lastRewardBlock = startBlock;
        stakeLimit = _stakeLimit;
        contractStakeLimit = _contractStakeLimit;

        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            accumulatedRewardMultiplier.push(0);
        }
    }

    modifier onlyInsideBlockBounds() {
        require(block.number > startBlock, "Stake::Staking has not yet started");
        require(block.number <= endBlock, "Stake::Staking has finished");
        _;
    }

    modifier onlyUnderStakeLimit(address staker, uint256 newStake) {
        require(userInfo[staker].amountStaked + newStake <= stakeLimit, "Portal:: Stake limit exceed.");
        require(totalStaked + newStake <= contractStakeLimit, "Portal:: Contract Stake limit exceed.");
        _;
    }

    function stake(uint256 _tokenAmount) public nonReentrant {
        _stake(_tokenAmount, msg.sender);
    }

    function _stake(uint256 _tokenAmount, address staker) internal onlyInsideBlockBounds onlyUnderStakeLimit(staker, _tokenAmount) {
        require(_tokenAmount > 0, "Stake::Cannot stake 0");

        UserInfo storage user = userInfo[staker];

        // if no amount has been staked this is considered the initial stake
        if (user.amountStaked == 0) {
            onInitialStake(staker);
        }

        updateRewardMultipliers(); // Update the accumulated multipliers for everyone
        updateUserAccruedReward(staker); // Update the accrued reward for this specific user

        user.amountStaked = user.amountStaked + _tokenAmount;
        totalStaked = totalStaked + _tokenAmount;

        uint256 rewardsTokensLength = rewardsTokens.length;

        for (uint256 i = 0; i < rewardsTokensLength; i++) {
            uint256 tokenDecimals = IERC20Detailed(rewardsTokens[i]).decimals();
            uint256 tokenMultiplier = 10**tokenDecimals;
            uint256 totalDebt = (user.amountStaked * accumulatedRewardMultiplier[i]) / tokenMultiplier;
            user.rewardDebt[i] = totalDebt;
        }

        stakingToken.transferFrom(msg.sender, address(this), _tokenAmount);
    }

    function claim() public nonReentrant {
        _claim(msg.sender);
    }

    function _claim(address claimer) internal {
        UserInfo storage user = userInfo[claimer];
        updateRewardMultipliers();
        updateUserAccruedReward(claimer);

        uint256 rewardsTokensLength = rewardsTokens.length;

        for (uint256 i = 0; i < rewardsTokensLength; i++) {
            uint256 reward = user.tokensOwed[i];
            user.tokensOwed[i] = 0;
            IERC20Detailed(rewardsTokens[i]).transfer(claimer, reward);
        }
    }

    function withdraw(uint256 _tokenAmount) public nonReentrant {
        _withdraw(_tokenAmount, msg.sender);
    }

    function _withdraw(uint256 _tokenAmount, address staker) internal {
        require(_tokenAmount > 0, "Portal:: Cannot withdraw 0");

        UserInfo storage user = userInfo[staker];

        updateRewardMultipliers();
        updateUserAccruedReward(staker);

        user.amountStaked = user.amountStaked - _tokenAmount;
        totalStaked = totalStaked - _tokenAmount;

        uint256 rewardsTokensLength = rewardsTokens.length;

        for (uint256 i = 0; i < rewardsTokensLength; i++) {
            uint256 tokenDecimals = IERC20Detailed(rewardsTokens[i]).decimals();
            uint256 tokenMultiplier = 10**tokenDecimals;
            uint256 totalDebt = (user.amountStaked * accumulatedRewardMultiplier[i]) / (tokenMultiplier);
            user.rewardDebt[i] = totalDebt;
        }

        stakingToken.transfer(staker, _tokenAmount);
    }

    function exit() public nonReentrant {
        _exit(msg.sender);
    }

    function _exit(address exiter) internal {
        UserInfo storage user = userInfo[exiter];
        _claim(exiter);
        _withdraw(user.amountStaked, exiter);
    }

    function balanceOf(address _userAddress) public view returns (uint256) {
        UserInfo storage user = userInfo[_userAddress];
        return user.amountStaked;
    }

    function onInitialStake(address _userAddress) internal {
        UserInfo storage user = userInfo[_userAddress];
        user.firstStakedBlockNumber = block.number;
    }

    function updateRewardMultipliers() public {
        uint256 currentBlock = block.number;

        if (currentBlock <= lastRewardBlock) {
            return;
        }

        uint256 applicableBlock = (currentBlock < endBlock) ? currentBlock : endBlock;

        uint256 blocksSinceLastReward = applicableBlock - lastRewardBlock;

        if (blocksSinceLastReward == 0) {
            // Nothing to update
            return;
        }

        if (totalStaked == 0) {
            lastRewardBlock = applicableBlock;
            return;
        }

        uint256 rewardsTokensLength = rewardsTokens.length;

        for (uint256 i = 0; i < rewardsTokensLength; i++) {
            uint256 tokenDecimals = IERC20Detailed(rewardsTokens[i]).decimals();
            uint256 tokenMultiplier = 10**tokenDecimals;

            uint256 newReward = blocksSinceLastReward * rewardPerBlock[i];
            uint256 rewardMultiplierIncrease = (newReward * tokenMultiplier) / totalStaked;
            accumulatedRewardMultiplier[i] = accumulatedRewardMultiplier[i] + rewardMultiplierIncrease;
        }
        lastRewardBlock = applicableBlock;
    }

    function updateUserAccruedReward(address _userAddress) internal {
        UserInfo storage user = userInfo[_userAddress];

        initialiseUserRewardDebt(_userAddress);
        initialiseUserTokensOwed(_userAddress);

        if (user.amountStaked == 0) {
            return;
        }

        uint256 rewardsTokensLength = rewardsTokens.length;

        for (uint256 tokenIndex = 0; tokenIndex < rewardsTokensLength; tokenIndex++) {
            updateUserRewardForToken(_userAddress, tokenIndex);
        }
    }

    function initialiseUserTokensOwed(address _userAddress) internal {
        UserInfo storage user = userInfo[_userAddress];

        if (user.tokensOwed.length != rewardsTokens.length) {
            uint256 rewardsTokensLength = rewardsTokens.length;

            for (uint256 i = user.tokensOwed.length; i < rewardsTokensLength; i++) {
                user.tokensOwed.push(0);
            }
        }
    }

    function initialiseUserRewardDebt(address _userAddress) internal {
        UserInfo storage user = userInfo[_userAddress];

        if (user.rewardDebt.length != rewardsTokens.length) {
            uint256 rewardsTokensLength = rewardsTokens.length;

            for (uint256 i = user.rewardDebt.length; i < rewardsTokensLength; i++) {
                user.rewardDebt.push(0);
            }
        }
    }

    function updateUserRewardForToken(address _userAddress, uint256 tokenIndex) internal {
        UserInfo storage user = userInfo[_userAddress];
        uint256 tokenDecimals = IERC20Detailed(rewardsTokens[tokenIndex]).decimals();
        uint256 tokenMultiplier = 10**tokenDecimals;

        uint256 totalDebt = (user.amountStaked * accumulatedRewardMultiplier[tokenIndex]) / tokenMultiplier;
        uint256 pendingDebt = totalDebt - user.rewardDebt[tokenIndex];
        if (pendingDebt > 0) {
            user.tokensOwed[tokenIndex] = user.tokensOwed[tokenIndex] + pendingDebt;
            user.rewardDebt[tokenIndex] = totalDebt;
        }
    }

    function hasStakingStarted() public view returns (bool) {
        return (block.number >= startBlock);
    }

    function getUserRewardDebt(address _userAddress, uint256 _index) external view returns (uint256) {
        UserInfo storage user = userInfo[_userAddress];
        return user.rewardDebt[_index];
    }

    function getUserOwedTokens(address _userAddress, uint256 _index) external view returns (uint256) {
        UserInfo storage user = userInfo[_userAddress];
        return user.tokensOwed[_index];
    }

    function getUserAccumulatedReward(address _userAddress, uint256 tokenIndex) public view returns (uint256) {
        uint256 currentBlock = block.number;
        uint256 applicableBlock = (currentBlock < endBlock) ? currentBlock : endBlock;

        uint256 blocksSinceLastReward = applicableBlock - lastRewardBlock;

        uint256 tokenDecimals = IERC20Detailed(rewardsTokens[tokenIndex]).decimals();
        uint256 tokenMultiplier = 10**tokenDecimals;

        uint256 newReward = blocksSinceLastReward * rewardPerBlock[tokenIndex];
        uint256 rewardMultiplierIncrease = (newReward * tokenMultiplier) / totalStaked;
        uint256 currentMultiplier = accumulatedRewardMultiplier[tokenIndex] + rewardMultiplierIncrease;

        UserInfo storage user = userInfo[_userAddress];

        uint256 totalDebt = (user.amountStaked * currentMultiplier) / tokenMultiplier; // Simulate the current debt
        uint256 pendingDebt = totalDebt - user.rewardDebt[tokenIndex]; // Simulate the pending debt
        return user.tokensOwed[tokenIndex] + pendingDebt;
    }

    function getUserTokensOwedLength(address _userAddress) external view returns (uint256) {
        UserInfo storage user = userInfo[_userAddress];
        return user.tokensOwed.length;
    }

    function getUserRewardDebtLength(address _userAddress) external view returns (uint256) {
        UserInfo storage user = userInfo[_userAddress];
        return user.rewardDebt.length;
    }

    function extend(
        uint256 _endBlock,
        uint256[] memory _rewardsPerBlock,
        uint256[] memory _currentRemainingRewards,
        uint256[] memory _newRemainingRewards
    ) external nonReentrant {
        require(_endBlock > block.number, "Portal:: End block must be in the future");
        require(_endBlock >= endBlock, "Portal:: End block must be after the current end block");
        require(_rewardsPerBlock.length == rewardsTokens.length, "Portal:: Rewards amounts length is less than expected");
        updateRewardMultipliers();

        for (uint256 i = 0; i < _rewardsPerBlock.length; i++) {
            address rewardsToken = rewardsTokens[i];

            if (_currentRemainingRewards[i] > _newRemainingRewards[i]) {
                // Some reward leftover needs to be returned
                IERC20Detailed(rewardsToken).transfer(msg.sender, (_currentRemainingRewards[i] - _newRemainingRewards[i]));
            }

            rewardPerBlock[i] = _rewardsPerBlock[i];
        }

        endBlock = _endBlock;
    }

    function withdrawLPRewards(address recipient, address lpTokenContract) external nonReentrant {
        uint256 currentReward = IERC20Detailed(lpTokenContract).balanceOf(address(this));
        require(currentReward > 0, "WithdrawLPRewards::There are no rewards from liquidity pools");

        require(lpTokenContract != address(stakingToken), "WithdrawLPRewards:: cannot withdraw from the LP tokens");

        uint256 rewardsTokensLength = rewardsTokens.length;

        for (uint256 i = 0; i < rewardsTokensLength; i++) {
            require(lpTokenContract != rewardsTokens[i], "WithdrawLPRewards::Cannot withdraw from token rewards");
        }
        IERC20Detailed(lpTokenContract).transfer(recipient, currentReward);
    }

    function calculateRewardsAmount(
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rewardPerBlock
    ) internal pure returns (uint256) {
        require(_rewardPerBlock > 0, "Pool:: Rewards per block must be greater than zero");
        uint256 rewardsPeriod = _endBlock - _startBlock;
        return _rewardPerBlock * rewardsPeriod;
    }

    function getRewardTokensCount() public view returns (uint256) {
        return rewardsTokens.length;
    }
}
