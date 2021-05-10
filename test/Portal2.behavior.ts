import { ethers } from "ethers";
import hre from "hardhat";

export function shouldBehaveLikePortal(): void {
  it("should add reward", async function () {
    await this.portal2.connect(this.signers.providers[0]).addReward(ethers.utils.parseEther("1000").toString(), "1000");
    console.log("TotalHarvestForDuration: ", (await this.portal2.harvestForDuration()).toString());

    await mineBlocks(hre.ethers.provider, 50);

    let user = this.signers.users[0];

    console.log("=========== USER 1 ===========");
    // Stake
    console.log("\nStake");
    await this.portal2.connect(user).stake(ethers.utils.parseEther("100").toString());
    await mineBlocks(hre.ethers.provider, 50);

    console.log("RewardPerToken: ", (await this.portal2.rewardPerTokenStaked()).toString());
    console.log("Earned: ", (await this.portal2.earned(user.address)).toString());

    // Withdraw;
    console.log("\nWithdraw");
    await this.portal2.connect(user).withdraw(ethers.utils.parseEther("100").toString());
    await mineBlocks(hre.ethers.provider, 50);
    console.log("RewardPerToken: ", (await this.portal2.rewardPerTokenStaked()).toString());
    console.log("Earned: ", (await this.portal2.earned(user.address)).toString());

    // Harvest;
    console.log("\nHarvest");
    await this.portal2.connect(user).harvest();
    await mineBlocks(hre.ethers.provider, 50);
    console.log("RewardPerToken: ", (await this.portal2.rewardPerTokenStaked()).toString());
    console.log("Earned: ", (await this.portal2.earned(user.address)).toString());
    console.log("DistributedReward", (await this.portal2.distributedReward()).toString());

    console.log("\n=========== USER 1 ===========");
    user = this.signers.users[1];
    // Stake
    console.log("\nStake");
    await this.portal2.connect(user).stake(ethers.utils.parseEther("100").toString());
    await mineBlocks(hre.ethers.provider, 50);
    console.log("RewardPerToken: ", (await this.portal2.rewardPerTokenStaked()).toString());
    console.log("Earned: ", (await this.portal2.earned(user.address)).toString());

    // Withdraw;
    console.log("\nWithdraw");
    await this.portal2.connect(user).withdraw(ethers.utils.parseEther("100").toString());
    await mineBlocks(hre.ethers.provider, 50);
    console.log("RewardPerToken: ", (await this.portal2.rewardPerTokenStaked()).toString());
    console.log("Earned: ", (await this.portal2.earned(user.address)).toString());

    // Harvest
    console.log("\nHarvest");
    await this.portal2.connect(user).harvest();
    await mineBlocks(hre.ethers.provider, 50);
    console.log("RewardPerToken: ", (await this.portal2.rewardPerTokenStaked()).toString());
    console.log("Earned: ", (await this.portal2.earned(user.address)).toString());
    console.log("DistributedReward", (await this.portal2.distributedReward()).toString());
  });
}

async function mineBlocks(provider: ethers.providers.JsonRpcProvider, blocks: number): Promise<void> {
  for (let i = 0; i <= blocks; i++) {
    await provider.send("evm_mine", []);
  }
}
