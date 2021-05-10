import hre from "hardhat";
import { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { Signers } from "../types";
import { shouldBehaveLikePortal } from "./Portal2.behavior";
import { ERC20, Portal2 } from "../typechain";

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
    for (let i = 1; i < 4; i++) {
      this.signers.providers = signers.slice(1, 4);
      this.signers.users = signers.slice(4, 7);
    }

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
    const portalArtifact: Artifact = await hre.artifacts.readArtifact("Portal2");
    this.portal2 = <Portal2>(
      await deployContract(this.signers.admin, portalArtifact, [_endBlock, this.rewards[0].address, this.stakingToken.address])
    );

    // Mint and Approve reward tokens
    for (const t of this.rewards) {
      for (const p of this.signers.providers) {
        await t.mint(p.address, hre.ethers.utils.parseEther("5000000000"));
        await t.connect(p).approve(this.portal2.address, hre.ethers.constants.MaxUint256.toString());
      }
    }

    // Mint and Approve staking tokens
    for (const u of this.signers.users) {
      await this.stakingToken.mint(u.address, hre.ethers.utils.parseEther("5000000000"));
      await this.stakingToken.connect(u).approve(this.portal2.address, hre.ethers.constants.MaxUint256.toString());
    }
  });

  describe("Portal", function () {
    shouldBehaveLikePortal();
  });
});
