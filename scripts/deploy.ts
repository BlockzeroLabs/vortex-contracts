import { Contract, ContractFactory } from "ethers";
// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main(): Promise<void> {
  const currentBlockNumber = await ethers.provider.getBlockNumber();

  const _startBlock = currentBlockNumber + 5;
  const _endBlock = currentBlockNumber + 10000;
  const _stakeLimit = ethers.utils.parseEther("10000").toString();
  const _contractStakeLimit = ethers.utils.parseEther("100000000000").toString();
  const _rewardPerBlock = [ethers.utils.parseEther("0.005").toString(), ethers.utils.parseEther("0.000025").toString()];
  const _rewardsTokens = ["0xc8b23857d66ae204d195968714840a75d28dc217", "0x1371597fc11aedbd2446f5390fa1dbf22491752a"];
  const _stakingToken = "0x8f8a7cff6bfcb4b88b83aa9b61e0ac5d57546f98";

  const Portal: ContractFactory = await ethers.getContractFactory("Portal");

  const constructorArgs = [_startBlock, _endBlock, _stakeLimit, _contractStakeLimit, _rewardPerBlock, _rewardsTokens, _stakingToken];

  const encodedArgs = ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256", "uint256[]", "uint256[]", "address"],
    constructorArgs,
  );

  console.log("Encoded Constructor arguments: ", encodedArgs);

  console.log("Constructor arguments: ", constructorArgs);

  const portal: Contract = await Portal.deploy(...constructorArgs);
  console.log("Portal address: ", portal.address);
  await portal.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

// npx hardhat verify --network ropsten --constructor-args ./scripts/constructorArgs.ts 0xa2940A33554DD59dF51C3DD6B0A6bd21B4fd76D5
