import { ethers } from "ethers";
import hre from "hardhat";

export function shouldBehaveLikePortal(): void {
  it("Full scenarios", async function () {
    log("=========== PROVIDER 1 ===========");
    log("Add reward");

    const rewardAmount = ethers.utils.parseEther("1000").toString();
    await this.portal.connect(this.signers.providers[0]).addReward(
      this.rewards.map(() => rewardAmount),
      "1023",
    );
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    log("\n=========== USER 1 ===========");
    log("Stake");
    await this.portal.connect(this.signers.users[0]).stake(ethers.utils.parseEther("100").toString(), this.signers.users[0].address);
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    log("\n=========== USER 2 ===========");
    log("Stake");
    await this.portal.connect(this.signers.users[1]).stake(ethers.utils.parseEther("100").toString(), this.signers.users[1].address);
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    log("\n=========== PROVIDER 2 ===========");
    log("Add Reward");
    await this.portal.connect(this.signers.providers[1]).addReward(
      this.rewards.map(() => rewardAmount),
      "1023",
    );
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    log("\n=========== USER 3 ===========");
    log("Stake");
    await this.portal.connect(this.signers.users[2]).stake(ethers.utils.parseEther("100").toString(), this.signers.users[2].address);
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    log("\n=========== USER 1 ===========");
    log("Exit");
    await this.portal.connect(this.signers.users[0]).withdraw(ethers.utils.parseEther("100").toString());

    await this.portal.connect(this.signers.users[0]).functions["harvest(address)"](this.signers.users[0].address);
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 48);

    log("\n=========== PROVIDER 1 ===========");
    log("Remove Reward");
    await this.portal.connect(this.signers.providers[0]).removeReward();
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    log("\n=========== USER 2 ===========");
    log("Exit");
    await this.portal.connect(this.signers.users[1]).exit();
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    log("\n=========== USER 3 ===========");
    log("Exit");
    await this.portal.connect(this.signers.users[2]).exit();
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    log("\n=========== PROVIDER 2 ===========");
    log("Remove Reward");
    await this.portal.connect(this.signers.providers[1]).removeReward();

    log("Balance of contract: ", (await this.rewards[0].balanceOf(this.portal.address)).toString());
    log("Balance of Provider 1", (await this.rewards[0].balanceOf(this.signers.providers[0].address)).toString());
    log("Balance of Provider 2", (await this.rewards[0].balanceOf(this.signers.providers[1].address)).toString());
    log("Balance of User 1", (await this.rewards[0].balanceOf(this.signers.users[0].address)).toString());
    log("Balance of User 2", (await this.rewards[0].balanceOf(this.signers.users[1].address)).toString());
    log("Balance of User 3", (await this.rewards[0].balanceOf(this.signers.users[2].address)).toString());
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());
  });

  it("Distribution Limit Test", async function () {
    log("=========== PROVIDER 1 ===========");
    log("Add reward");

    const rewardAmount = ethers.utils.parseEther("1000").toString();
    await this.portal.connect(this.signers.providers[0]).addReward(
      this.rewards.map(() => rewardAmount),
      "1023",
    );
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    log("\n=========== USER 1 ===========");
    log("Stake");
    await this.portal.connect(this.signers.users[0]).stake(ethers.utils.parseEther("1").toString(), this.signers.users[0].address);
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    log("Exit");
    await this.portal.connect(this.signers.users[0]).functions["harvest(address)"](this.signers.users[0].address);
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    log("\n=========== PROVIDER 1 ===========");
    log("Remove Reward");
    await this.portal.connect(this.signers.providers[0]).removeReward();
    log("TotalRewards: ", (await this.portal.totalRewards(0)).toString());
    log("TotalEarned: ", (await this.portal.totalEarned(0)).toString());
  });
}

async function mineBlocks(provider: ethers.providers.JsonRpcProvider, blocks: number): Promise<void> {
  for (let i = 0; i <= blocks; i++) {
    await provider.send("evm_mine", []);
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function log(message?: any, ...optionalParams: any[]) {
  if (process.env.DEBUG) {
    console.log(message, ...optionalParams);
  }
}
