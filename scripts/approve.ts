import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const abi = [
  {
    constant: false,
    inputs: [
      {
        name: "_spender",
        type: "address",
      },
      {
        name: "_value",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [
      {
        name: "",
        type: "bool",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
];

export async function approve(provider: SignerWithAddress, token: string, spender: string): Promise<void> {
  const contract = new ethers.Contract(token, abi, provider);
  await contract.approve(spender, ethers.constants.MaxUint256);
}
