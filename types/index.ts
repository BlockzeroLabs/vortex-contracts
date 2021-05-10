import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

export interface Signers {
  admin: SignerWithAddress;
  users: SignerWithAddress[];
  providers: SignerWithAddress[];
}
