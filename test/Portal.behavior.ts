import { ethers } from "hardhat";

export function shouldBehaveLikePortal(): void {
  it("should add reward", async function () {
    // add reward
    await this.portal.addReward([ethers.utils.parseEther("500").toString(), ethers.utils.parseEther("250").toString()], "1000");

    // mine 100 blocks
    for (let i = 0; i < 100; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    // remove reward
    await this.portal.removeReward();
  });
}
