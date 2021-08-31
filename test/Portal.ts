import hre from "hardhat";
import { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { Signers } from "../types";
import { ERC20, Portal } from "../typechain";

import { shouldBehaveLikePortal } from "./Portal.behavior";

const { deployContract } = hre.waffle;

const config = {
  duration: 1000,
  rewardsCount: 20,
};

describe("Integration tests", function () {
  before(async function () {
    this.signers = {} as Signers;
    this.rewards = [];

    // Configure users and providers
    const signers: SignerWithAddress[] = await hre.ethers.getSigners();
    this.signers.admin = signers[0];
    for (let i = 1; i < 4; i++) {
      this.signers.providers = signers.slice(1, 4);
      this.signers.users = signers.slice(4, 7);
    }

    // Deploy ERC20 tokens
    const erc20Artifact: Artifact = await hre.artifacts.readArtifact("TestToken");
    this.stakingToken = <ERC20>await deployContract(this.signers.admin, erc20Artifact, ["StakingToken", "ST", 6]);
    for (let i = 0; i < config.rewardsCount; i++) {
      this.rewards[i] = <ERC20>await deployContract(this.signers.admin, erc20Artifact, [`Token${i}`, `TT${i}`, 6]);
    }

    //Portal configuration
    const currentBlockNumber = await hre.ethers.provider.getBlockNumber();
    const _endBlock = currentBlockNumber + config.duration;

    // Deploy Portal
    const portalArtifact: Artifact = await hre.artifacts.readArtifact("Portal");
    this.portal = <Portal>(
      await deployContract(this.signers.admin, portalArtifact, [
        _endBlock,
        this.rewards.map(m => m.address),
        this.rewards.map(() => "0"),
        this.stakingToken.address,
        hre.ethers.utils.parseEther("1000"),
        hre.ethers.utils.parseEther("10000"),
        hre.ethers.utils.parseEther("2"),
      ])
    );

    // Mint and Approve reward tokens
    for (const t of this.rewards) {
      for (const p of this.signers.providers) {
        await t.mint(p.address, hre.ethers.utils.parseEther("5000000000"));
        await t.connect(p).approve(this.portal.address, hre.ethers.constants.MaxUint256.toString());
      }
    }

    // Mint and Approve staking tokens
    for (const u of this.signers.users) {
      await this.stakingToken.mint(u.address, hre.ethers.utils.parseEther("5000000000"));
      await this.stakingToken.connect(u).approve(this.portal.address, hre.ethers.constants.MaxUint256.toString());
    }
  });

  describe("Portal", function () {
    shouldBehaveLikePortal();
  });
});
