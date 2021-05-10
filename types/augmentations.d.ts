// eslint-disable @typescript-eslint/no-explicit-any
import { Fixture } from "ethereum-waffle";

import { Signers } from "./";
import { ERC20, Portal } from "../typechain";

declare module "mocha" {
  export interface Context {
    rewards: ERC20[];
    stakingToken: ERC20;
    portal: Portal;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}
