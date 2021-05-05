import hre from "hardhat";
import { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { Signers } from "../types";
import { shouldBehaveLikePortal } from "./Portal.behavior";
import { ERC20, Portal } from "../typechain";

const { deployContract } = hre.waffle;

const config = {
  duration: 1000,
  stakeLimit: hre.ethers.utils.parseEther("10000").toString(),
  contractStakeLimit: hre.ethers.utils.parseEther("100000000000").toString(),
  rewardPerBlock: [hre.ethers.utils.parseEther("0").toString(), hre.ethers.utils.parseEther("0").toString()],
};

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await hre.ethers.getSigners();
    this.signers.admin = signers[0];

    // Deploy ERC20 tokens
    const erc20Artifact: Artifact = await hre.artifacts.readArtifact("TestToken");
    this.rewards = [];
    this.rewards[0] = <ERC20>await deployContract(this.signers.admin, erc20Artifact, ["TestToken1", "TT1"]);
    this.rewards[1] = <ERC20>await deployContract(this.signers.admin, erc20Artifact, ["TestToken2", "TT2"]);
    this.stakingToken = <ERC20>await deployContract(this.signers.admin, erc20Artifact, ["StakingToken", "ST"]);

    //Portal configuration
    const currentBlockNumber = await hre.ethers.provider.getBlockNumber();
    const _startBlock = currentBlockNumber + 5;
    const _endBlock = currentBlockNumber + config.duration;

    // Deploy Portal
    const portalArtifact: Artifact = await hre.artifacts.readArtifact("Portal");
    this.portal = <Portal>(
      await deployContract(this.signers.admin, portalArtifact, [
        _startBlock,
        _endBlock,
        config.stakeLimit,
        config.contractStakeLimit,
        config.rewardPerBlock,
        this.rewards.map(m => m.address),
        this.stakingToken.address,
      ])
    );

    // Mint and Approve reward tokens
    for (const t of this.rewards) {
      await t.mint(this.signers.admin.address, hre.ethers.utils.parseEther("5000000000"));
      await t.approve(this.portal.address, hre.ethers.constants.MaxUint256.toString());
    }

    // Mint and Approve staking tokens
    await this.stakingToken.mint(this.signers.admin.address, hre.ethers.utils.parseEther("5000000000"));
    await this.stakingToken.approve(this.portal.address, hre.ethers.constants.MaxUint256.toString());
  });

  describe("Portal", function () {
    shouldBehaveLikePortal();
  });
});
