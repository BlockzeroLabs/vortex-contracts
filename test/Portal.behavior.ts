import { ethers } from "hardhat";

export function shouldBehaveLikePortal(): void {
  it("should add reward", async function () {
    // provider 0 adds reward -> block 0
    await this.portal
      .connect(this.signers.providers[0])
      .addReward([ethers.utils.parseEther("1000").toString(), ethers.utils.parseEther("250").toString()], "1000");

    // mine 100 blocks
    for (let i = 0; i < 99; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    // user 0 joins -> block 100
    await this.portal.connect(this.signers.users[0]).stake(ethers.utils.parseEther("1").toString());

    // mine 100 blocks
    for (let i = 0; i < 99; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    // // user 1 joins -> block 200
    await this.portal.connect(this.signers.users[1]).stake(ethers.utils.parseEther("1").toString());

    // mine 100 blocks
    for (let i = 0; i < 99; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    // // provider 1 adds reward -> block 300
    // await this.portal
    // .connect(this.signers.providers[1])
    // .addReward([ethers.utils.parseEther("500").toString(), ethers.utils.parseEther("25").toString()], "500");

    // mine 100 blocks
    for (let i = 0; i < 100; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    // provider 1 removes reward -> block 400
    // await this.portal
    //   .connect(this.signers.providers[1])
    //   .removeReward();

    // mine 100 blocks
    for (let i = 0; i < 100; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    // provider 0 removes reward -> block 500
    await this.portal.connect(this.signers.providers[0]).removeReward();

    // mine 100 blocks
    for (let i = 0; i < 99; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    await this.portal // user 1 harvests -> block 600
      .connect(this.signers.users[1])
      .harvest();

    // mine 100 blocks
    for (let i = 0; i < 99; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    await this.portal // user 0 harvests -> block 700
      .connect(this.signers.users[0])
      .harvest();

    const result = await this.portal.getPortalInfo();
    console.log("total rewards 0", result[7][0].toString());
    console.log("total rewards 1", result[7][1].toString());

    const balance0 = await this.rewards[0].balanceOf(this.portal.address);
    console.log("balance 0: ", balance0.toString());

    const balance1 = await this.rewards[1].balanceOf(this.portal.address);
    console.log("balance 1: ", balance1.toString());
  });
}
