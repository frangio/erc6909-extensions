import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import { encodeAbiParameters } from "viem";
import { createERC5267Client } from "eip712domains/viem";

const ERC6909XApproveAndCall = [
  { name: "temporary", type: "bool" },
  { name: "owner", type: "address" },
  { name: "spender", type: "address" },
  { name: "operator", type: "bool" },
  { name: "id", type: "uint256" },
  { name: "amount", type: "uint256" },
  { name: "target", type: "address" },
  { name: "data", type: "bytes" },
  { name: "nonce", type: "uint256" },
  { name: "deadline", type: "uint256" },
] as const;

async function deployTestToken() {
  const tokenId = 0n;
  const tokenSupply = 100n;

  const [owner, receiver] = await hre.viem.getWalletClients();

  const token = await hre.viem.deployContract("TestToken", [
    owner.account.address,
    tokenId,
    tokenSupply,
  ]);

  const callback = await hre.viem.deployContract("TestCallback", [token.address]);

  const client = await hre.viem.getPublicClient();

  const { getEIP712Domain } = createERC5267Client(client);
  const domain = await getEIP712Domain(token.address);
  if (domain === undefined) {
    throw Error("Missing domain");
  }

  const { timestamp } = await client.getBlock();

  return {
    token,
    callback,
    tokenId,
    tokenSupply,
    owner,
    receiver,
    domain,
    timestamp,
  };
}

it("temporaryApproveAndCall", async function () {
  const { token, callback, tokenId, tokenSupply, owner, receiver } =
    await loadFixture(deployTestToken);

  const approvedAmount = tokenSupply / 2n;
  const transferAmount = approvedAmount / 2n;

  const data = encodeAbiParameters(
    [{ type: "address" }, { type: "uint256" }],
    [receiver.account.address, transferAmount],
  );

  await token.write.temporaryApproveAndCall(
    [callback.address, false, tokenId, approvedAmount, callback.address, data],
    { account: owner.account },
  );

  expect(await token.read.balanceOf([receiver.account.address, tokenId])).to.equal(transferAmount);
  expect(await token.read.balanceOf([owner.account.address, tokenId])).to.equal(tokenSupply - transferAmount);

  expect(await token.read.allowance([owner.account.address, callback.address, tokenId])).to.equal(0n);
});

it("temporaryApproveAndCallBySig", async function () {
  const { token, callback, tokenId, tokenSupply, owner, receiver, domain, timestamp } =
    await loadFixture(deployTestToken);

  const approvedAmount = tokenSupply / 2n;
  const transferAmount = approvedAmount / 2n;

  const data = encodeAbiParameters(
    [{ type: "address" }, { type: "uint256" }],
    [receiver.account.address, transferAmount],
  );

  const nonce = await token.read.nonces([owner.account.address]);
  const deadline = timestamp + 600n;

  const signature = await owner.signTypedData({
    domain,
    types: { ERC6909XApproveAndCall },
    primaryType: "ERC6909XApproveAndCall",
    message: {
      temporary: true,
      owner: owner.account.address,
      spender: callback.address,
      operator: false,
      id: tokenId,
      amount: approvedAmount,
      target: callback.address,
      data,
      nonce,
      deadline,
    },
  });

  await token.write.temporaryApproveAndCallBySig([
    owner.account.address,
    callback.address,
    false,
    tokenId,
    approvedAmount,
    callback.address,
    data,
    deadline,
    signature,
  ]);

  expect(await token.read.balanceOf([receiver.account.address, tokenId])).to.equal(transferAmount);
  expect(await token.read.balanceOf([owner.account.address, tokenId])).to.equal(tokenSupply - transferAmount);

  expect(await token.read.allowance([owner.account.address, callback.address, tokenId])).to.equal(0n);
  expect(await token.read.nonces([owner.account.address])).to.equal(nonce + 1n);
});

it("approveBySig", async function () {
  const { token, callback, tokenId, tokenSupply, owner, domain, timestamp } =
    await loadFixture(deployTestToken);

  const amount = tokenSupply / 2n;

  const nonce = await token.read.nonces([owner.account.address]);
  const deadline = timestamp + 600n;

  const signature = await owner.signTypedData({
    domain,
    types: { ERC6909XApproveAndCall },
    primaryType: "ERC6909XApproveAndCall",
    message: {
      temporary: false,
      owner: owner.account.address,
      spender: callback.address,
      operator: false,
      id: tokenId,
      amount,
      target: "0x0000000000000000000000000000000000000000",
      data: "0x",
      nonce,
      deadline,
    },
  });

  await token.write.approveBySig([
    owner.account.address,
    callback.address,
    false,
    tokenId,
    amount,
    deadline,
    signature,
  ]);

  expect(await token.read.allowance([owner.account.address, callback.address, tokenId])).to.equal(amount);
  expect(await token.read.nonces([owner.account.address])).to.equal(nonce + 1n);
});
