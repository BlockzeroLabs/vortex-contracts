// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Portal is ReentrancyGuard, ERC20 {
    using SafeERC20 for IERC20Metadata;

    uint8 public immutable tokenDecimals;

    struct ProviderInfo {
        uint256[] initalRewards;
        uint256 startBlock;
        uint256 endBlock;
    }

    mapping(address => ProviderInfo) public providerInfo;

    uint256 public immutable startBlock;
    uint256 public immutable userStakeLimit;
    uint256 public immutable totalStakeLimit;

    uint256 public endBlock;
    uint256 public totalStaked;
    uint256 public lastBlockUpdate;

    uint256[] public rewardPerBlock;
    uint256[] public rewardPerTokenStaked;

    address[] public tokensReward;

    IERC20Metadata public immutable portalToken;

    struct UserInfo {
        uint256 amount;
        uint256[] debt;
        uint256[] reward;
    }

    mapping(address => UserInfo) public userInfo;

    constructor(
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _userStakeLimit,
        uint256 _totalStakeLimit,
        uint256[] memory _rewardPerBlock,
        address[] memory _tokensReward,
        IERC20Metadata _portalToken,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol) {
        require(_startBlock > block.number, "Portal:: invalid start block.");
        require(_endBlock > _startBlock, "Portal:: invalid end block.");
        require(_rewardPerBlock.length == _tokensReward.length, "Portal:: invalid rewards arrays.");
        require(_userStakeLimit != 0, "Portal:: invalid user stake limit.");
        require(_totalStakeLimit != 0, "Portal:: invalid total stake limit.");
        require(_decimals > 0, "Portal:: reward token decimals.");

        tokenDecimals = _decimals;

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

        if (user.debt.length != tokensReward.length) {
            uint256 rewardsTokensLength = tokensReward.length;
            for (uint256 i = user.debt.length; i < rewardsTokensLength; i++) {
                user.debt.push(0);
            }
        }

        if (user.reward.length != tokensReward.length) {
            uint256 rewardsTokensLength = tokensReward.length;
            for (uint256 i = user.reward.length; i < rewardsTokensLength; i++) {
                user.reward.push(0);
            }
        }

        if (user.amount > 0) {
            uint256 rewardsTokensLength = tokensReward.length;

            for (uint256 tokenIndex = 0; tokenIndex < rewardsTokensLength; tokenIndex++) {
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

    function addReward(uint256[] memory _tokenAmounts, uint256 _duration) public nonReentrant {
        _addReward(_tokenAmounts, _duration, msg.sender);
    }

    function _addReward(uint256[] memory _tokenAmounts, uint256 _duration, address _provider) internal {
        // TODO: handle case in which provider adds more reward on top of previous
        uint256 tokenAmountsLength = _tokenAmounts.length;
        require(_tokenAmounts.length == tokensReward.length, "Portal:: invalid tokens length.");
        require(_duration != 0 , "Portal:: duration cannot be 0.");

        updatePortalData();

        uint256 currentBlock = block.number;
        endBlock = currentBlock + _duration > endBlock ? currentBlock + _duration : endBlock;

        for (uint256 i = 0; i < tokenAmountsLength; i++) {
            if (_tokenAmounts[i] == 0) {
                continue;
            }

            IERC20Metadata(tokensReward[i]).safeTransferFrom(
                _provider,
                address(this),
                _tokenAmounts[i]
            );

            rewardPerBlock[i] = rewardPerBlock[i] + (_tokenAmounts[i] / (endBlock - currentBlock));
        }

        ProviderInfo storage provider = providerInfo[_provider];
        provider.endBlock = endBlock;
        provider.startBlock = currentBlock;
        provider.initalRewards = _tokenAmounts;

        // TODO: calculate LP tokens and mint them to user
        // _mint(address(_provider), _amount);
    }

    function removeReward() public nonReentrant {
        _removeReward(msg.sender);
    }

    function _removeReward(address _provider) internal {
        ProviderInfo memory provider = providerInfo[_provider];
        uint256 currentBlock = block.number;

        require(provider.endBlock < currentBlock, "Portal:: reward distribution ended.");

        updatePortalData();

        uint256 duration = provider.endBlock - provider.startBlock;
        uint256 portion = (currentBlock - provider.startBlock) / duration;

        for (uint256 i = 0; i < tokensReward.length; i++) {
            IERC20Metadata(tokensReward[i]).safeTransferFrom(
                _provider,
                address(this),
                provider.initalRewards[i] * portion
            );

            rewardPerBlock[i] = rewardPerBlock[i] - (provider.initalRewards[i] / duration);
            provider.initalRewards[i] = 0;
        }

        // TODO: provider endBlock and startBlock?
        // _burn(address(_provider), balanceOf(_provider));
    }
}
