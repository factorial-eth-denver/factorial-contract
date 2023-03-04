import {
    MaxUint128,
} from "./constants";

const fs = require('fs');
import {ethers} from "hardhat";
import hre from 'hardhat'
import {
    FactorialRouter__factory,
    MockERC20__factory, OracleRouter__factory, SushiswapConnector__factory, TestHelper__factory,
    WrappedNativeToken__factory
} from "../typechain";

async function main() {
    // ----------------------file setting---------------------------------
    let readFileAddress = "../networks/" + hre.network.name + ".json";
    let writeFileAddress = "./networks/" + hre.network.name + ".json";

    const config = require(readFileAddress);

    const [deployer, user1] = await ethers.getSigners();

    let oracleRouter = await OracleRouter__factory.connect(config.ORACLE_ROUTER, deployer);
    console.log("usdc price" + await oracleRouter.getPrice(config.USDC));
    console.log("wmatic price :" + await oracleRouter.getPrice(config.WMATIC));
    console.log("usdc-wmatic sushi lp price :" + await oracleRouter.getPrice(config.SUSHI_WMATIC_USDC_LP));

    // ---------------------------write file-------------------------------
    fs.writeFileSync(writeFileAddress, JSON.stringify(config, null, 1));
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
