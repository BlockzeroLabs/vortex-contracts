## Methods


`addReward(uint256[] rewards, uint256 newEndBlock)` - used to add rewards by the **Reward Providers**
`rewards` - array  that should contain amount for each reward token
`newEndBlock` - should always be greater than the current portal `endBlock` specified by either `createPortal` or `addReward`

`contractStakeLimit()` - returns the Portal stake limit

`distributedReward(uint256)` - returns distributed reward for a given token index

`distributionLimit()` - returns the limit before which distribution does not start

`earned(address,uint256)` - returns the earned amount per user and reward index

`endBlock()` - returns the portal end block

`exit()` - calls `harvest` and `withdraw`

`getTokenMultiplier(uint256)` - returns the token multiplier for given reward token index. If the token has 18 decimals it returns 10^18

`harvest(address)` - claims the reward for a given recipient address. This allows for a person to use his cold storage for staking and use a hot wallet to harvest the cold storage's rewards.

`harvestForDuration(uint256)` - returns the amount harvested for the reward duration period for a given reward token index. The reward duration is equal to: `endBlock - block.number`

`lastBlockRewardIsApplicable()` - returns the last block number the rewards should be distributed

`lastBlockUpdate()` - returns the last block where the rewards were updated

`migrate(uint256,address)`- used to transfer staked token to another portal

`minimumRewardRate(uint256)` - returns the minimum reward rate.

`providerRewardRatios(address,uint256)` - gives the provider reward ratio for a given provider and a reward token index. 

`removeReward()` - used by Reward Providers to remove/withdraw their provider reward. They cannot withdraw already distributed amounts.

`rewardPerTokenSnapshot(uint256)` - 

`rewardPerTokenStaked(uint256)` - returns the reward per each token that's staked for a given reward token index

`rewardRate(uint256)` - returns the reward rate for a given reward token index

`rewardsDuration()` - returns the reward duration in blocks. The duration specifies the amount of blocks the rewards are going to be distributed. At the end of the duration there should be 0 rewards inside the contract.

`rewardsToken(uint256)` - returns the token address for a given token index.

`stake(uint256,address)` - used by the users to stake tokens and specify the recipient. E.g. `stake(10*10^18, 0x1264...)` stakes 10 tokens and address **0x1264...** can harvest the rewards.

`stakingToken()` - returns staking token address

`totalEarned(uint256)` - returns the total earned tokens by a given reward token index.

`totalRewardRatios(uint256)` - returns the total reward ratios for all reward providers. E.g. if there is only 1 reward provider, his `providerRewardRatio` will be 1 and the `totalRewardRatios` will also be 1.

`totalRewards(uint256)` - returns the total rewards for a given reward token index

`totalStaked()` - returns the total amount of staked tokens.

`userStakeLimit()` - returns the user stake limit. Users cannot stake more than that limit. E.g. if the limit is 1000 tokens, each user can stake up to 1000 tokens.

`users(address)` - returns an user object by a given wallet address. The user object contains: 
`balance` - the staked balance
`userRewardPerTokenPaid[tokenIndex]` - the reward per token that's being paid
`rewards[tokenIndex]` - the rewards for each token

`withdraw(uint256)` - used by the staker to withdraw the staked amount
``

``createPortal(
uint256  _endBlock,
address[] memory  _rewardsToken,
uint256[] memory  _minimumRewardRate,
address  _stakingToken,
uint256  _stakeLimit,
uint256  _contractStakeLimit,
uint256  _distributionLimit
)`` - used to create a portal.

## Events
`event  PortalCreated(address  creator)`

`event  Harvested(address  recipient);`

`event  Withdrawn(address  recipient, uint256  amount);`

`event  Staked(address  staker, address  recipient, uint256  amount);`
