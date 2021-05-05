import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat";
import { approve } from "./approve";

const config = {
  duration: 1000,
  stakeLimit: ethers.utils.parseEther("10000").toString(),
  contractStakeLimit: ethers.utils.parseEther("100000000000").toString(),
  rewardPerBlock: [ethers.utils.parseEther("0.005").toString(), ethers.utils.parseEther("0.000025").toString()],
  rewardsToken: ["0xc8b23857d66ae204d195968714840a75d28dc217", "0x1371597fc11aedbd2446f5390fa1dbf22491752a"],
  stakingToken: "0x8f8a7cff6bfcb4b88b83aa9b61e0ac5d57546f98",
};

async function main(): Promise<void> {
  const currentBlockNumber = await ethers.provider.getBlockNumber();
  const [wallet] = await ethers.getSigners();

  const _startBlock = currentBlockNumber + 5;
  const _endBlock = currentBlockNumber + config.duration;

  const Portal: ContractFactory = await ethers.getContractFactory("Portal");

  const constructorArgs = [
    _startBlock,
    _endBlock,
    config.stakeLimit,
    config.contractStakeLimit,
    config.rewardPerBlock,
    config.rewardsToken,
    config.stakingToken,
  ];

  const portal: Contract = await Portal.deploy(...constructorArgs);
  console.log("Constructor arguments: ", constructorArgs);
  console.log("Portal address: ", portal.address);

  await portal.deployed();

  for (const t of config.rewardsToken) {
    console.log("Approving ", t);
    await approve(wallet, t, portal.address);
  }

  await portal.addReward([ethers.utils.parseEther("500"), ethers.utils.parseEther("250")], "1000");
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

// npx hardhat verify --network ropsten --constructor-args ./scripts/constructorArgs.ts 0xa2940A33554DD59dF51C3DD6B0A6bd21B4fd76D5
