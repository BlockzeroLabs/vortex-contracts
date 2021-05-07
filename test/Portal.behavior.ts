import { ethers } from "hardhat";

export function shouldBehaveLikePortal(): void {
  it("should add reward", async function () {
    // add reward
    await this.portal
      .connect(this.signers.providers[0])
      .addReward([ethers.utils.parseEther("500").toString(), ethers.utils.parseEther("250").toString()], "1000");

    // mine 100 blocks
    for (let i = 0; i < 100; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    await this.portal
    .connect(this.signers.providers[1])
    .addReward([ethers.utils.parseEther("50").toString(), ethers.utils.parseEther("25").toString()], "500");

    // mine 50 blocks
    for (let i = 0; i < 100; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    // remove reward
    await this.portal
      .connect(this.signers.providers[1])
      .removeReward();

    // mine 50 blocks
    for (let i = 0; i < 100; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    await this.portal
      .connect(this.signers.providers[0])
      .removeReward();
  });
}
