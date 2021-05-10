// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract Portal is ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    struct UserInfo {
        uint256 amount;
        uint256[] debt;
        uint256[] reward;
    }

    uint256 public immutable startBlock;
    uint256 public immutable userStakeLimit;
    uint256 public immutable totalStakeLimit;

    uint256 public endBlock;
    uint256 public totalStaked;
    uint256 public lastBlockUpdate;

    uint256[] public rewardPerBlock;
    uint256[] public rewardPerTokenStaked;
    uint256[] public totalRewards;
    uint256[] public totalRewardRatios;
    uint256[] public neverToBeHarvestedReward;

    address[] public tokensReward;
    IERC20Metadata public immutable portalToken;

    mapping(address => uint256[]) public providerRewardRatios;
    mapping(address => UserInfo) public userInfo;

    constructor(
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _userStakeLimit,
        uint256 _totalStakeLimit,
        uint256[] memory _rewardPerBlock,
        address[] memory _tokensReward,
        IERC20Metadata _portalToken
    ) {
        require(_startBlock > block.number, "Portal:: invalid start block.");
        require(_endBlock > _startBlock, "Portal:: invalid end block.");
        require(_rewardPerBlock.length == _tokensReward.length, "Portal:: invalid rewards arrays.");
        require(_userStakeLimit != 0, "Portal:: invalid user stake limit.");
        require(_totalStakeLimit != 0, "Portal:: invalid total stake limit.");

        portalToken = _portalToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
        tokensReward = _tokensReward;
        lastBlockUpdate = _startBlock;
        userStakeLimit = _userStakeLimit;
        totalStakeLimit = _totalStakeLimit;

        for (uint256 i = 0; i < tokensReward.length; i++) {
            rewardPerTokenStaked.push(0);
            totalRewardRatios.push(0);
            totalRewards.push(0);
            neverToBeHarvestedReward.push(0);
        }
    }

    function stake(uint256 _amount) public nonReentrant {
        _stake(_amount, msg.sender);
    }

    function _stake(uint256 _amount, address _user) internal {
        require(_amount > 0, "Portal:: cannot stake 0.");
        require(block.number > startBlock, "Portal:: portal not opened yet.");
        require(block.number <= endBlock, "Portal:: portal closed.");
        require(totalStaked + _amount <= totalStakeLimit, "Portal:: total stake limit exceed.");

        UserInfo storage user = userInfo[_user];
        require(user.amount + _amount <= userStakeLimit, "Portal:: user stake limit exceed.");

        updatePortalData();
        updateUserReward(_user);

        user.amount = user.amount + _amount;
        totalStaked = totalStaked + _amount;

        for (uint256 i = 0; i < tokensReward.length; i++) {
            console.log("\nrewardPerTokenStaked on stake:", rewardPerTokenStaked[i]);
            uint256 totalDebt = (user.amount * rewardPerTokenStaked[i]) / getTokenMultiplier(tokensReward[i]);
            user.debt[i] = totalDebt;
        }

        portalToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function harvest() public nonReentrant {
        _harvest(msg.sender);
    }

    function _harvest(address _user) internal {
        UserInfo storage user = userInfo[_user];
        updatePortalData();
        updateUserReward(_user);

        for (uint256 i = 0; i < tokensReward.length; i++) {
            uint256 reward = user.reward[i];
            user.reward[i] = 0;
            IERC20Metadata(tokensReward[i]).safeTransfer(_user, reward);

            totalRewards[i] = totalRewards[i] - reward;
        }
    }

    function withdraw(uint256 _amount) public nonReentrant {
        _withdraw(_amount, msg.sender);
    }

    function _withdraw(uint256 _amount, address _user) internal {
        require(_amount > 0, "Portal:: zero withdraw.");

        UserInfo storage user = userInfo[_user];

        updatePortalData();
        updateUserReward(_user);

        user.amount = user.amount - _amount;
        totalStaked = totalStaked - _amount;

        for (uint256 i = 0; i < tokensReward.length; i++) {
            uint256 totalDebt = (user.amount * rewardPerTokenStaked[i]) / getTokenMultiplier(tokensReward[i]);
            user.debt[i] = totalDebt;
        }

        portalToken.safeTransfer(_user, _amount);
    }

    function exit() public nonReentrant {
        _exit(msg.sender);
    }

    function _exit(address _user) internal {
        UserInfo memory user = userInfo[_user];
        _harvest(_user);
        _withdraw(user.amount, _user);
    }

    function updatePortalData() public {
        uint256 currentBlock = block.number;

        if (currentBlock > lastBlockUpdate) {
            uint256 latestBlock = (currentBlock < endBlock) ? currentBlock : endBlock;
            uint256 numberOfBlocksSinceLastUpdate = latestBlock - lastBlockUpdate;

            if (numberOfBlocksSinceLastUpdate > 0) {
                if (totalStaked > 0) {
                    for (uint256 i = 0; i < tokensReward.length; i++) {
                        uint256 newReward = numberOfBlocksSinceLastUpdate * rewardPerBlock[i];
                        uint256 rewardPerTokenIncrease = (newReward * getTokenMultiplier(tokensReward[i])) / totalStaked;
                        rewardPerTokenStaked[i] = rewardPerTokenStaked[i] + rewardPerTokenIncrease;
                    }
                } else {
                    for (uint256 i = 0; i < tokensReward.length; i++) {
                        neverToBeHarvestedReward[i] = neverToBeHarvestedReward[i] + (numberOfBlocksSinceLastUpdate * rewardPerBlock[i]);
                    }
                }

                lastBlockUpdate = latestBlock;
            }
        }
    }

    function extend(uint256 _endBlock, uint256[] calldata _rewardsPerBlock) external nonReentrant {
        require(_endBlock >= endBlock, "Portal:: invalid end block.");
        require(_rewardsPerBlock.length == tokensReward.length, "Portal:: invalid rewards length.");
        updatePortalData();

        for (uint256 i = 0; i < _rewardsPerBlock.length; i++) {
            rewardPerBlock[i] = _rewardsPerBlock[i];
        }
        endBlock = _endBlock;
    }

    function withdrawRewards(address _user, address _token) external nonReentrant {
        uint256 currentReward = IERC20Metadata(_token).balanceOf(address(this));
        require(currentReward > 0, "Portal:: no rewards.");
        require(_token != address(portalToken), "Portal:: invalid token.");

        for (uint256 i = 0; i < tokensReward.length; i++) {
            require(_token != tokensReward[i], "Portal:: cannot withdraw from token rewards.");
        }
        IERC20Metadata(_token).safeTransfer(_user, currentReward);
    }

    // solhint-disable-next-line
    function updateUserReward(address _user) internal {
        UserInfo storage user = userInfo[_user];
        uint256 tokensRewardLength = tokensReward.length;

        for (uint256 i = user.debt.length; i < tokensRewardLength; i++) {
            user.debt.push(0);
        }

        for (uint256 i = user.reward.length; i < tokensRewardLength; i++) {
            user.reward.push(0);
        }

        if (user.amount > 0) {
            for (uint256 tokenIndex = 0; tokenIndex < tokensRewardLength; tokenIndex++) {
                uint256 totalDebt = (user.amount * rewardPerTokenStaked[tokenIndex]) / getTokenMultiplier(tokensReward[tokenIndex]);
                uint256 pendingDebt = totalDebt - user.debt[tokenIndex];

                if (pendingDebt > 0) {
                    user.reward[tokenIndex] = user.reward[tokenIndex] + pendingDebt;
                    user.debt[tokenIndex] = totalDebt;
                }
            }
        }
    }

    function userBalanceOf(address _user) public view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        return user.amount;
    }

    function getUserRewardDebt(address _userAddress, uint256 _index) public view returns (uint256) {
        UserInfo memory user = userInfo[_userAddress];
        return user.debt[_index];
    }

    function getUserOwedTokens(address _userAddress, uint256 _index) public view returns (uint256) {
        UserInfo memory user = userInfo[_userAddress];
        return user.reward[_index];
    }

    function portalStarted() public view returns (bool) {
        return block.number >= startBlock;
    }

    function getUserReward(address _userAddress, uint256 tokenIndex) public view returns (uint256) {
        uint256 currentBlock = block.number;
        uint256 latestBlock = (currentBlock < endBlock) ? currentBlock : endBlock;
        uint256 numberOfBlocksSinceLastUpdate = latestBlock - lastBlockUpdate;
        uint256 tokenMultiplier = getTokenMultiplier(tokensReward[tokenIndex]);

        uint256 rewardForLastPeriod = numberOfBlocksSinceLastUpdate * rewardPerBlock[tokenIndex];
        uint256 rewardPerTokenIncrease = (rewardForLastPeriod * tokenMultiplier) / totalStaked;
        uint256 currentMultiplier = rewardPerTokenStaked[tokenIndex] + rewardPerTokenIncrease;

        UserInfo memory user = userInfo[_userAddress];

        uint256 totalDebt = (user.amount * currentMultiplier) / tokenMultiplier;
        uint256 pendingDebt = totalDebt - user.debt[tokenIndex];
        return user.reward[tokenIndex] + pendingDebt;
    }

    function getUserTokensOwedLength(address _userAddress) public view returns (uint256) {
        UserInfo memory user = userInfo[_userAddress];
        return user.reward.length;
    }

    function getUserRewardDebtLength(address _userAddress) public view returns (uint256) {
        UserInfo memory user = userInfo[_userAddress];
        return user.debt.length;
    }

    function portalReward(uint256 tokenIndex) public view returns (uint256) {
        uint256 rewardsPeriod = endBlock - startBlock;
        return rewardPerBlock[tokenIndex] * rewardsPeriod;
    }

    function getRewardTokensCount() public view returns (uint256) {
        return tokensReward.length;
    }

    function getTokenMultiplier(address _token) internal view returns (uint256) {
        uint256 decimals = IERC20Metadata(_token).decimals();
        return 10**decimals;
    }

    function getPortalInfo()
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            address[] memory,
            address,
            uint256,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        return (
            endBlock,
            startBlock,
            userStakeLimit,
            totalStakeLimit,
            tokensReward,
            address(portalToken),
            lastBlockUpdate,
            totalRewards,
            rewardPerBlock,
            rewardPerTokenStaked
        );
    }

    function getStartAndEnd() public view returns (uint256, uint256) {
        return (endBlock, startBlock);
    }

    function getLimits() public view returns (uint256, uint256) {
        return (userStakeLimit, totalStakeLimit);
    }

    function getTokens() public view returns (address[] memory, address) {
        return (tokensReward, address(portalToken));
    }

    function getLastBlockUpdate() public view returns (uint256) {
        return lastBlockUpdate;
    }

    function getTotalRewards(uint256 _tokenIndex) public view returns (uint256) {
        return totalRewards[_tokenIndex];
    }

    function getRewardPerBlock(uint256 _tokenIndex) public view returns (uint256) {
        return rewardPerBlock[_tokenIndex];
    }

    function getRewardPerTokenStaked(uint256 _tokenIndex) public view returns (uint256) {
        return rewardPerTokenStaked[_tokenIndex];
    }

    function getRefundableReward(address _provider, uint256 _tokenIndex) public view returns (uint256) {
        uint256[] storage provider = providerRewardRatios[_provider];

        uint256 balance = portalToken.balanceOf(address(this));
        uint256 distributedReward = (balance * rewardPerTokenStaked[_tokenIndex]) / getTokenMultiplier(tokensReward[_tokenIndex]);
        uint256 nonDistributedReward = totalRewards[_tokenIndex] - distributedReward;

        return (nonDistributedReward * provider[_tokenIndex]) / totalRewardRatios[_tokenIndex];
    }

    function addReward(uint256[] memory _tokenAmounts, uint256 _duration) public nonReentrant {
        _addReward(_tokenAmounts, _duration, msg.sender);
    }

    function _addReward(
        uint256[] memory _tokenAmounts,
        uint256 _duration,
        address _provider
    ) internal {
        require(_tokenAmounts.length == tokensReward.length, "Portal:: invalid tokens length.");
        require(_duration != 0, "Portal:: duration cannot be 0.");

        updatePortalData();

        uint256[] storage provider = providerRewardRatios[_provider];

        uint256 newEndBlock = block.number + _duration > endBlock ? block.number + _duration : endBlock;

        for (uint256 i = 0; i < _tokenAmounts.length; i++) {
            console.log("\n");
            require(_tokenAmounts[i] > 0, "Portal:: reward cannot be 0.");

            if (provider.length < _tokenAmounts.length) {
                provider.push(0);
            }

            IERC20Metadata(tokensReward[i]).safeTransferFrom(_provider, address(this), _tokenAmounts[i]);

            uint256 balance = portalToken.balanceOf(address(this));
            console.log("rewardPerTokenStaked:", rewardPerTokenStaked[i]);
            uint256 distributedReward = (balance * rewardPerTokenStaked[i]) / getTokenMultiplier(tokensReward[i]);
            uint256 nonDistributedReward = totalRewards[i] - distributedReward;

            uint256 precision = getTokenMultiplier(tokensReward[i]);
            uint256 newRewardRatio = nonDistributedReward == 0 ? precision : (_tokenAmounts[i] * precision) / nonDistributedReward;

            provider[i] = provider[i] + newRewardRatio;
            totalRewardRatios[i] = totalRewardRatios[i] + provider[i];

            totalRewards[i] = totalRewards[i] + _tokenAmounts[i];
            rewardPerBlock[i] = (nonDistributedReward + _tokenAmounts[i]) / (newEndBlock - block.number);
        }

        endBlock = newEndBlock;
        // TODO: I believe this needs to be called here after the removal, but please check if that's correct
        // updatePortalData();
    }

    function removeReward() public nonReentrant {
        _removeReward(msg.sender);
    }

    function _removeReward(address _provider) internal {
        uint256[] storage provider = providerRewardRatios[_provider];

        require(endBlock > block.number, "Portal:: rewards distribution ended.");

        updatePortalData();

        for (uint256 i = 0; i < tokensReward.length; i++) {
            console.log("\n");
            uint256 balance = portalToken.balanceOf(address(this));
            console.log("rewardPerTokenStaked:", rewardPerTokenStaked[i]);
            uint256 distributedReward = (balance * rewardPerTokenStaked[i]) / getTokenMultiplier(tokensReward[i]);
            console.log("distributedReward:", distributedReward);
            uint256 nonDistributedReward = totalRewards[i] - distributedReward;

            uint256 providerPortion = (nonDistributedReward * provider[i]) / totalRewardRatios[i];
            console.log("providerPortion:", providerPortion);
            IERC20Metadata(tokensReward[i]).safeTransfer(_provider, providerPortion);

            totalRewardRatios[i] = totalRewardRatios[i] - provider[i];
            provider[i] = 0;

            totalRewards[i] = totalRewards[i] - providerPortion;
            rewardPerBlock[i] = (nonDistributedReward - providerPortion) / (endBlock - block.number);
        }

        // TODO: I believe this needs to be called here after the removal, but please check if that's correct
        // updatePortalData();
    }
}
