import { ethers } from "ethers";
import hre from "hardhat";

export function shouldBehaveLikePortal(): void {
  it("should add reward", async function () {
    console.log("=========== Provider 1 ===========");
    console.log("\nAdd");
    await this.portal2.connect(this.signers.providers[0]).addReward([ethers.utils.parseEther("1000").toString()], "1023");
    // console.log("TotalRewards: ", (await this.portal2.totalRewards(0)).toString());
    // console.log("TotalEarned: ", (await this.portal2.totalEarned(0)).toString());

    // console.log("harvestForDuration: ", (await this.portal2.harvestForDuration(0)).toString());
    // console.log("TotalRewards: ", (await this.portal2.totalRewards(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    console.log("=========== USER 1 ===========");
    console.log("\nStake");
    await this.portal2.connect(this.signers.users[0]).stake(ethers.utils.parseEther("100").toString());
    // console.log("TotalRewards: ", (await this.portal2.totalRewards(0)).toString());
    // console.log("TotalEarned: ", (await this.portal2.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    // console.log("RewardPerToken: ", (await this.portal2.rewardPerTokenSnapshot(0)).toString());
    // console.log("Earned: ", (await this.portal2.earned(user.address, 0)).toString());


    console.log("=========== USER 2 ===========");
    console.log("\nStake");
    await this.portal2.connect(this.signers.users[1]).stake(ethers.utils.parseEther("100").toString());

    await mineBlocks(hre.ethers.provider, 49);


    console.log("=========== Provider 2 ===========");
    console.log("\nAdd");
    await this.portal2.connect(this.signers.providers[1]).addReward([ethers.utils.parseEther("1000").toString()], "1023");
    // console.log("TotalRewards: ", (await this.portal2.totalRewards(0)).toString());
    // console.log("TotalEarned: ", (await this.portal2.totalEarned(0)).toString());

    // console.log("harvestForDuration: ", (await this.portal2.harvestForDuration(0)).toString());
    // console.log("TotalRewards: ", (await this.portal2.totalRewards(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);

    console.log("=========== USER 3 ===========");
    console.log("\nStake");
    await this.portal2.connect(this.signers.users[2]).stake(ethers.utils.parseEther("100").toString());

    await mineBlocks(hre.ethers.provider, 49);


    console.log("=========== USER 1 ===========");
    console.log("\nExit");
    await this.portal2.connect(this.signers.users[0]).withdraw(ethers.utils.parseEther("100").toString());
    await this.portal2.connect(this.signers.users[0]).harvest();

    // console.log("TotalRewards: ", (await this.portal2.totalRewards(0)).toString());
    // console.log("TotalEarned: ", (await this.portal2.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 48);
    // console.log("RewardPerToken: ", (await this.portal2.rewardPerTokenSnapshot(0)).toString());
    // console.log("Earned: ", (await this.portal2.earned(user.address, 0)).toString());


    console.log("=========== Provider 1 ===========");
    console.log("\nRemove");
    await this.portal2.connect(this.signers.providers[0]).removeReward();

    // console.log("TotalRewards: ", (await this.portal2.totalRewards(0)).toString());
    // console.log("TotalEarned: ", (await this.portal2.totalEarned(0)).toString());

    await mineBlocks(hre.ethers.provider, 49);
    // console.log("harvestForDuration: ", (await this.portal2.harvestForDuration(0)).toString());
    // console.log("TotalRewards: ", (await this.portal2.totalRewards(0)).toString());


    console.log("=========== USER 2 ===========");
    console.log("\nExit");
    await this.portal2.connect(this.signers.users[1]).exit();

    console.log("=========== USER 3 ===========");
    console.log("\nExit");
    await this.portal2.connect(this.signers.users[2]).exit();

    console.log("=========== Provider 2 ===========");
    console.log("\nRemove");
    await this.portal2.connect(this.signers.providers[1]).removeReward();
  });
}

async function mineBlocks(provider: ethers.providers.JsonRpcProvider, blocks: number): Promise<void> {
  for (let i = 0; i <= blocks; i++) {
    await provider.send("evm_mine", []);
  }
}
