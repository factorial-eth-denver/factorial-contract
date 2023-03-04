import {
    MaxUint128,
} from "./constants";

const fs = require('fs');
import {ethers} from "hardhat";
import hre from 'hardhat'
import {
    FactorialRouter__factory,
    MockERC20__factory, SushiswapConnector__factory, TestHelper__factory,
    WrappedNativeToken__factory
} from "../typechain";

async function main() {
    // ----------------------file setting---------------------------------
    let readFileAddress = "../networks/" + hre.network.name + ".json";
    let writeFileAddress = "./networks/" + hre.network.name + ".json";

    const config = require(readFileAddress);

    const [deployer, user1] = await ethers.getSigners();


    let wmatic = await WrappedNativeToken__factory.connect(config.WMATIC, deployer);
    let usdc = await MockERC20__factory.connect(config.USDC, deployer);
    let helper = await TestHelper__factory.connect(config.HELPER, deployer);
    let sushiConnector = await SushiswapConnector__factory.connect(config.SUSHI_CONNECTOR, deployer);
    let router = await FactorialRouter__factory.connect(config.FACTORIAL_ROUTER, deployer);
    let lp = await MockERC20__factory.connect(config.SUSHI_WMATIC_USDC_LP, deployer);


    console.log("lp balance" + await lp.balanceOf(deployer.address));
    console.log("usdc balance :" + await usdc.balanceOf(deployer.address));
    console.log("wmatic balance :" + await wmatic.balanceOf(deployer.address));
    let usdcId = await helper.convertAddressToId(usdc.address);
    let wmaticId = await helper.convertAddressToId(wmatic.address);
    let mintCalldata = sushiConnector.interface.encodeFunctionData("mint",
        [[wmaticId, usdcId], ["100000000000000000", "100000"]])
    await router.execute(MaxUint128, sushiConnector.address, mintCalldata);
    let bal = await lp.balanceOf(deployer.address);
    console.log("lp balance" + bal);
    console.log("usdc balance :" + await usdc.balanceOf(deployer.address));
    console.log("wmatic balance :" + await wmatic.balanceOf(deployer.address));
    let burnCalldata = sushiConnector.interface.encodeFunctionData("burn",
        [[wmaticId, usdcId], bal])
    await router.execute(MaxUint128, sushiConnector.address, burnCalldata);

    console.log("lp balance" + await lp.balanceOf(deployer.address));
    console.log("usdc balance :" + await usdc.balanceOf(deployer.address));
    console.log("wmatic balance :" + await wmatic.balanceOf(deployer.address));

    // ---------------------------write file-------------------------------
    fs.writeFileSync(writeFileAddress, JSON.stringify(config, null, 1));
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
