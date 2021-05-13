// eslint-disable @typescript-eslint/no-explicit-any
import { Fixture } from "ethereum-waffle";

import { Signers } from "./";
import { ERC20, Portal } from "../typechain";

declare module "mocha" {
  export interface Context {
    portal: Portal;
    stakingToken: ERC20;
    rewards: ERC20[];
    signers: Signers;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
  }
}
